// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title USD
 * @dev ERC20 Token, fully flattened for easy Etherscan verification
 */
contract USD {

    // Token details
    string public name = "USD";
    string public symbol = "USD";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    // Mappings
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        uint256 initialSupply = 100_000_000 * 10 ** uint256(decimals);
        totalSupply = initialSupply;
        balances[msg.sender] = initialSupply;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    // View balance
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    // Transfer tokens
    function transfer(address to, uint256 amount) public returns (bool) {
        require(to != address(0), "ERC20: transfer to zero address");
        require(balances[msg.sender] >= amount, "ERC20: insufficient balance");

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // Allowance
    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    // Approve spender
    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "ERC20: approve to zero address");

        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // Transfer from
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        require(balances[from] >= amount, "ERC20: insufficient balance");
        require(allowances[from][msg.sender] >= amount, "ERC20: insufficient allowance");

        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }
}