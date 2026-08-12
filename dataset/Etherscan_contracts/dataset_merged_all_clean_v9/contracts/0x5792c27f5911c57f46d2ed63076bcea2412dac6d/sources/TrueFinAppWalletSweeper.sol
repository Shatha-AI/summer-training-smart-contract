// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

// ─────────────────────────────────────────────────────────────────────────────
//  AmanFiAppWalletSweeper V2
//  Supports non-standard ERC-20 tokens (USDT / USDC on Ethereum mainnet)
//  - Uses SafeERC20-style low-level call for transfers (handles void returns)
//  - Per-token decimal registry (supports 6-decimal USDT & USDC)
//  - minimumSweepAmount stored and set in raw token units (no decimal math)
//  - Backward-compatible with standard 18-decimal tokens
// ─────────────────────────────────────────────────────────────────────────────

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    // NOTE: We deliberately do NOT declare transfer / transferFrom here.
    // Ethereum USDT returns void, so calling the standard interface reverts.
    // All transfers go through _safeTransferFrom() below.
}

interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData) external view returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

contract TrueFinAppWalletSweeper is AutomationCompatibleInterface {

    // ─── State ────────────────────────────────────────────────────────────────

    address public masterWallet;
    address public owner;

    uint256 public GAS_FEE_AMOUNT;
    uint256 public constant SWEEP_INTERVAL = 24 hours;

    address[] public AmFiUsers;

    mapping(address => bool)    public approvedWallets;
    mapping(address => uint256) public lastSweepTime;
    mapping(address => bool)    public isSweepEnabled;

    // Token registry
    address[] public supportedTokens;
    mapping(address => bool)    public tokenExists;
    /// @dev Decimals for each registered token (e.g. 6 for USDT/USDC, 18 for most others)
    mapping(address => uint8)   public tokenDecimals;

    // Primary sweep token (USDT by default)
    address public usdtToken = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    /// @dev Minimum balance to trigger a sweep, stored in RAW token units.
    ///      e.g. for USDT (6 dec): 10 USDT = 10_000_000
    ///           for DAI  (18 dec): 10 DAI  = 10_000_000_000_000_000_000
    uint256 public minimumSweepAmount;

    // Chainlink Automation cursor
    uint256 public sweepCursor;
    uint256 public constant BATCH_SIZE = 100;

    // ─── Events ───────────────────────────────────────────────────────────────

    event WalletApproved(address indexed wallet);
    event WalletRemoved(address indexed wallet);
    event WalletFunded(address indexed wallet, uint256 amount);
    event TokensSwept(address indexed fromWallet, address indexed token, uint256 amount);
    event SweepExecuted(address indexed wallet, uint256 tokenCount);
    event TokenAdded(address indexed token, uint8 decimals);
    event TokenRemoved(address indexed token);
    event MasterWalletUpdated(address indexed newMasterWallet);
    event GasFeeAmountUpdated(uint256 newAmount);
    event MinimumSweepAmountUpdated(address indexed token, uint256 rawAmount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyApproved(address wallet) {
        require(approvedWallets[wallet], "Wallet not approved");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _masterWallet, address _owner, uint256 _gasFeeAmount) {
        require(_masterWallet != address(0), "Invalid master wallet");
        require(_owner != address(0), "Invalid owner");
        masterWallet  = _masterWallet;
        owner         = _owner;
        GAS_FEE_AMOUNT = _gasFeeAmount;
    }

    // ─── Safe Transfer (handles non-standard void-return tokens like USDT) ────

    /**
     * @dev Calls transferFrom via a low-level call.
     *      Handles both:
     *        • Standard ERC-20 (returns bool true)
     *        • Non-standard USDT on Ethereum (returns nothing / void)
     *      Reverts on failure in both cases.
     */
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        // abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        (bool callSuccess, bytes memory returnData) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        require(callSuccess, "TransferFrom call failed");

        // If the token returned data (standard ERC-20), it must decode to true
        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "TransferFrom returned false");
        }
        // If returnData is empty (non-standard USDT) and callSuccess == true → OK
    }

    /**
     * @dev Calls transfer via a low-level call (same pattern as above).
     *      Used for emergency withdrawals.
     */
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool callSuccess, bytes memory returnData) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        require(callSuccess, "Transfer call failed");
        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "Transfer returned false");
        }
    }

    // ─── Wallet Management ────────────────────────────────────────────────────

    /**
     * @dev Registers and funds a single custodial wallet with gas.
     */
    function registerAndFundWallet(address custodialWallet) external onlyOwner {
        require(custodialWallet != address(0), "Invalid address");
        require(!approvedWallets[custodialWallet], "Already approved");
        require(address(this).balance >= GAS_FEE_AMOUNT, "Insufficient ETH");

        approvedWallets[custodialWallet]  = true;
        isSweepEnabled[custodialWallet]   = true;
        lastSweepTime[custodialWallet]    = block.timestamp;
        AmFiUsers.push(custodialWallet);

        (bool success,) = payable(custodialWallet).call{value: GAS_FEE_AMOUNT}("");
        require(success, "Fund failed");

        emit WalletApproved(custodialWallet);
        emit WalletFunded(custodialWallet, GAS_FEE_AMOUNT);
    }

    /**
     * @dev Registers and funds multiple custodial wallets in one transaction.
     */
    function registerAndFundWalletsBatch(address[] calldata custodialWallets) external onlyOwner {
        require(custodialWallets.length > 0, "Empty array");
        uint256 totalRequired = custodialWallets.length * GAS_FEE_AMOUNT;
        require(address(this).balance >= totalRequired, "Insufficient ETH");

        for (uint256 i = 0; i < custodialWallets.length; i++) {
            address wallet = custodialWallets[i];
            require(wallet != address(0), "Invalid address");
            require(!approvedWallets[wallet], "Already approved");

            approvedWallets[wallet]  = true;
            isSweepEnabled[wallet]   = true;
            lastSweepTime[wallet]    = block.timestamp;
            AmFiUsers.push(wallet);

            (bool success,) = payable(wallet).call{value: GAS_FEE_AMOUNT}("");
            require(success, "Fund failed");

            emit WalletApproved(wallet);
            emit WalletFunded(wallet, GAS_FEE_AMOUNT);
        }
    }

    /**
     * @dev Removes a wallet from the approved list.
     */
    function removeWallet(address custodialWallet) external onlyOwner {
        require(approvedWallets[custodialWallet], "Not approved");
        approvedWallets[custodialWallet]  = false;
        isSweepEnabled[custodialWallet]   = false;
        emit WalletRemoved(custodialWallet);
    }

    // ─── Token Registry ───────────────────────────────────────────────────────

    /**
     * @dev Adds a supported token.
     * @param token  Token contract address
     * @param decimals  Token decimals (6 for USDT/USDC, 18 for most others)
     *
     * Example — add Ethereum USDT:
     *   addSupportedToken(0xdAC17F958D2ee523a2206206994597C13D831ec7, 6)
     *
     * Example — add USDC:
     *   addSupportedToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 6)
     */
    function addSupportedToken(address token, uint8 decimals) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!tokenExists[token], "Already supported");

        supportedTokens.push(token);
        tokenExists[token]   = true;
        tokenDecimals[token] = decimals;

        emit TokenAdded(token, decimals);
    }

    /**
     * @dev Removes a token from the supported list.
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(tokenExists[token], "Not supported");
        tokenExists[token] = false;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    /**
     * @dev Returns all supported token addresses.
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    // ─── Manual Sweep ─────────────────────────────────────────────────────────

    /**
     * @dev Sweeps all supported tokens from a single custodial wallet.
     *      Enforces 24-hour interval. Callable by anyone (wallet must be approved).
     */
    function sweepWallet(address custodialWallet) external onlyApproved(custodialWallet) {
        require(isSweepEnabled[custodialWallet], "Sweep disabled");
        require(
            block.timestamp >= lastSweepTime[custodialWallet] + SWEEP_INTERVAL,
            "Interval not met"
        );

        lastSweepTime[custodialWallet] = block.timestamp;
        uint256 sweptCount = 0;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token   = supportedTokens[i];
            uint256 balance = IERC20(token).balanceOf(custodialWallet);

            if (balance == 0) continue;

            uint256 allowed = IERC20(token).allowance(custodialWallet, address(this));
            if (allowed < balance) continue;

            // Use safe low-level call — works for USDT, USDC, and standard tokens
            (bool callSuccess, bytes memory returnData) = token.call(
                abi.encodeWithSelector(0x23b872dd, custodialWallet, masterWallet, balance)
            );
            bool transferred = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));

            if (transferred) {
                sweptCount++;
                emit TokensSwept(custodialWallet, token, balance);
            }
        }

        emit SweepExecuted(custodialWallet, sweptCount);
    }

    // ─── Batch Sweep (Automation) ─────────────────────────────────────────────

    /**
     * @dev Sweeps the primary USDT token across a batch of wallets.
     */
    function sweepBatch(uint256 startIndex, uint256 endIndex) public {
        _sweepBatchForToken(startIndex, endIndex, usdtToken);
    }

    /**
     * @dev Sweeps any supported token across a batch of wallets.
     */
    function sweepBatchSupportedToken(uint256 startIndex, uint256 endIndex, address token) public {
        require(tokenExists[token] || token == usdtToken, "Token not supported");
        _sweepBatchForToken(startIndex, endIndex, token);
    }

    /**
     * @dev Internal batch sweep core.
     *      Uses per-token minimumSweepAmount for the primary usdtToken,
     *      and sweeps any balance > 0 for other tokens.
     */
    function _sweepBatchForToken(uint256 startIndex, uint256 endIndex, address token) internal {
        require(endIndex >= startIndex, "Invalid range");
        require(endIndex - startIndex <= BATCH_SIZE, "Exceeds batch size");
        require(token != address(0), "Token not set");

        uint256 actualEnd = endIndex > AmFiUsers.length ? AmFiUsers.length : endIndex;

        for (uint256 i = startIndex; i < actualEnd; i++) {
            address wallet = AmFiUsers[i];

            if (!approvedWallets[wallet] || !isSweepEnabled[wallet]) continue;

            uint256 bal     = IERC20(token).balanceOf(wallet);
            uint256 allowed = IERC20(token).allowance(wallet, address(this));

            bool meetsMinimum;
            if (token == usdtToken) {
                // minimumSweepAmount is in raw token units (already accounts for decimals)
                meetsMinimum = (bal >= minimumSweepAmount);
            } else {
                meetsMinimum = (bal > 0);
            }

            if (!meetsMinimum || allowed < bal) continue;

            (bool callSuccess, bytes memory returnData) = token.call(
                abi.encodeWithSelector(0x23b872dd, wallet, masterWallet, bal)
            );
            bool transferred = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));

            if (transferred) {
                emit TokensSwept(wallet, token, bal);
            }
        }
    }

    // ─── Chainlink Automation ─────────────────────────────────────────────────

    function checkUpkeep(bytes calldata /* checkData */)
        external view override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (usdtToken == address(0) || AmFiUsers.length == 0) return (false, "");

        uint256 startIndex = sweepCursor >= AmFiUsers.length ? 0 : sweepCursor;
        uint256 checkEnd   = startIndex + 1000;
        if (checkEnd > AmFiUsers.length) checkEnd = AmFiUsers.length;

        for (uint256 i = startIndex; i < checkEnd; i++) {
            address wallet = AmFiUsers[i];
            if (approvedWallets[wallet] && isSweepEnabled[wallet] && _hasEnoughBalance(wallet)) {
                uint256 sweepEnd = i + BATCH_SIZE;
                if (sweepEnd > AmFiUsers.length) sweepEnd = AmFiUsers.length;
                return (true, abi.encode(i, sweepEnd));
            }
        }
        return (false, "");
    }

    function performUpkeep(bytes calldata performData) external override {
        (uint256 startIndex, uint256 endIndex) = abi.decode(performData, (uint256, uint256));
        sweepBatch(startIndex, endIndex);

        sweepCursor = endIndex >= AmFiUsers.length ? 0 : endIndex;
    }

    // ─── Internal Helpers ─────────────────────────────────────────────────────

    /**
     * @dev Checks whether a wallet has enough USDT balance and allowance to sweep.
     *      minimumSweepAmount is compared directly in raw token units.
     */
    function _hasEnoughBalance(address wallet) internal view returns (bool) {
        if (usdtToken == address(0)) return false;
        uint256 balance = IERC20(usdtToken).balanceOf(wallet);
        if (balance < minimumSweepAmount) return false;
        uint256 allowed = IERC20(usdtToken).allowance(wallet, address(this));
        return allowed >= balance;
    }

    // ─── View Helpers ─────────────────────────────────────────────────────────

    function getTokenBalance(address custodialWallet, address token) external view returns (uint256) {
        return IERC20(token).balanceOf(custodialWallet);
    }

    function getAllTokenBalances(address custodialWallet)
        external view
        returns (address[] memory tokens, uint256[] memory balances)
    {
        tokens   = supportedTokens;
        balances = new uint256[](supportedTokens.length);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            balances[i] = IERC20(supportedTokens[i]).balanceOf(custodialWallet);
        }
    }

    function getTimeUntilNextSweep(address custodialWallet) external view returns (uint256) {
        uint256 next = lastSweepTime[custodialWallet] + SWEEP_INTERVAL;
        return block.timestamp >= next ? 0 : next - block.timestamp;
    }

    // ─── Admin Configuration ──────────────────────────────────────────────────

    function setMasterWallet(address newMasterWallet) external onlyOwner {
        require(newMasterWallet != address(0), "Invalid address");
        masterWallet = newMasterWallet;
        emit MasterWalletUpdated(newMasterWallet);
    }

    function setSweepEnabled(address custodialWallet, bool enabled) external onlyOwner {
        require(approvedWallets[custodialWallet], "Not approved");
        isSweepEnabled[custodialWallet] = enabled;
    }

    /**
     * @dev Sets the primary token used for Chainlink Automation sweeps.
     * @param _token  Token address (e.g. USDT 0xdAC17F958D2ee523a2206206994597C13D831ec7)
     */
    function setUsdtToken(address _token) external onlyOwner {
        usdtToken = _token;
    }

    function setGasFeeAmount(uint256 _gasFeeAmount) external onlyOwner {
        require(_gasFeeAmount > 0, "Invalid amount");
        GAS_FEE_AMOUNT = _gasFeeAmount;
        emit GasFeeAmountUpdated(_gasFeeAmount);
    }

    /**
     * @dev Sets the minimum sweep threshold in RAW token units.
     *
     * You must pass the amount already scaled to the token's decimals:
     *
     *   USDT / USDC (6 decimals):
     *     10 tokens → pass 10_000_000
     *
     *   DAI / WETH (18 decimals):
     *     10 tokens → pass 10_000_000_000_000_000_000
     *
     * This replaces the old helper that hardcoded * 10**18 and was
     * wrong for USDT/USDC.
     *
     * @param _rawAmount  Amount in smallest token unit (no decimal multiplication applied here)
     */
    function setMinimumSweepAmount(uint256 _rawAmount) external onlyOwner {
        require(_rawAmount > 0, "Amount must be > 0");
        minimumSweepAmount = _rawAmount;
        emit MinimumSweepAmountUpdated(usdtToken, _rawAmount);
    }

    /**
     * @dev Convenience setter: provide a human-readable amount and the token address.
     *      Reads decimals from the registry and scales automatically.
     *
     * Example: setMinimumSweepAmountHuman(10, usdtAddress) → stores 10_000_000 for 6-dec USDT
     *
     * @param humanAmount  Amount in whole tokens (e.g. 10 for "10 USDT")
     * @param token        Token whose decimal record to use (must be registered)
     */
    function setMinimumSweepAmountHuman(uint256 humanAmount, address token) external onlyOwner {
        require(humanAmount > 0, "Amount must be > 0");
        require(tokenExists[token] || token == usdtToken, "Token not registered");
        uint8 dec = tokenDecimals[token];
        minimumSweepAmount = humanAmount * (10 ** uint256(dec));
        emit MinimumSweepAmountUpdated(token, minimumSweepAmount);
    }

    // ─── ETH / Token Recovery ─────────────────────────────────────────────────

    receive() external payable {}

    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient ETH");
        (bool success,) = payable(owner).call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Emergency token withdrawal using safe low-level call.
     */
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        _safeTransfer(token, owner, amount);
    }
}