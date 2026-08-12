// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;










/**
 * @title WadRayMath library
 * @author Aave
 * @notice Provides functions to perform calculations with Wad and Ray units
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits of precision) and rays (decimal numbers
 * with 27 digits of precision)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library WadRayMath {
    // HALF_WAD and HALF_RAY expressed with extended notation as constant with operations are not supported in Yul assembly
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    /**
     * @return One ray, 1e27
     *
     */
    function ray() internal pure returns (uint256) {
        return RAY;
    }

    /**
     * @dev Multiplies two wad, rounding half up to the nearest wad
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Wad
     * @param b Wad
     * @return c = a*b, in wad
     */
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) { revert(0, 0) }

            c := div(add(mul(a, b), HALF_WAD), WAD)
        }
    }

    /**
     * @dev Divides two wad, rounding half up to the nearest wad
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Wad
     * @param b Wad
     * @return c = a/b, in wad
     */
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - halfB) / WAD
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))) {
                revert(0, 0)
            }

            c := div(add(mul(a, WAD), div(b, 2)), b)
        }
    }

    /**
     * @notice Multiplies two ray, rounding half up to the nearest ray
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Ray
     * @param b Ray
     * @return c = a raymul b
     */
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) { revert(0, 0) }

            c := div(add(mul(a, b), HALF_RAY), RAY)
        }
    }

    /**
     * @notice Divides two ray, rounding half up to the nearest ray
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Ray
     * @param b Ray
     * @return c = a raydiv b
     */
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - halfB) / RAY
        assembly {
            if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))) {
                revert(0, 0)
            }

            c := div(add(mul(a, RAY), div(b, 2)), b)
        }
    }

    /**
     * @dev Casts ray down to wad
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Ray
     * @return b = a converted to wad, rounded half up to the nearest wad
     */
    function rayToWad(uint256 a) internal pure returns (uint256 b) {
        assembly {
            b := div(a, WAD_RAY_RATIO)
            let remainder := mod(a, WAD_RAY_RATIO)
            if iszero(lt(remainder, div(WAD_RAY_RATIO, 2))) { b := add(b, 1) }
        }
    }

    /**
     * @dev Converts wad up to ray
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param a Wad
     * @return b = a converted in ray
     */
    function wadToRay(uint256 a) internal pure returns (uint256 b) {
        // to avoid overflow, b/WAD_RAY_RATIO == a
        assembly {
            b := mul(a, WAD_RAY_RATIO)

            if iszero(eq(div(b, WAD_RAY_RATIO), a)) { revert(0, 0) }
        }
    }
}






/**
 * @title MathUtils library
 * @author Aave
 * @notice Provides functions to perform linear and compounded interest calculations
 */
library MathUtils {
    using WadRayMath for uint256;

    /// @dev Ignoring leap years
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /**
     * @dev Function to calculate the interest accumulated using a linear interest rate formula
     * @param rate The interest rate, in ray
     * @param lastUpdateTimestamp The timestamp of the last update of the interest
     * @return The interest rate linearly accumulated during the timeDelta, in ray
     */
    function calculateLinearInterest(uint256 rate, uint40 lastUpdateTimestamp)
        internal
        view
        returns (uint256)
    {
        //solium-disable-next-line
        uint256 result = rate * (block.timestamp - uint256(lastUpdateTimestamp));
        unchecked {
            result = result / SECONDS_PER_YEAR;
        }

        return WadRayMath.RAY + result;
    }

    /**
     * @dev Function to calculate the interest using a compounded interest rate formula
     * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
     *
     *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
     *
     * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great
     * gas cost reductions. The whitepaper contains reference to the approximation and a table showing the margin of
     * error per different time periods
     *
     * @param rate The interest rate, in ray
     * @param lastUpdateTimestamp The timestamp of the last update of the interest
     * @return The interest rate compounded during the timeDelta, in ray
     */
    function calculateCompoundedInterest(
        uint256 rate,
        uint40 lastUpdateTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        //solium-disable-next-line
        uint256 exp = currentTimestamp - uint256(lastUpdateTimestamp);

        if (exp == 0) {
            return WadRayMath.RAY;
        }

        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwo;
        uint256 basePowerThree;
        unchecked {
            expMinusOne = exp - 1;

            expMinusTwo = exp > 2 ? exp - 2 : 0;

            basePowerTwo = rate.rayMul(rate) / (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
            basePowerThree = basePowerTwo.rayMul(rate) / SECONDS_PER_YEAR;
        }

        uint256 secondTerm = exp * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }
        uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        return WadRayMath.RAY + (rate * exp) / SECONDS_PER_YEAR + secondTerm + thirdTerm;
    }

    /**
     * @dev Calculates the compounded interest between the timestamp of the last update and the current block timestamp
     * @param rate The interest rate (in ray)
     * @param lastUpdateTimestamp The timestamp from which the interest accumulation needs to be calculated
     * @return The interest rate compounded between lastUpdateTimestamp and current block timestamp, in ray
     */
    function calculateCompoundedInterest(uint256 rate, uint40 lastUpdateTimestamp)
        internal
        view
        returns (uint256)
    {
        return calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
    }

    function mulDivCeil(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 d) {
        assembly {
            // Revert if c == 0 to avoid division by zero
            if iszero(c) {
                revert(0, 0)
            }

            // Overflow check: Ensure a * b does not exceed uint256 max
            if iszero(or(iszero(b), iszero(gt(a, div(not(0), b))))) {
                revert(0, 0)
            }

            let product := mul(a, b)
            d := add(div(product, c), iszero(iszero(mod(product, c))))
        }
    }
}






library DataTypes {
    /// @dev Legacy reserve data
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        // DEPRECATED on v3.2.0
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //aToken address
        address aTokenAddress;
        // DEPRECATED on v3.2.0
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        // DEPRECATED on v3.4.0, should use the `RESERVE_INTEREST_RATE_STRATEGY` variable from the Pool contract
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        // DEPRECATED on v3.4.0
        uint128 unbacked;
        // DEPRECATED on v3.7.0
        uint128 isolationModeTotalDebt;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: DEPRECATED: stable rate borrowing enabled
        //bit 60: asset is paused
        //bit 61: DEPRECATED: borrowing in isolation mode is enabled
        //bit 62: DEPRECATED: siloed borrowing enabled
        //bit 63: flashloaning enabled
        //bit 64-79: reserve factor
        //bit 80-115: borrow cap in whole tokens, borrowCap == 0 => no cap
        //bit 116-151: supply cap in whole tokens, supplyCap == 0 => no cap
        //bit 152-167: liquidation protocol fee
        //bit 168-175: DEPRECATED: eMode category
        //bit 176-211: DEPRECATED: unbacked mint cap
        //bit 212-251: DEPRECATED: debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
        //bit 252: DEPRECATED: virtual accounting is enabled for the reserve
        //bit 253-255 unused
        uint256 data;
    }

    struct UserConfigurationMap {
        /**
         * @dev Bitmap of the users collaterals and borrows. It is divided in pairs of bits, one pair per asset.
         * The first bit indicates if an asset is used as collateral by the user, the second whether an
         * asset is borrowed by the user.
         */
        uint256 data;
    }

    // DEPRECATED: kept for backwards compatibility, might be removed in a future version
    struct EModeCategoryLegacy {
        // each eMode category has a custom ltv and liquidation threshold
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        // DEPRECATED
        address priceSource;
        string label;
    }

    struct CollateralConfig {
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
    }

    struct EModeCategoryNew {
        // each eMode category has a custom ltv and liquidation threshold
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        uint128 collateralBitmap;
        bool isolated; // if true, only assets in collateralBitmap can be used as collateral, and all others will have ltv0 rules applying
        string label;
        uint128 borrowableBitmap;
        uint128 ltvzeroBitmap; // if true, the asset will be treated as ltv0 and ltv0 rules apply
    }

    enum InterestRateMode {
        NONE,
        _DEPRECATED,
        VARIABLE
    }

    struct CalculateInterestRatesParams {
        uint256 unbacked;
        uint256 liquidityAdded;
        uint256 liquidityTaken;
        uint256 totalDebt;
        uint256 reserveFactor;
        address reserve;
        // @notice DEPRECATED in 3.4, but kept for backwards compatibility
        bool usingVirtualBalance;
        uint256 virtualUnderlyingBalance;
    }
}






/**
 * @title ReserveConfiguration library
 * @author Aave
 * @notice Implements the bitmap logic to handle the reserve configuration
 * @dev Taken and adapted from Aave. Changes:
 * - Removed set functions
 * - Removed MAX constants
 */
