// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract CallcodeDepositLookalike {
    event CallcodeResult(address indexed apparentRecipient, uint256 amount, bool ok);

    function fakeDeposit(address payable apparentRecipient) external payable {
        require(msg.value > 0, "value required");

        bool ok;
        assembly {
            ok := callcode(gas(), apparentRecipient, callvalue(), 0, 0, 0, 0)
        }

        emit CallcodeResult(apparentRecipient, msg.value, ok);
        require(ok, "CALLCODE failed");

        uint256 refund = address(this).balance;
        if (refund > 0) {
            (bool refunded,) = payable(msg.sender).call{value: refund}("");
            require(refunded, "refund failed");
        }
    }

    receive() external payable {}
}