// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPriceOracle {
    function name() external view returns (string memory);
    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256 outAmount);
    function getQuotes(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256 bidOutAmount, uint256 askOutAmount);
}

library Errors {
    error PriceOracle_InvalidAnswer();
    error PriceOracle_InvalidConfiguration();
    error PriceOracle_NotSupported(address base, address quote);
    error PriceOracle_Overflow();
    error PriceOracle_TooStale(uint256 staleness, uint256 maxStaleness);
    error Governance_CallerNotGovernor();
}

library FixedPointMathLib {
    error FullMulDivFailed();

    function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 result) {
        unchecked {
            if (d == 0) revert FullMulDivFailed();
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            if (prod1 == 0) return prod0 / d;
            if (d <= prod1) revert FullMulDivFailed();
            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, d)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }
            uint256 twos = d & (~d + 1);
            assembly {
                d := div(d, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;
            uint256 inv = (3 * d) ^ 2;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            result = prod0 * inv;
        }
    }
}

type Scale is uint256;

library ScaleUtils {
    uint256 internal constant PRICE_SCALE_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
    uint256 internal constant MAX_EXPONENT = 38;

    function from(uint8 priceExponent, uint8 feedExponent) internal pure returns (Scale) {
        if (priceExponent > MAX_EXPONENT || feedExponent > MAX_EXPONENT) {
            revert Errors.PriceOracle_Overflow();
        }
        return Scale.wrap((10 ** feedExponent << 128) | 10 ** priceExponent);
    }

    function getDirectionOrRevert(address givenBase, address base, address givenQuote, address quote)
        internal
        pure
        returns (bool)
    {
        if (givenBase == base && givenQuote == quote) return false;
        if (givenBase == quote && givenQuote == base) return true;
        revert Errors.PriceOracle_NotSupported(givenBase, givenQuote);
    }

    function calcScale(uint8 baseDecimals, uint8 quoteDecimals, uint8 feedDecimals) internal pure returns (Scale) {
        return from(quoteDecimals, feedDecimals + baseDecimals);
    }

    function calcOutAmount(uint256 inAmount, uint256 unitPrice, Scale scale, bool inverse)
        internal
        pure
        returns (uint256)
    {
        uint256 priceScale = Scale.unwrap(scale) & PRICE_SCALE_MASK;
        uint256 feedScale = Scale.unwrap(scale) >> 128;

        if (inverse) {
            return FixedPointMathLib.fullMulDiv(inAmount, feedScale, priceScale * unitPrice);
        } else {
            return FixedPointMathLib.fullMulDiv(inAmount, priceScale * unitPrice, feedScale);
        }
    }
}

interface IRateProvider {
    function getRate() external view returns (uint256);
}

abstract contract BaseAdapter is IPriceOracle {
    uint256 internal constant ADDRESS_RESERVED_RANGE = 0xffffffff;

    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256) {
        return _getQuote(inAmount, base, quote);
    }

    function getQuotes(uint256 inAmount, address base, address quote) external view returns (uint256, uint256) {
        uint256 outAmount = _getQuote(inAmount, base, quote);
        return (outAmount, outAmount);
    }

    function _getDecimals(address asset) internal view returns (uint8) {
        if (uint160(asset) <= ADDRESS_RESERVED_RANGE) return 18;
        (bool success, bytes memory data) = asset.staticcall(abi.encodeCall(IERC20.decimals, ()));
        return success && data.length == 32 ? abi.decode(data, (uint8)) : 18;
    }

    function _getQuote(uint256, address, address) internal view virtual returns (uint256);
}

/// @title RateProviderOracle
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice PriceOracle adapter for Balancer Rate Providers.
/// @dev See https://docs.balancer.fi/reference/contracts/rate-providers.html
/// Note: Every Rate Provider has unique security properties. Always perform due dilligence before deploying.
contract RateProviderOracle is BaseAdapter {
    /// @inheritdoc IPriceOracle
    string public constant name = "RateProviderOracle";

    /// @notice The address of the base asset corresponding to the rate provider.
    address public immutable base;

    /// @notice The address of the quote asset corresponding to the rate provider.
    address public immutable quote;

    /// @notice The address of the Rate Provider contract.
    address public immutable rateProvider;

    /// @notice The scale factors used for decimal conversions.
    Scale internal immutable scale;

    /// @notice Deploy a RateProviderOracle.
    /// @param _base The address of the base asset corresponding to the Rate Provider.
    /// @param _quote The address of the quote asset corresponding to the Rate Provider.
    /// @param _rateProvider The address of the Balancer Rate Provider contract.
    constructor(address _base, address _quote, address _rateProvider) {
        base = _base;
        quote = _quote;
        rateProvider = _rateProvider;

        uint8 baseDecimals = _getDecimals(base);
        uint8 quoteDecimals = _getDecimals(quote);

        // Balancer Rate Providers return an 18-decimal fixed-point value.
        scale = ScaleUtils.calcScale(baseDecimals, quoteDecimals, 18);
    }

    /// @notice Get the quote from the Rate Provider.
    /// @param inAmount The amount of `base` to convert.
    /// @param _base The token that is being priced.
    /// @param _quote The token that is the unit of account.
    /// @return The converted amount using the Rate Provider.
    function _getQuote(uint256 inAmount, address _base, address _quote) internal view override returns (uint256) {
        bool inverse = ScaleUtils.getDirectionOrRevert(_base, base, _quote, quote);

        uint256 rate = IRateProvider(rateProvider).getRate();

        if (rate == 0) revert Errors.PriceOracle_InvalidAnswer();
        return ScaleUtils.calcOutAmount(inAmount, rate, scale, inverse);
    }
}