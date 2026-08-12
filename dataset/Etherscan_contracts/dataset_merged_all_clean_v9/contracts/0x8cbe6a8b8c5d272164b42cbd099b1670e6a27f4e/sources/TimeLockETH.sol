// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TimeLockETH {
    address public immutable OWNER = 0x9D01BaeB747fE8BEb214C152Ea2E35892787200F;
    
    uint256 public lockEndTime;
    bool public isLocked;
    
    event LockActivated(uint256 unlockTime);
    event ETHWithdrawn(uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == OWNER, "Unauthorized");
        _;
    }
    
    modifier whenUnlocked() {
        require(!isLocked || block.timestamp >= lockEndTime, "Contract blocked");
        _;
    }
    
    function timelockETH(uint256 daysToLock) 
        external 
        onlyOwner 
    {
        if (isLocked) {
            require(block.timestamp >= lockEndTime, "Current active block");
        }
        require(daysToLock >= 1 && daysToLock <= 365, "Days between 1 and 365");
        
        isLocked = true;
        lockEndTime = block.timestamp + (daysToLock * 1 days);
        
        emit LockActivated(lockEndTime);
    }
    
    function withdrawETH(uint256 amount) 
        external 
        onlyOwner 
        whenUnlocked 
    {
        require(amount > 0, "Amount must be greater than 0.");
        require(amount <= address(this).balance, "Saldo insuficiente");
        
        (bool success, ) = payable(OWNER).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit ETHWithdrawn(amount);
    }
    
    function getLockTimeLeft() external view returns (uint256) {
        if (!isLocked) return 0;
        if (block.timestamp >= lockEndTime) return 0;
        return lockEndTime - block.timestamp;
    }
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    receive() external payable {}
}