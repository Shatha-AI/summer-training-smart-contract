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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
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

// File: contracts/contracts/src/interfaces/IProtocol.sol


pragma solidity ^0.8.24;

/**
 * @title 协议内部合约接口集（v2 多级）
 * @author suni
 */

interface IPriceOracle {
    /// @notice 将一定数量的 UNI 折算为 U(稳定币,18位)
    function uniToU(uint256 uniAmount) external view returns (uint256 valueU);
}

interface IReferralRegistry {
    function referrer(address user) external view returns (address);

    function directCount(address user) external view returns (uint32);

    function activated(address user) external view returns (bool);

    /// @notice 入金时绑定上级(首次,不可改)并激活
    function bind(address user, address upline) external;

    /// @notice 受控绑定(供 IDO/空投链下补录)
    function adminBind(address user, address upline) external;

    /// @notice 沿上级链向上取 n 级(遇黑洞/零地址截断,不足补零)
    function uplinesN(address user, uint256 n) external view returns (address[] memory);

    /// @notice 上行遍历深度上限
    function maxUplineDepth() external view returns (uint256);
}

interface ITeamLevel {
    /// @notice 入金时累加业绩:个人 + 直推 + 沿链传播综合业绩(≤depth)
    function addPerformance(address user, uint256 valueU) external;

    /// @notice 当前等级 0=无级,1..6=V1..V6
    function levelOf(address user) external view returns (uint8);

    /// @notice 某等级团队奖励比例(百分数)
    function rewardRateOf(uint8 level) external view returns (uint256);
}

interface IMiningController {
    /// @notice 为用户增加算力(hashU = 3×valueU),同时设置出局额度
    function addHash(address user, uint256 hashU) external;

    /// @notice 结算并向上分发某用户的动态基数(任何人可 poke,推动其上级收益)
    function settleAndDistribute(address user) external;
}

interface INodeNFT {
    function totalSupply() external view returns (uint256);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function mint(address to) external returns (uint256 tokenId);
}

interface IPoolManager {
    /// @notice 注入 NFT 池(sUNI 已转入),累积达阈值则均分给节点持有者
    function fundNftPool(uint256 amount) external;

    /// @notice 注入共振池(sUNI 已转入)
    function fundResonance(uint256 amount) external;

    /// @notice TeamLevel 在用户跨入 V5 时回调登记共振成员
    function onQualified(address user) external;
}

interface ISUNIToken {
    /// @notice DepositVault 累计入金 U,用于二级市场门槛判定
    function notifyDeposit(uint256 valueU) external;
}

// File: contracts/contracts/src/MiningController.sol


pragma solidity ^0.8.24;





/**
 * @title 算力产出控制器（v2 多级动态）
 * @author suni
 * @notice 静态:个人算力占比×LP×1%,用户自领;动态:纯团队奖,用户不产个人动态,其"动态基数"
 *         沿上级链按代数(≤8代,顶格45%)+团队级差(顶格35%)分发,未分出的余量(≥20%)转基金会;
 *         算力随累计产出递减,达 3× 出局。排放率为可配置参数,近似"LP×1%/日"。
 * @dev 动态基数在生成者被 settle(自己 claim 或被 poke) 时向上分发;跨用户出局封顶在 _pay 内处理。
 */
