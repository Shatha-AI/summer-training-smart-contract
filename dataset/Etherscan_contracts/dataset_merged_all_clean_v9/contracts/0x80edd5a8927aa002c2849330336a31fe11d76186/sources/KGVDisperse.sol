// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract KGVDisperse {
    event Dispersed(address indexed token, address indexed sender, address indexed recipient, uint256 amount);
    event BatchDispersed(address indexed token, address indexed sender, uint256 totalAmount, uint256 recipientCount);

    function disperseToken(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty recipients");
        require(recipients.length <= 100, "Too many recipients");

        IERC20 tokenContract = IERC20(token);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Zero address");
            require(amounts[i] > 0, "Zero amount");
            totalAmount += amounts[i];
        }

        require(
            tokenContract.allowance(msg.sender, address(this)) >= totalAmount,
            "Insufficient allowance"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            require(
                tokenContract.transferFrom(msg.sender, recipients[i], amounts[i]),
                "Transfer failed"
            );
            emit Dispersed(token, msg.sender, recipients[i], amounts[i]);
        }

        emit BatchDispersed(token, msg.sender, totalAmount, recipients.length);
    }

    function checkDisperse(
        address token,
        address sender,
        uint256 totalAmount
    ) external view returns (bool hasAllowance, uint256 currentAllowance) {
        IERC20 tokenContract = IERC20(token);
        currentAllowance = tokenContract.allowance(sender, address(this));
        hasAllowance = currentAllowance >= totalAmount;
    }
}