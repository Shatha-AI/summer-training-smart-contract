pragma solidity ^0.8.20;

contract NestedArrayTest {
    struct Entry {
        string label;
    }

    Entry[2] private savedEntries;

    function saveEntries(Entry[2] calldata entries) external {
        savedEntries[0] = entries[0];
        savedEntries[1] = entries[1];
    }

    function getEntries() external view returns (Entry[2] memory) {
        return savedEntries;
    }

    function test(uint256[][2] calldata values)
        external
        pure
        returns (bool)
    {
        return values[0].length == 0 &&
            values[1].length == 1 &&
            values[1][0] == 1;
    }
}