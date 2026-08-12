// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CheemsBonkCounter {
    uint256 public bonkCount;
    address public owner;
    string public lastBonker;
    uint256 public lastBonkAt;

    event Bonked(address indexed bonker, string name, uint256 newCount, uint256 timestamp);
    event CounterReset(address indexed resetBy, uint256 oldCount, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function bonk(string memory name) external {
        require(bytes(name).length > 0, "Name required");
        require(bytes(name).length <= 32, "Name too long");

        bonkCount += 1;
        lastBonker = name;
        lastBonkAt = block.timestamp;

        emit Bonked(msg.sender, name, bonkCount, block.timestamp);
    }

    function resetCounter() external onlyOwner {
        uint256 oldCount = bonkCount;
        bonkCount = 0;
        lastBonker = "";
        lastBonkAt = 0;

        emit CounterReset(msg.sender, oldCount, block.timestamp);
    }
}