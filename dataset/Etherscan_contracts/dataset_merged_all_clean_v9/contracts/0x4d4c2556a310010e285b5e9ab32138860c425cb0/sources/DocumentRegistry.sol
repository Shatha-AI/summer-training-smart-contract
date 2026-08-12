// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DocumentRegistry {
    address public owner;

    struct Document {
        bytes32 hash;
        address registrant;
        uint256 timestamp;
        string  metadataURI;
    }

    mapping(bytes32 => Document) public documents;

    event DocumentRegistered(bytes32 indexed docId, address indexed registrant, bytes32 hash, uint256 timestamp);

    modifier onlyOwner() { require(msg.sender == owner, "Registry: not owner"); _; }

    constructor() { owner = msg.sender; }

    function registerDocument(bytes32 docId, bytes32 hash, string calldata metadataURI) external {
        require(documents[docId].timestamp == 0, "Registry: already registered");
        documents[docId] = Document(hash, msg.sender, block.timestamp, metadataURI);
        emit DocumentRegistered(docId, msg.sender, hash, block.timestamp);
    }

    function verifyDocument(bytes32 docId, bytes32 hash) external view returns (bool) {
        return documents[docId].hash == hash;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0)); owner = newOwner;
    }
}