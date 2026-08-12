// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Name: CoinNewList (COINNEWLIST)
Website: https://coinnewlist.com/

Standard: ERC-20
Total Supply: 100,000,000,000
Decimals: 18
Network: Ethereum & EVM compatible
*/

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

contract ERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public view returns (uint8) { return _decimals; }
    function totalSupply() public view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(recipient != address(0), "ERC20: transfer to zero address");
        uint256 senderBalance = _balances[msg.sender];
        require(senderBalance >= amount, "ERC20: transfer exceeds balance");
        unchecked { _balances[msg.sender] = senderBalance - amount; }
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(sender != address(0), "ERC20: transfer from zero address");
        require(recipient != address(0), "ERC20: transfer to zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer exceeds balance");

        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer exceeds allowance");

        unchecked {
            _balances[sender] = senderBalance - amount;
            _allowances[sender][msg.sender] = currentAllowance - amount;
        }

        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(uint256 amount) public {
        uint256 accountBalance = _balances[msg.sender];
        require(accountBalance >= amount, "ERC20: burn exceeds balance");
        unchecked {
            _balances[msg.sender] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
    }
}

contract CoinNewList is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 100_000_000_000 * 10 ** 18;

    constructor() ERC20("CoinNewList", "COINNEWLIST", 18) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}