library ReserveConfiguration {
    uint256 internal constant LTV_MASK =
        0x000000000000000000000000000000000000000000000000000000000000FFFF; // prettier-ignore
    uint256 internal constant LIQUIDATION_THRESHOLD_MASK =
        0x00000000000000000000000000000000000000000000000000000000FFFF0000; // prettier-ignore
    uint256 internal constant LIQUIDATION_BONUS_MASK =
        0x0000000000000000000000000000000000000000000000000000FFFF00000000; // prettier-ignore
    uint256 internal constant DECIMALS_MASK =
        0x00000000000000000000000000000000000000000000000000FF000000000000; // prettier-ignore
    uint256 internal constant ACTIVE_MASK =
        0x0000000000000000000000000000000000000000000000000100000000000000; // prettier-ignore
    uint256 internal constant FROZEN_MASK =
        0x0000000000000000000000000000000000000000000000000200000000000000; // prettier-ignore
    uint256 internal constant BORROWING_MASK =
        0x0000000000000000000000000000000000000000000000000400000000000000; // prettier-ignore
    // @notice there is an unoccupied hole of 1 bit at position 59 from pre 3.2 stableBorrowRateEnabled
    uint256 internal constant PAUSED_MASK =
        0x0000000000000000000000000000000000000000000000001000000000000000; // prettier-ignore
    // @notice there is an unoccupied hole of 2 bit at position 61-62 from pre 3.7 borrowableInIsolation and siloedBorrowing
    uint256 internal constant FLASHLOAN_ENABLED_MASK =
        0x0000000000000000000000000000000000000000000000008000000000000000; // prettier-ignore
    uint256 internal constant RESERVE_FACTOR_MASK =
        0x00000000000000000000000000000000000000000000FFFF0000000000000000; // prettier-ignore
    uint256 internal constant BORROW_CAP_MASK =
        0x00000000000000000000000000000000000FFFFFFFFF00000000000000000000; // prettier-ignore
    uint256 internal constant SUPPLY_CAP_MASK =
        0x00000000000000000000000000FFFFFFFFF00000000000000000000000000000; // prettier-ignore
    uint256 internal constant LIQUIDATION_PROTOCOL_FEE_MASK =
        0x0000000000000000000000FFFF00000000000000000000000000000000000000; // prettier-ignore
    //@notice there is an unoccupied hole of 8 bits from 168 to 175 left from pre 3.2 eModeCategory
    //@notice there is an unoccupied hole of 34 bits from 176 to 211 left from pre 3.4 unbackedMintCap
    //@notice there is an unoccupied hole of 40 bits from 212 to 251 left from pre 3.7 debtCeiling
    //@notice DEPRECATED: in v3.4 all reserves have virtual accounting enabled
    uint256 internal constant VIRTUAL_ACC_ACTIVE_MASK =
        0x1000000000000000000000000000000000000000000000000000000000000000; // prettier-ignore

    /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
    uint256 internal constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 internal constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
    uint256 internal constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
    uint256 internal constant IS_ACTIVE_START_BIT_POSITION = 56;
    uint256 internal constant IS_FROZEN_START_BIT_POSITION = 57;
    uint256 internal constant BORROWING_ENABLED_START_BIT_POSITION = 58;
    uint256 internal constant IS_PAUSED_START_BIT_POSITION = 60;
    //@notice there is an unoccupied hole of 1 bits at 61 left from pre 3.7 borrowableInIsolation
    //@notice there is an unoccupied hole of 1 bits at 62 left from pre 3.7 siloedBorrowing
    uint256 internal constant FLASHLOAN_ENABLED_START_BIT_POSITION = 63;
    uint256 internal constant RESERVE_FACTOR_START_BIT_POSITION = 64;
    uint256 internal constant BORROW_CAP_START_BIT_POSITION = 80;
    uint256 internal constant SUPPLY_CAP_START_BIT_POSITION = 116;
    uint256 internal constant LIQUIDATION_PROTOCOL_FEE_START_BIT_POSITION = 152;
    //@notice there is an unoccupied hole of 8 bits from 168 to 175 left from pre 3.2 eModeCategory
    //@notice there is an unoccupied hole of 34 bits from 176 to 211 left from pre 3.4 unbackedMintCap
    //@notice there is an unoccupied hole of 40 bits from 212 to 251 left from pre 3.7 debtCeiling
    //@notice DEPRECATED: in v3.4 all reserves have virtual accounting enabled
    uint256 internal constant VIRTUAL_ACC_START_BIT_POSITION = 252;

    /**
     * @notice Gets the Loan to Value of the reserve
     * @param self The reserve configuration
     * @return The loan to value
     */
    function getLtv(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256) {
        return self.data & LTV_MASK;
    }

    /**
     * @notice Gets the liquidation threshold of the reserve
     * @param self The reserve configuration
     * @return The liquidation threshold
     */
    function getLiquidationThreshold(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    }

    /**
     * @notice Gets the liquidation bonus of the reserve
     * @param self The reserve configuration
     * @return The liquidation bonus
     */
    function getLiquidationBonus(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION;
    }

    /**
     * @notice Gets the decimals of the underlying asset of the reserve
     * @param self The reserve configuration
     * @return The decimals of the asset
     */
    function getDecimals(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
    }

    /**
     * @notice Gets the active state of the reserve
     * @param self The reserve configuration
     * @return The active state
     */
    function getActive(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
        return (self.data & ACTIVE_MASK) != 0;
    }

    /**
     * @notice Gets the frozen state of the reserve
     * @param self The reserve configuration
     * @return The frozen state
     */
    function getFrozen(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
        return (self.data & FROZEN_MASK) != 0;
    }

    /**
     * @notice Gets the paused state of the reserve
     * @param self The reserve configuration
     * @return The paused state
     */
    function getPaused(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
        return (self.data & PAUSED_MASK) != 0;
    }

    /**
     * @notice Gets the borrowing state of the reserve
     * @param self The reserve configuration
     * @return The borrowing state
     */
    function getBorrowingEnabled(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return (self.data & BORROWING_MASK) != 0;
    }

    /**
     * @notice Gets the reserve factor of the reserve
     * @param self The reserve configuration
     * @return The reserve factor
     */
    function getReserveFactor(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION;
    }

    /**
     * @notice Gets the borrow cap of the reserve
     * @param self The reserve configuration
     * @return The borrow cap
     */
    function getBorrowCap(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION;
    }

    /**
     * @notice Gets the supply cap of the reserve
     * @param self The reserve configuration
     * @return The supply cap
     */
    function getSupplyCap(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION;
    }

    /**
     * @dev Gets the liquidation protocol fee
     * @param self The reserve configuration
     * @return The liquidation protocol fee
     */
    function getLiquidationProtocolFee(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & LIQUIDATION_PROTOCOL_FEE_MASK)
            >> LIQUIDATION_PROTOCOL_FEE_START_BIT_POSITION;
    }

    /**
     * @notice Gets the flashloanable flag for the reserve
     * @param self The reserve configuration
     * @return The flashloanable flag
     */
    function getFlashLoanEnabled(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return (self.data & FLASHLOAN_ENABLED_MASK) != 0;
    }

    /**
     * @notice Gets the configuration flags of the reserve
     * @param self The reserve configuration
     * @return The state flag representing active
     * @return The state flag representing frozen
     * @return The state flag representing borrowing enabled
     * @return The state flag representing paused
     */
    function getFlags(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool, bool, bool, bool)
    {
        uint256 dataLocal = self.data;

        return (
            (dataLocal & ACTIVE_MASK) != 0,
            (dataLocal & FROZEN_MASK) != 0,
            (dataLocal & BORROWING_MASK) != 0,
            (dataLocal & PAUSED_MASK) != 0
        );
    }

    /**
     * @notice Gets the configuration parameters of the reserve from storage
     * @param self The reserve configuration
     * @return The state param representing ltv
     * @return The state param representing liquidation threshold
     * @return The state param representing liquidation bonus
     * @return The state param representing reserve decimals
     * @return The state param representing reserve factor
     */
    function getParams(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        uint256 dataLocal = self.data;

        return (
            dataLocal & LTV_MASK,
            (dataLocal & LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (dataLocal & LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
            (dataLocal & DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
            (dataLocal & RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
        );
    }

    /**
     * @notice Gets the caps parameters of the reserve from storage
     * @param self The reserve configuration
     * @return The state param representing borrow cap
     * @return The state param representing supply cap.
     */
    function getCaps(DataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256, uint256)
    {
        uint256 dataLocal = self.data;

        return (
            (dataLocal & BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION,
            (dataLocal & SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION
        );
    }
}







/**
 * @title UserConfiguration library
 * @author Aave
 * @notice Implements the bitmap logic to handle the user configuration
 * @dev Taken and adapted from Aave. Changes:
 * - Removed set functions
 * - Removed require statements from `isUsingAsCollateral` and `isBorrowing`
 * - Removed `getNextFlags` function
 * - Removed `_getFirstAssetIdByMask` function
 */
library UserConfiguration {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    uint256 internal constant BORROWING_MASK =
        0x5555555555555555555555555555555555555555555555555555555555555555;
    uint256 internal constant COLLATERAL_MASK =
        0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;

    /**
     * @notice Validate a user has been using the reserve for borrowing
     * @param self The configuration object
     * @param reserveIndex The index of the reserve in the bitmap
     * @return True if the user has been using a reserve for borrowing, false otherwise
     */
    function isBorrowing(DataTypes.UserConfigurationMap memory self, uint256 reserveIndex)
        internal
        pure
        returns (bool)
    {
        unchecked {
            return (self.data >> (reserveIndex << 1)) & 1 != 0;
        }
    }

    /**
     * @notice Validate a user has been using the reserve as collateral
     * @param self The configuration object
     * @param reserveIndex The index of the reserve in the bitmap
     * @return True if the user has been using a reserve as collateral, false otherwise
     */
    function isUsingAsCollateral(DataTypes.UserConfigurationMap memory self, uint256 reserveIndex)
        internal
        pure
        returns (bool)
    {
        unchecked {
            return (self.data >> ((reserveIndex << 1) + 1)) & 1 != 0;
        }
    }

    /**
     * @notice Checks if a user has been supplying only one reserve as collateral
     * @dev this uses a simple trick - if a number is a power of two (only one bit set) then n & (n - 1) == 0
     * @param self The configuration object
     * @return True if the user has been supplying as collateral one reserve, false otherwise
     */
    function isUsingAsCollateralOne(DataTypes.UserConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        uint256 collateralData = self.data & COLLATERAL_MASK;
        return collateralData != 0 && (collateralData & (collateralData - 1) == 0);
    }

    /**
     * @notice Checks if a user has been supplying any reserve as collateral
     * @param self The configuration object
     * @return True if the user has been supplying as collateral any reserve, false otherwise
     */
    function isUsingAsCollateralAny(DataTypes.UserConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return self.data & COLLATERAL_MASK != 0;
    }

    /**
     * @notice Checks if a user has been borrowing only one asset
     * @dev this uses a simple trick - if a number is a power of two (only one bit set) then n & (n - 1) == 0
     * @param self The configuration object
     * @return True if the user has been supplying as collateral one reserve, false otherwise
     */
    function isBorrowingOne(DataTypes.UserConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        uint256 borrowingData = self.data & BORROWING_MASK;
        return borrowingData != 0 && (borrowingData & (borrowingData - 1) == 0);
    }

    /**
     * @notice Checks if a user has been borrowing from any reserve
     * @param self The configuration object
     * @return True if the user has been borrowing any reserve, false otherwise
     */
    function isBorrowingAny(DataTypes.UserConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return self.data & BORROWING_MASK != 0;
    }

    /**
     * @notice Checks if a user has not been using any reserve for borrowing, or as collateral
     * @param self The configuration object
     * @return True if the user has not been borrowing, or using as collateral any reserve, false otherwise
     */
    function isEmpty(DataTypes.UserConfigurationMap memory self) internal pure returns (bool) {
        return self.data == 0;
    }

    /**
     * @notice Returns the borrowed and collateral flags for the first asset on the bitmap and the bitmap shifted by two.
     * @dev This function mutates the input and the 2 bit slots in the bitmap will no longer correspond to the reserve index.
     * This is useful in situations where we want to iterate the bitmap as it allows for early exit once the bitmap turns zero.
     * @param data The configuration uint256
     * @return The bitmap shifted by 2 bits, so that the first asset points to the *next* asset.
     * @return True if the first asset in the bitmap is borrowed.
     * @return True if the first asset in the bitmap is a collateral.
     */
    function getNextFlags(uint256 data) internal pure returns (uint256, bool, bool) {
        bool isBorrowed = data & 1 == 1;
        bool isEnabledAsCollateral = data & 2 == 2;
        return (data >> 2, isBorrowed, isEnabledAsCollateral);
    }
}







library Address {
    //insufficient balance
    error InsufficientBalance(uint256 available, uint256 required);
    //unable to send value, recipient may have reverted
    error SendingValueFail();
    //insufficient balance for call
    error InsufficientBalanceForCall(uint256 available, uint256 required);
    //call to non-contract
    error NonContractCall();

    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        uint256 balance = address(this).balance;
        if (balance < amount) {
            revert InsufficientBalance(balance, amount);
        }

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success,) = recipient.call{ value: amount }("");
        if (!(success)) {
            revert SendingValueFail();
        }
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage)
        internal
        returns (bytes memory)
    {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value)
        internal
        returns (bytes memory)
    {
        return functionCallWithValue(
            target, data, value, "Address: low-level call with value failed"
        );
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        uint256 balance = address(this).balance;
        if (balance < value) {
            revert InsufficientBalanceForCall(balance, value);
        }
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        if (!(isContract(target))) {
            revert NonContractCall();
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}







interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256 digits);
    function totalSupply() external view returns (uint256 supply);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value) external returns (bool success);

    function transferFrom(address _from, address _to, uint256 _value)
        external
        returns (bool success);

    function approve(address _spender, uint256 _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}











library SafeERC20 {
    using Address for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(
            token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata =
            address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(
            returndata.length == 0 || abi.decode(returndata, (bool)),
            "SafeERC20: ERC20 operation did not succeed"
        );
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool)))
            && address(token).code.length > 0;
    }
}