contract MiningController is IMiningController, Ownable, ReentrancyGuard {
    uint256 private constant ACC = 1e12;

    IERC20 public immutable suni;
    IReferralRegistry public referral;
    ITeamLevel public teamLevel;
    address public foundation; // 动态余量与超额去向

    uint256 public staticRatePerSec; // sUNI/sec
    uint256 public dynamicRatePerSec; // sUNI/sec

    uint256 public totalHash; // 全网有效算力(active 之和)
    uint256 public accStatic; // 静态每单位算力累计(×ACC)
    uint256 public accDynBase; // 动态基数每单位算力累计(×ACC)
    uint256 public lastUpdate;

    struct UserInfo {
        uint256 hashWeight; // 算力权重(出局后归 0)
        uint256 cap; // 出局额度(=累计 3×入金)
        uint256 earned; // 累计已得(静态+动态收到)
        uint256 debtStatic;
        uint256 debtDynBase;
        uint256 staticClaimable; // 已结算未领静态
        bool active;
    }

    mapping(address => UserInfo) public users;
    mapping(address => bool) public authorized;

    event HashAdded(address indexed user, uint256 hashU);
    event StaticClaimed(address indexed user, uint256 amount);
    event DynamicPaid(address indexed to, address indexed from, uint256 amount);
    event Deactivated(address indexed user);

    constructor(address suni_, address referral_, address teamLevel_, address foundation_) Ownable(msg.sender) {
        suni = IERC20(suni_);
        referral = IReferralRegistry(referral_);
        teamLevel = ITeamLevel(teamLevel_);
        foundation = foundation_;
        lastUpdate = block.timestamp;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "not authorized");
        _;
    }

    function setAuthorized(address a, bool v) external onlyOwner {
        authorized[a] = v;
    }

    function setRates(uint256 s, uint256 d) external onlyOwner {
        _updatePool();
        staticRatePerSec = s;
        dynamicRatePerSec = d;
    }

    function setRefs(address referral_, address teamLevel_, address foundation_) external onlyOwner {
        referral = IReferralRegistry(referral_);
        teamLevel = ITeamLevel(teamLevel_);
        foundation = foundation_;
    }

    // --------------------------------------------------------------- 内部核算

    function _updatePool() internal {
        uint256 dt = block.timestamp - lastUpdate;
        if (dt == 0) return;
        if (totalHash > 0) {
            accStatic += (staticRatePerSec * dt * ACC) / totalHash;
            accDynBase += (dynamicRatePerSec * dt * ACC) / totalHash;
        }
        lastUpdate = block.timestamp;
    }

    function _settleStatic(address u) internal {
        UserInfo storage a = users[u];
        if (a.hashWeight > 0) {
            a.staticClaimable += (a.hashWeight * (accStatic - a.debtStatic)) / ACC;
        }
        a.debtStatic = accStatic;
    }

    /// @dev 结算本人动态基数并向上分发(生成者触发)
    function _settleDynBase(address u) internal {
        UserInfo storage a = users[u];
        uint256 bbase;
        if (a.hashWeight > 0) {
            bbase = (a.hashWeight * (accDynBase - a.debtDynBase)) / ACC;
        }
        a.debtDynBase = accDynBase;
        if (bbase > 0) {
            _distributeDynamic(u, bbase);
        }
    }

    /// @dev 代数上限:1人2代/2人3代/3人4代/4人6代/5+人8代
    function _maxGen(uint32 dc) internal pure returns (uint256) {
        if (dc >= 5) return 8;
        if (dc == 4) return 6;
        if (dc == 3) return 4;
        if (dc == 2) return 3;
        if (dc == 1) return 2;
        return 0;
    }

    /// @dev 向上分发动态基数:代数 + 级差;余量转基金会
    function _distributeDynamic(address producer, uint256 bbase) internal {
        uint256 depth = referral.maxUplineDepth();
        address up = referral.referrer(producer);
        uint256 paidLevelRate;
        uint256 allocated;

        for (uint256 g = 1; g <= depth; g++) {
            if (up == address(0) || up == address(0xdEaD)) break;
            uint256 amt;
            if (users[up].active) {
                // 代数奖(前 8 代,受烧伤限制)
                if (g <= 8) {
                    uint256 maxg = _maxGen(referral.directCount(up));
                    if (g <= maxg) {
                        uint256 rate = (g == 1) ? 10 : 5;
                        amt += (bbase * rate) / 100;
                    }
                }
                // 团队级差(望远镜差额)
                uint256 lvRate = teamLevel.rewardRateOf(teamLevel.levelOf(up));
                if (lvRate > paidLevelRate) {
                    amt += (bbase * (lvRate - paidLevelRate)) / 100;
                    paidLevelRate = lvRate;
                }
            }
            if (amt > 0) {
                allocated += amt;
                _pay(up, amt, producer);
            }
            up = referral.referrer(up);
        }

        uint256 remainder = bbase - allocated; // ≤80% 分出 → 余量≥20%
        if (remainder > 0 && foundation != address(0)) {
            suni.transfer(foundation, remainder);
        }
    }

    /// @dev 支付动态收益,受收款方出局额度封顶;超额部分转基金会;达额度即出局
    function _pay(address to, uint256 amt, address from) internal {
        UserInfo storage a = users[to];
        uint256 room = (a.active && a.cap > a.earned) ? a.cap - a.earned : 0;
        uint256 payAmt = amt > room ? room : amt;
        if (payAmt > 0) {
            a.earned += payAmt;
            suni.transfer(to, payAmt);
            emit DynamicPaid(to, from, payAmt);
        }
        uint256 over = amt - payAmt;
        if (over > 0 && foundation != address(0)) {
            suni.transfer(foundation, over);
        }
        if (a.active && a.earned >= a.cap) {
            _deactivate(to);
        }
    }

    /// @dev 出局:结算静态挂账后移除算力权重(静态余额仍可领)
    function _deactivate(address u) internal {
        UserInfo storage a = users[u];
        _settleStatic(u);
        a.debtDynBase = accDynBase; // 放弃剩余动态基数(简化)
        totalHash -= a.hashWeight;
        a.hashWeight = 0;
        a.active = false;
        emit Deactivated(u);
    }

    // --------------------------------------------------------------- 外部

    /// @notice 增加算力(hashU = 3×valueU),同步增加出局额度
    function addHash(address user, uint256 hashU) external override onlyAuthorized nonReentrant {
        _updatePool();
        _settleStatic(user);
        _settleDynBase(user); // 变更权重前先分发已生成的动态基数

        UserInfo storage a = users[user];
        a.active = true;
        a.hashWeight += hashU;
        a.cap += hashU; // 3× 出局(hashU 已含 3×)
        totalHash += hashU;
        a.debtStatic = accStatic;
        a.debtDynBase = accDynBase;
        emit HashAdded(user, hashU);
    }

    /// @notice 领取本人静态收益;同时把本人动态基数向上分发给上级
    function claim() external nonReentrant {
        _updatePool();
        _settleDynBase(msg.sender); // 分发本人动态基数(付上级)
        _settleStatic(msg.sender);

        UserInfo storage a = users[msg.sender];
        uint256 amt = a.staticClaimable;
        require(amt > 0, "nothing");
        a.staticClaimable = 0;
        _pay(msg.sender, amt, msg.sender); // 静态计入本人出局额度
        emit StaticClaimed(msg.sender, amt);
    }

    /// @notice 推动某用户结算,使其动态基数分发给上级(任何人可调用)
    function settleAndDistribute(address user) external override nonReentrant {
        _updatePool();
        _settleStatic(user);
        _settleDynBase(user);
    }

    // --------------------------------------------------------------- 查询

    function pendingStatic(address u) external view returns (uint256) {
        UserInfo storage a = users[u];
        uint256 acc = accStatic;
        uint256 dt = block.timestamp - lastUpdate;
        if (dt > 0 && totalHash > 0) {
            acc += (staticRatePerSec * dt * ACC) / totalHash;
        }
        return a.staticClaimable + (a.hashWeight * (acc - a.debtStatic)) / ACC;
    }

    function sweep(address to, uint256 amount) external onlyOwner {
        suni.transfer(to, amount);
    }
}