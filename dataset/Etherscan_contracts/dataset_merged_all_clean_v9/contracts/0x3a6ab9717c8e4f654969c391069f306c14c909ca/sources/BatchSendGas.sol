// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BatchSendGas {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Batch send ETH to multiple addresses
    function batchSendGas(address[] calldata recipients, uint256 amount) external payable {
        uint256 totalAmount = amount * recipients.length;
        require(msg.value >= totalAmount, "Insufficient ETH sent");

        for(uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");
            (bool success, ) = recipients[i].call{value: amount}("");
            require(success, "Failed to send ETH");
        }

        // If more ETH is sent than needed, return the remaining ETH to owner
        uint256 remaining = msg.value - totalAmount;
        if(remaining > 0) {
            (bool success, ) = owner.call{value: remaining}("");
            require(success, "Failed to return remaining ETH");
        }
    }

    // Batch send ETH to multiple addresses
    function batchSendGas(address[] calldata recipients, uint256[] calldata amounts) external payable {
        require(recipients.length == amounts.length, "Recipients and amounts length mismatch");

        uint256 totalAmount = 0;
        for(uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(msg.value >= totalAmount, "Insufficient ETH sent");

        for(uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");
            (bool success, ) = recipients[i].call{value: amounts[i]}("");
            require(success, "Failed to send ETH");
        }

        // If more ETH is sent than needed, return the remaining ETH to owner
        uint256 remaining = msg.value - totalAmount;
        if(remaining > 0) {
            (bool success, ) = owner.call{value: remaining}("");
            require(success, "Failed to return remaining ETH");
        }
    }

    // Allow owner to withdraw ETH from the contract
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        require(success, "Failed to withdraw ETH");
    }

    // Allow changing the owner
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }

    receive() external payable {}
}