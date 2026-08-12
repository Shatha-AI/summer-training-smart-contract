// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

interface MoonCatRescue {
    function rescueOrder(uint256 _rescueOrder) external view returns (bytes5);
    function acceptAdoptionOffer(bytes5 catId) external payable;
    function giveCat(bytes5 catId, address to) external;
    function nameCat(bytes5 catId, bytes32 catName) external;
}

contract MoonCatGenNamePerformance {

    MoonCatRescue constant MCR = MoonCatRescue(0x60cd862c9C687A9dE49aecdC3A99b74A4fc54aB6);

    address public owner = msg.sender;
    mapping(address => uint256) private userNonces;

    event CatTantrum(string);

    function performGenCatName() public {
        require(msg.sender == owner);

        bytes5 catId = MCR.rescueOrder(20069);
        require(catId == 0x00377aeabf);
        
        MCR.acceptAdoptionOffer(catId);

        userNonces[msg.sender]++;
        bytes32 randomName = keccak256(
            abi.encodePacked(
                block.prevrandao,
                block.timestamp,
                block.number,
                msg.sender,
                userNonces[msg.sender]
            )
        );
        MCR.nameCat(catId, randomName);

        emit CatTantrum("MEOW MEOW MEOW!!!");

        MCR.giveCat(catId, msg.sender);
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }
}