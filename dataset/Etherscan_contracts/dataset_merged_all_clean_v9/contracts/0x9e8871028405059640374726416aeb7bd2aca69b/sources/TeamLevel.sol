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

// File: contracts/contracts/src/TeamLevel.sol


pragma solidity ^0.8.24;



/**
 * @title 团队等级 V1–V6（v2 整棵下线树 KPI）
 * @author suni
 * @notice 综合业绩 = 整棵下线树累计入金(入金时沿上级链逐级传播,≤maxUplineDepth);
 *         三项(个人/直推/综合)同时满足才达该级;业绩只增,等级单调不降
 */
contract TeamLevel is ITeamLevel, Ownable {
    address public constant BLACKHOLE = 0x000000000000000000000000000000000000dEaD;

    IReferralRegistry public referral;
    address public resonanceHook; // PoolManager

    mapping(address => uint256) public personalPerf; // 个人业绩
    mapping(address => uint256) public directPerf; // 直推业绩(直接下级之和)
    mapping(address => uint256) public teamPerf; // 综合业绩(整棵下线树)
    mapping(address => bool) public authorized;

    struct Threshold {
        uint256 personal;
        uint256 direct;
        uint256 comprehensive;
        uint256 rewardRate; // 百分数
    }

    mapping(uint8 => Threshold) public thresholds;

    event PerformanceAdded(address indexed user, uint256 valueU);
    event ResonanceQualified(address indexed user);

    constructor(address referral_) Ownable(msg.sender) {
        referral = IReferralRegistry(referral_);
        uint256 U = 1e18;
        thresholds[1] = Threshold(500 * U, 1_000 * U, 10_000 * U, 10);
        thresholds[2] = Threshold(1_000 * U, 3_000 * U, 30_000 * U, 15);
        thresholds[3] = Threshold(1_500 * U, 5_000 * U, 100_000 * U, 20);
        thresholds[4] = Threshold(2_000 * U, 10_000 * U, 200_000 * U, 25);
        thresholds[5] = Threshold(3_000 * U, 20_000 * U, 500_000 * U, 30);
        thresholds[6] = Threshold(5_000 * U, 30_000 * U, 1_000_000 * U, 35);
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "not authorized");
        _;
    }

    function setAuthorized(address a, bool v) external onlyOwner {
        authorized[a] = v;
    }

    function setResonanceHook(address hook) external onlyOwner {
        resonanceHook = hook;
    }

    function setReferral(address r) external onlyOwner {
        referral = IReferralRegistry(r);
    }

    function setThreshold(uint8 level, Threshold calldata t) external onlyOwner {
        require(level >= 1 && level <= 6, "bad level");
        thresholds[level] = t;
    }

    /**
     * @notice 入金时累加业绩:个人 += valueU;直接上级直推 += valueU;沿链所有祖先综合 += valueU
     * @dev 上行遍历受 referral.maxUplineDepth() 限制;祖先跨入 V5 时回调共振池登记
     */
    function addPerformance(address user, uint256 valueU) external override onlyAuthorized {
        personalPerf[user] += valueU;
        _maybeResonance(user, 0);
        emit PerformanceAdded(user, valueU);

        uint256 depth = referral.maxUplineDepth();
        address up = referral.referrer(user);
        bool first = true;
        for (uint256 i = 0; i < depth; i++) {
            if (up == address(0) || up == BLACKHOLE) break;
            uint8 before = levelOf(up);
            if (first) {
                directPerf[up] += valueU;
                first = false;
            }
            teamPerf[up] += valueU;
            _maybeResonance(up, before);
            up = referral.referrer(up);
        }
    }

    /// @notice 三项阈值同时满足才达该级;从 V6 向 V1 取首个满足
    function levelOf(address user) public view override returns (uint8) {
        uint256 p = personalPerf[user];
        uint256 d = directPerf[user];
        uint256 c = teamPerf[user];
        for (uint8 lv = 6; lv >= 1; lv--) {
            Threshold storage t = thresholds[lv];
            if (p >= t.personal && d >= t.direct && c >= t.comprehensive) {
                return lv;
            }
            if (lv == 1) break;
        }
        return 0;
    }

    function rewardRateOf(uint8 level) external view override returns (uint256) {
        if (level == 0) return 0;
        return thresholds[level].rewardRate;
    }

    /// @dev 用户从 <V5 跨到 ≥V5 时通知共振池(hook 自去重);失败不阻断
    function _maybeResonance(address user, uint8 levelBefore) internal {
        if (resonanceHook == address(0) || levelBefore >= 5) return;
        if (levelOf(user) >= 5) {
            (bool ok,) = resonanceHook.call(abi.encodeWithSignature("onQualified(address)", user));
            ok;
            emit ResonanceQualified(user);
        }
    }
}