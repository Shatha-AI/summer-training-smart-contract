// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract HookDeployer {
    event HookDeployed(address indexed deployed);

    function deployHook(
        bytes32 salt,
        bytes memory bytecode,
        address expected
    ) external returns (address deployed) {
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(deployed != address(0), "CREATE2 failed");
        require(deployed == expected,   "Address mismatch");
        emit HookDeployed(deployed);
    }
}