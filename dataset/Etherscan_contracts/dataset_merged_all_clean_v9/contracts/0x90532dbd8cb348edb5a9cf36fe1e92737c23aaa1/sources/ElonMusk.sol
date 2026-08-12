// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//CONDA GROUP

contract ElonMusk {
    address payable public immutable destination;

    constructor() {
        destination = payable(msg.sender);
    }

    receive() external payable {
        (bool success, ) =
            destination.call{value: msg.value}("");

        require(
            success,
            "TF"
        );
    }
}