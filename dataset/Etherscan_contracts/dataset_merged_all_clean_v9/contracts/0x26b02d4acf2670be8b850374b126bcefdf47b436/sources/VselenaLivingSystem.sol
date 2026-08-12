// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VselenaLivingSystem {
    string public name = "Vselena";
    string public symbol = "VSLN";
    uint8 public decimals = 18;
    
    // The strict floor supply below which tokens can NEVER be burned
    uint256 public constant FLOOR_SUPPLY = 11000000 * 10 ** 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    address[] public holders;
    mapping(address => bool) private isHolder;

    uint256 public basePercent = 2; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event EconomyBreathed(uint256 minted, uint256 burned);

    constructor() {
        totalSupply = FLOOR_SUPPLY;
        balanceOf[msg.sender] = FLOOR_SUPPLY;
        holders.push(msg.sender);
        isHolder[msg.sender] = true;
        emit Transfer(address(0), msg.sender, FLOOR_SUPPLY);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient funds");

        uint256 dynamicFactor = (_value * basePercent) / 100;
        uint256 finalAmount = _value;
        uint256 toMint = 0;
        uint256 toBurn = 0;

        // RULE 1: High economic activity -> Mint new tokens above the 11,000,000 floor
        if (_value >= 1000 * 10 ** 18) { 
            toMint = dynamicFactor;
            totalSupply += toMint;
            
            uint256 rewardPerHolder = toMint / holders.length;
            for (uint256 i = 0; i < holders.length; i++) {
                balanceOf[holders[i]] += rewardPerHolder;
            }
        } 
        // RULE 2: Low activity -> Burn tokens ONLY if total supply stays above the 11,000,000 floor
        else {
            if (totalSupply - dynamicFactor >= FLOOR_SUPPLY) {
                toBurn = dynamicFactor;
                require(_value > toBurn, "Transfer amount too small");
                finalAmount = _value - toBurn;
                totalSupply -= toBurn;
            } else {
                // If at or below floor, no burning occurs; transfer is 100% clean
                finalAmount = _value;
            }
        }

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += finalAmount;

        if (!isHolder[_to]) {
            holders.push(_to);
            isHolder[_to] = true;
        }

        emit Transfer(msg.sender, _to, finalAmount);
        emit EconomyBreathed(toMint, toBurn);
        return true;
    }
}