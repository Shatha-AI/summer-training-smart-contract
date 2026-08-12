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

    /// @dev Helper function to check if ratio is 0, used for better readability.
    function isRatioZero(uint256 _ratio) internal pure returns (bool) {
        return _ratio == 0;
    }
}







contract MainnetActionsUtilAddresses {
    address internal constant DFS_REG_CONTROLLER_ADDR = 0xF8f8B3C98Cf2E63Df3041b73f80F362a4cf3A576;
    address internal constant REGISTRY_ADDR = 0x287778F121F134C66212FB16c9b53eC991D32f5b;
    address internal constant DFS_LOGGER_ADDR = 0xcE7a977Cac4a481bc84AC06b2Da0df614e621cf3;
    address internal constant SUB_STORAGE_ADDR = 0x1612fc28Ee0AB882eC99842Cde0Fc77ff0691e90;
    address internal constant PROXY_AUTH_ADDR = 0x149667b6FAe2c63D1B4317C716b0D0e4d3E2bD70;
    address internal constant LSV_PROXY_REGISTRY_ADDRESS =
        0xa8a3c86c4A2DcCf350E84D2b3c46BDeBc711C16e;
    address internal constant TRANSIENT_STORAGE = 0x2F7Ef2ea5E8c97B8687CA703A0e50Aa5a49B7eb2;
    address internal constant TRANSIENT_STORAGE_CANCUN = 0x0304E27cccE28bAB4d78C6cb7AfD4cd01c87c1e4;
}







contract ActionsUtilHelper is MainnetActionsUtilAddresses { }







contract MainnetAuthAddresses {
    address internal constant ADMIN_VAULT_ADDR = 0xCCf3d848e08b94478Ed8f46fFead3008faF581fD;
    address internal constant DSGUARD_FACTORY_ADDRESS = 0x5a15566417e6C1c9546523066500bDDBc53F88C7;
    address internal constant ADMIN_ADDR = 0x25eFA336886C74eA8E282ac466BdCd0199f85BB9; // USED IN ADMIN VAULT CONSTRUCTOR
    address internal constant PROXY_AUTH_ADDRESS = 0x149667b6FAe2c63D1B4317C716b0D0e4d3E2bD70;
    address internal constant MODULE_AUTH_ADDRESS = 0x7407974DDBF539e552F1d051e44573090912CC3D;
}







contract AuthHelper is MainnetAuthAddresses { }







interface IAdminVault {
    function owner() external view returns (address);
    function admin() external view returns (address);
    function changeOwner(address _owner) external;
    function changeAdmin(address _admin) external;
}











contract AdminAuth is AuthHelper {
    using SafeERC20 for IERC20;

    IAdminVault public constant adminVault = IAdminVault(ADMIN_VAULT_ADDR);

    error SenderNotOwner();
    error SenderNotAdmin();

    modifier onlyOwner() {
        if (adminVault.owner() != msg.sender) {
            revert SenderNotOwner();
        }
        _;
    }

    modifier onlyAdmin() {
        if (adminVault.admin() != msg.sender) {
            revert SenderNotAdmin();
        }
        _;
    }

    /// @notice withdraw stuck funds
    function withdrawStuckFunds(address _token, address _receiver, uint256 _amount)
        public
        onlyOwner
    {
        if (_token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            payable(_receiver).transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(_receiver, _amount);
        }
    }
}







interface IDFSRegistry {
    function getAddr(bytes4 _id) external view returns (address);

    function addNewContract(bytes32 _id, address _contractAddr, uint256 _waitPeriod) external;

    function startContractChange(bytes32 _id, address _newContractAddr) external;

    function approveContractChange(bytes32 _id) external;

    function cancelContractChange(bytes32 _id) external;

    function changeWaitPeriod(bytes32 _id, uint256 _newWaitPeriod) external;
}







contract DefisaverLogger {
    event RecipeEvent(address indexed caller, string indexed logName);

    event ActionDirectEvent(address indexed caller, string indexed logName, bytes data);

    function logRecipeEvent(string memory _logName) public {
        emit RecipeEvent(msg.sender, _logName);
    }

    function logActionDirectEvent(string memory _logName, bytes memory _data) public {
        emit ActionDirectEvent(msg.sender, _logName, _data);
    }
}







interface IDSProxy {
    function execute(bytes memory _code, bytes memory _data)
        external
        payable
        returns (address, bytes32);

    function execute(address _target, bytes memory _data) external payable returns (bytes32);

    function setCache(address _cacheAddr) external payable returns (bool);

    function owner() external view returns (address);

