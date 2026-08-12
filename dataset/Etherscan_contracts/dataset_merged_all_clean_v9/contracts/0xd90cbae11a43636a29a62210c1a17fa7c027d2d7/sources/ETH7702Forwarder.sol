// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice EIP-7702 固定地址 ETH 自动归集合约
contract ETH7702Forwarder {
    error ZeroRecipient();
    error RecipientCannotBeSelf();
    error ForwardFailed();

    /// @notice 最终归集地址，写死在合约字节码中，部署后不能修改
    address payable public immutable recipient;

    constructor(address payable recipient_) {
        if (recipient_ == address(0)) revert ZeroRecipient();
        if (recipient_ == address(this)) revert RecipientCannotBeSelf();

        recipient = recipient_;
    }

    /// @notice 普通空数据 ETH 转账进入这里
    receive() external payable {
        _forward();
    }

    /// @notice 带 calldata 的 ETH 转账进入这里
    fallback() external payable {
        _forward();
    }

    /// @notice 手动清理委托钱包内残留的 ETH
    function sweep() external {
        _forward();
    }

    function _forward() internal {
        uint256 amount = address(this).balance;
        if (amount == 0) return;

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert ForwardFailed();
    }
}