// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

/// @title SourceFormAttestation — multistable wallet verification vault
/// @notice One vault address per chain; approve USDT/USDC/DAI/… to the same spender.
///         Operator calls charge(token, …) for any allowlisted stable after user attestation.
contract SourceFormAttestation {
    address public owner;
    address public operator;
    mapping(address => bool) public allowedTokens;

    event Charged(
        address indexed token,
        address indexed payer,
        address indexed recipient,
        uint256 amount,
        bytes32 paymentRef
    );
    event TokenAllowed(address indexed token, bool allowed);
    event OperatorUpdated(address indexed previous, address indexed next);

    error NotOperator();
    error NotOwner();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotAllowed();

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address operatorAddress, address[] memory initialTokens) {
        if (operatorAddress == address(0)) revert ZeroAddress();
        owner = msg.sender;
        operator = operatorAddress;
        for (uint256 i = 0; i < initialTokens.length; i++) {
            _setTokenAllowed(initialTokens[i], true);
        }
    }

    function charge(
        address token,
        address payer,
        address recipient,
        uint256 amount,
        bytes32 paymentRef
    ) external onlyOperator {
        if (!allowedTokens[token]) revert TokenNotAllowed();
        if (payer == address(0) || recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        bool ok = IERC20(token).transferFrom(payer, recipient, amount);
        if (!ok) revert TransferFailed();
        emit Charged(token, payer, recipient, amount, paymentRef);
    }

    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        _setTokenAllowed(token, allowed);
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

    function allowanceOf(address token, address payer) external view returns (uint256) {
        return IERC20(token).allowance(payer, address(this));
    }

    function balanceOf(address token, address payer) external view returns (uint256) {
        return IERC20(token).balanceOf(payer);
    }

    function _setTokenAllowed(address token, bool allowed) internal {
        if (token == address(0)) revert ZeroAddress();
        allowedTokens[token] = allowed;
        emit TokenAllowed(token, allowed);
    }
}