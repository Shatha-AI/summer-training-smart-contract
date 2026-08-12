// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRateProvider {
    function getRate() external view returns (uint256);
}

interface ICurveStableSwapPool {
    function price_oracle() external view returns (uint256);
}

contract CurveSdCrvCrvRateProvider is IRateProvider {
    address public immutable pool;

    error InvalidRate();

    constructor(address _pool) {
        pool = _pool;
    }

    function getRate() external view override returns (uint256) {
        uint256 p = ICurveStableSwapPool(pool).price_oracle();
        if (p == 0) revert InvalidRate();

        // Returns CRV per 1 sdCRV, scaled by 1e18.
        // Example:
        // 0.673030701510642528 = 1 sdCRV -> 0.673030701510642528 CRV
        return p;
    }
}