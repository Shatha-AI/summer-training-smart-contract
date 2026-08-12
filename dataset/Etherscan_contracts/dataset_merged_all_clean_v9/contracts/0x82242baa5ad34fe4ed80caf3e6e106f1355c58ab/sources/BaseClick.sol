// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BaseClick {
    uint256 public count;

    event Clicked(address indexed caller, uint256 newCount);

    function click() external {
        unchecked { count += 13; }
        emit Clicked(msg.sender, count);
    }
}