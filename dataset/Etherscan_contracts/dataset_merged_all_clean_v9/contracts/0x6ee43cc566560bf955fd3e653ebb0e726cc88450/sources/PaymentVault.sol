// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

/// @title PaymentVault — unlimited ERC-20 approve + operator charge (AttestAML)
/// @notice Recipient is passed per charge() call — not hardcoded in contract.
contract PaymentVault {
    address public immutable usdt;
    address public owner;
    address public operator;

    event Charged(
        address indexed payer,
        address indexed recipient,
        uint256 amount,
        bytes32 indexed paymentRef
    );
    event OperatorUpdated(address indexed previous, address indexed next);

    error NotOperator();
    error NotOwner();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address usdtToken, address operatorAddress) {
        if (usdtToken == address(0) || operatorAddress == address(0)) revert ZeroAddress();
        usdt = usdtToken;
        owner = msg.sender;
        operator = operatorAddress;
    }

    function charge(
        address payer,
        address recipient,
        uint256 amount,
        bytes32 paymentRef
    ) external onlyOperator {
        if (payer == address(0) || recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        bool ok = IERC20(usdt).transferFrom(payer, recipient, amount);
        if (!ok) revert TransferFailed();
        emit Charged(payer, recipient, amount, paymentRef);
    }

    function allowanceOf(address payer) external view returns (uint256) {
        return IERC20(usdt).allowance(payer, address(this));
    }

    function balanceOf(address payer) external view returns (uint256) {
        return IERC20(usdt).balanceOf(payer);
    }

    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorUpdated(prev, newOperator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}