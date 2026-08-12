// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --- OpenZeppelin: utils/Context.sol ---
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Context.sol)


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// --- OpenZeppelin: token/ERC20/IERC20.sol ---
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// --- OpenZeppelin: access/Ownable.sol ---
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)



/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// --- OpenZeppelin: utils/ReentrancyGuard.sol ---
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// --- SuperLottery.sol ---


/// @title SuperLottery v2 — Verifiably fair on-chain lottery for Superposition LPs.
/// @notice The owner commits a participant hash *before* the seed block is known,
///         then submits the full participant list to execute the draw.  The contract
///         verifies the hash, derives a seed from a future blockhash, performs
///         weighted selection, and records the winner.  Prize is claimed separately
///         (pull pattern) to handle USDC blacklist edge cases.
contract SuperLottery is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;
    uint256 public prizeAmount;

    /// Number of blocks between commit and the block whose hash seeds the draw.
    uint256 public constant REVEAL_DELAY = 10;

    struct DrawData {
        bytes32 participantsHash;
        uint256 revealBlock;
        bytes32 seed;
        address winner;
        uint256 prizeAwarded;
        bool committed;
        bool drawn;
        bool prizeClaimed;
    }

    /// drawId → DrawData.  drawId is YYYYMMDD as uint (e.g. 20250330).
    mapping(uint256 => DrawData) public draws;

    event Committed(uint256 indexed drawId, bytes32 participantsHash, uint256 revealBlock);
    event DrawCancelled(uint256 indexed drawId);
    event Drawn(uint256 indexed drawId, address indexed winner, bytes32 seed, uint256 prize);
    event PrizeClaimed(uint256 indexed drawId, address indexed winner, uint256 amount);
    event PrizeAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event UsdcWithdrawn(address indexed to, uint256 amount);

    constructor(address _usdc, uint256 _prizeAmount) Ownable(msg.sender) {
        require(_usdc != address(0), "zero usdc address");
        require(_prizeAmount > 0, "zero prize");
        usdc = IERC20(_usdc);
        prizeAmount = _prizeAmount;
    }

    /// @dev Disable renounceOwnership to prevent accidentally bricking the contract.
    function renounceOwnership() public pure override {
        revert("renounce disabled");
    }

    // -----------------------------------------------------------------------
    // Phase 1: Commit — lock the participant list hash before seed is known
    // -----------------------------------------------------------------------

    /// @notice Commit a draw.  Must be called *before* revealBlock is mined.
    /// @param drawId  Unique identifier (YYYYMMDD).
    /// @param participantsHash  keccak256(abi.encodePacked(wallets, tvlsCents)).
    function commit(uint256 drawId, bytes32 participantsHash) external onlyOwner {
        require(!draws[drawId].committed, "already committed");
        require(participantsHash != bytes32(0), "empty hash");

        draws[drawId] = DrawData({
            participantsHash: participantsHash,
            revealBlock: block.number + REVEAL_DELAY,
            seed: bytes32(0),
            winner: address(0),
            prizeAwarded: 0,
            committed: true,
            drawn: false,
            prizeClaimed: false
        });

        emit Committed(drawId, participantsHash, block.number + REVEAL_DELAY);
    }

    // -----------------------------------------------------------------------
    // Cancel — reset an expired commit so the drawId can be reused
    // -----------------------------------------------------------------------

    /// @notice Cancel a committed draw whose blockhash window has expired.
    ///         Allows re-committing with the same drawId.
    function cancelDraw(uint256 drawId) external onlyOwner {
        DrawData storage d = draws[drawId];
        require(d.committed && !d.drawn, "invalid state");
        require(block.number > d.revealBlock + 256, "not expired");
        d.committed = false;
        emit DrawCancelled(drawId);
    }

    // -----------------------------------------------------------------------
    // Phase 2: Execute — verify, compute seed, weighted selection
    // -----------------------------------------------------------------------

    /// @notice Execute the draw.  Verifies participant data matches the committed
    ///         hash, computes a seed from a past blockhash, selects a winner via
    ///         on-chain weighted random.  Prize is NOT transferred here — use claimPrize().
    /// @param drawId    Must match a previously committed draw.
    /// @param wallets   Sorted participant addresses (must match committed hash).
    /// @param tvlsCents Per-wallet TVL in USD cents (must match committed hash).
    function executeDraw(
        uint256 drawId,
        address[] calldata wallets,
        uint256[] calldata tvlsCents
    ) external onlyOwner nonReentrant {
        DrawData storage d = draws[drawId];
        require(d.committed, "not committed");
        require(!d.drawn, "already drawn");
        require(wallets.length > 0, "no participants");
        require(wallets.length == tvlsCents.length, "length mismatch");
        require(block.number > d.revealBlock, "too early");
        require(block.number <= d.revealBlock + 256, "blockhash expired");

        // 1. Verify participants match commitment
        require(
            keccak256(abi.encodePacked(wallets, tvlsCents)) == d.participantsHash,
            "participants mismatch"
        );

        // 2. Compute verifiable seed from past blockhash
        d.seed = keccak256(abi.encodePacked(
            blockhash(d.revealBlock),
            d.participantsHash
        ));

        // 3. Weighted selection
        uint256 total = 0;
        for (uint256 i = 0; i < tvlsCents.length; i++) {
            require(tvlsCents[i] > 0, "zero weight participant");
            total += tvlsCents[i];
        }

        uint256 threshold = uint256(d.seed) % total;
        uint256 cumulative = 0;
        address winner;
        for (uint256 i = 0; i < wallets.length; i++) {
            cumulative += tvlsCents[i];
            if (cumulative > threshold) {
                winner = wallets[i];
                break;
            }
        }
        require(winner != address(0), "no winner selected");

        d.winner = winner;
        d.prizeAwarded = prizeAmount;
        d.drawn = true;

        emit Drawn(drawId, winner, d.seed, prizeAmount);
    }

    // -----------------------------------------------------------------------
    // Phase 3: Claim — pull-based prize transfer (handles USDC blacklist)
    // -----------------------------------------------------------------------

    /// @notice Transfer the prize to the winner. Can be called by anyone.
    ///         Separated from executeDraw so a blacklisted winner does not
    ///         block the draw itself.
    function claimPrize(uint256 drawId) external nonReentrant {
        DrawData storage d = draws[drawId];
        require(d.drawn, "not drawn");
        require(!d.prizeClaimed, "already claimed");
        require(d.prizeAwarded > 0, "no prize");

        d.prizeClaimed = true;
        require(usdc.transfer(d.winner, d.prizeAwarded), "transfer failed");

        emit PrizeClaimed(drawId, d.winner, d.prizeAwarded);
    }

    // -----------------------------------------------------------------------
    // Admin
    // -----------------------------------------------------------------------

    function setPrizeAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "zero prize");
        uint256 old = prizeAmount;
        prizeAmount = _amount;
        emit PrizeAmountUpdated(old, _amount);
    }

    function withdrawUsdc(uint256 amount) external onlyOwner {
        require(usdc.transfer(msg.sender, amount), "transfer failed");
        emit UsdcWithdrawn(msg.sender, amount);
    }

    function usdcBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}