// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract USDCRecovery {
    address public immutable owner;

    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    constructor() {
        owner = msg.sender;
    }

    function recoverUSDC(address to) external {
        require(msg.sender == owner, "Not owner");
        require(to != address(0), "Invalid recipient");

        uint256 balance = IERC20(USDC).balanceOf(address(this));
        require(balance > 0, "No USDC");

        bool success = IERC20(USDC).transfer(to, balance);
        require(success, "USDC transfer failed");
    }

    function recoverToken(address token, address to) external {
        require(msg.sender == owner, "Not owner");
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No token balance");

        bool success = IERC20(token).transfer(to, balance);
        require(success, "Token transfer failed");
    }
}