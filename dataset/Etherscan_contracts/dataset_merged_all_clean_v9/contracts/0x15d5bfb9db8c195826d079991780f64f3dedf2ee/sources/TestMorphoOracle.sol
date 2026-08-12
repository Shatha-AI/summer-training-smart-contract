// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// TEST ONLY — owner can arbitrarily change the collateral price.
contract TestMorphoOracle {
    address public immutable owner;
    uint256 private _price;

    error NotOwner();
    error InvalidPrice();

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    constructor(uint256 initialPrice) {
        owner = msg.sender;
        _setPrice(initialPrice);
    }

    function price() external view returns (uint256) {
        return _price;
    }

    function setPrice(uint256 newPrice) external {
        if (msg.sender != owner) revert NotOwner();
        _setPrice(newPrice);
    }

    function _setPrice(uint256 newPrice) internal {
        if (newPrice == 0) revert InvalidPrice();

        emit PriceUpdated(_price, newPrice);
        _price = newPrice;
    }
}