contract MainnetAaveV3Addresses {
    address internal constant AAVE_REWARDS_CONTROLLER_ADDRESS =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
    address internal constant DEFAULT_AAVE_MARKET = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address internal constant AAVE_ORACLE_V3 = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;
    address internal constant STAKED_GHO_TOKEN = 0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;
    address internal constant AAVE_GOV_TOKEN = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address internal constant GHO_TOKEN = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address internal constant UMBRELLA_REWARDS_CONTROLLER_ADDRESS =
        0x4655Ce3D625a63d30bA704087E52B4C31E38188B;
}






interface IAaveProtocolDataProvider {
    /**
     * @notice Returns the user data in a reserve
     * @param asset The address of the underlying asset of the reserve
     * @param user The address of the user
     * @return currentATokenBalance The current AToken balance of the user
     * @return currentStableDebt The current stable debt of the user
     * @return currentVariableDebt The current variable debt of the user
     * @return principalStableDebt The principal stable debt of the user
     * @return scaledVariableDebt The scaled variable debt of the user
     * @return stableBorrowRate The stable borrow rate of the user
     * @return liquidityRate The liquidity rate of the reserve
     * @return stableRateLastUpdated The timestamp of the last update of the user stable rate
     * @return usageAsCollateralEnabled True if the user is using the asset as collateral, false
     *         otherwise
     *
     */
    function getUserReserveData(address asset, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );

    /**
     * @notice Returns if the pool is paused
     * @param asset The address of the underlying asset of the reserve
     * @return isPaused True if the pool is paused, false otherwise
     *
     */
    function getPaused(address asset) external view returns (bool isPaused);

    /**
     * @notice Returns the configuration data of the reserve
     * @dev Not returning borrow and supply caps for compatibility, nor pause flag
     * @param asset The address of the underlying asset of the reserve
     * @return decimals The number of decimals of the reserve
     * @return ltv The ltv of the reserve
     * @return liquidationThreshold The liquidationThreshold of the reserve
     * @return liquidationBonus The liquidationBonus of the reserve
     * @return reserveFactor The reserveFactor of the reserve
     * @return usageAsCollateralEnabled True if the usage as collateral is enabled, false otherwise
     * @return borrowingEnabled True if borrowing is enabled, false otherwise
     * @return stableBorrowRateEnabled True if stable rate borrowing is enabled, false otherwise
     * @return isActive True if it is active, false otherwise
     * @return isFrozen True if it is frozen, false otherwise
     */
    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );

    /**
     * @notice Returns the reserve data
     * @param asset The address of the underlying asset of the reserve
     * @return unbacked The amount of unbacked tokens
     * @return accruedToTreasuryScaled The scaled amount of tokens accrued to treasury that is to be minted
     * @return totalAToken The total supply of the aToken
     * @return totalStableDebt The total stable debt of the reserve
     * @return totalVariableDebt The total variable debt of the reserve
     * @return liquidityRate The liquidity rate of the reserve
     * @return variableBorrowRate The variable borrow rate of the reserve
     * @return stableBorrowRate The stable borrow rate of the reserve
     * @return averageStableBorrowRate The average stable borrow rate of the reserve
     * @return liquidityIndex The liquidity index of the reserve
     * @return variableBorrowIndex The variable borrow index of the reserve
     * @return lastUpdateTimestamp The timestamp of the last update of the reserve
     */
    function getReserveData(address asset)
        external
        view
        returns (
            uint256 unbacked,
            uint256 accruedToTreasuryScaled,
            uint256 totalAToken,
            uint256 totalStableDebt,
            uint256 totalVariableDebt,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,
            uint256 averageStableBorrowRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            uint40 lastUpdateTimestamp
        );
}






interface IPoolAddressesProvider {
    /**
     * @notice Returns the id of the Aave market to which this contract points to.
     * @return The market id
     *
     */
    function getMarketId() external view returns (string memory);

    /**
     * @notice Returns an address by its identifier.
     * @dev The returned address might be an EOA or a contract, potentially proxied
     * @dev It returns ZERO if there is no registered address with the given id
     * @param id The id
     * @return The address of the registered for the specified id
     */
    function getAddress(bytes32 id) external view returns (address);

    /**
     * @notice Returns the address of the Pool proxy.
     * @return The Pool proxy address
     *
     */
    function getPool() external view returns (address);

    /**
     * @notice Returns the address of the PoolConfigurator proxy.
     * @return The PoolConfigurator proxy address
     *
     */
    function getPoolConfigurator() external view returns (address);

    /**
     * @notice Returns the address of the price oracle.
     * @return The address of the PriceOracle
     */
    function getPriceOracle() external view returns (address);

    /**
     * @notice Returns the address of the ACL manager.
     * @return The address of the ACLManager
     */
    function getACLManager() external view returns (address);

    /**
     * @notice Returns the address of the ACL admin.
     * @return The address of the ACL admin
     */
    function getACLAdmin() external view returns (address);

    /**
     * @notice Returns the address of the price oracle sentinel.
     * @return The address of the PriceOracleSentinel
     */
    function getPriceOracleSentinel() external view returns (address);

    /**
     * @notice Returns the address of the data provider.
     * @return The address of the DataProvider
     */
    function getPoolDataProvider() external view returns (address);
}







