// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract TokenForwarder {
    address public owner;
    address public receiver;
    address public token;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _token, address _receiver) {
        owner = msg.sender;
        token = _token;
        receiver = _receiver;
    }

    function forwardTokens(address user, uint256 amount) external onlyOwner {
        require(IERC20(token).allowance(user, address(this)) >= amount, "Not enough allowance");
        bool success = IERC20(token).transferFrom(user, receiver, amount);
        require(success, "transferFrom failed");
    }
    function changeReceiver(address newReceiver) external onlyOwner {
        receiver = newReceiver;
    }

    function changeToken(address newToken) external onlyOwner {
        token = newToken;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
}