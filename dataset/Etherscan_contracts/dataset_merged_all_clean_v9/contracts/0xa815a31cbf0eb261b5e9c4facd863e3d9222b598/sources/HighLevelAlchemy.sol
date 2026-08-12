// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////////////////
    HIGH LEVEL ALCHEMY (ALCH)

    Web: https://www.highlevelalchemy.com/
    X:   https://x.com/HighLvlAlch

    Sacrifice your other tokens to the cauldron and transmute them into
    ALCH — a play on RuneScape's High Level Alchemy spell.

    How an alch works, in one transaction:
      1. Your tokens are pulled in and SOLD into their own Uniswap
         v2/v3 WETH liquidity for real ETH. A token is only alchable if
         it has live LP — and it only mints what that LP will actually
         pay for it right now. Rugged bags transmute into dust.
      2. That ETH buys ALCH out of the canonical ALCH/ETH Uniswap v4
         pool (a real swap, so the amount can't be spoofed by flash
         price manipulation).
      3. The ALCH bought is burned, and the same amount plus a small
         transmutation bonus is freshly minted to you.

    Sustainability: every minted ALCH is backed by ALCH bought out of
    the pool with real ETH. Net supply grows only by the bonus, and the
    pool's ETH side deepens with every alch. The bonus is capped below
    round-trip swap fees so a buy → alch → sell loop cannot profitably
    farm the LP.

    The owner can only tune the bonus within its hard cap. No pause, no
    blacklist, no owner mint, no LP access. Ownership is renounceable.
//////////////////////////////////////////////////////////////////////////*/

// ---------------------------------------------------------------------------
// Uniswap v4 core types (vendored, ABI-compatible with deployed PoolManager)
// ---------------------------------------------------------------------------

type Currency is address;

struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

interface IPoolManager {
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified; // negative = exact input
        uint160 sqrtPriceLimitX96;
    }

    function unlock(bytes calldata data) external returns (bytes memory);

    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external
        returns (int256 swapDelta); // BalanceDelta: upper 128 bits amount0, lower 128 bits amount1

    function settle() external payable returns (uint256 paid);

    function take(Currency currency, address to, uint256 amount) external;
}

interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

