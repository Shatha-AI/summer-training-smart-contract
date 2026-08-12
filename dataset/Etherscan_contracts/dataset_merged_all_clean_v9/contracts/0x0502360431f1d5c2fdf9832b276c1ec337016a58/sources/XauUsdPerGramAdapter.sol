// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal Chainlink AggregatorV3 interface.
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);

    function getRoundData(uint80 roundId)
        external
        view
        returns (
            uint80 roundId_,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title XAU/USD Per Gram Adapter
/// @notice Wraps a Chainlink-compatible XAU/USD feed quoted per troy ounce and
/// returns a Chainlink-compatible XAU/USD price quoted per gram.
/// @dev Intended to be used as a base feed in MorphoChainlinkOracleV2 when
/// XAUa represents 1 gram of gold.
contract XauUsdPerGramAdapter is AggregatorV3Interface {
    error InvalidFeed();
    error InvalidAnswer(int256 answer);

    AggregatorV3Interface public immutable XAU_USD_PER_TROY_OUNCE;

    /// @dev 31.103476800 grams per troy ounce, scaled by 1e9.
    uint256 private constant GRAMS_PER_TROY_OUNCE_SCALED = 31_103_476_800;
    uint256 private constant GRAMS_PER_TROY_OUNCE_SCALE = 1e9;

    constructor(address xauUsdPerTroyOunceFeed) {
        if (xauUsdPerTroyOunceFeed == address(0)) revert InvalidFeed();

        XAU_USD_PER_TROY_OUNCE = AggregatorV3Interface(xauUsdPerTroyOunceFeed);
    }

    function decimals() external view returns (uint8) {
        return XAU_USD_PER_TROY_OUNCE.decimals();
    }

    function description() external pure returns (string memory) {
        return "XAU / USD per gram";
    }

    function version() external view returns (uint256) {
        return XAU_USD_PER_TROY_OUNCE.version();
    }

    function getRoundData(uint80 roundId)
        external
        view
        returns (
            uint80 roundId_,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId_, answer, startedAt, updatedAt, answeredInRound) =
            XAU_USD_PER_TROY_OUNCE.getRoundData(roundId);

        answer = _toPerGram(answer);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) =
            XAU_USD_PER_TROY_OUNCE.latestRoundData();

        answer = _toPerGram(answer);
    }

    function _toPerGram(int256 answer) internal pure returns (int256) {
        if (answer <= 0) revert InvalidAnswer(answer);

        uint256 scaledAnswer =
            uint256(answer) * GRAMS_PER_TROY_OUNCE_SCALE / GRAMS_PER_TROY_OUNCE_SCALED;

        if (scaledAnswer == 0) revert InvalidAnswer(answer);

        return int256(scaledAnswer);
    }
}