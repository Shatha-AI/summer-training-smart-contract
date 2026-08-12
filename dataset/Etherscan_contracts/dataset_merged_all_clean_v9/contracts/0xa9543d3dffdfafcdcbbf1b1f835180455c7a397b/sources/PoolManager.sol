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

// File: contracts/contracts/src/PoolManager.sol


pragma solidity ^0.8.24;




/**
 * @title 池管理器（v2，sUNI 计价）
 * @author suni
 * @notice 共振池:V5/V6 成员按等额份额惰性释放、自领;NFT池:入金3%+出金2%累积达阈值→均分节点持有者。
 *         两池均以 sUNI 计;来源 = 入金分账 + 出金分账(均由授权合约转入)。
 */
contract PoolManager is IPoolManager, Ownable {
    uint256 private constant ACC = 1e18;

    IERC20 public immutable suni;
    INodeNFT public nodeNft;

    address public teamLevel;
    mapping(address => bool) public funders; // DepositVault / WithdrawRouter

    // 共振池(等额份额惰性释放)
    uint256 public resonanceRatePerSec;
    uint256 public resonanceMemberCount;
    uint256 public accResonancePerMember;
    uint256 public resonanceLastUpdate;
    mapping(address => bool) public isResonanceMember;
    mapping(address => uint256) public resonanceDebt;

    // NFT 池(阈值均分)
    uint256 public nftBuffer;
    uint256 public nftDistributeThreshold;

    event ResonanceMemberAdded(address indexed user, uint256 count);
    event ResonanceClaimed(address indexed user, uint256 amount);
    event NftFunded(uint256 amount, uint256 buffer);
    event NftDistributed(uint256 total, uint256 holders);

    constructor(address suni_, address nodeNft_, uint256 threshold_) Ownable(msg.sender) {
        suni = IERC20(suni_);
        nodeNft = INodeNFT(nodeNft_);
        nftDistributeThreshold = threshold_;
        resonanceLastUpdate = block.timestamp;
    }

    function setRefs(address teamLevel_, address nodeNft_) external onlyOwner {
        teamLevel = teamLevel_;
        if (nodeNft_ != address(0)) nodeNft = INodeNFT(nodeNft_);
    }

    function setFunder(address a, bool v) external onlyOwner {
        funders[a] = v;
    }

    function setResonanceRate(uint256 r) external onlyOwner {
        _updateResonance();
        resonanceRatePerSec = r;
    }

    function setNftThreshold(uint256 t) external onlyOwner {
        nftDistributeThreshold = t;
    }

    // ---------------------------------------------------------------- 共振池

    function _updateResonance() internal {
        uint256 dt = block.timestamp - resonanceLastUpdate;
        if (dt > 0) {
            if (resonanceMemberCount > 0) {
                accResonancePerMember += (resonanceRatePerSec * dt * ACC) / resonanceMemberCount;
            }
            resonanceLastUpdate = block.timestamp;
        }
    }

    /// @notice TeamLevel 在用户跨入 V5 时回调(去重、单调)
    function onQualified(address user) external override {
        require(msg.sender == teamLevel, "only teamLevel");
        if (isResonanceMember[user]) return;
        _updateResonance();
        isResonanceMember[user] = true;
        resonanceDebt[user] = accResonancePerMember;
        resonanceMemberCount += 1;
        emit ResonanceMemberAdded(user, resonanceMemberCount);
    }

    function claimResonance() external {
        require(isResonanceMember[msg.sender], "not member");
        _updateResonance();
        uint256 amount = accResonancePerMember - resonanceDebt[msg.sender];
        require(amount > 0, "nothing");
        resonanceDebt[msg.sender] = accResonancePerMember;
        require(suni.transfer(msg.sender, amount), "transfer fail");
        emit ResonanceClaimed(msg.sender, amount);
    }

    /// @notice 注入共振池(sUNI 已由调用方转入本合约);仅记账/事件,释放靠惰性指数
    function fundResonance(uint256 amount) external override {
        require(funders[msg.sender], "not funder");
        // sUNI 已在合约余额中,作为释放储备;无需额外动作
        amount;
    }

    // ---------------------------------------------------------------- NFT 池

    /// @notice 注入 NFT 池(sUNI 已转入),达阈值均分给全部节点持有者
    function fundNftPool(uint256 amount) external override {
        require(funders[msg.sender], "not funder");
        nftBuffer += amount;
        emit NftFunded(amount, nftBuffer);
        if (nftBuffer >= nftDistributeThreshold && nftDistributeThreshold > 0) {
            _distributeNft();
        }
    }

    function _distributeNft() internal {
        uint256 supply = nodeNft.totalSupply();
        if (supply == 0) return;
        uint256 per = nftBuffer / supply;
        if (per == 0) return;

        uint256 distributed;
        for (uint256 i = 0; i < supply; i++) {
            address holder = nodeNft.ownerOf(nodeNft.tokenByIndex(i));
            suni.transfer(holder, per);
            distributed += per;
        }
        nftBuffer -= distributed; // 余数留待下轮
        emit NftDistributed(distributed, supply);
    }

    function sweep(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}