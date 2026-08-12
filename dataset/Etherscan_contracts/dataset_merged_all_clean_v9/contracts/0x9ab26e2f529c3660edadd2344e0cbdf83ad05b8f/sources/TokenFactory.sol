// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract TokenFactory {
    event Deployed(address indexed addr, bytes32 indexed salt);

    /// @notice Deploy arbitrary bytecode using CREATE2.
    function deploy(bytes memory bytecode, bytes32 salt)
        external
        returns (address addr)
    {
        require(bytecode.length != 0, "Empty bytecode");

        assembly {
            addr := create2(
                0,
                add(bytecode, 0x20),
                mload(bytecode),
                salt
            )

            if iszero(addr) {
                revert(0, 0)
            }
        }

        emit Deployed(addr, salt);
    }

    /// @notice Computes the CREATE2 deployment address.
    function computeAddress(
        bytes32 salt,
        bytes32 bytecodeHash
    ) external view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            bytecodeHash
                        )
                    )
                )
            )
        );
    }
}