    function guard() external view returns (address);
}







interface IDSProxyFactory {
    function isProxy(address _proxy) external view returns (bool);
    function build(address owner) external returns (IDSProxy proxy);
    function build() external returns (IDSProxy proxy);
}






interface IInstaList {
    struct AccountLink {
        address first;
        address last;
        uint64 count;
    }

    struct AccountList {
        address prev;
        address next;
    }

    struct UserLink {
        uint64 first;
        uint64 last;
        uint64 count;
    }

    struct UserList {
        uint64 prev;
        uint64 next;
    }

    function accountAddr(uint64 _id) external view returns (address);
    function accountID(address _addr) external view returns (uint64);
    function accountLink(uint64 _id) external view returns (AccountLink memory);
    function accountList(uint64 _id, address _user) external view returns (AccountList memory);
    function userLink(address _user) external view returns (UserLink memory);
    function userList(address _user, uint64 _id) external view returns (UserList memory);
}







interface ISafe {
    enum Operation {
        Call,
        DelegateCall
    }

    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation
    ) external returns (bool success);

    function checkSignatures(bytes32 dataHash, bytes memory data, bytes memory signatures)
        external
        view;

    function checkNSignatures(
        address executor,
        bytes32 dataHash,
        bytes memory, /* data */
        bytes memory signatures,
        uint256 requiredSignatures
    ) external view;

    function approveHash(bytes32 hashToApprove) external;

    function domainSeparator() external view returns (bytes32);

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);

    function nonce() external view returns (uint256);

    function setFallbackHandler(address handler) external;

    function getOwners() external view returns (address[] memory);

    function isOwner(address owner) external view returns (bool);

    function getThreshold() external view returns (uint256);

    function enableModule(address module) external;

    function isModuleEnabled(address module) external view returns (bool);

    function disableModule(address prevModule, address module) external;

    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory array, address next);
}







contract MainnetDSAProxyFactoryAddresses {
    address internal constant DSA_LIST_ADDR = 0x4c8a1BEb8a87765788946D6B19C6C6355194AbEb;
}







contract DSAProxyFactoryHelper is MainnetDSAProxyFactoryAddresses { }







contract MainnetProxyFactoryAddresses {
    address internal constant PROXY_FACTORY_ADDR = 0xA26e15C895EFc0616177B7c1e7270A4C7D51C997;
}







contract DSProxyFactoryHelper is MainnetProxyFactoryAddresses { }







contract MainnetSFProxyFactoryAddresses {
    address internal constant SF_PROXY_FACTORY_ADDR = 0xF7B75183A2829843dB06266c114297dfbFaeE2b6;
    address internal constant SF_PROXY_GUARD = 0xCe91349d2A4577BBd0fC91Fe6019600e047f2847;
    bytes32 internal constant SF_PROXY_CODEHASH =
        0x15b0c1a13812f0fce8291b8e7786ece58e0daab08d489cdfe2899fdac4f66045;
}







contract SFProxyFactoryHelper is MainnetSFProxyFactoryAddresses { }







enum WalletType {
    DSPROXY,
    SAFE,
    DSAPROXY,
    SFPROXY
}















contract SmartWalletUtils is DSProxyFactoryHelper, DSAProxyFactoryHelper, SFProxyFactoryHelper {
    /// @notice Determine the type of wallet an address represents
    function _getWalletType(address _wallet) internal view returns (WalletType) {
        if (_isDSProxy(_wallet)) {
            return WalletType.DSPROXY;
        }

        if (_isDSAProxy(_wallet)) {
            return WalletType.DSAPROXY;
        }

        if (_isSFProxy(_wallet)) {
            return WalletType.SFPROXY;
        }

        // Otherwise, we assume we are in context of Safe
        return WalletType.SAFE;
    }

    /// @notice Check if the wallet is a DSProxy
    function _isDSProxy(address _wallet) internal view returns (bool) {
        return IDSProxyFactory(PROXY_FACTORY_ADDR).isProxy(_wallet);
    }

    /// @notice Check if the wallet is a DSA Proxy Account
    function _isDSAProxy(address _wallet) internal view returns (bool) {
        return IInstaList(DSA_LIST_ADDR).accountID(_wallet) != 0;
    }

    /// @notice Check if the wallet is a Summerfi account
    function _isSFProxy(address _wallet) internal view returns (bool) {
        return _wallet.codehash == SF_PROXY_CODEHASH;
    }

    /// @notice Fetch the owner of the smart wallet or the wallet itself
    /// @dev For 1/1 Safe it returns the owner, otherwise it returns the wallet itself
    /// @dev Only supports Safe and DSProxy wallets because SFProxy and DSAProxy are not part of automation
    /// @param _wallet Address of the smart wallet
    /// @return Address of the owner or wallet
    function _fetchOwnerOrWallet(address _wallet) internal view returns (address) {
        if (_isDSProxy(_wallet)) return IDSProxy(_wallet).owner();

        // Otherwise, we assume we are in context of Safe
        address[] memory owners = ISafe(_wallet).getOwners();
        return owners.length == 1 ? owners[0] : _wallet;
    }
}











