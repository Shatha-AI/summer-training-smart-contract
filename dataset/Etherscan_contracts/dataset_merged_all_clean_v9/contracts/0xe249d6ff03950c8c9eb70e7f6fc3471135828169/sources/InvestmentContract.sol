// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ─────────────────────────────────────────────────────────────────────────────
// Uniswap Permit2 — SignatureTransfer interface
// Deployed at: 0x000000000022D473030F116dDEE9F6B43aC78BA3 (all EVM chains)
// ─────────────────────────────────────────────────────────────────────────────
interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    /// @notice Transfers tokens using a signed permit.
    /// @param permit      The permit data including token, amount, nonce, deadline.
    /// @param transferDetails Destination and requested amount.
    /// @param owner       The address that signed the permit (token owner).
    /// @param signature   EIP-712 signature over the permit.
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal ERC-20 interface (SafeTransfer pattern)
// ─────────────────────────────────────────────────────────────────────────────
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// ─────────────────────────────────────────────────────────────────────────────
// InvestmentContract
//
// Flow for tokens:
//   1. User calls `approve(Permit2, MaxUint256)` ONCE on the token contract
//      (or has already done so — connector checks allowance before showing)
//   2. Backend signs nothing — user signs PermitTransferFrom off-chain
//   3. Backend calls depositTokenPermit2(..., owner = userAddress, ...)
//   4. Permit2 verifies the signature against `owner` and pulls tokens here
// ─────────────────────────────────────────────────────────────────────────────
contract InvestmentContract {

    // ── State ──────────────────────────────────────────────────────────────
    address public owner;
    uint256 public nextDepositId = 1;

    IPermit2 public constant PERMIT2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    // ── Data ───────────────────────────────────────────────────────────────
    struct Deposit {
        uint256 userId;
        address userWallet;  // tracking wallet (e.g. same as from)
        address token;       // address(0) for native ETH
        address from;        // actual token owner / ETH sender
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256[]) public userDeposits;

    event DepositCreated(
        uint256 indexed id,
        address indexed from,
        address token,
        uint256 amount
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ── Modifiers ──────────────────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // ── Constructor ────────────────────────────────────────────────────────
    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    // ── Owner management ───────────────────────────────────────────────────
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ── Deposit: native ETH ────────────────────────────────────────────────
    /// @notice Accepts ETH and records the deposit.
    /// @param userId   Internal user ID from the backend.
    /// @param wallet   User's wallet address for record-keeping.
    function depositNative(uint256 userId, address wallet)
        external
        payable
    {
        require(msg.value > 0, "zero value");
        _createDeposit(userId, wallet, address(0), msg.sender, msg.value);
    }

    // ── Deposit: ERC-20 via Permit2 ────────────────────────────────────────
    /// @notice Pulls ERC-20 tokens using a Permit2 PermitTransferFrom signature.
    ///         The user must have approved Permit2 on the token contract first.
    ///
    /// @param userId    Internal user ID from the backend.
    /// @param wallet    User's wallet address for record-keeping.
    /// @param tokenOwner The address that owns the tokens and signed the permit.
    ///                   MUST equal the address passed as `owner` to Permit2.
    /// @param token     ERC-20 token address.
    /// @param amount    Exact amount to pull (wei units).
    /// @param nonce     One-time nonce embedded in the signed permit.
    /// @param deadline  Unix timestamp after which the permit expires.
    /// @param signature EIP-712 PermitTransferFrom signature from `tokenOwner`.
    function depositTokenPermit2(
        uint256 userId,
        address wallet,
        address tokenOwner,   // ← the user who signed, NOT msg.sender
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(tokenOwner != address(0), "zero owner");
        require(token != address(0), "zero token");
        require(amount > 0, "zero amount");
        require(deadline >= block.timestamp, "permit expired");

        // Build the permit struct matching what the user signed
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: token,
                amount: amount
            }),
            nonce: nonce,
            deadline: deadline
        });

        // Tokens go directly to this contract
        IPermit2.SignatureTransferDetails memory details = IPermit2.SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount
        });

        // Permit2 verifies signature against `tokenOwner` and pulls tokens
        PERMIT2.permitTransferFrom(permit, details, tokenOwner, signature);

        _createDeposit(userId, wallet, token, tokenOwner, amount);
    }

    // ── Withdraw: tokens (owner only) ──────────────────────────────────────
    function withdrawToken(address token, address to, uint256 amount)
        external
        onlyOwner
    {
        require(to != address(0), "zero address");
        bool ok = IERC20(token).transfer(to, amount);
        require(ok, "transfer failed");
    }

    // ── Withdraw: native ETH (owner only) ──────────────────────────────────
    function withdrawNative(address payable to, uint256 amount)
        external
        onlyOwner
    {
        require(to != address(0), "zero address");
        require(address(this).balance >= amount, "insufficient balance");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    // ── Withdraw: full token balance (owner only) ──────────────────────────
    function withdrawAllToken(address token, address to)
        external
        onlyOwner
    {
        require(to != address(0), "zero address");
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0, "nothing to withdraw");
        bool ok = IERC20(token).transfer(to, bal);
        require(ok, "transfer failed");
    }

    // ── Internal ───────────────────────────────────────────────────────────
    function _createDeposit(
        uint256 userId,
        address wallet,
        address token,
        address from,
        uint256 amount
    ) internal {
        uint256 id = nextDepositId++;
        deposits[id] = Deposit({
            userId: userId,
            userWallet: wallet,
            token: token,
            from: from,
            amount: amount,
            timestamp: block.timestamp
        });
        userDeposits[wallet].push(id);
        emit DepositCreated(id, from, token, amount);
    }
}