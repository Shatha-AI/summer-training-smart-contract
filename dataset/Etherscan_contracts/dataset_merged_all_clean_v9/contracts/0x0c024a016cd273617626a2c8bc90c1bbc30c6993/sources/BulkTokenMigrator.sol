// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BulkTokenMigrator {

    /**
     * @notice Bulk send ERC20 tokens from caller to multiple recipients
     * @dev Caller must have approved this contract for total amount
     */
    function migrate(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "Length mismatch");

        IERC20 erc20 = IERC20(token);

        for (uint256 i = 0; i < recipients.length; i++) {
            require(
                erc20.transferFrom(msg.sender, recipients[i], amounts[i]),
                "Transfer failed"
            );
        }
    }
}