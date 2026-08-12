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

// File: contracts/contracts/src/ReferralRegistry.sol


pragma solidity ^0.8.24;



/**
 * @title 推荐关系登记（v2 多级）
 * @author suni
 * @notice 每个用户仅存一个直接上级(单指针),多级关系为其传递闭包;
 *         分发/传播沿指针向上遍历,设深度上限 maxUplineDepth 兜底 gas
 */
contract ReferralRegistry is IReferralRegistry, Ownable {
    address public constant BLACKHOLE = 0x000000000000000000000000000000000000dEaD;

    mapping(address => address) public override referrer;
    mapping(address => uint32) public override directCount;
    mapping(address => bool) public override activated;
    mapping(address => bool) public authorized;

    /// @notice 上行遍历深度上限(gas 兜底,可调)
    uint256 public override maxUplineDepth = 20;

    event Bound(address indexed user, address indexed upline);
    event Activated(address indexed user);

    constructor() Ownable(msg.sender) {}

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "not authorized");
        _;
    }

    function setAuthorized(address a, bool v) external onlyOwner {
        authorized[a] = v;
    }

    function setMaxUplineDepth(uint256 d) external onlyOwner {
        require(d >= 1 && d <= 100, "bad depth");
        maxUplineDepth = d;
    }

    function activate(address user) external onlyAuthorized {
        _activate(user);
    }

    function _activate(address user) internal {
        if (!activated[user]) {
            activated[user] = true;
            emit Activated(user);
        }
    }

    /// @notice 入金时绑定上级并激活本人
    function bind(address user, address upline) external override onlyAuthorized {
        _bind(user, upline);
        _activate(user);
    }

    /// @notice 受控绑定(IDO/空投链下补录),同样激活本人
    function adminBind(address user, address upline) external override onlyAuthorized {
        _bind(user, upline);
        _activate(user);
    }

    /// @notice 用户自助绑定上级：由用户钱包直接调用上链（首次不可改，上级须已激活）
    /// @dev 仅在绑定成功后激活本人，避免上级未激活时产生"空激活"
    function bindUpline(address upline) external {
        _bind(msg.sender, upline);
        if (referrer[msg.sender] != address(0)) {
            _activate(msg.sender);
        }
    }

    /// @dev 首次绑定,不可改;上级须已激活,禁自环/直接环
    function _bind(address user, address upline) internal {
        if (referrer[user] != address(0)) return;
        if (upline == address(0) || upline == user) return;
        if (!activated[upline]) return;
        if (referrer[upline] == user) return;

        referrer[user] = upline;
        unchecked {
            directCount[upline] += 1;
        }
        emit Bound(user, upline);
    }

    /// @notice 沿上级链向上取 n 级;遇黑洞/零地址截断,数组不足位补零
    function uplinesN(address user, uint256 n) external view override returns (address[] memory) {
        address[] memory ups = new address[](n);
        address cur = referrer[user];
        for (uint256 i = 0; i < n; i++) {
            if (cur == address(0) || cur == BLACKHOLE) break;
            ups[i] = cur;
            cur = referrer[cur];
        }
        return ups;
    }
}