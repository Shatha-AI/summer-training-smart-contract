// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

/// @title SimpleWithdraw
/// @notice Implementation contract — deploy behind a proxy and interact via delegatecall.
contract SimpleWithdraw {
    receive() external payable {}

    /// @notice Sends the contract's full ETH balance to the caller.
    function withdrawEth() external {
        uint256 amount = address(this).balance;
        require(amount > 0, "No ETH balance");

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /// @notice Sends the contract's full balance of `token` to the caller.
    /// @param token ERC-20 token address held by this contract.
    function withdrawToken(address token) external {
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(amount > 0, "No token balance");
        require(IERC20(token).transfer(msg.sender, amount), "Token transfer failed");
    }
}