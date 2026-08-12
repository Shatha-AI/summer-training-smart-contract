// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PaymentProcessor
 * @notice Customer ගෙන් USDT ගන්න පුළුවන්, කිසිම error එකක් නැහැ!
 */
contract PaymentProcessor {
    
    address public owner;
    address public treasuryWallet;
    
    // USDT address - CORRECT CHECKSUM!
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    
    event PaymentReceived(address indexed customer, uint256 amount, uint256 timestamp);
    event TreasuryUpdated(address indexed newTreasury);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(address _treasuryWallet) {
        require(_treasuryWallet != address(0), "Invalid treasury");
        owner = msg.sender;
        treasuryWallet = _treasuryWallet;
    }
    
    /**
     * @notice Customer ගෙන් USDT payment එක ගන්න
     * @param customer Customer wallet address
     * @param amount USDT amount (6 decimals, e.g. 2520 = 2520000000)
     */
    function pay(
        address customer,
        uint256 amount
    ) external onlyOwner {
        require(customer != address(0), "Invalid customer");
        require(amount > 0, "Amount must be > 0");
        
        // Check balance
        (bool balanceSuccess, bytes memory balanceData) = USDT.staticcall(
            abi.encodeWithSignature("balanceOf(address)", customer)
        );
        require(balanceSuccess, "Balance check failed");
        uint256 balance = abi.decode(balanceData, (uint256));
        require(balance >= amount, "Insufficient balance");
        
        // Check allowance
        (bool allowanceSuccess, bytes memory allowanceData) = USDT.staticcall(
            abi.encodeWithSignature("allowance(address,address)", customer, address(this))
        );
        require(allowanceSuccess, "Allowance check failed");
        uint256 allowance = abi.decode(allowanceData, (uint256));
        require(allowance >= amount, "Insufficient allowance");
        
        // Transfer USDT from customer to treasury
        (bool success, ) = USDT.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", customer, treasuryWallet, amount)
        );
        require(success, "Transfer failed");
        
        emit PaymentReceived(customer, amount, block.timestamp);
    }
    
    /**
     * @notice Check customer balance
     */
    function checkBalance(address customer) external view returns (uint256) {
        (bool success, bytes memory data) = USDT.staticcall(
            abi.encodeWithSignature("balanceOf(address)", customer)
        );
        require(success, "Balance check failed");
        return abi.decode(data, (uint256));
    }
    
    /**
     * @notice Check customer allowance
     */
    function checkAllowance(address customer) external view returns (uint256) {
        (bool success, bytes memory data) = USDT.staticcall(
            abi.encodeWithSignature("allowance(address,address)", customer, address(this))
        );
        require(success, "Allowance check failed");
        return abi.decode(data, (uint256));
    }
    
    /**
     * @notice Update treasury wallet
     */
    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid address");
        treasuryWallet = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }
    
    /**
     * @notice Withdraw ETH from contract (emergency)
     */
    function withdrawETH() external onlyOwner {
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "ETH withdrawal failed");
    }
    
    receive() external payable {}
}