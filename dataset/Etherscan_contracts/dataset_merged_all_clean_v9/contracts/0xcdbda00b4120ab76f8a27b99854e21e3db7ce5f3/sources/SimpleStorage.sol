// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This file was flattened using a custom flattening tool
// All imports have been resolved and inlined

/**
 * @title SimpleStorage
 * @dev Store and retrieve a value
 */
contract SimpleStorage {
    uint256 private storedValue;
    
    event ValueChanged(uint256 newValue);
    
    /**
     * @dev Store a new value
     * @param newValue The value to store
     */
    function store(uint256 newValue) public {
        storedValue = newValue;
        emit ValueChanged(newValue);
    }
    
    /**
     * @dev Retrieve the stored value
     * @return The stored value
     */
    function retrieve() public view returns (uint256) {
        return storedValue;
    }
}