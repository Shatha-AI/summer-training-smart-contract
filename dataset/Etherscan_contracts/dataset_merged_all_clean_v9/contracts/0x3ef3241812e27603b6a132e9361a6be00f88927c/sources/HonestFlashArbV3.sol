// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// ============================================================
//  HonestFlashArbV3
//  Two-leg flash-loan arbitrage executor.
//
//  Improvements over V2:
//    1.  Dedicated nonReentrant modifier.
//    2.  Runtime whitelist management (setRouter / setToken).
//    3.  Two-step ownership transfer.
//    4.  Profit withdrawal usable while contract is live.
//    5.  On-chain slippage floor enforced inside _checkPlan.
//    6.  Maximum loan cap configurable by the owner.
//    7.  Deadline minimum buffer (>= block.timestamp + 60 s).
//    8.  Richer FlashCompleted event (routers included).
//    9.  simulatePlan view function for free off-chain dry-runs.
//   10.  Full NatSpec documentation.
//
//  Stack fix:
//    executeOperation fully delegated to _runArb to eliminate
//    all local variables from the callback frame.
// ============================================================


// ─────────────────────────────────────────────────────────────
//  Interfaces
// ─────────────────────────────────────────────────────────────

interface IERC20Minimal {
    function balanceOf(address who) external view returns (uint256);
    function transfer(address recipient, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

interface IAaveSimplePool {
    function flashLoanSimple(
        address receiver,
        address asset,
        uint256 amount,
        bytes calldata data,
        uint16 referralCode
    ) external;
}

interface IAaveSimpleFlashBorrower {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata data
    ) external returns (bool);
}

interface IRouterV2Like {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 minAmountOut,
        address[] calldata route,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}


// ─────────────────────────────────────────────────────────────
//  TokenOps library
// ─────────────────────────────────────────────────────────────

library TokenOps {
    error TokenCallReverted(address token);
    error TokenCallReturnedFalse(address token);

    function safeSend(IERC20Minimal token, address recipient, uint256 value) internal {
        _invoke(token, abi.encodeWithSelector(token.transfer.selector, recipient, value));
    }

    function safeApproveExact(IERC20Minimal token, address spender, uint256 value) internal {
        bytes memory payload = abi.encodeWithSelector(token.approve.selector, spender, value);
        if (!_invokeBool(token, payload)) {
            _invoke(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _invoke(token, payload);
        }
    }

    function _invoke(IERC20Minimal token, bytes memory payload) private {
        (bool ok, bytes memory ret) = address(token).call(payload);
        if (!ok) revert TokenCallReverted(address(token));
        if (ret.length > 0 && !abi.decode(ret, (bool))) revert TokenCallReturnedFalse(address(token));
    }

    function _invokeBool(IERC20Minimal token, bytes memory payload) private returns (bool) {
        (bool ok, bytes memory ret) = address(token).call(payload);
        return ok && (ret.length == 0 || abi.decode(ret, (bool)));
    }
}


// ─────────────────────────────────────────────────────────────
//  Main contract
// ─────────────────────────────────────────────────────────────

/// @title  HonestFlashArbV3
/// @notice Owner-controlled two-leg flash-loan arbitrage executor.
contract HonestFlashArbV3 is IAaveSimpleFlashBorrower {
    using TokenOps for IERC20Minimal;

    // ── Errors ────────────────────────────────────────────────

    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error BadPlan();
    error BadCallback();
    error LoanAlreadyOpen();
    error NoLoanOpen();
    error RouterNotAllowed(address router);
    error TokenNotAllowed(address token);
    error GainTooSmall();
    error ContractPaused();
    error MustBePaused();
    error NativeTransfersDisabled();
    error Reentrancy();
    error AmountExceedsCap();
    error SlippageTooPermissive();
    error NoPendingOwner();

    // ── Structs ───────────────────────────────────────────────

    /// @notice Full description of a two-leg arbitrage trade.
    struct ArbPlan {
        address router1;
        address router2;
        address[] path1;
        address[] path2;
        uint256 amountOutMin1;
        uint256 amountOutMin2;
        uint256 minProfit;
        uint256 deadline;
    }

    // ── State ─────────────────────────────────────────────────

    address public immutable pool;
    address public owner;
    address public pendingOwner;

    bool public paused;
    bool private _locked;
    bool public loanOpen;

    bytes32 public activePlanHash;
    address public activeAsset;
    uint256 public activeAmount;
    uint256 public balanceBefore;

    uint256 public maxLoanAmount;
    uint256 public minSlippageBps;

    mapping(address => bool) public routerWhitelist;
    mapping(address => bool) public tokenWhitelist;

    // ── Events ────────────────────────────────────────────────

    event OwnershipTransferInitiated(address indexed candidate);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PauseStatusChanged(bool isPaused);
    event RouterUpdated(address indexed router, bool allowed);
    event TokenUpdated(address indexed token, bool allowed);
    event MaxLoanAmountUpdated(uint256 newCap);
    event MinSlippageBpsUpdated(uint256 newBps);
    event FlashRequested(address indexed asset, uint256 amount);
    event FlashCompleted(
        address indexed asset,
        uint256 amount,
        uint256 premium,
        uint256 profit,
        address indexed router1,
        address indexed router2
    );
    event ProfitWithdrawn(address indexed token, address indexed recipient, uint256 amount);
    event TokenRecovered(address indexed token, address indexed recipient, uint256 amount);

    // ── Modifiers ─────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenRunning() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    // ── Constructor ───────────────────────────────────────────

    /// @notice Deploys the contract and seeds whitelists and parameters.
    constructor(
        address pool_,
        address[] memory routers,
        address[] memory tokens,
        uint256 maxLoanAmount_,
        uint256 minSlippageBps_
    ) {
        if (pool_ == address(0)) revert ZeroAddress();
        owner          = msg.sender;
        pool           = pool_;
        maxLoanAmount  = maxLoanAmount_;
        minSlippageBps = minSlippageBps_;

        for (uint256 i = 0; i < routers.length; ) {
            if (routers[i] == address(0)) revert ZeroAddress();
            routerWhitelist[routers[i]] = true;
            emit RouterUpdated(routers[i], true);
            unchecked { ++i; }
        }
        for (uint256 i = 0; i < tokens.length; ) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            tokenWhitelist[tokens[i]] = true;
            emit TokenUpdated(tokens[i], true);
            unchecked { ++i; }
        }
    }

    // ── Ownership ─────────────────────────────────────────────

    /// @notice Step 1 of ownership transfer — nominate a candidate.
    function transferOwnership(address candidate) external onlyOwner {
        if (candidate == address(0)) revert ZeroAddress();
        pendingOwner = candidate;
        emit OwnershipTransferInitiated(candidate);
    }

    /// @notice Step 2 of ownership transfer — candidate accepts.
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NoPendingOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner        = msg.sender;
        pendingOwner = address(0);
    }

