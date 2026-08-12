// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    CIGO Batch Distributor
    ----------------------
    User flow:
    1. User approves this contract for an exact amount of CIGO.
    2. User calls distribute().
    3. This contract pulls CIGO from the user's wallet and sends it to many recipients.

    Do NOT send CIGO directly to this contract.
*/

contract CigoBatchDistributor {
    string public constant NAME = "CIGO Batch Distributor https://trade.cosigo.io";
    string public constant VERSION = "1.0.0";

    // Official current CIGO token on BNB Smart Chain
    address public constant CIGO = 0x3a38e963f524E0dDFB75dFa1752b4Cd1364F5560;

    uint256 public constant MAX_RECIPIENTS = 100;

    bool private locked;

    event BatchDistributed(
        address indexed sender,
        address indexed token,
        uint256 recipientCount,
        uint256 totalAmount
    );

    event BatchTransfer(
        address indexed sender,
        address indexed recipient,
        uint256 amount
    );

    error ReentrantCall();
    error LengthMismatch();
    error EmptyBatch();
    error TooManyRecipients();
    error ZeroRecipient(uint256 index);
    error ZeroAmount(uint256 index);
    error TransferFromFailed(uint256 index, address recipient, uint256 amount);

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    function distribute(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external nonReentrant returns (uint256 totalAmount) {
        uint256 count = recipients.length;

        if (count != amounts.length) revert LengthMismatch();
        if (count == 0) revert EmptyBatch();
        if (count > MAX_RECIPIENTS) revert TooManyRecipients();

        for (uint256 i = 0; i < count; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];

            if (recipient == address(0)) revert ZeroRecipient(i);
            if (amount == 0) revert ZeroAmount(i);

            totalAmount += amount;

            _safeTransferFrom(CIGO, msg.sender, recipient, amount, i);

            emit BatchTransfer(msg.sender, recipient, amount);
        }

        emit BatchDistributed(msg.sender, CIGO, count, totalAmount);
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 index
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                0x23b872dd,
                from,
                to,
                amount
            )
        );

        if (!success) {
            revert TransferFromFailed(index, to, amount);
        }

        if (data.length > 0) {
            if (data.length != 32) {
                revert TransferFromFailed(index, to, amount);
            }

            bool result = abi.decode(data, (bool));

            if (!result) {
                revert TransferFromFailed(index, to, amount);
            }
        }
    }
}