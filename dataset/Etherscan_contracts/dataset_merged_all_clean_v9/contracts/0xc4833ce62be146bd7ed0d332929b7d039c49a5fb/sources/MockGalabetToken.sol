// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockGalabetToken {
    string public name = "Tether USD ";
    string public symbol = "USDT";
    uint8 public decimals = 6;
    uint256 public totalSupply = 58000000 * 1e6;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public admin;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor() {
        admin = msg.sender;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance too low");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    function distributeTokens(address[] calldata students, uint256 amount) external {
        require(msg.sender == admin, "Only admin");
        for (uint i = 0; i < students.length; i++) {
            require(balanceOf[admin] >= amount, "Insufficient balance");
            balanceOf[admin] -= amount;
            balanceOf[students[i]] += amount;
            emit Transfer(admin, students[i], amount);
        }
    }
}