    // ── Pause ─────────────────────────────────────────────────

    function pause() external onlyOwner {
        paused = true;
        emit PauseStatusChanged(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit PauseStatusChanged(false);
    }

    // ── Whitelist management ──────────────────────────────────

    /// @notice Add or remove a DEX router from the whitelist.
    function setRouter(address router, bool allowed) external onlyOwner {
        if (router == address(0)) revert ZeroAddress();
        routerWhitelist[router] = allowed;
        emit RouterUpdated(router, allowed);
    }

    /// @notice Add or remove a token from the whitelist.
    function setToken(address token, bool allowed) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        tokenWhitelist[token] = allowed;
        emit TokenUpdated(token, allowed);
    }

    // ── Parameter management ──────────────────────────────────

    /// @notice Update the maximum flash-loan size.
    function setMaxLoanAmount(uint256 cap) external onlyOwner {
        maxLoanAmount = cap;
        emit MaxLoanAmountUpdated(cap);
    }

    /// @notice Update the minimum slippage floor in basis points.
    function setMinSlippageBps(uint256 bps) external onlyOwner {
        minSlippageBps = bps;
        emit MinSlippageBpsUpdated(bps);
    }

    // ── Core arbitrage ────────────────────────────────────────

    /// @notice Initiates a two-leg flash-loan arbitrage via Aave V3.
    function startArbitrage(
        address asset,
        uint256 amount,
        ArbPlan calldata plan
    ) external onlyOwner whenRunning nonReentrant {
        if (loanOpen)            revert LoanAlreadyOpen();
        if (asset == address(0)) revert ZeroAddress();
        if (amount == 0)         revert ZeroAmount();
        if (amount > maxLoanAmount) revert AmountExceedsCap();

        _checkPlan(asset, amount, plan);

        bytes memory encodedPlan = abi.encode(plan);

        loanOpen       = true;
        activePlanHash = keccak256(encodedPlan);
        activeAsset    = asset;
        activeAmount   = amount;
        balanceBefore  = IERC20Minimal(asset).balanceOf(address(this));

        emit FlashRequested(asset, amount);

        IAaveSimplePool(pool).flashLoanSimple(address(this), asset, amount, encodedPlan, 0);

        if (loanOpen) revert BadCallback();
    }