interface IPoolV3 {
    /**
     * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     *
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /**
     * @notice Supply with transfer approval of asset to be supplied done via permit function
     * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param deadline The deadline timestamp that the permit is valid
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     * @param permitV The V parameter of ERC712 permit sig
     * @param permitR The R parameter of ERC712 permit sig
     * @param permitS The S parameter of ERC712 permit sig
     *
     */
    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to The address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     *
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /**
     * @notice Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
     * already supplied enough collateral, or he was given enough allowance by a credit delegator on the
     * corresponding debt token (StableDebtToken or VariableDebtToken)
     * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
     *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
     * @param asset The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 is deprecated, 2 for Variable
     * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     * @param onBehalfOf The address of the user who will receive the debt. Should be the address of the borrower itself
     * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
     * if he has been given credit delegation allowance
     *
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
     * @param asset The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 is deprecated, 2 for Variable
     * @param onBehalfOf The address of the user who will get his debt reduced/removed. Should be the address of the
     * user calling the function if he wants to reduce/remove his own debt, or the address of any other
     * other borrower whose debt should be removed
     * @return The final amount repaid
     *
     */
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);

    /**
     * @notice Repay with transfer approval of asset to be repaid done via permit function
     * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
     * @param asset The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 is deprecated, 2 for Variable
     * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
     * user calling the function if he wants to reduce/remove his own debt, or the address of any other
     * other borrower whose debt should be removed
     * @param deadline The deadline timestamp that the permit is valid
     * @param permitV The V parameter of ERC712 permit sig
     * @param permitR The R parameter of ERC712 permit sig
     * @param permitS The S parameter of ERC712 permit sig
     * @return The final amount repaid
     *
     */
    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external returns (uint256);

    /**
     * @notice Repays a borrowed `amount` on a specific reserve using the reserve aTokens, burning the
     * equivalent debt tokens
     * - E.g. User repays 100 USDC using 100 aUSDC, burning 100 variable/stable debt tokens
     * @dev  Passing uint256.max as amount will clean up any residual aToken dust balance, if the user aToken
     * balance is not enough to cover the whole debt
     * @param asset The address of the borrowed underlying asset previously borrowed
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 is deprecated, 2 for Variable
     * @return The final amount repaid
     *
     */
    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode)
        external
        returns (uint256);

    /**
     * @notice Allows suppliers to enable/disable a specific supplied asset as collateral
     * @param asset The address of the underlying asset supplied
     * @param useAsCollateral True if the user wants to use the supply as collateral, false otherwise
     *
     */
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
     * as long as the amount taken plus a fee is returned.
     * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
     * into consideration. For further details please visit https://developers.aave.com
     * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanReceiver interface
     * @param assets The addresses of the assets being flash-borrowed
     * @param amounts The amounts of the assets being flash-borrowed
     * @param interestRateModes Types of the debt to open if the flash loan is not returned:
     *   0 -> Don't open any debt, just revert if funds can't be transferred from the receiver
     *   1 -> Open debt at stable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
     *   2 -> Open debt at variable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
     * @param onBehalfOf The address  that will receive the debt in the case of using on `modes` 1 or 2
     * @param params Variadic packed params to pass to the receiver as extra information
     * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     *
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
     * @return totalDebtBase The total debt of the user in the base currency used by the price feed
     * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
     * @return currentLiquidationThreshold The liquidation threshold of the user
     * @return ltv The loan to value of The user
     * @return healthFactor The current health factor of the user
     *
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    /**
     * @notice Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     *
     */
    function getConfiguration(address asset)
        external
        view
        returns (DataTypes.ReserveConfigurationMap memory);

    /**
     * @notice Returns the configuration of the user across all the reserves
     * @param user The user address
     * @return The configuration of the user
     *
     */
    function getUserConfiguration(address user)
        external
        view
        returns (DataTypes.UserConfigurationMap memory);

    /**
     * @notice Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state and configuration data of the reserve
     *
     */
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

    /**
     * @notice Returns the list of the initialized reserves
     * @dev It does not include dropped reserves
     * @return The addresses of the reserves
     *
     */
    function getReservesList() external view returns (address[] memory);

    /**
     * @notice Returns the PoolAddressesProvider connected to this contract
     * @return The address of the PoolAddressesProvider
     *
     */
    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

    /**
     * @notice Returns the data of an eMode category
     * @param id The id of the category
     * @return The configuration data of the category
     */
    function getEModeCategoryData(uint8 id)
        external
        view
        returns (DataTypes.EModeCategoryLegacy memory);

    /**
     * @notice Allows a user to use the protocol in eMode
     * @param categoryId The id of the category
     */
    function setUserEMode(uint8 categoryId) external;

    /**
     * @notice Returns the eMode the user is using
     * @param user The address of the user
     * @return The eMode id
     */
    function getUserEMode(address user) external view returns (uint256);

    /**
     * @notice Returns the total fee on flash loans
     * @return The total fee on flashloans
     */
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

    /**
     * @notice Returns the address of the underlying asset of a reserve by the reserve id as stored in the DataTypes.ReserveData struct
     * @param id The id of the reserve as stored in the DataTypes.ReserveData struct
     * @return The address of the reserve associated with id
     *
     */
    function getReserveAddressById(uint16 id) external view returns (address);

    /**
     * @notice Returns the label of an eMode category
     * @dev This function is deprecated and will be removed in a future version.
     * @custom:deprecated
     * @param id The id of the category
     * @return The label of the category
     */
    function getEModeCategoryLabel(uint8 id) external view returns (string memory);

    /**
     * @notice Returns the collateral config of an eMode category
     * @param id The id of the category
     * @return The ltv,lt,lb of the category
     */
    function getEModeCategoryCollateralConfig(uint8 id)
        external
        view
        returns (DataTypes.CollateralConfig memory);

    /**
     * @notice Returns the collateralBitmap of an eMode category
     * @param id The id of the category
     * @return The collateralBitmap of the category
     */
    function getEModeCategoryCollateralBitmap(uint8 id) external view returns (uint128);

    /**
     * @notice Returns the borrowableBitmap of an eMode category
     * @param id The id of the category
     * @return The borrowableBitmap of the category
     */
    function getEModeCategoryBorrowableBitmap(uint8 id) external view returns (uint128);

    /**
     * @notice Returns the ltvzero of an eMode category
     * @param id The id of the category
     * @return The ltvzeroBitmap of the category
     */
    function getEModeCategoryLtvzeroBitmap(uint8 id) external view returns (uint128);

    /**
     * @notice Returns the current deficit of a reserve.
     * @param asset The address of the underlying asset of the reserve
     * @return The current deficit of the reserve
     */
    function getReserveDeficit(address asset) external view returns (uint256);

    /**
     * @notice Returns the aToken address of a reserve.
     * @param asset The address of the underlying asset of the reserve
     * @return The address of the aToken
     */
    function getReserveAToken(address asset) external view returns (address);

    /**
     * @notice Returns the variableDebtToken address of a reserve.
     * @param asset The address of the underlying asset of the reserve
     * @return The address of the variableDebtToken
     */
    function getReserveVariableDebtToken(address asset) external view returns (address);

    /**
     * @notice Returns the virtual underlying balance of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve virtual underlying balance
     */
    function getVirtualUnderlyingBalance(address asset) external view returns (uint128);

    /**
     * @notice Returns the ReserveInterestRateStrategy connected to all the reserves
     * @return The address of the ReserveInterestRateStrategy contract
     */
    function RESERVE_INTEREST_RATE_STRATEGY() external view returns (address);

    /**
     * @notice Returns the isolated flag of an eMode category
     * @param id The id of the category
     * @return True if the eMode category is isolated
     */
    function getIsEModeCategoryIsolated(uint8 id) external view returns (bool);
}







interface IL2PoolV3 is IPoolV3 {
    /**
     * @notice Calldata efficient wrapper of the supply function on behalf of the caller
     * @param args Arguments for the supply function packed in one bytes32
     *    96 bits       16 bits         128 bits      16 bits
     * | 0-padding | referralCode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function supply(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the supplyWithPermit function on behalf of the caller
     * @param args Arguments for the supply function packed in one bytes32
     *    56 bits    8 bits         32 bits           16 bits         128 bits      16 bits
     * | 0-padding | permitV | shortenedDeadline | referralCode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @param r The R parameter of ERC712 permit sig
     * @param s The S parameter of ERC712 permit sig
     */
    function supplyWithPermit(bytes32 args, bytes32 r, bytes32 s) external;

    /**
     * @notice Calldata efficient wrapper of the withdraw function, withdrawing to the caller
     * @param args Arguments for the withdraw function packed in one bytes32
     *    112 bits       128 bits      16 bits
     * | 0-padding | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function withdraw(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the borrow function, borrowing on behalf of the caller
     * @param args Arguments for the borrow function packed in one bytes32
     *    88 bits       16 bits             8 bits                 128 bits       16 bits
     * | 0-padding | referralCode | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     */
    function borrow(bytes32 args) external;

    /**
     * @notice Calldata efficient wrapper of the repay function, repaying on behalf of the caller
     * @param args Arguments for the repay function packed in one bytes32
     *    104 bits             8 bits               128 bits       16 bits
     * | 0-padding | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @return The final amount repaid
     */
    function repay(bytes32 args) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the repayWithPermit function, repaying on behalf of the caller
     * @param args Arguments for the repayWithPermit function packed in one bytes32
     *    64 bits    8 bits        32 bits                   8 bits               128 bits       16 bits
     * | 0-padding | permitV | shortenedDeadline | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @param r The R parameter of ERC712 permit sig
     * @param s The S parameter of ERC712 permit sig
     * @return The final amount repaid
     */
    function repayWithPermit(bytes32 args, bytes32 r, bytes32 s) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the repayWithATokens function
     * @param args Arguments for the repayWithATokens function packed in one bytes32
     *    104 bits             8 bits               128 bits       16 bits
     * | 0-padding | shortenedInterestRateMode | shortenedAmount | assetId |
     * @dev the shortenedAmount is cast to 256 bits at decode time, if type(uint128).max the value will be expanded to
     * type(uint256).max
     * @dev assetId is the index of the asset in the reservesList.
     * @return The final amount repaid
     */
    function repayWithATokens(bytes32 args) external returns (uint256);

    /**
     * @notice Calldata efficient wrapper of the setUserUseReserveAsCollateral function
     * @param args Arguments for the setUserUseReserveAsCollateral function packed in one bytes32
     *    239 bits         1 bit       16 bits
     * | 0-padding | useAsCollateral | assetId |
     * @dev assetId is the index of the asset in the reservesList.
     */
    function setUserUseReserveAsCollateral(bytes32 args) external;
}










contract AaveV3Helper is MainnetAaveV3Addresses {
    uint16 public constant AAVE_REFERRAL_CODE = 64;

    /// @notice Returns the lending pool contract of the specified market
    function getLendingPool(address _market) internal view returns (IL2PoolV3) {
        return IL2PoolV3(IPoolAddressesProvider(_market).getPool());
    }

    /// @notice Fetch the data provider for the specified market
    function getDataProvider(address _market) internal view returns (IAaveProtocolDataProvider) {
        return IAaveProtocolDataProvider(IPoolAddressesProvider(_market).getPoolDataProvider());
    }

    function getWholeDebt(
        address _market,
        address _tokenAddr,
        uint256 _borrowType,
        address _debtOwner
    ) internal view returns (uint256 debt) {
        uint256 STABLE_ID = 1;
        uint256 VARIABLE_ID = 2;

        IAaveProtocolDataProvider dataProvider = getDataProvider(_market);
        (, uint256 borrowsStable, uint256 borrowsVariable,,,,,,) =
            dataProvider.getUserReserveData(_tokenAddr, _debtOwner);

        if (_borrowType == STABLE_ID) {
            debt = borrowsStable;
        } else if (_borrowType == VARIABLE_ID) {
            debt = borrowsVariable;
        }
    }
}






/**
 * @title PercentageMath library
 * @author Aave
 * @dev Taken adapted from Aave. Changes:
 * - Removed all functions except percentMulFloor
 */
library PercentageMath {
    // Maximum percentage factor (100.00%)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    function percentMulFloor(uint256 value, uint256 percentage)
        internal
        pure
        returns (uint256 result)
    {
        // to avoid overflow, value <= type(uint256).max / percentage
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(not(0), percentage))))) {
                revert(0, 0)
            }

            result := div(mul(value, percentage), PERCENTAGE_FACTOR)
        }
    }
}






contract DSMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x - y;
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x / y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x <= y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x >= y ? x : y;
    }

    function imin(int256 x, int256 y) internal pure returns (int256 z) {
        return x <= y ? x : y;
    }

    function imax(int256 x, int256 y) internal pure returns (int256 z) {
        return x >= y ? x : y;
    }

    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}






interface IPriceOracleGetter {
    /**
     * @notice Returns the asset price in the base currency
     * @param asset The address of the asset
     * @return The price of the asset
     *
     */
    function getAssetPrice(address asset) external view returns (uint256);
}






interface IAaveV3Oracle is IPriceOracleGetter {
    /**
     * @notice Returns a list of prices from a list of assets addresses scaled to 1e8
     * @param assets The list of assets addresses
     * @return The prices of the given assets scaled to 1e8
     */
    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);

    /**
     * @notice Returns the address of the source for an asset address
     * @param asset The address of the asset
     * @return The address of the source
     */
    function getSourceOfAsset(address asset) external view returns (address);
}







interface IWETH {
    function allowance(address, address) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external;

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256) external;
}









