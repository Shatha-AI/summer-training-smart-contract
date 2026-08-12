// https://x.com/ChainForgeETH

// https://www.chainforge.sh/

pragma solidity 0.8.23;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) { return _owner; }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

struct PoolKeyV4 {
    address currency0;
    address currency1;
    uint24  fee;
    int24   tickSpacing;
    address hooks;
}

interface IV4PoolManager {
    struct ModifyLiquidityParams {
        int24   tickLower;
        int24   tickUpper;
        int256  liquidityDelta;
        bytes32 salt;
    }
    function initialize(PoolKeyV4 memory key, uint160 sqrtPriceX96) external returns (int24);
    function unlock(bytes calldata data) external returns (bytes memory);
    function modifyLiquidity(
        PoolKeyV4 memory key,
        ModifyLiquidityParams memory params,
        bytes calldata hookData
    ) external returns (int256 callerDelta, int256 feesAccrued);
    function sync(address currency) external;
    function settle() external payable returns (uint256);
    function take(address currency, address to, uint256 amount) external;
}

contract ERC420 is Context, IERC20, Ownable {
    mapping(address => uint256)                     private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint8   private constant _decimals = 9;
    uint256 private constant _tTotal   = 100000000000 * 10**_decimals;
    string  private constant _name     = unicode"ChainForge";
    string  private constant _symbol   = unicode"CFG";

    IV4PoolManager private _v4Manager;
    PoolKeyV4      private _v4Key;
    bool           private _v4TradingOpen;
    int256         private _v4Liquidity;
    int24          private _v4TickLower;
    int24          private _v4TickUpper;

    constructor() payable {
        _balances[address(this)] = _tTotal;
        emit Transfer(address(0), address(this), _tTotal);
    }

    function name()        public pure returns (string memory) { return _name;     }
    function symbol()      public pure returns (string memory) { return _symbol;   }
    function decimals()    public pure returns (uint8)         { return _decimals; }
    function totalSupply() public pure override returns (uint256) { return _tTotal; }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked { _allowances[sender][_msgSender()] = currentAllowance - amount; }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to   != address(0), "ERC20: transfer to the zero address");
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] -= amount;
            _balances[to]   += amount;
        }
        emit Transfer(from, to, amount);
    }

    function openTradingV4(
        address v4Manager,
        address weth,
        uint160 sqrtPriceX96,
        int24   tickSpacing,
        uint24  fee,
        int24   tickLower,
        int24   tickUpper,
        int256  liquidityDelta
    ) external onlyOwner {
        require(!_v4TradingOpen, "V4 already open");
        _v4Manager   = IV4PoolManager(v4Manager);
        _v4TickLower = tickLower;
        _v4TickUpper = tickUpper;
        _v4Liquidity = liquidityDelta;
        (address t0, address t1) = address(this) < weth
            ? (address(this), weth)
            : (weth, address(this));
        _v4Key = PoolKeyV4(t0, t1, fee, tickSpacing, address(0));
        _v4Manager.unlock(abi.encode(uint8(0), sqrtPriceX96, tickLower, tickUpper, liquidityDelta));
        _v4TradingOpen = true;
    }

    function removeLiquidityV4() external onlyOwner {
        require(_v4TradingOpen, "V4 not open");
        _v4Manager.unlock(abi.encode(uint8(1)));
        _v4TradingOpen = false;
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(_v4Manager));
        uint8 action = abi.decode(data, (uint8));

        if (action == 0) {
            (, uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper, int256 liquidityDelta) =
                abi.decode(data, (uint8, uint160, int24, int24, int256));
            try _v4Manager.initialize(_v4Key, sqrtPriceX96) {} catch {}
            (int256 delta,) = _v4Manager.modifyLiquidity(
                _v4Key,
                IV4PoolManager.ModifyLiquidityParams(tickLower, tickUpper, liquidityDelta, bytes32(0)),
                ""
            );
            int128 d0 = int128(delta >> 128);
            int128 d1 = int128(delta);
            if (d0 < 0) {
                _v4Manager.sync(_v4Key.currency0);
                IERC20(_v4Key.currency0).transfer(address(_v4Manager), uint128(-d0));
                _v4Manager.settle();
            }
            if (d1 < 0) {
                _v4Manager.sync(_v4Key.currency1);
                IERC20(_v4Key.currency1).transfer(address(_v4Manager), uint128(-d1));
                _v4Manager.settle();
            }
        } else {
            (int256 delta,) = _v4Manager.modifyLiquidity(
                _v4Key,
                IV4PoolManager.ModifyLiquidityParams(_v4TickLower, _v4TickUpper, -_v4Liquidity, bytes32(0)),
                ""
            );
            int128 d0 = int128(delta >> 128);
            int128 d1 = int128(delta);
            if (d0 > 0) _v4Manager.take(_v4Key.currency0, owner(), uint128(d0));
            if (d1 > 0) _v4Manager.take(_v4Key.currency1, owner(), uint128(d1));
        }
        return "";
    }

    function rescueERC20(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    receive() external payable {}
}