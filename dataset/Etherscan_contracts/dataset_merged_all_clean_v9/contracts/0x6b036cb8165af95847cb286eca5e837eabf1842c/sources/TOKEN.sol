// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

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
        if (a == 0) return 0;
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

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
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

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
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

contract TOKEN is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    address payable private _taxWallet;

    string private constant _name = unicode"SHSH";
    string private constant _symbol = unicode"SH";
    uint8 private constant _decimals = 9;

    uint256 private constant _tTotal = 1000000000000000 * 10 ** _decimals;

    uint256 public _maxTxAmount = 20000000000000 * 10 ** _decimals;

    uint256 private constant _sellTax = 5;
    uint256 private constant _taxDuration = 24 hours;

    uint256 private _taxSwapThreshold = _tTotal * 5 / 1000;

    IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;

    bool private tradingOpen;
    bool private swapEnabled;
    bool private inSwap;

    uint256 private tradingOpenTime;

    event MaxTxAmountUpdated(uint256 _maxTxAmount);
    event TaxWalletUpdated(address indexed oldWallet, address indexed newWallet);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () payable {
        _taxWallet = payable(_msgSender());

        _balances[_msgSender()] = _tTotal;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function isTradingOpen() public view returns (bool) {
        return tradingOpen;
    }

    function _currentSellTax() private view returns (uint256) {
        if (!tradingOpen) {
            return 0;
        }

        if (block.timestamp < tradingOpenTime + _taxDuration) {
            return _sellTax;
        }

        return 0;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address holder, address spender) public view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")
        );

        _transfer(sender, recipient, amount);

        return true;
    }

    function _approve(address holder, address spender, uint256 amount) private {
        require(holder != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[holder][spender] = amount;

        emit Approval(holder, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (!tradingOpen) {
            require(
                from == owner() || from == address(this),
                "Trading not open"
            );
        }

        uint256 taxAmount = 0;

        bool takeFee = true;

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        bool isBuy = from == uniswapV2Pair && to != address(uniswapV2Router);
        bool isSell = to == uniswapV2Pair && from != address(this);

        if (isBuy || isSell) {
            require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
        }

        if (takeFee && isSell) {
            uint256 sellTaxRate = _currentSellTax();

            if (sellTaxRate > 0) {
                taxAmount = amount.mul(sellTaxRate).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));

            if (
                !inSwap &&
                swapEnabled &&
                tradingOpen &&
                contractTokenBalance >= _taxSwapThreshold
            ) {
                uint256 swapAmount = contractTokenBalance;

                if (swapAmount > _taxSwapThreshold) {
                    swapAmount = _taxSwapThreshold;
                }

                swapTokensForEth(swapAmount);

                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(contractETHBalance);
                }
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }

        _balances[from] = _balances[from].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[to] = _balances[to].add(amount.sub(taxAmount));

        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        require(tokenAmount > 0, "Token amount is zero");

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function sendETHToFee(uint256 amount) private {
        require(_taxWallet.code.length == 0, "Tax wallet cannot be contract");
        _taxWallet.transfer(amount);
    }

    function setTaxWallet(address payable newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        require(newWallet.code.length == 0, "Tax wallet cannot be contract");

        address oldWallet = _taxWallet;
        _taxWallet = newWallet;

        _isExcludedFromFee[oldWallet] = false;
        _isExcludedFromFee[newWallet] = true;

        emit TaxWalletUpdated(oldWallet, newWallet);
    }

    function removeLimits() external onlyOwner {
        _maxTxAmount = _tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function openTrading() external onlyOwner {
        require(!tradingOpen, "Trading is already open");

        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 contractETHBalance = address(this).balance;

        require(contractTokenBalance > 0, "No tokens in contract");
        require(contractETHBalance > 0, "No ETH in contract");

        address pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(
            address(this),
            uniswapV2Router.WETH()
        );

        if (pair == address(0)) {
            pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );
        }

        uniswapV2Pair = pair;

        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        uniswapV2Router.addLiquidityETH{value: contractETHBalance}(
            address(this),
            contractTokenBalance,
            0,
            0,
            owner(),
            block.timestamp
        );

        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint256).max);

        swapEnabled = true;
        tradingOpen = true;
        tradingOpenTime = block.timestamp;
    }

    function manualSwap() external {
        require(_msgSender() == _taxWallet || _msgSender() == owner(), "Not allowed");
        require(address(uniswapV2Router) != address(0), "Router not set");

        uint256 tokenBalance = balanceOf(address(this));

        if (tokenBalance > 0) {
            uint256 swapAmount = tokenBalance;

            if (swapAmount > _taxSwapThreshold) {
                swapAmount = _taxSwapThreshold;
            }

            swapTokensForEth(swapAmount);
        }

        uint256 ethBalance = address(this).balance;

        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }

    receive() external payable {}
}