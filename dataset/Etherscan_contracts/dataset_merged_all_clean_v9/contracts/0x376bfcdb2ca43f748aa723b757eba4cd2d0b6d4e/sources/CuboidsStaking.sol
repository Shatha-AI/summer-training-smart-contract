// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/IERC721.sol)

pragma solidity >=0.6.2;


/**
 * @dev Required interface of an ERC-721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC-721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC-721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity >=0.5.0;

/**
 * @title ERC-721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC-721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// File: @openzeppelin/contracts/utils/StorageSlot.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;


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
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * IMPORTANT: Deprecated. This storage-based reentrancy guard will be removed and replaced
 * by the {ReentrancyGuardTransient} variant in v6.0.
 *
 * @custom:stateless
 */
abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

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

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
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

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/utils/Pausable.sol


// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


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

// File: contracts/stakingv2.sol


pragma solidity ^0.8.20;






/**
 * @title CuboidsStaking v2
 * @author Cuboids Team
 * @notice Hard-lock staking with rarity boost multipliers + on-chain points.
 *
 * ═══════════════════════════════════════════════════════════════
 *  STAKING & BOOST
 * ═══════════════════════════════════════════════════════════════
 *
 *  Holders stake Cuboids → NFTs lock in this contract.
 *  Longer staking = higher rarity boost for V2 evolution:
 *
 *       Days Staked    Boost     Tier
 *       ──────────     ─────     ────────
 *       0  (none)      1.00x     None
 *       7+             1.25x     Bronze
 *       30+            1.50x     Silver
 *       60+            1.75x     Gold
 *       90+            2.00x     Diamond
 *
 *     1/1 tokens get +0.50x bonus on top.
 *     Time is cumulative across unstake/re-stake cycles.
 *
 * ═══════════════════════════════════════════════════════════════
 *  POINTS SYSTEM
 * ═══════════════════════════════════════════════════════════════
 *
 *  - Every staked Cuboid earns 10 points per day.
 *  - 1/1 tokens (IDs: 192, 1242, 1343, 1433, 1503, 1537) earn 2x (20/day).
 *  - Points are non-transferable and tracked per wallet.
 *  - Points accumulate automatically — no claiming needed.
 *  - Points can be spent by:
 *      • The holder themselves (selfSpendPoints)
 *      • Owner-authorized contracts (spendPoints) — e.g. key mint contract
 *  - Points persist after unstaking (earned points are never lost).
 *
 * ═══════════════════════════════════════════════════════════════
 *  SNAPSHOT
 * ═══════════════════════════════════════════════════════════════
 *
 *  Owner calls snapshot() before key mint to freeze boosts.
 *  After snapshot, holders can unstake without losing recorded boost.
 *
 * ═══════════════════════════════════════════════════════════════
 *  DEPLOYMENT CHECKLIST
 * ═══════════════════════════════════════════════════════════════
 *
 *  1. Deploy with constructor arg: NFT contract address
 *  2. Add staking contract to Transfer Validator list #43:
 *     addAccountsToList(43, 1, [thisContractAddress])
 *  3. Test stake/unstake with one token
 *  4. Later: addAuthorizedSpender(keyMintContractAddress)
 */
