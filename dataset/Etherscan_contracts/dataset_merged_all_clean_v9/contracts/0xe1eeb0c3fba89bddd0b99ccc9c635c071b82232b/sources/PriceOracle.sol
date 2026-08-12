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

// File: contracts/contracts/src/interfaces/IUniswapV2.sol


pragma solidity ^0.8.24;

/**
 * @title Uniswap V2 最小接口集
 * @author suni
 * @notice 仅声明本项目用到的 Uniswap V2 Factory / Router / Pair 方法
 */

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function sync() external;
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

// File: contracts/contracts/src/PriceOracle.sol


pragma solidity ^0.8.24;




/**
 * @title UNI→U 计价预言机
 * @author suni
 * @notice 基于 UNI/USDT Uniswap V2 交易对的累积价格做 TWAP,将 UNI 折算成 U(18 位)
 * @dev 需外部定期调用 update() 累积价格窗口;首版采用简易 TWAP,生产前建议加长窗口与偏离校验
 */
contract PriceOracle is IPriceOracle, Ownable {
    /// @notice UNI/USDT 交易对
    IUniswapV2Pair public immutable pair;

    /// @notice UNI 在交易对中的 token 序位(true=token0)
    bool public immutable uniIsToken0;

    /// @notice UNI 精度(用于把"数量"折算为 18 位 U 值)
    uint256 public immutable uniDecimalsFactor;

    // TWAP 累积状态(UQ112x112 定点)
    uint256 public priceCumulativeLast;
    uint32 public blockTimestampLast;
    /// @notice 平均价格(UQ112x112):每 1 单位 UNI 值多少 U(按最小单位)
    uint256 public priceAverage;

    /// @notice TWAP 最小窗口(秒),窗口不足时沿用上一次均价
    uint256 public minWindow = 30 minutes;

    event PriceUpdated(uint256 priceAverage, uint32 timestamp);

    constructor(address pair_, address uni, uint8 uniDecimals) Ownable(msg.sender) {
        // 用局部变量,避免在构造期读取 immutable(Solidity 禁止)
        IUniswapV2Pair p = IUniswapV2Pair(pair_);
        bool isToken0 = (p.token0() == uni);

        pair = p;
        uniIsToken0 = isToken0;
        uniDecimalsFactor = 10 ** uniDecimals;

        (, , uint32 ts) = p.getReserves();
        blockTimestampLast = ts;
        priceCumulativeLast = isToken0 ? p.price0CumulativeLast() : p.price1CumulativeLast();
    }

    function setMinWindow(uint256 seconds_) external onlyOwner {
        minWindow = seconds_;
    }

    /// @notice 累积价格并在窗口足够时刷新均价;任何人可调用(建议交易/keeper 触发)
    function update() external {
        (, , uint32 ts) = pair.getReserves();
        uint32 timeElapsed;
        unchecked {
            timeElapsed = ts - blockTimestampLast; // 允许溢出回绕,符合 UniswapV2Oracle 约定
        }
        if (timeElapsed < minWindow) return;

        uint256 cumulative = uniIsToken0 ? pair.price0CumulativeLast() : pair.price1CumulativeLast();
        unchecked {
            // 每单位 UNI 对应的 U 价格(UQ112x112)
            priceAverage = (cumulative - priceCumulativeLast) / timeElapsed;
        }
        priceCumulativeLast = cumulative;
        blockTimestampLast = ts;
        emit PriceUpdated(priceAverage, ts);
    }

    /// @notice 将 uniAmount 折算为 U(18 位);priceAverage 为 UQ112x112 定点
    function uniToU(uint256 uniAmount) external view override returns (uint256 valueU) {
        require(priceAverage != 0, "oracle not ready");
        // (uniAmount / 10^uniDecimals) * price ,其中 price = 每最小单位 UNI 的 U 值 * 2^112
        // 结果换算为 18 位 U:此处假设 U(USDT桥接)已按 18 位口径,若为 6 位需在部署侧调整
        valueU = (uniAmount * priceAverage) >> 112;
    }
}