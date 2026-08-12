// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MerkleRootRecorder
 * @dev Records Merkle roots on-chain using events for cost-effective Web3 timestamping.
 */
contract MerkleRootRecorder {
    address public owner;

    event AnchorSaved(bytes32 indexed merkleRoot);

    error Unauthorized();
    error InvalidRoot();
    error InvalidAddress();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @dev Anchors a new Merkle root by emitting an event.
     * @param _merkleRoot The 32-byte hash of the Merkle tree root.
     */
    function saveNewAnchor(bytes32 _merkleRoot) external onlyOwner {
        if (_merkleRoot == bytes32(0)) {
            revert InvalidRoot();
        }
        
        emit AnchorSaved(_merkleRoot);
    }

    /**
     * @dev Transfers ownership of the contract to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidAddress();
        }
        
        owner = newOwner;
    }
}