contract CuboidsStaking is IERC721Receiver, ReentrancyGuard, Pausable, Ownable {

    // ═══════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════

    IERC721 public immutable cuboidsNFT;

    /// @notice Rarity boost tiers in basis points (10000 = 1.00x)
    uint256 public constant BOOST_BASE       = 10000; // 1.00x
    uint256 public constant BOOST_TIER_1     = 12500; // 1.25x — 7+ days
    uint256 public constant BOOST_TIER_2     = 15000; // 1.50x — 30+ days
    uint256 public constant BOOST_TIER_3     = 17500; // 1.75x — 60+ days
    uint256 public constant BOOST_TIER_4     = 20000; // 2.00x — 90+ days
    uint256 public constant BONUS_ONE_OF_ONE = 5000;  // +0.50x for 1/1 tokens

    uint256 public constant TIER_1_DAYS = 7 days;
    uint256 public constant TIER_2_DAYS = 30 days;
    uint256 public constant TIER_3_DAYS = 60 days;
    uint256 public constant TIER_4_DAYS = 90 days;

    /// @notice Points earned per day per staked token (in wei-like precision: 18 decimals)
    /// 10 points/day = 10e18 per 86400 seconds = 115740740740740 per second
    uint256 public constant POINTS_PER_SEC     = 115740740740740;     // ~10 points/day
    uint256 public constant POINTS_PER_SEC_1OF1 = 231481481481481;    // ~20 points/day (2x)
    uint256 public constant POINTS_DECIMALS     = 1e18;

    // ═══════════════════════════════════════════════════════════
    // STATE — STAKING
    // ═══════════════════════════════════════════════════════════

    struct StakeInfo {
        address owner;            // Who staked this token
        uint128 stakedAt;         // Timestamp when current session began
        uint128 accumulatedTime;  // Total seconds from previous sessions
        bool    isStaked;         // Currently staked?
    }

    /// @dev tokenId => StakeInfo
    mapping(uint256 => StakeInfo) public stakes;

    /// @dev address => list of currently staked token IDs
    mapping(address => uint256[]) private _stakedTokens;

    /// @dev tokenId => index in _stakedTokens array
    mapping(uint256 => uint256) private _stakedTokenIndex;

    /// @dev 1/1 token lookup
    mapping(uint256 => bool) public isOneOfOne;

    /// @notice Total NFTs currently staked
    uint256 public totalStaked;

    // ═══════════════════════════════════════════════════════════
    // STATE — POINTS
    // ═══════════════════════════════════════════════════════════

    /// @dev Credited points balance per user (points already "banked")
    mapping(address => uint256) public creditedPoints;

    /// @dev Last time pending points were credited for each token
    mapping(uint256 => uint256) public lastPointsCreditAt;

    /// @dev Total points spent per user (lifetime)
    mapping(address => uint256) public totalSpent;

    /// @dev Authorized contracts that can spend points on behalf of holders
    mapping(address => bool) public authorizedSpenders;

    // ═══════════════════════════════════════════════════════════
    // STATE — SNAPSHOT
    // ═══════════════════════════════════════════════════════════

    struct Snapshot {
        uint128 timestamp;
        bool    exists;
    }

    mapping(uint256 => Snapshot) public snapshots;
    mapping(uint256 => mapping(uint256 => uint256)) public snapshotBoosts;
    mapping(uint256 => mapping(uint256 => uint256)) public snapshotPoints;
    uint256 public snapshotCount;

    // ═══════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════

    event Staked(address indexed user, uint256[] tokenIds, uint256 timestamp);
    event Unstaked(address indexed user, uint256[] tokenIds, uint256 timestamp);
    event PointsCredited(address indexed user, uint256 amount);
    event PointsSpent(address indexed user, uint256 amount, address indexed spender);
    event SpenderAuthorized(address indexed spender, bool authorized);
    event SnapshotTaken(uint256 indexed snapshotId, uint256 timestamp);
    event EmergencyUnstaked(uint256 indexed tokenId, address indexed to);

    // ═══════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════

    constructor(address nftAddress_) Ownable(msg.sender) {
        require(nftAddress_ != address(0), "Zero address");
        cuboidsNFT = IERC721(nftAddress_);

        // Register 1/1 tokens
        isOneOfOne[192]  = true;
        isOneOfOne[1242] = true;
        isOneOfOne[1343] = true;
        isOneOfOne[1433] = true;
        isOneOfOne[1503] = true;
        isOneOfOne[1537] = true;
    }

    // ═══════════════════════════════════════════════════════════
    // STAKING
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Stake one or more Cuboids. NFTs transfer into this contract.
     * @param  tokenIds Array of token IDs to stake. Max 50 per tx.
     */
    function stake(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
        uint256 length = tokenIds.length;
        require(length > 0,  "Empty array");
        require(length <= 50, "Max 50 per transaction");

        for (uint256 i = 0; i < length; ) {
            uint256 tokenId = tokenIds[i];
            require(cuboidsNFT.ownerOf(tokenId) == msg.sender, "Not token owner");

            StakeInfo storage info = stakes[tokenId];
            require(!info.isStaked, "Already staked");

            // Update state BEFORE external call
            info.owner     = msg.sender;
            info.stakedAt  = uint128(block.timestamp);
            info.isStaked  = true;

            // Start points clock for this token
            lastPointsCreditAt[tokenId] = block.timestamp;

            // Track in user's staked list
            _stakedTokenIndex[tokenId] = _stakedTokens[msg.sender].length;
            _stakedTokens[msg.sender].push(tokenId);

            totalStaked++;

            // Transfer NFT into this contract
            cuboidsNFT.transferFrom(msg.sender, address(this), tokenId);

            unchecked { ++i; }
        }

        emit Staked(msg.sender, tokenIds, block.timestamp);
    }

    /**
     * @notice Unstake one or more Cuboids. NFTs return to staker.
     *         All pending points are automatically credited before unstaking.
     * @param  tokenIds Array of token IDs to unstake. Max 50 per tx.
     */
    function unstake(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
        uint256 length = tokenIds.length;
        require(length > 0,  "Empty array");
        require(length <= 50, "Max 50 per transaction");

        for (uint256 i = 0; i < length; ) {
            uint256 tokenId = tokenIds[i];
            StakeInfo storage info = stakes[tokenId];

            require(info.isStaked,            "Not staked");
            require(info.owner == msg.sender, "Not your token");

            // Credit pending points BEFORE unstaking
            _creditTokenPoints(tokenId, msg.sender);

            // Accumulate boost time
            uint128 sessionTime = uint128(block.timestamp) - info.stakedAt;
            info.accumulatedTime += sessionTime;
            info.isStaked  = false;
            info.stakedAt  = 0;

            // Remove from staked list
            _removeFromStakedList(msg.sender, tokenId);
            totalStaked--;

            // Transfer NFT back
            cuboidsNFT.transferFrom(address(this), msg.sender, tokenId);

            unchecked { ++i; }
        }

        emit Unstaked(msg.sender, tokenIds, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════
    // POINTS — EARNING
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Get pending (uncredited) points for a single token.
     * @param  tokenId The token to query.
     * @return Pending points (18 decimal precision).
     */
    function pendingTokenPoints(uint256 tokenId) public view returns (uint256) {
        StakeInfo memory info = stakes[tokenId];
        if (!info.isStaked) return 0;

        uint256 elapsed = block.timestamp - lastPointsCreditAt[tokenId];
        uint256 rate = isOneOfOne[tokenId] ? POINTS_PER_SEC_1OF1 : POINTS_PER_SEC;
        return elapsed * rate;
    }

    /**
     * @notice Get total pending points for all of a user's staked tokens.
     * @param  user The address to query.
     * @return Total pending points (18 decimal precision).
     */
    function pendingPoints(address user) public view returns (uint256) {
        uint256[] memory tokens = _stakedTokens[user];
        uint256 total = 0;
        for (uint256 i = 0; i < tokens.length; ) {
            total += pendingTokenPoints(tokens[i]);
            unchecked { ++i; }
        }
        return total;
    }

    /**
     * @notice Get total points for a user (credited + pending).
     * @dev    This is the "real" balance used for spending.
     * @param  user The address to query.
     * @return Total points (18 decimal precision).
     */
    function getTotalPoints(address user) public view returns (uint256) {
        return creditedPoints[user] + pendingPoints(user);
    }

    /**
     * @notice Get points as a human-readable number (no decimals).
     * @param  user The address to query.
     * @return Points as a whole number (e.g., 150 = 150 points).
     */
    function getPointsDisplay(address user) external view returns (uint256) {
        return getTotalPoints(user) / POINTS_DECIMALS;
    }

    /**
     * @notice Get detailed points breakdown for a user.
     * @param  user The address to query.
     * @return credited   Already banked points (display units).
     * @return pending    Currently earning, not yet banked (display units).
     * @return total      credited + pending (display units).
     * @return spent      Total points spent lifetime (display units).
     * @return stakedCount Number of tokens currently staked.
     * @return dailyRate  Points earned per day at current stake (display units).
     */
    function getPointsInfo(address user) external view returns (
        uint256 credited,
        uint256 pending,
        uint256 total,
        uint256 spent,
        uint256 stakedCount,
        uint256 dailyRate
    ) {
        uint256 rawCredited = creditedPoints[user];
        uint256 rawPending  = pendingPoints(user);

        credited    = rawCredited / POINTS_DECIMALS;
        pending     = rawPending / POINTS_DECIMALS;
        total       = (rawCredited + rawPending) / POINTS_DECIMALS;
        spent       = totalSpent[user] / POINTS_DECIMALS;
        stakedCount = _stakedTokens[user].length;

        // Calculate daily rate
        uint256[] memory tokens = _stakedTokens[user];
        uint256 rawDaily = 0;
        for (uint256 i = 0; i < tokens.length; ) {
            rawDaily += isOneOfOne[tokens[i]]
                ? POINTS_PER_SEC_1OF1 * 86400
                : POINTS_PER_SEC * 86400;
            unchecked { ++i; }
        }
        dailyRate = rawDaily / POINTS_DECIMALS;
    }

    /**
     * @notice Credit all pending points for the caller's staked tokens.
     * @dev    This is optional — points are auto-credited on unstake.
     *         Useful if a user wants to "bank" points without unstaking.
     */
    function claimPoints() external nonReentrant whenNotPaused {
        uint256[] memory tokens = _stakedTokens[msg.sender];
        require(tokens.length > 0, "No staked tokens");

        uint256 totalCredited = 0;
        for (uint256 i = 0; i < tokens.length; ) {
            totalCredited += _creditTokenPoints(tokens[i], msg.sender);
            unchecked { ++i; }
        }

        if (totalCredited > 0) {
            emit PointsCredited(msg.sender, totalCredited);
        }
    }

    /**
     * @dev Credit pending points for a single token to its owner.
     * @return The amount of points credited.
     */
    function _creditTokenPoints(uint256 tokenId, address owner_) internal returns (uint256) {
        uint256 pending = pendingTokenPoints(tokenId);
        if (pending > 0) {
            creditedPoints[owner_] += pending;
            lastPointsCreditAt[tokenId] = block.timestamp;
        }
        return pending;
    }

    // ═══════════════════════════════════════════════════════════
    // POINTS — SPENDING
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Spend your own points. Used for future redemptions.
     * @param  amount Points to spend (display units, e.g., 100 = 100 points).
     */
    function selfSpendPoints(uint256 amount) external nonReentrant whenNotPaused {
        uint256 rawAmount = amount * POINTS_DECIMALS;
        _deductPoints(msg.sender, rawAmount);
        totalSpent[msg.sender] += rawAmount;
        emit PointsSpent(msg.sender, rawAmount, msg.sender);
    }

    /**
     * @notice Authorized spender deducts points from a holder.
     * @dev    Only callable by contracts added via addAuthorizedSpender().
     *         Used by key mint contract, future drops, etc.
     * @param  user   The holder whose points to deduct.
     * @param  amount Points to spend (display units, e.g., 100 = 100 points).
     */
    function spendPoints(address user, uint256 amount) external nonReentrant {
        require(authorizedSpenders[msg.sender], "Not authorized spender");
        uint256 rawAmount = amount * POINTS_DECIMALS;
        _deductPoints(user, rawAmount);
        totalSpent[user] += rawAmount;
        emit PointsSpent(user, rawAmount, msg.sender);
    }

    /**
     * @dev Internal: deduct points from a user. Credits pending first.
     *      Reverts if insufficient balance.
     */
    function _deductPoints(address user, uint256 rawAmount) internal {
        // First, credit all pending points to ensure accurate balance
        uint256[] memory tokens = _stakedTokens[user];
        for (uint256 i = 0; i < tokens.length; ) {
            _creditTokenPoints(tokens[i], user);
            unchecked { ++i; }
        }

        require(creditedPoints[user] >= rawAmount, "Insufficient points");
        creditedPoints[user] -= rawAmount;
    }

    // ═══════════════════════════════════════════════════════════
    // AUTHORIZED SPENDERS
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Add or remove an authorized points spender.
     * @dev    Use this to authorize the key mint contract, future drops, etc.
     * @param  spender    The contract address to authorize.
     * @param  authorized True to authorize, false to revoke.
     */
    function setAuthorizedSpender(address spender, bool authorized) external onlyOwner {
        require(spender != address(0), "Zero address");
        authorizedSpenders[spender] = authorized;
        emit SpenderAuthorized(spender, authorized);
    }

    // ═══════════════════════════════════════════════════════════
    // BOOST CALCULATION
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Get total staking duration for a token (cumulative).
     */
    function getTotalStakeTime(uint256 tokenId) public view returns (uint256) {
        StakeInfo memory info = stakes[tokenId];
        uint256 total = info.accumulatedTime;
        if (info.isStaked) {
            total += block.timestamp - info.stakedAt;
        }
        return total;
    }

    /**
     * @notice Get rarity boost for a token in basis points.
     */
    function getBoost(uint256 tokenId) public view returns (uint256) {
        uint256 totalTime = getTotalStakeTime(tokenId);
        uint256 boost = _calculateBoostFromTime(totalTime);
        if (isOneOfOne[tokenId]) {
            boost += BONUS_ONE_OF_ONE;
        }
        return boost;
    }

    /**
     * @notice Get full boost info for display.
     */
    function getBoostInfo(uint256 tokenId) external view returns (
        uint8 tier,
        uint256 boost,
        uint256 totalDays,
        bool is1of1
    ) {
        uint256 totalTime = getTotalStakeTime(tokenId);
        totalDays = totalTime / 1 days;
        boost = getBoost(tokenId);
        is1of1 = isOneOfOne[tokenId];

        if (totalTime >= TIER_4_DAYS) tier = 4;      // Diamond
        else if (totalTime >= TIER_3_DAYS) tier = 3;  // Gold
        else if (totalTime >= TIER_2_DAYS) tier = 2;  // Silver
        else if (totalTime >= TIER_1_DAYS) tier = 1;  // Bronze
        else tier = 0;                                 // None
    }

    function _calculateBoostFromTime(uint256 totalTime) internal pure returns (uint256) {
        if (totalTime >= TIER_4_DAYS) return BOOST_TIER_4;
        if (totalTime >= TIER_3_DAYS) return BOOST_TIER_3;
        if (totalTime >= TIER_2_DAYS) return BOOST_TIER_2;
        if (totalTime >= TIER_1_DAYS) return BOOST_TIER_1;
        return BOOST_BASE;
    }

    // ═══════════════════════════════════════════════════════════
    // SNAPSHOT
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Snapshot boosts AND points for all specified tokens.
     * @param  tokenIds All staked token IDs to snapshot.
     */
    function snapshot(uint256[] calldata tokenIds) external onlyOwner {
        uint256 snapId = snapshotCount;
        snapshotCount++;

        snapshots[snapId] = Snapshot({
            timestamp: uint128(block.timestamp),
            exists:    true
        });

        for (uint256 i = 0; i < tokenIds.length; ) {
            uint256 tokenId = tokenIds[i];
            if (stakes[tokenId].owner != address(0)) {
                snapshotBoosts[snapId][tokenId] = getBoost(tokenId);
                // Store total points for the token's owner at snapshot time
                address tokenOwner = stakes[tokenId].owner;
                if (snapshotPoints[snapId][tokenId] == 0) {
                    snapshotPoints[snapId][tokenId] = getTotalPoints(tokenOwner);
                }
            }
            unchecked { ++i; }
        }

        emit SnapshotTaken(snapId, block.timestamp);
    }

    /**
     * @notice Continue a snapshot with more tokens (for large collections).
     */
    function snapshotContinue(uint256 snapId, uint256[] calldata tokenIds) external onlyOwner {
        require(snapshots[snapId].exists, "Snapshot does not exist");

        for (uint256 i = 0; i < tokenIds.length; ) {
            uint256 tokenId = tokenIds[i];
            if (stakes[tokenId].owner != address(0)) {
                snapshotBoosts[snapId][tokenId] = getBoost(tokenId);
                address tokenOwner = stakes[tokenId].owner;
                if (snapshotPoints[snapId][tokenId] == 0) {
                    snapshotPoints[snapId][tokenId] = getTotalPoints(tokenOwner);
                }
            }
            unchecked { ++i; }
        }
    }

    /**
     * @notice Get a token's frozen boost from a snapshot.
     */
    function getSnapshotBoost(uint256 snapId, uint256 tokenId) external view returns (uint256) {
        require(snapshots[snapId].exists, "Snapshot does not exist");
        return snapshotBoosts[snapId][tokenId];
    }

    /**
     * @notice Get a token owner's frozen points from a snapshot.
     */
    function getSnapshotPoints(uint256 snapId, uint256 tokenId) external view returns (uint256) {
        require(snapshots[snapId].exists, "Snapshot does not exist");
        return snapshotPoints[snapId][tokenId] / POINTS_DECIMALS;
    }

    // ═══════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Get all currently staked token IDs for a user.
     */
    function getStakedTokens(address user) external view returns (uint256[] memory) {
        return _stakedTokens[user];
    }

    /**
     * @notice Get staked count for a user.
     */
    function getStakedCount(address user) external view returns (uint256) {
        return _stakedTokens[user].length;
    }

    /**
     * @notice Check if a token is staked.
     */
    function isStaked(uint256 tokenId) external view returns (bool) {
        return stakes[tokenId].isStaked;
    }

    /**
     * @notice Get the staker of a token.
     */
    function stakerOf(uint256 tokenId) external view returns (address) {
        return stakes[tokenId].owner;
    }

    /**
     * @notice Batch query: boosts, points, and staking status.
     */
    function batchGetInfo(uint256[] calldata tokenIds) external view returns (
        uint256[] memory boosts,
        bool[]    memory staked,
        address[] memory owners,
        uint256[] memory days_,
        uint256[] memory tokenPoints
    ) {
        uint256 length = tokenIds.length;
        boosts      = new uint256[](length);
        staked      = new bool[](length);
        owners      = new address[](length);
        days_       = new uint256[](length);
        tokenPoints = new uint256[](length);

        for (uint256 i = 0; i < length; ) {
            uint256 tokenId = tokenIds[i];
            boosts[i]      = getBoost(tokenId);
            staked[i]      = stakes[tokenId].isStaked;
            owners[i]      = stakes[tokenId].owner;
            days_[i]       = getTotalStakeTime(tokenId) / 1 days;
            tokenPoints[i] = pendingTokenPoints(tokenId) / POINTS_DECIMALS;
            unchecked { ++i; }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // ADMIN
    // ═══════════════════════════════════════════════════════════

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    /**
     * @notice Emergency: return a stuck NFT. Credits pending points first.
     */
    function emergencyUnstake(uint256 tokenId) external onlyOwner nonReentrant {
        StakeInfo storage info = stakes[tokenId];
        require(info.isStaked, "Not staked");

        address tokenOwner = info.owner;
        require(tokenOwner != address(0), "Invalid owner");

        // Credit points before unstaking
        _creditTokenPoints(tokenId, tokenOwner);

        // Accumulate time
        uint128 sessionTime = uint128(block.timestamp) - info.stakedAt;
        info.accumulatedTime += sessionTime;
        info.isStaked  = false;
        info.stakedAt  = 0;

        _removeFromStakedList(tokenOwner, tokenId);
        totalStaked--;

        cuboidsNFT.transferFrom(address(this), tokenOwner, tokenId);

        emit EmergencyUnstaked(tokenId, tokenOwner);
    }

    /**
     * @notice Emergency: batch return multiple stuck NFTs.
     */
    function emergencyUnstakeBatch(uint256[] calldata tokenIds) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; ) {
            uint256 tokenId = tokenIds[i];
            StakeInfo storage info = stakes[tokenId];

            if (info.isStaked && info.owner != address(0)) {
                address tokenOwner = info.owner;

                _creditTokenPoints(tokenId, tokenOwner);

                uint128 sessionTime = uint128(block.timestamp) - info.stakedAt;
                info.accumulatedTime += sessionTime;
                info.isStaked  = false;
                info.stakedAt  = 0;

                _removeFromStakedList(tokenOwner, tokenId);
                totalStaked--;

                cuboidsNFT.transferFrom(address(this), tokenOwner, tokenId);

                emit EmergencyUnstaked(tokenId, tokenOwner);
            }

            unchecked { ++i; }
        }
    }

    /**
     * @notice Owner can grant bonus points to any address (airdrops, rewards).
     * @param  user   Recipient address.
     * @param  amount Points to grant (display units, e.g., 100 = 100 points).
     */
    function grantPoints(address user, uint256 amount) external onlyOwner {
        require(user != address(0), "Zero address");
        creditedPoints[user] += amount * POINTS_DECIMALS;
        emit PointsCredited(user, amount * POINTS_DECIMALS);
    }

    /**
     * @notice Owner can batch grant points to multiple addresses.
     * @param  users   Array of recipient addresses.
     * @param  amounts Array of point amounts (display units).
     */
    function grantPointsBatch(address[] calldata users, uint256[] calldata amounts) external onlyOwner {
        require(users.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < users.length; ) {
            require(users[i] != address(0), "Zero address");
            uint256 rawAmount = amounts[i] * POINTS_DECIMALS;
            creditedPoints[users[i]] += rawAmount;
            emit PointsCredited(users[i], rawAmount);
            unchecked { ++i; }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // INTERNAL HELPERS
    // ═══════════════════════════════════════════════════════════

    function _removeFromStakedList(address user, uint256 tokenId) internal {
        uint256[] storage userTokens = _stakedTokens[user];
        uint256 index = _stakedTokenIndex[tokenId];
        uint256 lastIndex = userTokens.length - 1;

        if (index != lastIndex) {
            uint256 lastTokenId = userTokens[lastIndex];
            userTokens[index] = lastTokenId;
            _stakedTokenIndex[lastTokenId] = index;
        }

        userTokens.pop();
        delete _stakedTokenIndex[tokenId];
    }

    // ═══════════════════════════════════════════════════════════
    // ERC721 RECEIVER
    // ═══════════════════════════════════════════════════════════

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external view override returns (bytes4) {
        require(msg.sender == address(cuboidsNFT), "Only Cuboids NFTs accepted");
        return IERC721Receiver.onERC721Received.selector;
    }
}