// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

interface IPriceFeed {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 time, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

interface ICurveStableSwapNGMinimal {
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function coins(uint256 i) external view returns (address);
}

interface IERC20MetadataMinimal {
    function decimals() external view returns (uint8);
}

library MathMinimal {
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                return prod0 / denominator;
            }

            require(denominator > prod1, "mulDiv overflow");

            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }

            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;

            result = prod0 * inverse;
            return result;
        }
    }
}

contract PmUsdUsdFromCurveCrvUsdSpotPriceFeed is IPriceFeed {
    error ZeroAddress();
    error InvalidPrice();
    error StalePrice();
    error InvalidCoinOrder();

    address public immutable CURVE_POOL;
    address public immutable CRVUSD_USD_FEED;

    int128 public immutable PMUSD_INDEX;
    int128 public immutable CRVUSD_INDEX;

    uint256 public immutable MAX_STALENESS;
    uint256 public immutable ONE_PMUSD;

    constructor(
        address curvePool_,
        address crvUsdUsdFeed_,
        int128 pmUsdIndex_,
        int128 crvUsdIndex_,
        uint256 maxStaleness_
    ) {
        if (curvePool_ == address(0) || crvUsdUsdFeed_ == address(0)) revert ZeroAddress();

        CURVE_POOL = curvePool_;
        CRVUSD_USD_FEED = crvUsdUsdFeed_;
        PMUSD_INDEX = pmUsdIndex_;
        CRVUSD_INDEX = crvUsdIndex_;
        MAX_STALENESS = maxStaleness_;

        address pmusd = ICurveStableSwapNGMinimal(curvePool_).coins(uint256(uint128(pmUsdIndex_)));
        address crvusd = ICurveStableSwapNGMinimal(curvePool_).coins(uint256(uint128(crvUsdIndex_)));

        if (pmusd != 0xC0c17dD08263C16f6b64E772fB9B723Bf1344DdF) revert InvalidCoinOrder();
        if (crvusd != 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E) revert InvalidCoinOrder();

        ONE_PMUSD = 10 ** IERC20MetadataMinimal(pmusd).decimals();
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 time, uint80 answeredInRound)
    {
        uint256 crvUsdOut = ICurveStableSwapNGMinimal(CURVE_POOL).get_dy(PMUSD_INDEX, CRVUSD_INDEX, ONE_PMUSD);

        int256 crvUsdUsdPrice;
        (, crvUsdUsdPrice, startedAt, time, answeredInRound) =
            AggregatorV3Interface(CRVUSD_USD_FEED).latestRoundData();

        if (crvUsdUsdPrice <= 0) revert InvalidPrice();
        if (MAX_STALENESS > 0 && block.timestamp - time > MAX_STALENESS) revert StalePrice();

        uint8 chainlinkDecimals = AggregatorV3Interface(CRVUSD_USD_FEED).decimals();

        uint256 rawUsdValue = MathMinimal.mulDiv(crvUsdOut, uint256(crvUsdUsdPrice), 1e18);

        if (chainlinkDecimals > 18) {
            rawUsdValue = rawUsdValue / (10 ** (chainlinkDecimals - 18));
        } else if (chainlinkDecimals < 18) {
            rawUsdValue = rawUsdValue * (10 ** (18 - chainlinkDecimals));
        }

        price = int256(rawUsdValue);
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }
}