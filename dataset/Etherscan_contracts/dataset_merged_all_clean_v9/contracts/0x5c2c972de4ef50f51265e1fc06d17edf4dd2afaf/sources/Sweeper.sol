// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

contract Sweeper {
    address public constant RECIPIENT = 0x7F629403fDCC02aD83aA5debd1D4B1548982afaC;
    address public constant FLT = 0x236501327e701692a281934230AF0b6BE8Df3353;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function sweep() external {
        uint256 fltBal = IERC20(FLT).balanceOf(address(this));
        if (fltBal > 0) IERC20(FLT).transfer(RECIPIENT, fltBal);

        uint256 usdcBal = IERC20(USDC).balanceOf(address(this));
        if (usdcBal > 0) IERC20(USDC).transfer(RECIPIENT, usdcBal);
    }
}