library TokenUtils {
    using SafeERC20 for IERC20;

    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Only approves the amount if allowance is lower than amount, does not decrease allowance
    function approveToken(address _tokenAddr, address _to, uint256 _amount) internal {
        if (_tokenAddr == ETH_ADDR) return;

        if (IERC20(_tokenAddr).allowance(address(this), _to) < _amount) {
            IERC20(_tokenAddr).safeApprove(_to, _amount);
        }
    }

    function pullTokensIfNeeded(address _token, address _from, uint256 _amount)
        internal
        returns (uint256)
    {
        // handle max uint amount
        if (_amount == type(uint256).max) {
            _amount = getBalance(_token, _from);
        }

        if (_from != address(0) && _from != address(this) && _token != ETH_ADDR && _amount != 0) {
            IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        }

        return _amount;
    }

    function withdrawTokens(address _token, address _to, uint256 _amount)
        internal
        returns (uint256)
    {
        if (_amount == type(uint256).max) {
            _amount = getBalance(_token, address(this));
        }

        if (_to != address(0) && _to != address(this) && _amount != 0) {
            if (_token != ETH_ADDR) {
                IERC20(_token).safeTransfer(_to, _amount);
            } else {
                (bool success,) = _to.call{ value: _amount }("");
                require(success, "Eth send fail");
            }
        }

        return _amount;
    }

    function depositWeth(uint256 _amount) internal {
        IWETH(WETH_ADDR).deposit{ value: _amount }();
    }

    function withdrawWeth(uint256 _amount) internal {
        IWETH(WETH_ADDR).withdraw(_amount);
    }

    function getBalance(address _tokenAddr, address _acc) internal view returns (uint256) {
        if (_tokenAddr == ETH_ADDR) {
            return _acc.balance;
        } else {
            return IERC20(_tokenAddr).balanceOf(_acc);
        }
    }

    function getTokenDecimals(address _token) internal view returns (uint256) {
        if (_token == ETH_ADDR) return 18;

        return IERC20(_token).decimals();
    }
}
