abstract contract ActionBase is AdminAuth, ActionsUtilHelper, SmartWalletUtils {
    event ActionEvent(string indexed logName, bytes data);

    IDFSRegistry public constant registry = IDFSRegistry(REGISTRY_ADDR);

    DefisaverLogger public constant logger = DefisaverLogger(DFS_LOGGER_ADDR);

    //Wrong sub index value
    error SubIndexValueError();
    //Wrong return index value
    error ReturnIndexValueError();

    /// @dev Subscription params index range [128, 255]
    uint8 public constant SUB_MIN_INDEX_VALUE = 128;
    uint8 public constant SUB_MAX_INDEX_VALUE = 255;

    /// @dev Return params index range [1, 127]
    uint8 public constant RETURN_MIN_INDEX_VALUE = 1;
    uint8 public constant RETURN_MAX_INDEX_VALUE = 127;

    /// @dev If the input value should not be replaced
    uint8 public constant NO_PARAM_MAPPING = 0;

    /// @dev We need to parse Flash loan actions in a different way
    enum ActionType {
        FL_ACTION,
        STANDARD_ACTION,
        FEE_ACTION,
        CHECK_ACTION,
        CUSTOM_ACTION
    }

    /// @notice Parses inputs and runs the implemented action through a user wallet
    /// @dev Is called by the RecipeExecutor chaining actions together
    /// @param _callData Array of input values each value encoded as bytes
    /// @param _subData Array of subscribed vales, replaces input values if specified
    /// @param _paramMapping Array that specifies how return and subscribed values are mapped in input
    /// @param _returnValues Returns values from actions before, which can be injected in inputs
    /// @return Returns a bytes32 value through user wallet, each actions implements what that value is
    function executeAction(
        bytes memory _callData,
        bytes32[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable virtual returns (bytes32);

    /// @notice Parses inputs and runs the single implemented action through a user wallet
    /// @dev Used to save gas when executing a single action directly
    function executeActionDirect(bytes memory _callData) public payable virtual;

    /// @notice Returns the type of action we are implementing
    function actionType() public pure virtual returns (uint8);

    //////////////////////////// HELPER METHODS ////////////////////////////

    /// @notice Given an uint256 input, injects return/sub values if specified
    /// @param _param The original input value
    /// @param _mapType Indicated the type of the input in paramMapping
    /// @param _subData Array of subscription data we can replace the input value with
    /// @param _returnValues Array of subscription data we can replace the input value with
    function _parseParamUint(
        uint256 _param,
        uint8 _mapType,
        bytes32[] memory _subData,
        bytes32[] memory _returnValues
    ) internal pure returns (uint256) {
        if (isReplaceable(_mapType)) {
            if (isReturnInjection(_mapType)) {
                _param = uint256(_returnValues[getReturnIndex(_mapType)]);
            } else {
                _param = uint256(_subData[getSubIndex(_mapType)]);
            }
        }

        return _param;
    }

    /// @notice Given an addr input, injects return/sub values if specified
    /// @param _param The original input value
    /// @param _mapType Indicated the type of the input in paramMapping
    /// @param _subData Array of subscription data we can replace the input value with
    /// @param _returnValues Array of subscription data we can replace the input value with
    function _parseParamAddr(
        address _param,
        uint8 _mapType,
        bytes32[] memory _subData,
        bytes32[] memory _returnValues
    ) internal view returns (address) {
        if (isReplaceable(_mapType)) {
            if (isReturnInjection(_mapType)) {
                _param = address(bytes20((_returnValues[getReturnIndex(_mapType)])));
            } else {
                /// @dev The last two values are specially reserved for proxy addr and owner addr
                if (_mapType == 254) return address(this); // wallet address
                if (_mapType == 255) return _fetchOwnerOrWallet(address(this)); // owner if 1/1 wallet or the wallet itself

                _param = address(uint160(uint256(_subData[getSubIndex(_mapType)])));
            }
        }

        return _param;
    }

    /// @notice Given an bytes32 input, injects return/sub values if specified
    /// @param _param The original input value
    /// @param _mapType Indicated the type of the input in paramMapping
    /// @param _subData Array of subscription data we can replace the input value with
    /// @param _returnValues Array of subscription data we can replace the input value with
    function _parseParamABytes32(
        bytes32 _param,
        uint8 _mapType,
        bytes32[] memory _subData,
        bytes32[] memory _returnValues
    ) internal pure returns (bytes32) {
        if (isReplaceable(_mapType)) {
            if (isReturnInjection(_mapType)) {
                _param = (_returnValues[getReturnIndex(_mapType)]);
            } else {
                _param = _subData[getSubIndex(_mapType)];
            }
        }

        return _param;
    }

    /// @notice Checks if the paramMapping value indicated that we need to inject values
    /// @param _type Indicated the type of the input
    function isReplaceable(uint8 _type) internal pure returns (bool) {
        return _type != NO_PARAM_MAPPING;
    }

    /// @notice Checks if the paramMapping value is in the return value range
    /// @param _type Indicated the type of the input
    function isReturnInjection(uint8 _type) internal pure returns (bool) {
        return (_type >= RETURN_MIN_INDEX_VALUE) && (_type <= RETURN_MAX_INDEX_VALUE);
    }

    /// @notice Transforms the paramMapping value to the index in return array value
    /// @param _type Indicated the type of the input
    function getReturnIndex(uint8 _type) internal pure returns (uint8) {
        if (!(isReturnInjection(_type))) {
            revert SubIndexValueError();
        }

        return (_type - RETURN_MIN_INDEX_VALUE);
    }

    /// @notice Transforms the paramMapping value to the index in sub array value
    /// @param _type Indicated the type of the input
    function getSubIndex(uint8 _type) internal pure returns (uint8) {
        if (_type < SUB_MIN_INDEX_VALUE) {
            revert ReturnIndexValueError();
        }
        return (_type - SUB_MIN_INDEX_VALUE);
    }
}










contract AaveV3OpenRatioCheck is ActionBase, AaveV3RatioHelper {
    /// @notice 5% offset acceptable
    uint256 internal constant RATIO_OFFSET = 5e16;
    /// @notice We are checking for 5% RATIO_OFFSET only when the target ratio is < 999%
    uint256 internal constant RATIO_LIMIT = 999e16;

    error BadAfterRatio(uint256 currentRatio, uint256 targetRatio);

    /// @param targetRatio Target ratio.
    /// @param market Market address.
    /// @param user EOA or Smart Wallet address parameter that was added later in order to add support for EOA strategies.
    struct Params {
        uint256 targetRatio;
        address market;
        address user;
    }

    /// @inheritdoc ActionBase
    function executeAction(
        bytes memory _callData,
        bytes32[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable virtual override returns (bytes32) {
        Params memory inputData = parseInputs(_callData);

        uint256 targetRatio =
            _parseParamUint(inputData.targetRatio, _paramMapping[0], _subData, _returnValues);
        address market =
            _parseParamAddr(inputData.market, _paramMapping[1], _subData, _returnValues);

        address user;
        /// @dev User param is added later, hence the check
        if (_paramMapping.length == 3) {
            user = _parseParamAddr(inputData.user, _paramMapping[2], _subData, _returnValues);
        }

        if (user == address(0)) user = address(this); // default to proxy

        uint256 currRatio = getRatio(market, user);

        /// @notice If `targetRatio` is 999% or more then skip `RATIO_OFFSET` check because it is very hard to be precise under 5%.
        if (targetRatio < RATIO_LIMIT) {
            /// @notice If user is subscribed on full repay, currRatio must be exactly 0
            if (isRatioZero(targetRatio)) {
                if (!isRatioZero(currRatio)) {
                    revert BadAfterRatio(currRatio, targetRatio);
                }
            } else {
                /// @notice Normal repay with target ratio, we accept 5% offset
                if (
                    currRatio > (targetRatio + RATIO_OFFSET)
                        || currRatio < (targetRatio - RATIO_OFFSET)
                ) {
                    revert BadAfterRatio(currRatio, targetRatio);
                }
            }
        }

        emit ActionEvent("AaveV3OpenRatioCheck", abi.encode(currRatio));
        return bytes32(currRatio);
    }

    /// @inheritdoc ActionBase
    // solhint-disable-next-line no-empty-blocks
    function executeActionDirect(bytes memory _callData) public payable override { }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.CHECK_ACTION);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory inputData) {
        inputData = abi.decode(_callData, (Params));
    }
}