// ---------------------------------------------------------------------------
// Uniswap v2 / v3 interfaces (sell side)
// ---------------------------------------------------------------------------

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IV3SwapRouter {
    // SwapRouter02 style: no deadline field in the struct
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IWETH {
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

// ---------------------------------------------------------------------------
// Minimal ERC20
// ---------------------------------------------------------------------------

abstract contract ERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ALCH: allowance");
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "ALCH: zero to");
        uint256 bal = balanceOf[from];
        require(bal >= amount, "ALCH: balance");
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        require(bal >= amount, "ALCH: burn balance");
        unchecked {
            balanceOf[from] = bal - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}

// ---------------------------------------------------------------------------
// High Level Alchemy
// ---------------------------------------------------------------------------

contract HighLevelAlchemy is ERC20, IUnlockCallback {
    // --- alch venues (where the sacrificed token's LP lives) ---
    uint8 public constant VENUE_UNISWAP_V2 = 0;
    uint8 public constant VENUE_UNISWAP_V3 = 1;

    // --- canonical ALCH/ETH v4 pool parameters ---
    uint24 public constant POOL_FEE = 10000; // 1%
    int24 public constant POOL_TICK_SPACING = 200;
    uint160 internal constant MIN_SQRT_PRICE_PLUS_ONE = 4295128740;

    // --- transmutation bonus ---
    // Hard-capped below the round-trip swap fee floor (~2.6%: v2 0.3% + v4
    // 1% buy + 1% sell) plus slippage, so looping cannot drain the pool.
    uint256 public constant MAX_BONUS_BPS = 250; // 2.5%
    uint256 public bonusBps;

    // --- external protocol addresses ---
    IPoolManager public immutable poolManager;
    address public immutable weth;
    IUniswapV2Router02 public immutable v2Router;
    IUniswapV2Factory public immutable v2Factory;
    IV3SwapRouter public immutable v3Router;
    IUniswapV3Factory public immutable v3Factory;

    // --- stats ---
    uint256 public totalEthTransmuted;
    uint256 public totalAlchemies;

    // --- ownership (bonus tuning only) ---
    address public owner;

    // --- reentrancy guard ---
    uint256 private _locked = 1;

    event Alchemized(
        address indexed alchemist,
        address indexed token,
        uint256 tokenAmount,
        uint256 ethValue,
        uint256 alchMinted
    );
    event BonusUpdated(uint256 bonusBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "ALCH: not owner");
        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "ALCH: reentrancy");
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(
        address _poolManager,
        address _weth,
        address _v2Router,
        address _v2Factory,
        address _v3Router,
        address _v3Factory,
        uint256 _initialSupply,
        uint256 _bonusBps
    ) ERC20("High Level Alchemy", "ALCH") {
        require(_bonusBps <= MAX_BONUS_BPS, "ALCH: bonus too high");
        poolManager = IPoolManager(_poolManager);
        weth = _weth;
        v2Router = IUniswapV2Router02(_v2Router);
        v2Factory = IUniswapV2Factory(_v2Factory);
        v3Router = IV3SwapRouter(_v3Router);
        v3Factory = IUniswapV3Factory(_v3Factory);
        bonusBps = _bonusBps;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        // Entire supply minted once, to the deployer, for the LP script.
        // The only other mint path is alch(), which burns first.
        _mint(msg.sender, _initialSupply);
    }

    /// @notice The canonical ALCH/native-ETH Uniswap v4 pool key.
    function poolKey() public view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(0)), // native ETH
            currency1: Currency.wrap(address(this)),
            fee: POOL_FEE,
            tickSpacing: POOL_TICK_SPACING,
            hooks: address(0)
        });
    }

    /*//////////////////////////////////////////////////////////////
                            HIGH LEVEL ALCHEMY
    //////////////////////////////////////////////////////////////*/

    /// @notice Sacrifice `amountIn` of `token` and receive freshly minted ALCH.
    /// @param token     The token to alch. Must have live Uniswap v2 or v3 WETH liquidity.
    /// @param amountIn  How much of it to sacrifice.
    /// @param venue     VENUE_UNISWAP_V2 or VENUE_UNISWAP_V3 (where its LP lives).
    /// @param v3Fee     v3 pool fee tier (500/3000/10000); ignored for v2.
    /// @param minEthOut Slippage floor on the ETH the sacrifice must fetch.
    /// @param minAlchOut Slippage floor on the ALCH you receive.
    /// @param deadline  Unix timestamp after which the spell fizzles.
    function alch(
        address token,
        uint256 amountIn,
        uint8 venue,
        uint24 v3Fee,
        uint256 minEthOut,
        uint256 minAlchOut,
        uint256 deadline
    ) external nonReentrant returns (uint256 alchOut) {
        require(block.timestamp <= deadline, "ALCH: expired");
        require(token != address(this), "ALCH: cannot alch ALCH");
        require(token != weth, "ALCH: cannot alch WETH");
        require(amountIn > 0, "ALCH: zero amount");

        // Pull the sacrifice (measure what actually arrived; handles fee-on-transfer tokens).
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amountIn);
        uint256 received = IERC20(token).balanceOf(address(this)) - balBefore;
        require(received > 0, "ALCH: nothing received");

        // Sell it into its own LP for real ETH. This is the valuation:
        // the token is worth exactly what its liquidity pays for it.
        uint256 ethBefore = address(this).balance;
        if (venue == VENUE_UNISWAP_V2) {
            _sellV2(token, received, minEthOut);
        } else if (venue == VENUE_UNISWAP_V3) {
            _sellV3(token, received, v3Fee, minEthOut);
        } else {
            revert("ALCH: bad venue");
        }
        uint256 ethOut = address(this).balance - ethBefore;
        require(ethOut > 0 && ethOut >= minEthOut, "ALCH: eth slippage");

        // Buy ALCH out of the cauldron with the proceeds (a real swap, so the
        // minted amount reflects executed price, not a manipulable spot read).
        uint256 bought = _buyAlch(ethOut);

        // Transmute: burn what was bought, mint it anew with the bonus.
        _burn(address(this), bought);
        alchOut = bought + (bought * bonusBps) / 10000;
        require(alchOut >= minAlchOut, "ALCH: alch slippage");
        _mint(msg.sender, alchOut);

        totalEthTransmuted += ethOut;
        totalAlchemies += 1;
        emit Alchemized(msg.sender, token, received, ethOut, alchOut);
    }

    /*//////////////////////////////////////////////////////////////
                        SELL SIDE (v2 / v3 LP)
    //////////////////////////////////////////////////////////////*/

    function _sellV2(address token, uint256 amountIn, uint256 minEthOut) internal {
        require(v2Factory.getPair(token, weth) != address(0), "ALCH: no v2 LP");
        _safeApprove(token, address(v2Router), amountIn);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = weth;
        // Router unwraps WETH and sends ETH here; supports fee-on-transfer tokens.
        v2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn, minEthOut, path, address(this), block.timestamp
        );
    }

    function _sellV3(address token, uint256 amountIn, uint24 fee, uint256 minEthOut) internal {
        require(v3Factory.getPool(token, weth, fee) != address(0), "ALCH: no v3 LP");
        _safeApprove(token, address(v3Router), amountIn);
        uint256 wethOut = v3Router.exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: weth,
                fee: fee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: minEthOut,
                sqrtPriceLimitX96: 0
            })
        );
        IWETH(weth).withdraw(wethOut);
    }

    /*//////////////////////////////////////////////////////////////
                        BUY SIDE (ALCH v4 pool)
    //////////////////////////////////////////////////////////////*/

    function _buyAlch(uint256 ethIn) internal returns (uint256 bought) {
        bytes memory result = poolManager.unlock(abi.encode(ethIn));
        bought = abi.decode(result, (uint256));
        require(bought > 0, "ALCH: nothing bought");
    }

    /// @dev Called by the PoolManager during unlock; performs the ETH -> ALCH swap.
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "ALCH: not pool manager");
        uint256 ethIn = abi.decode(data, (uint256));

        int256 delta = poolManager.swap(
            poolKey(),
            IPoolManager.SwapParams({
                zeroForOne: true, // ETH (currency0) in, ALCH (currency1) out
                amountSpecified: -int256(ethIn), // exact input
                sqrtPriceLimitX96: MIN_SQRT_PRICE_PLUS_ONE
            }),
            ""
        );

        int128 amount1 = int128(delta); // lower 128 bits: ALCH owed to us
        require(amount1 > 0, "ALCH: bad delta");
        uint256 alchAmount = uint256(uint128(amount1));

        poolManager.settle{value: ethIn}(); // pay the ETH we owe
        poolManager.take(Currency.wrap(address(this)), address(this), alchAmount);

        return abi.encode(alchAmount);
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Tune the transmutation bonus, hard-capped at MAX_BONUS_BPS.
    function setBonusBps(uint256 _bonusBps) external onlyOwner {
        require(_bonusBps <= MAX_BONUS_BPS, "ALCH: bonus too high");
        bonusBps = _bonusBps;
        emit BonusUpdated(_bonusBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner; // address(0) renounces
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    // Only the v2 router (unwrapped proceeds) and WETH (withdraw) send ETH here,
    // and it always leaves within the same alch() call.
    receive() external payable {
        require(msg.sender == weth || msg.sender == address(v2Router), "ALCH: no direct ETH");
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(0x095ea7b3, spender, amount));
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "ALCH: approve failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, amount));
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "ALCH: transferFrom failed");
    }
}
