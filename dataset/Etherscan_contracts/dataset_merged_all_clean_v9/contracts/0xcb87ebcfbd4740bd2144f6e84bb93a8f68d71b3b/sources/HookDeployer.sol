// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// CREATE2 deployer for pERC20Hook.
// pERC20Hook requires: address & 0x3FFF == 0x0044
// Mine salt with mine_perc20.js before deploying.

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
        require(deployed != address(0), "CREATE2 failed - constructor reverted");
        require(deployed == expected,   "Address mismatch - wrong salt or bytecode");
        emit HookDeployed(deployed);
    }
}