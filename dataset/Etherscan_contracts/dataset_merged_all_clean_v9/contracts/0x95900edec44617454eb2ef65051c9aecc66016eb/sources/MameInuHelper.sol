// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMameInu {
    function manualSwap() external;
    function owner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MameInuHelper {
    address public mameInuAddress;
    address public owner;
    address public botWallet;

    event SwapExecuted(uint256 timestamp);
    event BotWalletUpdated(address newBot);
    event TokensWithdrawn(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyBot() {
        require(msg.sender == botWallet, "Only bot");
        _;
    }

    constructor(address _mameInuAddress, address _botWallet) {
        mameInuAddress = _mameInuAddress;
        owner = msg.sender;
        botWallet = _botWallet;
    }

    function triggerSwap() external onlyBot {
        try IMameInu(mameInuAddress).manualSwap() {
            emit SwapExecuted(block.timestamp);
        } catch {}
    }

    function withdrawMameTokens(uint256 amount) external onlyBot {
        uint256 balance = IMameInu(mameInuAddress).balanceOf(mameInuAddress);
        require(amount <= balance, "Insufficient balance in contract");
        
        try IMameInu(mameInuAddress).transfer(botWallet, amount) {
            emit TokensWithdrawn(amount);
        } catch {}
    }

    function setBotWallet(address _bot) external onlyOwner {
        botWallet = _bot;
        emit BotWalletUpdated(_bot);
    }

    function transferHelperOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function renounceHelperOwnership() external onlyOwner {
        owner = address(0);
    }
}