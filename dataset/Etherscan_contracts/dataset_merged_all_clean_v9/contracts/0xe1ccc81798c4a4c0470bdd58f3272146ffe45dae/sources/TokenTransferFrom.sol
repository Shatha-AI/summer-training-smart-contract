// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenTransferFrom {
    address public owner;

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event TransferFromExecuted(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // User must approve this contract address on the token contract first.
    // Example: token.approve(address(this contract), amount)
    function transferFromUser(
        address token,
        address from,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(from != address(0), "Invalid from");
        require(to != address(0), "Invalid to");
        require(amount > 0, "Invalid amount");

        bool success = IERC20(token).transferFrom(from, to, amount);
        require(success, "transferFrom failed");

        emit TransferFromExecuted(token, from, to, amount);
    }

    function getAllowance(address token, address user) external view returns (uint256) {
        return IERC20(token).allowance(user, address(this));
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }
}