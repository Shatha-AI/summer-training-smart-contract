// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ETHCAT {

    string public name     = "ETHCAT";
    string public symbol   = "ETHCAT";
    uint8  public decimals = 18;

    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public blacklisted;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "ETHCAT: caller is not the owner");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "ETHCAT: account is blacklisted");
        _;
    }

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        uint256 amount = initialSupply * (10 ** decimals);
        totalSupply = amount;
        _balances[msg.sender] = amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount)
        public
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        notBlacklisted(from)
        notBlacklisted(to)
        notBlacklisted(msg.sender)
        returns (bool)
    {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ETHCAT: insufficient allowance");
        unchecked { _allowances[from][msg.sender] = currentAllowance - amount; }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ETHCAT: transfer from zero address");
        require(to   != address(0), "ETHCAT: transfer to zero address");
        require(_balances[from] >= amount, "ETHCAT: insufficient balance");

        unchecked {
            _balances[from] -= amount;
            _balances[to]   += amount;
        }
        emit Transfer(from, to, amount);
    }

    function blacklist(address account) external onlyOwner {
        require(account != address(0), "ETHCAT: cannot blacklist zero address");
        require(account != owner,      "ETHCAT: cannot blacklist owner");
        require(!blacklisted[account], "ETHCAT: already blacklisted");
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function unblacklist(address account) external onlyOwner {
        require(blacklisted[account], "ETHCAT: not blacklisted");
        blacklisted[account] = false;
        emit Unblacklisted(account);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return blacklisted[account];
    }

    function mint(address to, uint256 amount) external onlyOwner notBlacklisted(to) {
        require(to != address(0), "ETHCAT: mint to zero address");
        totalSupply     += amount;
        _balances[to]   += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external notBlacklisted(msg.sender) {
        require(_balances[msg.sender] >= amount, "ETHCAT: insufficient balance");
        unchecked { _balances[msg.sender] -= amount; }
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ETHCAT: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}