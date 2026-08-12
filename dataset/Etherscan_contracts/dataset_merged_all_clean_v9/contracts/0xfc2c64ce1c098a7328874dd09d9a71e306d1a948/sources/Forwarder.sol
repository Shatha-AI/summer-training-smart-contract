// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Forwarder {
    address payable public destination;
    bool private initialized;

    function initialize(address payable _destination) public {
        require(!initialized, "Already initialized");
        require(_destination != address(0), "Invalid destination");
        destination = _destination;
        initialized = true;
    }

    receive() external payable {
        require(destination != address(0), "Not initialized");
        destination.transfer(msg.value);
    }
}