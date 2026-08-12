// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract WithdrawUSDC {
    address public usdcAddress = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    function withdrawUSDC(uint256 amount) external {
        IERC20 usdc = IERC20(usdcAddress);
        require(usdc.balanceOf(address(this)) >= amount, "Insufficient USDC balance");
        usdc.transfer(msg.sender, amount);
    }

    function getUSDCBalance() external view returns (uint256) {
        IERC20 usdc = IERC20(usdcAddress);
        return usdc.balanceOf(address(this));
    }
}