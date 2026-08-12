// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract MultiChainDonateSplitter {
    address public owner;
    address public backupTreasury;
    uint256 public platformFeePercent = 5;

    mapping(uint256 => address payable) public tailToStreamer;

    event DonatedETH(
        address indexed donor,
        address indexed streamerWallet,
        uint256 totalAmount,
        uint256 streamerAmount,
        uint256 tail
    );

    event RefundedETHToBackup(
        address indexed donor,
        uint256 totalAmount
    );

    event DonatedToken(
        address indexed donor,
        address indexed streamerWallet,
        address indexed token,
        uint256 totalAmount,
        uint256 streamerAmount
    );

    event TokensRescued(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    constructor(address _backupTreasury) {
        owner = msg.sender;
        backupTreasury = _backupTreasury;
    }

    function registerStreamerTail(uint256 tail, address payable streamerWallet) external {
        require(msg.sender == owner, "Only owner/backend");
        tailToStreamer[tail] = streamerWallet;
    }

    receive() external payable {
        require(msg.value > 0, "Amount must be greater than 0");

        uint256 tail = msg.value % 1000000;
        address payable streamerWallet = tailToStreamer[tail];

        if (streamerWallet == address(0)) {
            (bool successBackup, ) = payable(backupTreasury).call{value: msg.value}("");
            require(successBackup, "Transfer to backup failed");
            emit RefundedETHToBackup(msg.sender, msg.value);
            return;
        }

        uint256 platformFee = (msg.value * platformFeePercent) / 100;
        uint256 streamerAmount = msg.value - platformFee;

        (bool successStreamer, ) = streamerWallet.call{value: streamerAmount}("");
        require(successStreamer, "Transfer to streamer failed");

        (bool successOwner, ) = payable(owner).call{value: platformFee}("");
        require(successOwner, "Transfer to owner failed");

        emit DonatedETH(msg.sender, streamerWallet, msg.value, streamerAmount, tail);
    }

    function donateToken(address tokenAddress, uint256 amount, address payable streamerWallet) external {
        require(amount > 0, "Amount must be greater than 0");
        
        address targetWallet = streamerWallet == address(0) ? backupTreasury : streamerWallet;

        uint256 platformFee = (amount * platformFeePercent) / 100;
        uint256 streamerAmount = amount - platformFee;

        bool successStreamer = IERC20(tokenAddress).transferFrom(msg.sender, targetWallet, streamerAmount);
        require(successStreamer, "Token transfer to streamer failed");

        bool successOwner = IERC20(tokenAddress).transferFrom(msg.sender, owner, platformFee);
        require(successOwner, "Token transfer to owner failed");

        emit DonatedToken(msg.sender, targetWallet, tokenAddress, amount, streamerAmount);
    }

    function tokensRescued(address tokenAddress, uint256 amount, address recipient) external {
        require(msg.sender == owner, "Only owner");
        require(recipient != address(0), "Invalid recipient");

        if (tokenAddress == address(0)) {
            (bool success, ) = payable(recipient).call{value: amount}("");
            require(success, "ETH rescue failed");
        } else {
            bool success = IERC20(tokenAddress).transfer(recipient, amount);
            require(success, "Token rescue failed");
        }

        emit TokensRescued(tokenAddress, recipient, amount);
    }

    function setPlatformFee(uint256 _newFeePercent) external {
        require(msg.sender == owner, "Only owner");
        platformFeePercent = _newFeePercent;
    }

    function setBackupTreasury(address _newTreasury) external {
        require(msg.sender == owner, "Only owner");
        backupTreasury = _newTreasury;
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        owner = newOwner;
    }
}