    // ── Aave callback ─────────────────────────────────────────

    /// @notice Invoked by Aave after transferring borrowed funds.
    /// @dev    Guards are checked here; all swap logic delegated to _runArb
    ///         to keep this frame's stack depth minimal.
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata data
    ) external override whenRunning returns (bool) {
        if (msg.sender != pool)         revert BadCallback();
        if (initiator != address(this)) revert BadCallback();
        if (!loanOpen)                  revert NoLoanOpen();
        if (asset != activeAsset || amount != activeAmount) revert BadCallback();
        if (keccak256(data) != activePlanHash) revert BadCallback();

        _runArb(asset, amount, premium, data);
        return true;
    }

    // ── Fund management ───────────────────────────────────────

    /// @notice Withdraw accumulated profit while the contract is live.
    function withdrawProfit(address token, address to, uint256 amount)
        external onlyOwner whenRunning nonReentrant
    {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        IERC20Minimal(token).safeSend(to, amount);
        emit ProfitWithdrawn(token, to, amount);
    }

    /// @notice Emergency token recovery — only available while paused.
    function sweepToken(address token, address to, uint256 amount)
        external onlyOwner nonReentrant
    {
        if (!paused) revert MustBePaused();
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        IERC20Minimal(token).safeSend(to, amount);
        emit TokenRecovered(token, to, amount);
    }

    // ── Simulation helper ─────────────────────────────────────

    /// @notice Validate a plan off-chain for free before submitting a live tx.
    /// @return valid  True if all checks pass.
    /// @return reason Human-readable failure description, empty on success.
    function simulatePlan(address asset, uint256 amount, ArbPlan calldata plan)
        external view returns (bool valid, string memory reason)
    {
        if (paused)                 return (false, "contract paused");
        if (asset == address(0))    return (false, "zero asset");
        if (amount == 0)            return (false, "zero amount");
        if (amount > maxLoanAmount) return (false, "exceeds loan cap");
        if (!tokenWhitelist[asset]) return (false, "asset not whitelisted");
        if (!routerWhitelist[plan.router1]) return (false, "router1 not allowed");
        if (!routerWhitelist[plan.router2]) return (false, "router2 not allowed");
        if (plan.path1.length < 2 || plan.path2.length < 2) return (false, "path too short");
        if (plan.path1[0] != asset) return (false, "path1 must start with asset");
        if (plan.path2[plan.path2.length - 1] != asset) return (false, "path2 must end with asset");
        if (plan.path1[plan.path1.length - 1] != plan.path2[0]) return (false, "bridge token mismatch");
        if (plan.amountOutMin1 == 0 || plan.amountOutMin2 == 0 || plan.minProfit == 0) return (false, "zero minimum");
        if (plan.amountOutMin1 < (amount * (10_000 - minSlippageBps)) / 10_000) return (false, "amountOutMin1 below slippage floor");
        if (plan.deadline < block.timestamp + 60) return (false, "deadline too soon");

        for (uint256 i = 0; i < plan.path1.length; ) {
            if (!tokenWhitelist[plan.path1[i]]) return (false, "path1 token not whitelisted");
            unchecked { ++i; }
        }
        for (uint256 i = 0; i < plan.path2.length; ) {
            if (!tokenWhitelist[plan.path2[i]]) return (false, "path2 token not whitelisted");
            unchecked { ++i; }
        }
        return (true, "");
    }

    // ─────────────────────────────────────────────────────────
    //  Private helpers
    // ─────────────────────────────────────────────────────────

    /// @dev Contains all swap + profit logic for the flash callback.
    ///      Fully isolated from executeOperation to eliminate its local variables.
    function _runArb(
        address asset,
        uint256 amount,
        uint256 premium,
        bytes calldata data
    ) private {
        ArbPlan memory plan = abi.decode(data, (ArbPlan));
        _checkPlan(asset, amount, plan);

        if (IERC20Minimal(asset).balanceOf(address(this)) < balanceBefore + amount) {
            revert BadCallback();
        }

        // Leg 1: borrowed asset -> bridge token.
        uint256 bridgeAmount = _executeLeg1(asset, amount, plan);

        // Leg 2: bridge token -> borrowed asset.
        _executeLeg2(plan.path1[plan.path1.length - 1], bridgeAmount, plan);

        // Profit check.
        uint256 debt          = amount + premium;
        uint256 endingBalance = IERC20Minimal(asset).balanceOf(address(this));
        if (endingBalance < balanceBefore + debt + plan.minProfit) revert GainTooSmall();

        uint256 profit  = endingBalance - balanceBefore - debt;
        address router1 = plan.router1;
        address router2 = plan.router2;

        _resetLoanState();

        IERC20Minimal(asset).safeApproveExact(pool, debt);

        emit FlashCompleted(asset, amount, premium, profit, router1, router2);
    }

    /// @dev Leg 1: swap borrowed asset to bridge token.
    function _executeLeg1(
        address asset,
        uint256 amount,
        ArbPlan memory plan
    ) private returns (uint256 bridgeAmount) {
        IERC20Minimal(asset).safeApproveExact(plan.router1, amount);
        uint256[] memory out = IRouterV2Like(plan.router1).swapExactTokensForTokens(
            amount, plan.amountOutMin1, plan.path1, address(this), plan.deadline
        );
        IERC20Minimal(asset).safeApproveExact(plan.router1, 0);
        bridgeAmount = out[out.length - 1];
    }

    /// @dev Leg 2: swap bridge token back to borrowed asset.
    function _executeLeg2(
        address bridgeToken,
        uint256 bridgeAmount,
        ArbPlan memory plan
    ) private {
        IERC20Minimal(bridgeToken).safeApproveExact(plan.router2, bridgeAmount);
        IRouterV2Like(plan.router2).swapExactTokensForTokens(
            bridgeAmount, plan.amountOutMin2, plan.path2, address(this), plan.deadline
        );
        IERC20Minimal(bridgeToken).safeApproveExact(plan.router2, 0);
    }

    /// @dev Validates routers, paths, minimums, slippage floor, and deadline.
    function _checkPlan(address asset, uint256 amount, ArbPlan memory plan) internal view {
        if (!tokenWhitelist[asset])         revert TokenNotAllowed(asset);
        if (!routerWhitelist[plan.router1]) revert RouterNotAllowed(plan.router1);
        if (!routerWhitelist[plan.router2]) revert RouterNotAllowed(plan.router2);
        if (plan.path1.length < 2 || plan.path2.length < 2) revert BadPlan();
        if (plan.path1[0] != asset)                          revert BadPlan();
        if (plan.path2[plan.path2.length - 1] != asset)      revert BadPlan();
        if (plan.path1[plan.path1.length - 1] != plan.path2[0]) revert BadPlan();
        if (plan.amountOutMin1 == 0 || plan.amountOutMin2 == 0 || plan.minProfit == 0) revert BadPlan();
        if (plan.amountOutMin1 < (amount * (10_000 - minSlippageBps)) / 10_000) revert SlippageTooPermissive();
        if (plan.deadline < block.timestamp + 60) revert BadPlan();
        _checkWhitelistedPath(plan.path1);
        _checkWhitelistedPath(plan.path2);
    }

    /// @dev Reverts if any token in the path is not whitelisted.
    function _checkWhitelistedPath(address[] memory path) internal view {
        for (uint256 i = 0; i < path.length; ) {
            if (!tokenWhitelist[path[i]]) revert TokenNotAllowed(path[i]);
            unchecked { ++i; }
        }
    }

    /// @dev Clears all flash-loan bookkeeping after a completed loan.
    function _resetLoanState() internal {
        loanOpen       = false;
        activePlanHash = bytes32(0);
        activeAsset    = address(0);
        activeAmount   = 0;
        balanceBefore  = 0;
    }

    // ── Reject native ETH ─────────────────────────────────────

    receive() external payable { revert NativeTransfersDisabled(); }
    fallback() external payable { revert NativeTransfersDisabled(); }
}