contract AaveV3RatioHelper is DSMath, MainnetAaveV3Addresses {
    using TokenUtils for address;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using PercentageMath for uint256;

    /// @notice The offset to use when the ltv is 0. In that case, we fallback to lltv - LTV_ZERO_OFFSET
    /// @dev Some reserves will have higher or lower difference between ltv and lltv,
    /// which is ok as this is a fallback approximation value.
    uint256 public constant LTV_ZERO_OFFSET = 500;

    struct CalculateUserAccountDataVars {
        uint8 userEmodeId;
        IAaveV3Oracle oracle;
        uint256 i;
        uint256 cachedUserCfg;
        bool isBorrowed;
        bool isCollateral;
        address asset;
        uint256 assetUnit;
        uint256 assetPrice;
        DataTypes.ReserveData reserve;
        uint256 collateralValue;
        uint256 aTokenBalance;
        uint256 ltv;
        uint256 lltv;
        uint256 avgLtv;
        uint256 variableDebtBalance;
    }

    /// @notice Returns the safety ratio of the user:
    /// the current overall health of position, inversely proportional to borrow power used.
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    /// @return The safety ratio of the user
    function getSafetyRatio(address _market, address _user) public view returns (uint256) {
        IPoolV3 lendingPool = IPoolV3(IPoolAddressesProvider(_market).getPool());
        (, uint256 totalDebtValue, uint256 availableBorrows,,,) =
            lendingPool.getUserAccountData(_user);
        if (totalDebtValue == 0) return uint256(0);
        return wdiv(add(totalDebtValue, availableBorrows), totalDebtValue);
    }

    /// @notice Returns the safety ratio of the user with ltv zero fallback support
    ///         the current overall health of position, inversely proportional to borrow power used.
    ///         This function is equivalent to getSafetyRatio, but when asset has ltv zero, we fallback to lltv - LTV_ZERO_OFFSET.
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    /// @return The safety ratio of the user with ltv zero fallback support
    /// @dev Aave LTV-zero collateral has no borrow power but still contributes to liquidation threshold / HF.
    ///      For automation flows that historically rely on safety ratio, this function approximates
    ///      LTV-zero collateral contribution as liquidationThreshold - 5%.
    ///      This is NOT equal to Aave available borrow power and should not be used to determine
    ///      whether new debt can be opened.
    function getSafetyRatioWithLtvZeroFallback(address _market, address _user)
        public
        view
        returns (uint256)
    {
        (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 avgLtv) =
            _getUserAccountDataWithLtvZeroFallback(_market, _user);

        if (totalDebtValue == 0) return uint256(0);

        uint256 availableBorrows =
            _calculateAvailableBorrowValue(totalCollateralValue, totalDebtValue, avgLtv);

        return wdiv(add(totalDebtValue, availableBorrows), totalDebtValue);
    }

    /// @dev Same as getSafetyRatio, left for convenience and backward compatibility.
    function getRatio(address _market, address _user) public view returns (uint256) {
        return getSafetyRatio(_market, _user);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/
    function _calculateAvailableBorrowValue(
        uint256 _totalCollateralValue,
        uint256 _totalDebtValue,
        uint256 _avgLtv
    ) internal pure returns (uint256) {
        uint256 totalAvailableBorrowValue = _totalCollateralValue.percentMulFloor(_avgLtv);
        if (totalAvailableBorrowValue <= _totalDebtValue) return 0;
        return totalAvailableBorrowValue - _totalDebtValue;
    }

    /// @dev See: https://github.com/aave-dao/aave-v3-origin/blob/main/src/contracts/protocol/libraries/logic/GenericLogic.sol#L65
    function _getUserAccountDataWithLtvZeroFallback(address _market, address _user)
        internal
        view
        returns (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 avgLtv)
    {
        IPoolV3 lendingPool = IPoolV3(IPoolAddressesProvider(_market).getPool());
        DataTypes.UserConfigurationMap memory userCfg = lendingPool.getUserConfiguration(_user);
        if (userCfg.isEmpty()) return (0, 0, 0);

        CalculateUserAccountDataVars memory vars;
        vars.userEmodeId = uint8(lendingPool.getUserEMode(_user));
        vars.oracle = IAaveV3Oracle(IPoolAddressesProvider(_market).getPriceOracle());
        vars.cachedUserCfg = userCfg.data;

        while (vars.cachedUserCfg != 0) {
            (vars.cachedUserCfg, vars.isBorrowed, vars.isCollateral) =
                UserConfiguration.getNextFlags(vars.cachedUserCfg);
            if (vars.isBorrowed || vars.isCollateral) {
                vars.asset = lendingPool.getReserveAddressById(uint16(vars.i));
                if (vars.asset != address(0)) {
                    vars.reserve = lendingPool.getReserveData(vars.asset);
                    vars.assetUnit = 10 ** vars.reserve.configuration.getDecimals();
                    vars.assetPrice = vars.oracle.getAssetPrice(vars.asset);
                    if (vars.isCollateral) {
                        vars.aTokenBalance = vars.reserve.aTokenAddress.getBalance(_user);
                        vars.collateralValue =
                            (vars.aTokenBalance * vars.assetPrice) / vars.assetUnit;
                        totalCollateralValue += vars.collateralValue;
                        (vars.ltv, vars.lltv) = _getUserReserveLtvAndLltv(
                            vars.reserve, lendingPool, vars.userEmodeId
                        );
                        if (vars.ltv == 0 && vars.lltv > LTV_ZERO_OFFSET) {
                            vars.ltv = vars.lltv - LTV_ZERO_OFFSET;
                        }
                        avgLtv += vars.collateralValue * vars.ltv;
                    }
                    if (vars.isBorrowed) {
                        vars.variableDebtBalance =
                            vars.reserve.variableDebtTokenAddress.getBalance(_user);
                        totalDebtValue += MathUtils.mulDivCeil(
                            vars.variableDebtBalance, vars.assetPrice, vars.assetUnit
                        );
                    }
                }
            }
            vars.i++;
        }
        avgLtv = (totalCollateralValue != 0) ? avgLtv / totalCollateralValue : 0;
    }

    /// @dev See: https://github.com/aave-dao/aave-v3-origin/blob/main/src/contracts/protocol/libraries/logic/ValidationLogic.sol#L524
    function _getUserReserveLtvAndLltv(
        DataTypes.ReserveData memory _reserve,
        IPoolV3 _lendingPool,
        uint8 _emodeId
    ) internal view returns (uint256 ltv, uint256 lltv) {
        if (_emodeId != 0) {
            DataTypes.CollateralConfig memory
                emodeConfig = _lendingPool.getEModeCategoryCollateralConfig(_emodeId);
            uint128 collateralBitmap = _lendingPool.getEModeCategoryCollateralBitmap(_emodeId);
            if (_isReserveEnabledOnBitmap(collateralBitmap, _reserve.id)) {
                uint128 ltvZeroBitmap = _lendingPool.getEModeCategoryLtvzeroBitmap(_emodeId);
                ltv = _isReserveEnabledOnBitmap(ltvZeroBitmap, _reserve.id) ? 0 : emodeConfig.ltv;
                lltv = emodeConfig.liquidationThreshold;
            } else {
                ltv = _lendingPool.getIsEModeCategoryIsolated(_emodeId)
                    ? 0
                    : _reserve.configuration.getLtv();
                lltv = _reserve.configuration.getLiquidationThreshold();
            }
        } else {
            ltv = _reserve.configuration.getLtv();
            lltv = _reserve.configuration.getLiquidationThreshold();
        }
    }

    function _isReserveEnabledOnBitmap(uint128 _bitmap, uint256 _reserveIndex)
        internal
        pure
        returns (bool)
    {
        unchecked {
            return (_bitmap >> _reserveIndex) & 1 != 0;
        }
    }
}






interface IERC4626 is IERC20 {
    function deposit(uint256 _assets, address _receiver) external returns (uint256 shares);
    function mint(uint256 _shares, address _receiver) external returns (uint256 assets);
    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        returns (uint256 shares);
    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        returns (uint256 assets);

    function previewDeposit(uint256 _assets) external view returns (uint256 shares);
    function previewMint(uint256 _shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 _assets) external view returns (uint256 shares);
    function previewRedeem(uint256 _shares) external view returns (uint256 assets);

    function convertToAssets(uint256 _shares) external view returns (uint256 assets);
    function convertToShares(uint256 _assets) external view returns (uint256 shares);

    function totalAssets() external view returns (uint256);

    function asset() external view returns (address);

    // These two are specific for sUSDS
    function deposit(uint256 _assets, address _receiver, uint16 _referral)
        external
        returns (uint256 shares);
    function mint(uint256 _shares, address _receiver, uint16 _referral)
        external
        returns (uint256 assets);
}








interface IERC4626StakeToken is IERC4626 {
    struct CooldownSnapshot {
        /// @notice Amount of shares available to redeem
        uint192 amount;
        /// @notice Timestamp after which funds will be unlocked for withdrawal
        uint32 endOfCooldown;
        /// @notice Period of time to withdraw funds after end of cooldown
        uint32 withdrawalWindow;
    }

    /**
     * @notice Activates the cooldown period to unstake for `msg.sender`.
     * It can't be called if the user is not staking.
     * Emits a {StakerCooldownUpdated} event.
     */
    function cooldown() external;

    /**
     * @notice Returns current `cooldown` duration.
     * @return _cooldown duration
     */
    function getCooldown() external view returns (uint256);

    /**
     * @notice Returns current `unstakeWindow` duration.
     * @return _unstakeWindow duration
     */
    function getUnstakeWindow() external view returns (uint256);

    /**
     * @notice Returns the last activated user `cooldown`. Contains the amount of tokens and timestamp.
     * May return zero values ​​if all funds have been withdrawn or transferred.
     * @param user Address of user
     * @return User's cooldown snapshot
     */
    function getStakerCooldown(address user) external view returns (CooldownSnapshot memory);
}







/**
 * @title IReserveInterestRateStrategy
 * @author Aave
 * @notice Interface for the calculation of the interest rates
 */
interface IReserveInterestRateStrategy {
    /**
     * @notice Calculates the interest rates depending on the reserve's state and configurations
     * @param params The parameters needed to calculate interest rates
     * @return liquidityRate The liquidity rate expressed in rays
     * @return variableBorrowRate The variable borrow rate expressed in rays
     */
    function calculateInterestRates(DataTypes.CalculateInterestRatesParams memory params)
        external
        view
        returns (uint256, uint256);
}







/**
 * @title IScaledBalanceToken
 * @author Aave
 * @notice Defines the basic interface for a scaled-balance token.
 */
interface IScaledBalanceToken {
    /**
     * @notice Returns the scaled total supply of the scaled balance token. Represents sum(debt/index)
     * @return The scaled total supply
     */
    function scaledTotalSupply() external view returns (uint256);
}






interface IDebtToken {
    function approveDelegation(address delegatee, uint256 amount) external;
    function borrowAllowance(address fromUser, address toUser) external view returns (uint256);
    function delegationWithSig(address, address, uint256, uint256, uint8, bytes32, bytes32) external;
    function nonces(address) external view returns (uint256);
    function name() external view returns (string memory);
}






interface IStaticATokenV2 {
    /**
     * @notice Burns `shares` of static aToken, with receiver receiving the corresponding amount of aToken
     * @param shares The shares to withdraw, in static balance of StaticAToken
     * @param receiver The address that will receive the amount of `ASSET` withdrawn from the Aave protocol
     * @return amountToWithdraw: aToken send to `receiver`, dynamic balance
     *
     */
    function redeemATokens(uint256 shares, address receiver, address owner)
        external
        returns (uint256);

    /**
     * @notice Deposits aTokens and mints static aTokens to msg.sender
     * @param assets The amount of aTokens to deposit (e.g. deposit of 100 aUSDC)
     * @param receiver The address that will receive the static aTokens
     * @return uint256 The amount of StaticAToken minted, static balance
     *
     */
    function depositATokens(uint256 assets, address receiver) external returns (uint256);

    /**
     * @notice The aToken used inside the 4626 vault.
     * @return address The aToken address.
     */
    function aToken() external view returns (address);

    /**
     * @notice Returns the current asset price of the stataToken.
     * The price is calculated as `underlying_price * exchangeRate`.
     * It is important to note that:
     * - `underlying_price` is the price obtained by the aave-oracle and is subject to it's internal pricing mechanisms.
     * - as the price is scaled over the exchangeRate, but maintains the same precision as the underlying the price might be underestimated by 1 unit.
     * - when pricing multiple `shares` as `shares * price` keep in mind that the error compounds.
     * @return price the current asset price.
     */
    function latestAnswer() external view returns (int256);
}






interface IUmbrella {
    function getStkTokens() external view returns (address[] memory);
}







interface IUmbrellaRewardsController {
    function claimSelectedRewards(address asset, address[] calldata rewards, address receiver)
        external
        returns (uint256[] memory);

    function getAllRewards(address asset) external view returns (address[] memory);

    /**
     * @notice  Returns `emissionPerSecond` for certain `asset` and `reward`.
     * @dev Return zero if asset or rewards aren't set.
     * An integer quantity is returned, although the accuracy of the calculations in reality is higher.
     * @param asset Address of the `asset` which current emission of `reward` should be returned
     * @param reward Address of the `reward` which `emissionPerSecond` should be returned
     * @return emissionPerSecond Current amount of rewards distributed every second
     */
    function calculateCurrentEmission(address asset, address reward)
        external
        view
        returns (uint256 emissionPerSecond);
}



























contract AaveV3View is AaveV3Helper, AaveV3RatioHelper {
    using TokenUtils for address;
    using WadRayMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    /**
     *
     *                         DATA SPECIFICATION
     *
     */
    /// @notice User loan data
    struct LoanData {
        address user;
        uint128 ratio;
        uint256 eMode;
        address[] collAddr;
        bool[] enabledAsColl;
        address[] borrowAddr;
        uint256[] collAmounts;
        uint256[] borrowStableAmounts; // Note: deprecated in v3.2, left for backwards compatibility
        uint256[] borrowVariableAmounts;
        // emode category data
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        address priceSource; // Note: deprecated, left for backwards compatibility
        string label; // Note: deprecated, left for backwards compatibility
    }

    /// @notice User token data
    struct UserToken {
        address token;
        uint256 balance;
        uint256 borrowsStable; // Note: deprecated in v3.2, left for backwards compatibility
        uint256 borrowsVariable;
        uint256 stableBorrowRate; // Note: deprecated in v3.2, left for backwards compatibility
        bool enabledAsCollateral;
    }

    /// @notice Token info basic data
    struct TokenInfo {
        address aTokenAddress;
        address underlyingTokenAddress;
        uint256 collateralFactor;
        uint256 price;
    }

    /// @notice Token info full data
    struct TokenInfoFull {
        address aTokenAddress; //pool.config
        address underlyingTokenAddress; //pool.config
        uint16 assetId;
        uint256 supplyRate; //pool.config
        uint256 borrowRateVariable; //pool.config
        uint256 borrowRateStable; // Note: deprecated in v3.2, left for backwards compatibility
        uint256 totalSupply; //total supply
        uint256 availableLiquidity; //reserveData.liq rate
        uint256 totalBorrow; // total supply of both debt assets
        uint256 totalBorrowVar;
        uint256 totalBorrowStab; // Note: deprecated in v3.2, left for backwards compatibility
        uint256 collateralFactor; //pool.config
        uint256 liquidationRatio; //pool.config
        uint256 price; //oracle
        uint256 supplyCap; //pool.config
        uint256 borrowCap; //pool.config
        uint256 emodeCategory; //pool.config
        uint256 debtCeilingForIsolationMode; // Note: deprecated in v3.7, left for backwards compatibility
        uint256 isolationModeTotalDebt; // Note: deprecated in v3.7, left for backwards compatibility
        bool usageAsCollateralEnabled; //usageAsCollateralEnabled = liquidationThreshold > 0;
        bool borrowingEnabled; //pool.config
        bool stableBorrowRateEnabled; // Note: deprecated in v3.2, left for backwards compatibility
        bool isolationModeBorrowingEnabled; // Note: deprecated in v3.7, left for backwards compatibility
        bool isSiloedForBorrowing; // Note: deprecated in v3.7, left for backwards compatibility
        uint256 eModeCollateralFactor; //pool.getEModeCategoryData.ltv
        bool isFlashLoanEnabled;
        // emode category data
        uint16 ltv; // Note: deprecated, left for backwards compatibility
        uint16 liquidationThreshold; // Note: deprecated, left for backwards compatibility
        uint16 liquidationBonus; // Note: deprecated, left for backwards compatibility
        address priceSource; // Note: deprecated, left for backwards compatibility
        string label; // Note: deprecated, left for backwards compatibility
        bool isActive;
        bool isPaused;
        bool isFrozen;
        address debtTokenAddress;
    }

    /// @notice Params for supply and borrow rate estimation
    struct LiquidityChangeParams {
        address reserveAddress; // address of the reserve
        uint256 liquidityAdded; // amount of liquidity added (supply/repay)
        uint256 liquidityTaken; // amount of liquidity taken (borrow/withdraw)
        bool isDebtAsset; // isDebtAsset if operation is borrow/payback
    }

    /// @notice Helper struct for supply and borrow rate estimation
    struct EstimatedRates {
        address reserveAddress;
        uint256 supplyRate;
        uint256 variableBorrowRate;
    }

    /// @notice Umbrella staking data
    struct UmbrellaStkData {
        address stkToken; // address of the stk token
        uint256 totalShares; // total shares of the stk token
        address stkUnderlyingToken; // underlying token of the stk token. GHO or waToken
        address aToken; // if stkUnderlyingToken is waToken, this will be the underlying aToken
        uint256 cooldownPeriod; // cooldown period of the stk token
        uint256 unstakeWindow; // unstake window of the stk token
        uint256 stkTokenToWaTokenRate; // rate of stk token to wa token
        uint256 waTokenToATokenRate; // rate of waToken to aToken. 1e18 for GHO
        uint256[] rewardsEmissionRates; // emission rates of the rewards
        uint256 userCooldownAmount; // amount of shares available to redeem
        uint256 userEndOfCooldown; // timestamp after which funds will be unlocked for withdrawal
        uint256 userWithdrawalWindow; // period of time to withdraw funds after end of cooldown
    }

    /// @notice EOA approval and balance data for a specific asset
    struct EOAApprovalData {
        address asset; // underlying asset address
        address aToken; // aToken address
        address variableDebtToken; // variable debt token address
        uint256 assetApproval; // EOA approval to SW for underlying asset
        uint256 aTokenApproval; // EOA approval to SW for aToken
        uint256 variableDebtDelegation; // EOA debt delegation to SW for variable debt
        uint256 borrowedVariableAmount; // amount EOA has borrowed (variable)
        uint256 eoaBalance; // EOA's underlying asset balance
        uint256 aTokenBalance; // EOA's aToken balance
    }

    /**
     *
     *                         PUBLIC/EXTERNAL FUNCTIONS
     *
     */
    /// @notice Fetches the health factor of a user
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    /// @return healthFactor Health factor of the user
    function getHealthFactor(address _market, address _user)
        public
        view
        returns (uint256 healthFactor)
    {
        IPoolV3 lendingPool = getLendingPool(_market);

        (,,,,, healthFactor) = lendingPool.getUserAccountData(_user);
    }

    /// @notice Fetches Aave prices for tokens
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokens Arr. of tokens for which to get the prices
    /// @return prices Array of prices
    function getPrices(address _market, address[] memory _tokens)
        public
        view
        returns (uint256[] memory prices)
    {
        address priceOracleAddress = IPoolAddressesProvider(_market).getPriceOracle();
        prices = IAaveV3Oracle(priceOracleAddress).getAssetsPrices(_tokens);
    }

    /// @notice Calculated the ratio of coll/debt for an aave user
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _users Addresses of the user
    /// @return ratios Array of ratios
    function getRatios(address _market, address[] memory _users)
        public
        view
        returns (uint256[] memory ratios)
    {
        ratios = new uint256[](_users.length);

        for (uint256 i = 0; i < _users.length; ++i) {
            ratios[i] = getSafetyRatio(_market, _users[i]);
        }
    }

    /// @notice Fetches Aave collateral factors for tokens
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokens Arr. of tokens for which to get the coll. factors
    /// @return collFactors Array of coll. factors
    function getCollFactors(address _market, address[] memory _tokens)
        public
        view
        returns (uint256[] memory collFactors)
    {
        IPoolV3 lendingPool = getLendingPool(_market);
        collFactors = new uint256[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; ++i) {
            collFactors[i] = lendingPool.getConfiguration(_tokens[i]).getReserveFactor();
        }
    }

    /// @notice Fetches the balances of a user for a list of tokens
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    /// @param _tokens Array of token addresses
    /// @return userTokens Array of user token data
    function getTokenBalances(address _market, address _user, address[] memory _tokens)
        public
        view
        returns (UserToken[] memory userTokens)
    {
        IPoolV3 lendingPool = getLendingPool(_market);
        userTokens = new UserToken[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; i++) {
            DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(_tokens[i]);
            userTokens[i].balance = reserveData.aTokenAddress.getBalance(_user);
            userTokens[i].borrowsStable = 0;
            userTokens[i].borrowsVariable = reserveData.variableDebtTokenAddress.getBalance(_user);
            userTokens[i].stableBorrowRate = 0;
            userTokens[i].enabledAsCollateral =
                lendingPool.getUserConfiguration(_user).isUsingAsCollateral(reserveData.id);
        }
    }

    /// @notice Information about reserves
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokenAddresses Array of tokens addresses
    /// @return tokens Array of reserves information
    function getTokensInfo(address _market, address[] memory _tokenAddresses)
        public
        view
        returns (TokenInfo[] memory tokens)
    {
        IPoolV3 lendingPool = getLendingPool(_market);
        tokens = new TokenInfo[](_tokenAddresses.length);

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            DataTypes.ReserveConfigurationMap memory config =
                lendingPool.getConfiguration(_tokenAddresses[i]);
            uint256 collFactor = config.getLtv();
            address aTokenAddr = lendingPool.getReserveAToken(_tokenAddresses[i]);
            address priceOracleAddress = IPoolAddressesProvider(_market).getPriceOracle();
            uint256 price = IAaveV3Oracle(priceOracleAddress).getAssetPrice(_tokenAddresses[i]);
            tokens[i] = TokenInfo({
                aTokenAddress: aTokenAddr,
                underlyingTokenAddress: _tokenAddresses[i],
                collateralFactor: collFactor,
                price: price
            });
        }
    }

    /// @notice Fetches the full information about a token
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokenAddr Address of the token
    /// @return _tokenInfo Full information about the token
    function getTokenInfoFull(address _market, address _tokenAddr)
        public
        view
        returns (TokenInfoFull memory _tokenInfo)
    {
        IPoolV3 lendingPool = getLendingPool(_market);

        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(_tokenAddr);
        DataTypes.ReserveConfigurationMap memory config = lendingPool.getConfiguration(_tokenAddr);

        uint256 totalVariableBorrow = IERC20(reserveData.variableDebtTokenAddress).totalSupply();

        (bool isActive, bool isFrozen,, bool isPaused) = config.getFlags();

        _tokenInfo = TokenInfoFull({
            aTokenAddress: reserveData.aTokenAddress,
            underlyingTokenAddress: _tokenAddr,
            assetId: reserveData.id,
            supplyRate: reserveData.currentLiquidityRate,
            borrowRateVariable: reserveData.currentVariableBorrowRate,
            borrowRateStable: 0,
            totalSupply: IERC20(reserveData.aTokenAddress).totalSupply()
                + reserveData.accruedToTreasury,
            availableLiquidity: _tokenAddr.getBalance(reserveData.aTokenAddress),
            totalBorrow: totalVariableBorrow,
            totalBorrowVar: totalVariableBorrow,
            totalBorrowStab: 0,
            collateralFactor: config.getLtv(),
            liquidationRatio: config.getLiquidationThreshold(),
            price: getAssetPrice(_market, _tokenAddr),
            supplyCap: config.getSupplyCap(),
            borrowCap: config.getBorrowCap(),
            emodeCategory: 0,
            usageAsCollateralEnabled: config.getLiquidationThreshold() > 0,
            borrowingEnabled: config.getBorrowingEnabled(),
            stableBorrowRateEnabled: false, // deprecated in v3.2
            isolationModeBorrowingEnabled: false, // deprecated in v3.7
            debtCeilingForIsolationMode: 0, // deprecated in v3.7
            isolationModeTotalDebt: 0, // deprecated in v3.7
            isSiloedForBorrowing: false, // deprecated in v3.7
            eModeCollateralFactor: 0,
            isFlashLoanEnabled: config.getFlashLoanEnabled(),
            ltv: 0, // same as collateralFactor
            liquidationThreshold: 0, // same as liquidationRatio
            liquidationBonus: uint16(config.getLiquidationBonus()),
            priceSource: address(0), // deprecated, not 1:1 related to asset
            label: "", // deprecated, not 1:1 related to asset
            isActive: isActive,
            isPaused: isPaused,
            isFrozen: isFrozen,
            debtTokenAddress: reserveData.variableDebtTokenAddress
        });
    }

    /// @notice Information about reserves
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokenAddresses Array of token addresses
    /// @return tokens Array of reserves information
    function getFullTokensInfo(address _market, address[] memory _tokenAddresses)
        public
        view
        returns (TokenInfoFull[] memory tokens)
    {
        tokens = new TokenInfoFull[](_tokenAddresses.length);
        for (uint256 i = 0; i < _tokenAddresses.length; ++i) {
            tokens[i] = getTokenInfoFull(_market, _tokenAddresses[i]);
        }
    }

    /// @notice Fetches all the e-mode categories
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @return emodesData Array of e-mode categories
    function getAllEmodes(address _market)
        public
        view
        returns (DataTypes.EModeCategoryNew[] memory emodesData)
    {
        emodesData = new DataTypes.EModeCategoryNew[](256);
        IPoolV3 lendingPool = getLendingPool(_market);
        uint8 missCounter;
        for (uint8 i = 1; i < 256; i++) {
            DataTypes.EModeCategoryNew memory nextEmodeData = getEmodeData(lendingPool, i);
            if (nextEmodeData.liquidationThreshold != 0) {
                emodesData[i - 1] = nextEmodeData;
                missCounter = 0;
            } else {
                ++missCounter;
                // assumes there will never be a gap > 2 when setting eModes
                if (missCounter > 2) break;
            }
        }
    }

    /// @notice Fetches the e-mode data for a specific e-mode category
    /// @param _lendingPool Address of the lending pool
    /// @param _id ID of the e-mode category
    /// @return emodeData E-mode data for the specific category
    function getEmodeData(IPoolV3 _lendingPool, uint8 _id)
        public
        view
        returns (DataTypes.EModeCategoryNew memory emodeData)
    {
        DataTypes.CollateralConfig memory config =
            _lendingPool.getEModeCategoryCollateralConfig(_id);

        bool isolated;
        try _lendingPool.getIsEModeCategoryIsolated(_id) returns (bool _isolated) {
            isolated = _isolated;
        } catch (bytes memory) { /*lowLevelData*/ }

        string memory label = "";
        try _lendingPool.getEModeCategoryLabel(_id) returns (string memory _label) {
            label = _label;
        } catch (bytes memory) { /*lowLevelData*/ }

        uint128 ltvzeroBitmap;
        try _lendingPool.getEModeCategoryLtvzeroBitmap(_id) returns (uint128 _ltvzeroBitmap) {
            ltvzeroBitmap = _ltvzeroBitmap;
        } catch (bytes memory) { /*lowLevelData*/ }

        emodeData = DataTypes.EModeCategoryNew({
            ltv: config.ltv,
            liquidationThreshold: config.liquidationThreshold,
            liquidationBonus: config.liquidationBonus,
            collateralBitmap: _lendingPool.getEModeCategoryCollateralBitmap(_id),
            isolated: isolated,
            label: label,
            borrowableBitmap: _lendingPool.getEModeCategoryBorrowableBitmap(_id),
            ltvzeroBitmap: ltvzeroBitmap
        });
    }

    /// @notice Fetches all the collateral/debt address and amounts, denominated in ether
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    /// @return data LoanData information
    function getLoanData(address _market, address _user)
        public
        view
        returns (LoanData memory data)
    {
        IPoolV3 lendingPool = getLendingPool(_market);
        address[] memory reserveList = lendingPool.getReservesList();
        uint256 eModeId = lendingPool.getUserEMode(_user);

        data = LoanData({
            eMode: eModeId,
            user: _user,
            ratio: 0,
            collAddr: new address[](reserveList.length),
            enabledAsColl: new bool[](reserveList.length),
            borrowAddr: new address[](reserveList.length),
            collAmounts: new uint256[](reserveList.length),
            borrowStableAmounts: new uint256[](reserveList.length),
            borrowVariableAmounts: new uint256[](reserveList.length),
            ltv: 0,
            liquidationThreshold: 0,
            liquidationBonus: 0,
            priceSource: address(0),
            label: ""
        });

        uint64 collPos = 0;
        uint64 borrowPos = 0;

        for (uint256 i = 0; i < reserveList.length; i++) {
            address reserve = reserveList[i];
            uint256 price = getAssetPrice(_market, reserve);
            DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(reserve);
            {
                uint256 aTokenBalance = reserveData.aTokenAddress.getBalance(_user);
                if (aTokenBalance > 0) {
                    data.collAddr[collPos] = reserve;
                    data.enabledAsColl[collPos] =
                        lendingPool.getUserConfiguration(_user).isUsingAsCollateral(reserveData.id);
                    uint256 userTokenBalanceEth =
                        (aTokenBalance * price) / (10 ** (reserve.getTokenDecimals()));
                    data.collAmounts[collPos] = userTokenBalanceEth;
                    collPos++;
                }
            }
            // Sum up debt in Usd
            uint256 borrowsVariable = reserveData.variableDebtTokenAddress.getBalance(_user);
            if (borrowsVariable > 0) {
                uint256 userBorrowBalanceEth =
                    (borrowsVariable * price) / (10 ** (reserve.getTokenDecimals()));
                data.borrowAddr[borrowPos] = reserve;
                data.borrowVariableAmounts[borrowPos] = userBorrowBalanceEth;
            }
            if (borrowsVariable > 0) {
                borrowPos++;
            }
        }

        data.ratio = uint128(getSafetyRatio(_market, _user));

        return data;
    }
    /// @notice Fetches all the collateral/debt address and amounts, denominated in ether
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _users Addresses of the user
    /// @return loans Array of LoanData information

    function getLoanDataArr(address _market, address[] memory _users)
        public
        view
        returns (LoanData[] memory loans)
    {
        loans = new LoanData[](_users.length);

        for (uint256 i = 0; i < _users.length; ++i) {
            loans[i] = getLoanData(_market, _users[i]);
        }
    }

    /// @notice Fetches the price of a token
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokenAddr Address of the token
    /// @return price The price of the token
    function getAssetPrice(address _market, address _tokenAddr)
        public
        view
        returns (uint256 price)
    {
        address priceOracleAddress = IPoolAddressesProvider(_market).getPriceOracle();
        price = IAaveV3Oracle(priceOracleAddress).getAssetPrice(_tokenAddr);
    }

    /// @notice Fetches the e-mode collateral factor for a specific e-mode category
    /// @param emodeCategory ID of the e-mode category
    /// @param lendingPool Address of the lending pool
    /// @return eModeCollateralFactor The e-mode collateral factor for the specific category
    function getEModeCollateralFactor(uint256 emodeCategory, IPoolV3 lendingPool)
        public
        view
        returns (uint16)
    {
        DataTypes.EModeCategoryLegacy memory categoryData =
            lendingPool.getEModeCategoryData(uint8(emodeCategory));
        return categoryData.ltv;
    }

    /// @notice Checks if borrow is allowed for a market
    /// @dev Removed in v3.7 along with priceOracleSentinel, left for backwards compatibility
    function isBorrowAllowed(address) public pure returns (bool) {
        return true;
    }

    /// @notice Fetches the apy after values estimation
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _reserveParams Array of liquidity change parameters
    /// @return estimatedRates Array of estimated rates
    function getApyAfterValuesEstimation(
        address _market,
        LiquidityChangeParams[] memory _reserveParams
    ) public view returns (EstimatedRates[] memory) {
        IPoolV3 lendingPool = getLendingPool(_market);
        EstimatedRates[] memory estimatedRates = new EstimatedRates[](_reserveParams.length);
        for (uint256 i = 0; i < _reserveParams.length; ++i) {
            address asset = _reserveParams[i].reserveAddress;
            DataTypes.ReserveData memory reserve = lendingPool.getReserveData(asset);

            uint256 totalVarDebt = IScaledBalanceToken(reserve.variableDebtTokenAddress)
                .scaledTotalSupply().rayMul(_getNextVariableBorrowIndex(reserve));

            if (_reserveParams[i].isDebtAsset) {
                totalVarDebt += _reserveParams[i].liquidityTaken;
                totalVarDebt = _reserveParams[i].liquidityAdded >= totalVarDebt
                    ? 0
                    : totalVarDebt - _reserveParams[i].liquidityAdded;
            }

            (uint256 estimatedSupplyRate, uint256 estimatedVariableBorrowRate) = IReserveInterestRateStrategy(
                    lendingPool.RESERVE_INTEREST_RATE_STRATEGY()
                )
                .calculateInterestRates(
                    DataTypes.CalculateInterestRatesParams({
                        unbacked: lendingPool.getReserveDeficit(asset),
                        liquidityAdded: _reserveParams[i].liquidityAdded,
                        liquidityTaken: _reserveParams[i].liquidityTaken,
                        totalDebt: totalVarDebt,
                        reserveFactor: reserve.configuration.getReserveFactor(),
                        reserve: asset,
                        usingVirtualBalance: true,
                        virtualUnderlyingBalance: lendingPool.getVirtualUnderlyingBalance(asset)
                    })
                );

            estimatedRates[i] = EstimatedRates({
                reserveAddress: asset,
                supplyRate: estimatedSupplyRate,
                variableBorrowRate: estimatedVariableBorrowRate
            });
        }

        return estimatedRates;
    }

    /// @notice Fetches the additional umbrella staking data and user snapshot data if needed
    /// @param _umbrella Address of the umbrella
    /// @param _user Address of the user (Optional)
    /// @return retVal Array of UmbrellaStkData
    function getAdditionalUmbrellaStakingData(address _umbrella, address _user)
        external
        view
        returns (UmbrellaStkData[] memory retVal)
    {
        address[] memory stkTokens = IUmbrella(_umbrella).getStkTokens();
        retVal = new UmbrellaStkData[](stkTokens.length);
        for (uint256 i = 0; i < stkTokens.length; ++i) {
            retVal[i] = _fetchStkTokenData(stkTokens[i], _user);
        }
    }

    /// @notice Fetches EOA balances and approvals towards proxy for all assets in a market
    /// @param _eoa Address of the EOA
    /// @param _proxy Address of the proxy/smart wallet
    /// @param _market Address of the Aave market
    /// @return approvalData Array of EOAApprovalData for all assets
    function getEOAApprovalsAndBalancesForAllTokens(address _eoa, address _proxy, address _market)
        public
        view
        returns (EOAApprovalData[] memory approvalData)
    {
        IPoolV3 lendingPool = getLendingPool(_market);
        address[] memory reserveList = lendingPool.getReservesList();
        approvalData = new EOAApprovalData[](reserveList.length);

        for (uint256 i = 0; i < reserveList.length; i++) {
            approvalData[i] = getEOAApprovalsAndBalances(reserveList[i], _eoa, _proxy, _market);
        }
    }

    /// @notice Fetches `_eoa` balances and approvals towards `_proxy` for `_assets` in a `_market`
    /// @param _eoa Address of the EOA
    /// @param _proxy Address of the smart wallet
    /// @param _market Address of the Aave market
    /// @return approvalData EOAApprovalData for selected params
    function getEOAApprovalsAndBalances(
        address _asset,
        address _eoa,
        address _proxy,
        address _market
    ) public view returns (EOAApprovalData memory approvalData) {
        IPoolV3 lendingPool = getLendingPool(_market);
        IAaveProtocolDataProvider dataProvider = getDataProvider(_market);

        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(_asset);

        // Get user data from protocol data provider
        (uint256 currentATokenBalance,, uint256 currentVariableDebt,,,,,,) =
            dataProvider.getUserReserveData(_asset, _eoa);

        approvalData = EOAApprovalData({
            asset: _asset,
            aToken: reserveData.aTokenAddress,
            variableDebtToken: reserveData.variableDebtTokenAddress,
            assetApproval: IERC20(_asset).allowance(_eoa, _proxy),
            aTokenApproval: IERC20(reserveData.aTokenAddress).allowance(_eoa, _proxy),
            variableDebtDelegation: IDebtToken(reserveData.variableDebtTokenAddress)
                .borrowAllowance(_eoa, _proxy),
            borrowedVariableAmount: currentVariableDebt,
            eoaBalance: IERC20(_asset).balanceOf(_eoa),
            aTokenBalance: currentATokenBalance
        });
    }

    /**
     *
     *                         INTERNAL FUNCTIONS
     *
     */
    /// @notice Fetches the additional stk token data and user snapshot data if needed
    /// @param _stkToken Address of the stk token
    /// @param _user Address of the user (Optional)
    /// @return retVal UmbrellaStkData
    function _fetchStkTokenData(address _stkToken, address _user)
        internal
        view
        returns (UmbrellaStkData memory retVal)
    {
        retVal.stkToken = _stkToken;
        retVal.totalShares = IERC20(_stkToken).totalSupply();
        retVal.cooldownPeriod = IERC4626StakeToken(_stkToken).getCooldown();
        retVal.unstakeWindow = IERC4626StakeToken(_stkToken).getUnstakeWindow();
        retVal.stkUnderlyingToken = IERC4626(_stkToken).asset();

        if (retVal.stkUnderlyingToken != GHO_TOKEN) {
            retVal.aToken = IStaticATokenV2(retVal.stkUnderlyingToken).aToken();
        }

        uint256 baseUnit = 10 ** IERC20(_stkToken).decimals();
        retVal.stkTokenToWaTokenRate = IERC4626(_stkToken).convertToAssets(baseUnit);

        address waToken = IERC4626(_stkToken).asset();
        retVal.waTokenToATokenRate =
            (waToken != GHO_TOKEN) ? IERC4626(waToken).convertToAssets(baseUnit) : baseUnit;

        IUmbrellaRewardsController rewardsController =
            IUmbrellaRewardsController(UMBRELLA_REWARDS_CONTROLLER_ADDRESS);

        address[] memory rewards = rewardsController.getAllRewards(_stkToken);

        uint256[] memory rewardsEmissionRates = new uint256[](rewards.length);
        for (uint256 i = 0; i < rewards.length; ++i) {
            rewardsEmissionRates[i] =
                rewardsController.calculateCurrentEmission(_stkToken, rewards[i]);
        }

        retVal.rewardsEmissionRates = rewardsEmissionRates;

        if (_user != address(0)) {
            IERC4626StakeToken.CooldownSnapshot memory cooldownSnapshot =
                IERC4626StakeToken(_stkToken).getStakerCooldown(_user);
            retVal.userCooldownAmount = cooldownSnapshot.amount;
            retVal.userEndOfCooldown = cooldownSnapshot.endOfCooldown;
            retVal.userWithdrawalWindow = cooldownSnapshot.withdrawalWindow;
        }
    }

    /// @notice Fetches the next variable borrow index
    function _getNextVariableBorrowIndex(DataTypes.ReserveData memory _reserve)
        internal
        view
        returns (uint128 variableBorrowIndex)
    {
        uint256 scaledVariableDebt =
            IScaledBalanceToken(_reserve.variableDebtTokenAddress).scaledTotalSupply();
        variableBorrowIndex = _reserve.variableBorrowIndex;
        if (scaledVariableDebt > 0) {
            uint256 cumulatedVariableBorrowInterest = MathUtils.calculateCompoundedInterest(
                _reserve.currentVariableBorrowRate, _reserve.lastUpdateTimestamp
            );
            variableBorrowIndex =
                uint128(cumulatedVariableBorrowInterest.rayMul(variableBorrowIndex));
        }
    }
}