// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Context {
    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract XDEVLAB is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // === 0.16% FIXED TAX = 16 / 10000, CANNOT BE CHANGED ===
    uint256 public constant SELL_TAX = 16;
    address public taxWallet;

    mapping(address => bool) public excludedFromTax;
    mapping(address => bool) public isDexPair;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    event TaxWalletUpdated(address indexed newWallet);
    event DexPairAdded(address indexed pair);
    event DexPairRemoved(address indexed pair);

    constructor() {
        _name = "XDEVLAB";
        _symbol = "XDEV";
        _decimals = 18;
        _totalSupply = 50000000000 * 10 ** 18;
        _balances[msg.sender] = _totalSupply;

        taxWallet = msg.sender;
        excludedFromTax[msg.sender] = true;
        excludedFromTax[address(this)] = true;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // Standard ERC20 read functions
    function name() external view override returns (string memory) { return _name; }
    function symbol() external view override returns (string memory) { return _symbol; }
    function decimals() external view override returns (uint8) { return _decimals; }
    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) external view override returns (uint256) { return _balances[account]; }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[_msgSender()][spender] = amount;
        emit Approval(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _allowances[sender][_msgSender()] = _allowances[sender][_msgSender()].sub(amount, "ERC20: insufficient allowance");
        return true;
    }

    // Owner controls
    function setTaxWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "ERC20: zero address");
        taxWallet = newWallet;
        emit TaxWalletUpdated(newWallet);
    }

    function addDexPair(address pair) external onlyOwner {
        require(pair != address(0), "ERC20: zero address");
        isDexPair[pair] = true;
        emit DexPairAdded(pair);
    }

    function removeDexPair(address pair) external onlyOwner {
        isDexPair[pair] = false;
        emit DexPairRemoved(pair);
    }

    function setExcluded(address account, bool excluded) external onlyOwner {
        excludedFromTax[account] = excluded;
    }

    // Core transfer logic
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0) && to != address(0), "ERC20: invalid address");

        uint256 taxAmount = 0;
        // Tax only applies when sending TO a DEX pair (selling) and sender is not excluded
        if (isDexPair[to] && !excludedFromTax[from]) {
            taxAmount = amount.mul(SELL_TAX).div(10000);
        }
        uint256 sendAmount = amount.sub(taxAmount);

        _balances[from] = _balances[from].sub(amount, "ERC20: insufficient balance");
        _balances[to] = _balances[to].add(sendAmount);

        if (taxAmount > 0) {
            _balances[taxWallet] = _balances[taxWallet].add(taxAmount);
            emit Transfer(from, taxWallet, taxAmount);
        }

        emit Transfer(from, to, sendAmount);
    }
}