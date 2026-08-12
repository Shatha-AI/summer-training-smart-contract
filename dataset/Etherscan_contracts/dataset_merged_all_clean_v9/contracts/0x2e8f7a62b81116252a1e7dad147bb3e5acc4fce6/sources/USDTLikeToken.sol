// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract USDTLikeToken {
    // 基础ERC20参数
    string public name;
    string public symbol;
    uint8 public decimals = 6; // USDT固定6位小数，不是18
    uint256 public totalSupply;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    // 管理员权限
    address public owner;
    bool public paused; // 全局暂停转账
    mapping(address => bool) public blacklist; // 黑名单

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier notBlacklisted(address _addr) {
        require(!blacklist[_addr], "Address in blacklist");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initSupply
    ) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        uint256 init = _initSupply * (10 ** uint256(decimals));
        totalSupply = init;
        balances[owner] = init;
        emit Transfer(address(0), owner, init);
    }

    // 转账
    function transfer(address to, uint256 amount) 
        external notPaused notBlacklisted(msg.sender) notBlacklisted(to) 
        returns (bool)
    {
        address sender = msg.sender;
        require(balances[sender] >= amount, "Insufficient balance");
        balances[sender] -= amount;
        balances[to] += amount;
        emit Transfer(sender, to, amount);
        return true;
    }

    // 授权
    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // 代转
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external notPaused notBlacklisted(from) notBlacklisted(to) returns (bool) {
        address spender = msg.sender;
        uint256 spenderAllowance = allowances[from][spender];
        require(spenderAllowance >= amount, "Allowance too low");
        require(balances[from] >= amount, "Insufficient balance");

        allowances[from][spender] = spenderAllowance - amount;
        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // 管理员增发（USDT核心铸币功能）
    function mint(address to, uint256 amount) external onlyOwner {
        uint256 realAmt = amount * (10 ** uint256(decimals));
        totalSupply += realAmt;
        balances[to] += realAmt;
        emit Mint(to, realAmt);
    }

    // 管理员销毁
    function burn(uint256 amount) external onlyOwner {
        uint256 realAmt = amount * (10 ** uint256(decimals));
        require(balances[msg.sender] >= realAmt, "Burn exceed balance");
        balances[msg.sender] -= realAmt;
        totalSupply -= realAmt;
        emit Burn(msg.sender, realAmt);
    }

    // 黑名单添加移除
    function addBlacklist(address _addr) external onlyOwner {
        blacklist[_addr] = true;
    }
    function removeBlacklist(address _addr) external onlyOwner {
        blacklist[_addr] = false;
    }

    // 全局暂停/解除暂停
    function setPause(bool _paused) external onlyOwner {
        paused = _paused;
    }

    // 转移合约管理员权限
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}