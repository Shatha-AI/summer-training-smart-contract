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






library SparkDataTypes {
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
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //aToken address
        address aTokenAddress;
        //stableDebtToken address
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        //the outstanding debt borrowed against this asset in isolation mode
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
        //bit 59: stable rate borrowing enabled
        //bit 60: asset is paused
        //bit 61: borrowing in isolation mode is enabled
        //bit 62: siloed borrowing enabled
        //bit 63: flashloaning enabled
        //bit 64-79: reserve factor
        //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
        //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
        //bit 152-167 liquidation protocol fee
        //bit 168-175 eMode category
        //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
        //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
        //bit 252-255 unused
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

    struct EModeCategory {
        // each eMode category has a custom ltv and liquidation threshold
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        // each eMode category may or may not have a custom oracle to override the individual assets price oracles
        address priceSource;
        string label;
    }

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    struct CalculateInterestRatesParams {
        uint256 unbacked;
        uint256 liquidityAdded;
        uint256 liquidityTaken;
        uint256 totalStableDebt;
        uint256 totalVariableDebt;
        uint256 averageStableBorrowRate;
        uint256 reserveFactor;
        address reserve;
        address aToken;
    }
}






/**
 * @title ReserveConfiguration library
 * @author Aave
 * @notice Implements the bitmap logic to handle the reserve configuration
 * @dev Taken and adapted from Aave. Changes:
 * - Removed all functions, except `getParams`
 * - Renamed DataTypes to SparkDataTypes
 */
library ReserveConfiguration {
    uint256 internal constant LTV_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
    uint256 internal constant LIQUIDATION_THRESHOLD_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
    uint256 internal constant LIQUIDATION_BONUS_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
    uint256 internal constant DECIMALS_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant ACTIVE_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant FROZEN_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant BORROWING_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant STABLE_BORROWING_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant PAUSED_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant BORROWABLE_IN_ISOLATION_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant SILOED_BORROWING_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant FLASHLOAN_ENABLED_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant RESERVE_FACTOR_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant BORROW_CAP_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant SUPPLY_CAP_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant LIQUIDATION_PROTOCOL_FEE_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant EMODE_CATEGORY_MASK =
        0xFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant UNBACKED_MINT_CAP_MASK =
        0xFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant DEBT_CEILING_MASK =
        0xF0000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

    /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
    uint256 internal constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 internal constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
    uint256 internal constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
    uint256 internal constant IS_ACTIVE_START_BIT_POSITION = 56;
    uint256 internal constant IS_FROZEN_START_BIT_POSITION = 57;
    uint256 internal constant BORROWING_ENABLED_START_BIT_POSITION = 58;
    uint256 internal constant STABLE_BORROWING_ENABLED_START_BIT_POSITION = 59;
    uint256 internal constant IS_PAUSED_START_BIT_POSITION = 60;
    uint256 internal constant BORROWABLE_IN_ISOLATION_START_BIT_POSITION = 61;
    uint256 internal constant SILOED_BORROWING_START_BIT_POSITION = 62;
    uint256 internal constant FLASHLOAN_ENABLED_START_BIT_POSITION = 63;
    uint256 internal constant RESERVE_FACTOR_START_BIT_POSITION = 64;
    uint256 internal constant BORROW_CAP_START_BIT_POSITION = 80;
    uint256 internal constant SUPPLY_CAP_START_BIT_POSITION = 116;
    uint256 internal constant LIQUIDATION_PROTOCOL_FEE_START_BIT_POSITION = 152;
    uint256 internal constant EMODE_CATEGORY_START_BIT_POSITION = 168;
    uint256 internal constant UNBACKED_MINT_CAP_START_BIT_POSITION = 176;
    uint256 internal constant DEBT_CEILING_START_BIT_POSITION = 212;

    /**
     * @notice Gets the configuration parameters of the reserve from storage
     * @param self The reserve configuration
     * @return The state param representing ltv
     * @return The state param representing liquidation threshold
     * @return The state param representing liquidation bonus
     * @return The state param representing reserve decimals
     * @return The state param representing reserve factor
     * @return The state param representing eMode category
     */
    function getParams(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        uint256 dataLocal = self.data;

        return (
            dataLocal & ~LTV_MASK,
            (dataLocal & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (dataLocal & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
            (dataLocal & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
            (dataLocal & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION,
            (dataLocal & ~EMODE_CATEGORY_MASK) >> EMODE_CATEGORY_START_BIT_POSITION
        );
    }
}






/**
 * @title UserConfiguration library
 * @author Aave
 * @notice Implements the bitmap logic to handle the user configuration
 * @dev Taken and adapted from Aave. Changes:
 * - Removed all functions, except:
 *         - `isUsingAsCollateralOrBorrowing`,
 *         - `isBorrowing`,
 *         - `isUsingAsCollateral`, and
 *         - `isEmpty`
 * - Removed require statements from `isUsingAsCollateralOrBorrowing`, `isBorrowing`, and `isUsingAsCollateral`
 * - Renamed DataTypes to SparkDataTypes
 */
library UserConfiguration {
    /**
     * @notice Returns if a user has been using the reserve for borrowing or as collateral
     * @param self The configuration object
     * @param reserveIndex The index of the reserve in the bitmap
     * @return True if the user has been using a reserve for borrowing or as collateral, false otherwise
     */
    function isUsingAsCollateralOrBorrowing(
        SparkDataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        unchecked {
            return (self.data >> (reserveIndex << 1)) & 3 != 0;
        }
    }

    /**
     * @notice Validate a user has been using the reserve for borrowing
     * @param self The configuration object
     * @param reserveIndex The index of the reserve in the bitmap
     * @return True if the user has been using a reserve for borrowing, false otherwise
     */
    function isBorrowing(SparkDataTypes.UserConfigurationMap memory self, uint256 reserveIndex)
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
    function isUsingAsCollateral(
        SparkDataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        unchecked {
            return (self.data >> ((reserveIndex << 1) + 1)) & 1 != 0;
        }
    }

    /**
     * @notice Checks if a user has not been using any reserve for borrowing or supply
     * @param self The configuration object
     * @return True if the user has not been borrowing or supplying any reserve, false otherwise
     */
    function isEmpty(SparkDataTypes.UserConfigurationMap memory self) internal pure returns (bool) {
        return self.data == 0;
    }
}







contract MainnetSparkAddresses {
    address internal constant SPARK_REWARDS_CONTROLLER_ADDRESS =
        0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address internal constant DEFAULT_SPARK_MARKET = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address internal constant SPARK_ORACLE_V3 = 0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9;
    address internal constant SDAI_ADDR = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
}






interface ISparkPool {
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
     * @notice Returns the address of the underlying asset of a reserve by the reserve id as stored in the SparkDataTypes.ReserveData struct
     * @param id The id of the reserve as stored in the SparkDataTypes.ReserveData struct
     * @return The address of the reserve associated with id
     *
     */
    function getReserveAddressById(uint16 id) external view returns (address);

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
     * @notice Allows suppliers to enable/disable a specific supplied asset as collateral
     * @param asset The address of the underlying asset supplied
     * @param useAsCollateral True if the user wants to use the supply as collateral, false otherwise
     *
     */
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    /**
     * @notice Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state and configuration data of the reserve
     *
     */
    function getReserveData(address asset) external view returns (SparkDataTypes.ReserveData memory);

    /**
     * @notice Allows a user to use the protocol in eMode
     * @param categoryId The id of the category
     */
    function setUserEMode(uint8 categoryId) external;

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
     * @notice Allows a borrower to swap his debt between stable and variable mode, or vice versa
     * @param asset The address of the underlying asset borrowed
     * @param interestRateMode The current interest rate mode of the position being swapped: 1 for Stable, 2 for Variable
     *
     */
    function swapBorrowRateMode(address asset, uint256 interestRateMode) external;

    /**
     * @notice Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     *
     */
    function getConfiguration(address asset)
        external
        view
        returns (SparkDataTypes.ReserveConfigurationMap memory);

    /**
     * @notice Returns the configuration of the user across all the reserves
     * @param user The user address
     * @return The configuration of the user
     *
     */
    function getUserConfiguration(address user)
        external
        view
        returns (SparkDataTypes.UserConfigurationMap memory);

    /**
     * @notice Returns the data of an eMode category
     * @param id The id of the category
     * @return The configuration data of the category
     */
    function getEModeCategoryData(uint8 id)
        external
        view
        returns (SparkDataTypes.EModeCategory memory);

    /**
     * @notice Returns the list of the underlying assets of all the initialized reserves
     * @dev It does not include dropped reserves
     * @return The addresses of the underlying assets of the initialized reserves
     */
    function getReservesList() external view returns (address[] memory);

    /**
     * @notice Returns the eMode the user is using
     * @param user The address of the user
     * @return The eMode id
     */
    function getUserEMode(address user) external view returns (uint256);
}






interface ISparkPoolAddressesProvider {
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






interface ISparkProtocolDataProvider {
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

    function getSiloedBorrowing(address asset) external view returns (bool);

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









contract SparkHelper is MainnetSparkAddresses {
    uint16 public constant SPARK_REFERRAL_CODE = 64;

    /// @notice Returns the lending pool contract of the specified market
    function getSparkLendingPool(address _market) internal view returns (ISparkPool) {
        return ISparkPool(ISparkPoolAddressesProvider(_market).getPool());
    }

    /// @notice Fetch the data provider for the specified market
    function getSparkDataProvider(address _market)
        internal
        view
        returns (ISparkProtocolDataProvider)
    {
        return
            ISparkProtocolDataProvider(ISparkPoolAddressesProvider(_market).getPoolDataProvider());
    }

    function getSparkWholeDebt(
        address _market,
        address _tokenAddr,
        uint256 _borrowType,
        address _debtOwner
    ) internal view returns (uint256 debt) {
        uint256 STABLE_ID = 1;
        uint256 VARIABLE_ID = 2;

        ISparkProtocolDataProvider dataProvider = getSparkDataProvider(_market);
        (, uint256 borrowsStable, uint256 borrowsVariable,,,,,,) =
            dataProvider.getUserReserveData(_tokenAddr, _debtOwner);

        if (_borrowType == STABLE_ID) {
            debt = borrowsStable;
        } else if (_borrowType == VARIABLE_ID) {
            debt = borrowsVariable;
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






/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 *
 * ---------------------------------------------------
 * @dev Taken adapted from Aave. Changes:
 * - Removed all functions except percentMul
 */
library PercentageMath {
    // Maximum percentage factor (100.00%)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    // Half percentage factor (50.00%)
    uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

    /**
     * @notice Executes a percentage multiplication
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param value The value of which the percentage needs to be calculated
     * @param percentage The percentage of the value to be calculated
     * @return result value percentmul percentage
     */
    function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        assembly {
            if iszero(
                or(
                    iszero(percentage),
                    iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
                )
            ) {
                revert(0, 0)
            }

            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }
}






interface ISparkV3Oracle {
    /**
     * @notice Returns a list of prices from a list of assets addresses
     * @param assets The list of assets addresses
     * @return The prices of the given assets
     */
    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);

    /**
     * @notice Returns the address of the source for an asset address
     * @param asset The address of the asset
     * @return The address of the source
     */
    function getSourceOfAsset(address asset) external view returns (address);

    /**
     * @notice Returns the address of the fallback oracle
     * @return The address of the fallback oracle
     */
    function getFallbackOracle() external view returns (address);

    /**
     * @notice Returns the asset price in the base currency
     * @param asset The address of the asset
     * @return The price of the asset
     *
     */
    function getAssetPrice(address asset) external view returns (uint256);
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















contract SparkRatioHelper is DSMath, MainnetSparkAddresses {
    using TokenUtils for address;
    using UserConfiguration for SparkDataTypes.UserConfigurationMap;
    using ReserveConfiguration for SparkDataTypes.ReserveConfigurationMap;
    using PercentageMath for uint256;

    /// @notice The offset to use when the ltv is 0. In that case, we fallback to lltv - LTV_ZERO_OFFSET
    /// @dev Some reserves will have higher or lower difference between ltv and lltv,
    /// which is ok as this is a fallback approximation value.
    uint256 public constant LTV_ZERO_OFFSET = 500;

    struct CalculateUserAccountDataVars {
        uint256 i;
        address[] reserveList;
        address currentReserveAddress;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 decimals;
        uint256 assetPrice;
        uint256 assetUnit;
        ISparkV3Oracle oracle;
        uint256 userBalanceInBaseCurrency;
        uint256 userTotalDebtInAsset;
        bool isInEModeCategory;
        uint256 userEModeCategory;
        uint256 eModeAssetPrice;
        uint256 eModeLtv;
        uint256 eModeLiqThreshold;
        uint256 eModeAssetCategory;
    }

    /// @notice Returns the safety ratio of the user:
    /// the current overall health of position, inversely proportional to borrow power used.
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _user Address of the user
    /// @return The safety ratio of the user
    function getSafetyRatio(address _market, address _user) public view returns (uint256) {
        ISparkPool lendingPool = ISparkPool(ISparkPoolAddressesProvider(_market).getPool());
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
    /// @dev Spark LTV-zero collateral has no borrow power but still contributes to liquidation threshold / HF.
    ///      For automation flows that historically rely on safety ratio, this function approximates
    ///      LTV-zero collateral contribution as liquidationThreshold - 5%.
    ///      This is NOT equal to Spark available borrow power and should not be used to determine
    ///      whether new debt can be opened.
    function getSafetyRatioWithLtvZeroFallback(address _market, address _user)
        public
        view
        returns (uint256)
    {
        (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 avgLtv) =
            _getUserAccountDataWithLtvZeroFallback(_market, _user);

        if (totalDebtValue == 0) return uint256(0);

        uint256 availableBorrowValue =
            _calculateAvailableBorrowValue(totalCollateralValue, totalDebtValue, avgLtv);

        return wdiv(add(totalDebtValue, availableBorrowValue), totalDebtValue);
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
        uint256 totalAvailableBorrowValue = _totalCollateralValue.percentMul(_avgLtv);
        if (totalAvailableBorrowValue <= _totalDebtValue) return 0;
        return totalAvailableBorrowValue - _totalDebtValue;
    }

    /// @dev See: https://github.com/sparkdotfi/sparklend-v1-core/blob/master/contracts/protocol/libraries/logic/GenericLogic.sol#L64
    function _getUserAccountDataWithLtvZeroFallback(address _market, address _user)
        internal
        view
        returns (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 avgLtv)
    {
        ISparkPool lendingPool = ISparkPool(ISparkPoolAddressesProvider(_market).getPool());
        SparkDataTypes.UserConfigurationMap memory userCfg = lendingPool.getUserConfiguration(_user);
        if (userCfg.isEmpty()) return (0, 0, 0);

        CalculateUserAccountDataVars memory vars;

        vars.reserveList = lendingPool.getReservesList();
        vars.oracle = ISparkV3Oracle(ISparkPoolAddressesProvider(_market).getPriceOracle());
        vars.userEModeCategory = lendingPool.getUserEMode(_user);

        if (vars.userEModeCategory != 0) {
            SparkDataTypes.EModeCategory memory eModeCategory =
                lendingPool.getEModeCategoryData(uint8(vars.userEModeCategory));
            vars.eModeLtv = eModeCategory.ltv;
            vars.eModeLiqThreshold = eModeCategory.liquidationThreshold;
            if (eModeCategory.priceSource != address(0)) {
                vars.eModeAssetPrice = vars.oracle.getAssetPrice(eModeCategory.priceSource);
            }
        }

        while (vars.i < vars.reserveList.length) {
            if (!userCfg.isUsingAsCollateralOrBorrowing(vars.i)) {
                vars.i++;
                continue;
            }

            vars.currentReserveAddress = vars.reserveList[vars.i];

            if (vars.currentReserveAddress == address(0)) {
                vars.i++;
                continue;
            }

            SparkDataTypes.ReserveData memory currentReserve =
                lendingPool.getReserveData(vars.currentReserveAddress);

            (vars.ltv, vars.liquidationThreshold,, vars.decimals,, vars.eModeAssetCategory) =
                currentReserve.configuration.getParams();

            vars.assetUnit = 10 ** vars.decimals;
            vars.assetPrice = (vars.eModeAssetPrice != 0
                        && vars.userEModeCategory == vars.eModeAssetCategory)
                ? vars.eModeAssetPrice
                : vars.oracle.getAssetPrice(vars.currentReserveAddress);

            if (vars.liquidationThreshold != 0 && userCfg.isUsingAsCollateral(vars.i)) {
                vars.userBalanceInBaseCurrency = currentReserve.aTokenAddress.getBalance(_user)
                    * vars.assetPrice / vars.assetUnit;
                totalCollateralValue += vars.userBalanceInBaseCurrency;
                vars.isInEModeCategory = vars.userEModeCategory != 0
                    && vars.userEModeCategory == vars.eModeAssetCategory;
                if (vars.ltv != 0) {
                    avgLtv += vars.userBalanceInBaseCurrency
                    * (vars.isInEModeCategory ? vars.eModeLtv : vars.ltv);
                } else {
                    uint256 lltv = (vars.isInEModeCategory
                            ? vars.eModeLiqThreshold
                            : vars.liquidationThreshold);
                    if (lltv > LTV_ZERO_OFFSET) {
                        avgLtv += (vars.userBalanceInBaseCurrency * (lltv - LTV_ZERO_OFFSET));
                    }
                }
            }

            if (userCfg.isBorrowing(vars.i)) {
                vars.userTotalDebtInAsset = currentReserve.variableDebtTokenAddress
                    .getBalance(_user) + currentReserve.stableDebtTokenAddress.getBalance(_user);
                totalDebtValue += vars.userTotalDebtInAsset * vars.assetPrice / vars.assetUnit;
            }

            vars.i++;
        }

        avgLtv = (totalCollateralValue != 0) ? avgLtv / totalCollateralValue : 0;
    }

    /// @dev Helper function to check if ratio is 0, used for better readability.
    function _isRatioZero(uint256 _ratio) internal pure returns (bool) {
        return _ratio == 0;
    }
}







/**
 * @title IReserveInterestRateStrategy
 * @author Aave
 * @notice Interface for the calculation of the interest rates
 */
interface ISparkReserveInterestRateStrategy {
    /**
     * @notice Calculates the interest rates depending on the reserve's state and configurations
     * @param params The parameters needed to calculate interest rates
     * @return liquidityRate The liquidity rate expressed in rays
     * @return stableBorrowRate The stable borrow rate expressed in rays
     * @return variableBorrowRate The variable borrow rate expressed in rays
     */
    function calculateInterestRates(SparkDataTypes.CalculateInterestRatesParams memory params)
        external
        view
        returns (uint256, uint256, uint256);
}







/**
 * @title ISparkScaledBalanceToken
 * @author Aave
 * @notice Defines the basic interface for a scaled-balance token.
 */
interface ISparkScaledBalanceToken {
    /**
     * @notice Returns the scaled total supply of the scaled balance token. Represents sum(debt/index)
     * @return The scaled total supply
     */
    function scaledTotalSupply() external view returns (uint256);
}







/**
 * @title ISparkStableDebtToken
 * @author Aave
 * @notice Defines the interface for the stable debt token
 * @dev It does not inherit from IERC20 to save in code size
 */
interface ISparkStableDebtToken {
    /**
     * @notice Returns the total supply and the average stable rate
     * @return The total supply
     * @return The average rate
     */
    function getTotalSupplyAndAvgRate() external view returns (uint256, uint256);
}



















contract SparkView is SparkHelper, SparkRatioHelper {
    uint256 internal constant BORROW_CAP_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant SUPPLY_CAP_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant EMODE_CATEGORY_MASK =
        0xFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant BORROWABLE_IN_ISOLATION_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant BORROWING_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant STABLE_BORROWING_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant LTV_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
    uint256 internal constant RESERVE_FACTOR_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant LIQUIDATION_THRESHOLD_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
    uint256 internal constant DEBT_CEILING_MASK =
        0xF0000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant FLASHLOAN_ENABLED_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant ACTIVE_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant FROZEN_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
    uint256 internal constant PAUSED_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF; // prettier-ignore

    uint256 internal constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 internal constant RESERVE_FACTOR_START_BIT_POSITION = 64;
    uint256 internal constant BORROWING_ENABLED_START_BIT_POSITION = 58;
    uint256 internal constant STABLE_BORROWING_ENABLED_START_BIT_POSITION = 59;
    uint256 internal constant BORROW_CAP_START_BIT_POSITION = 80;
    uint256 internal constant SUPPLY_CAP_START_BIT_POSITION = 116;
    uint256 internal constant EMODE_CATEGORY_START_BIT_POSITION = 168;
    uint256 internal constant DEBT_CEILING_START_BIT_POSITION = 212;
    uint256 internal constant FLASHLOAN_ENABLED_START_BIT_POSITION = 63;

    using TokenUtils for address;
    using WadRayMath for uint256;

    struct LoanData {
        address user;
        uint128 ratio;
        uint256 eMode;
        address[] collAddr;
        bool[] enabledAsColl;
        address[] borrowAddr;
        uint256[] collAmounts;
        uint256[] borrowStableAmounts;
        uint256[] borrowVariableAmounts;
        // emode category data
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        address priceSource;
        string label;
    }

    struct UserToken {
        address token;
        uint256 balance;
        uint256 borrowsStable;
        uint256 borrowsVariable;
        uint256 stableBorrowRate;
        bool enabledAsCollateral;
    }

    struct TokenInfo {
        address aTokenAddress;
        address underlyingTokenAddress;
        uint256 collateralFactor;
        uint256 price;
    }

    struct TokenInfoFull {
        address aTokenAddress; //pool.config
        address underlyingTokenAddress; //pool.config
        uint16 assetId;
        uint256 supplyRate; //pool.config
        uint256 borrowRateVariable; //pool.config
        uint256 borrowRateStable; //pool.config
        uint256 totalSupply; //total supply
        uint256 availableLiquidity; //reserveData.liq rate
        uint256 totalBorrow; // total supply of both debt assets
        uint256 totalBorrowVar;
        uint256 totalBorrowStab;
        uint256 collateralFactor; //pool.config
        uint256 liquidationRatio; //pool.config
        uint256 price; //oracle
        uint256 supplyCap; //pool.config
        uint256 borrowCap; //pool.config
        uint256 emodeCategory; //pool.config
        uint256 debtCeilingForIsolationMode; //pool.config 212-251
        uint256 isolationModeTotalDebt; //pool.isolationModeTotalDebt
        bool usageAsCollateralEnabled; //usageAsCollateralEnabled = liquidationThreshold > 0;
        bool borrowingEnabled; //pool.config
        bool stableBorrowRateEnabled; //pool.config
        bool isolationModeBorrowingEnabled; //pool.config
        bool isSiloedForBorrowing; //ISparkProtocolDataProvider.getSiloedBorrowing
        uint256 eModeCollateralFactor; //pool.getEModeCategoryData.ltv
        bool isFlashLoanEnabled;
        // emode category data
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        address priceSource;
        string label;
        bool isActive;
        bool isPaused;
        bool isFrozen;
    }

    /// @notice Params for supply and borrow rate estimation
    /// @param reserveAddress Address of the reserve
    /// @param liquidityAdded Amount of liquidity added (supply/repay)
    /// @param liquidityTaken Amount of liquidity taken (borrow/withdraw)
    /// @param isDebtAsset isDebtAsset if operation is borrow/payback
    struct LiquidityChangeParams {
        address reserveAddress;
        uint256 liquidityAdded;
        uint256 liquidityTaken;
        bool isDebtAsset;
    }

    struct EstimatedRates {
        address reserveAddress;
        uint256 supplyRate;
        uint256 variableBorrowRate;
    }

    function getHealthFactor(address _market, address _user)
        public
        view
        returns (uint256 healthFactor)
    {
        ISparkPool lendingPool = getSparkLendingPool(_market);

        (,,,,, healthFactor) = lendingPool.getUserAccountData(_user);
    }

    /// @notice Fetches Spark prices for tokens
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokens Arr. of tokens for which to get the prices
    /// @return prices Array of prices
    function getPrices(address _market, address[] memory _tokens)
        public
        view
        returns (uint256[] memory prices)
    {
        address priceOracleAddress = ISparkPoolAddressesProvider(_market).getPriceOracle();
        prices = ISparkV3Oracle(priceOracleAddress).getAssetsPrices(_tokens);
    }

    /// @notice Calculated the ratio of coll/debt for an spark user
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

    /// @notice Fetches Spark collateral factors for tokens
    /// @param _market Address of LendingPoolAddressesProvider for specific market
    /// @param _tokens Arr. of tokens for which to get the coll. factors
    /// @return collFactors Array of coll. factors
    function getCollFactors(address _market, address[] memory _tokens)
        public
        view
        returns (uint256[] memory collFactors)
    {
        ISparkPool lendingPool = getSparkLendingPool(_market);
        collFactors = new uint256[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; ++i) {
            SparkDataTypes.ReserveConfigurationMap memory config =
                lendingPool.getConfiguration(_tokens[i]);
            collFactors[i] = getReserveFactor(config);
        }
    }

    function getTokenBalances(address _market, address _user, address[] memory _tokens)
        public
        view
        returns (UserToken[] memory userTokens)
    {
        ISparkPool lendingPool = getSparkLendingPool(_market);
        userTokens = new UserToken[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; i++) {
            SparkDataTypes.ReserveData memory reserveData = lendingPool.getReserveData(_tokens[i]);
            userTokens[i].balance = reserveData.aTokenAddress.getBalance(_user);
            userTokens[i].borrowsStable = reserveData.stableDebtTokenAddress.getBalance(_user);
            userTokens[i].borrowsVariable = reserveData.variableDebtTokenAddress.getBalance(_user);
            userTokens[i].stableBorrowRate = reserveData.currentStableBorrowRate;
            SparkDataTypes.UserConfigurationMap memory map = lendingPool.getUserConfiguration(_user);
            userTokens[i].enabledAsCollateral = isUsingAsCollateral(map, reserveData.id);
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
        ISparkPool lendingPool = getSparkLendingPool(_market);
        tokens = new TokenInfo[](_tokenAddresses.length);

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            SparkDataTypes.ReserveConfigurationMap memory config =
                lendingPool.getConfiguration(_tokenAddresses[i]);
            uint256 collFactor = config.data & ~LTV_MASK;
            SparkDataTypes.ReserveData memory reserveData =
                lendingPool.getReserveData(_tokenAddresses[i]);
            address aTokenAddr = reserveData.aTokenAddress;
            address priceOracleAddress = ISparkPoolAddressesProvider(_market).getPriceOracle();
            uint256 price = ISparkV3Oracle(priceOracleAddress).getAssetPrice(_tokenAddresses[i]);
            tokens[i] = TokenInfo({
                aTokenAddress: aTokenAddr,
                underlyingTokenAddress: _tokenAddresses[i],
                collateralFactor: collFactor,
                price: price
            });
        }
    }

    function getTokenInfoFull(address _market, address _tokenAddr)
        public
        view
        returns (TokenInfoFull memory _tokenInfo)
    {
        ISparkPool lendingPool = getSparkLendingPool(_market);

        SparkDataTypes.ReserveData memory reserveData = lendingPool.getReserveData(_tokenAddr);
        SparkDataTypes.ReserveConfigurationMap memory config =
            lendingPool.getConfiguration(_tokenAddr);

        uint256 totalVariableBorrow = IERC20(reserveData.variableDebtTokenAddress).totalSupply();
        uint256 totalStableBorrow = IERC20(reserveData.stableDebtTokenAddress).totalSupply();

        (bool isActive, bool isFrozen,,, bool isPaused) = getFlags(config);

        uint256 eMode = getEModeCategory(config);
        SparkDataTypes.EModeCategory memory categoryData =
            lendingPool.getEModeCategoryData(uint8(eMode));

        _tokenInfo = TokenInfoFull({
            aTokenAddress: reserveData.aTokenAddress,
            underlyingTokenAddress: _tokenAddr,
            assetId: reserveData.id,
            supplyRate: reserveData.currentLiquidityRate,
            borrowRateVariable: reserveData.currentVariableBorrowRate,
            borrowRateStable: reserveData.currentStableBorrowRate,
            totalSupply: IERC20(reserveData.aTokenAddress).totalSupply()
                + reserveData.accruedToTreasury,
            availableLiquidity: _tokenAddr.getBalance(reserveData.aTokenAddress),
            totalBorrow: totalVariableBorrow + totalStableBorrow,
            totalBorrowVar: totalVariableBorrow,
            totalBorrowStab: totalStableBorrow,
            collateralFactor: getLtv(config),
            liquidationRatio: getLiquidationThreshold(config),
            price: getAssetPrice(_market, _tokenAddr),
            supplyCap: getSupplyCap(config),
            borrowCap: getBorrowCap(config),
            emodeCategory: eMode,
            usageAsCollateralEnabled: getLiquidationThreshold(config) > 0,
            borrowingEnabled: getBorrowingEnabled(config),
            stableBorrowRateEnabled: getStableRateBorrowingEnabled(config),
            isolationModeBorrowingEnabled: getBorrowableInIsolation(config),
            debtCeilingForIsolationMode: getDebtCeiling(config),
            isolationModeTotalDebt: reserveData.isolationModeTotalDebt,
            isSiloedForBorrowing: isSiloedForBorrowing(_market, _tokenAddr),
            eModeCollateralFactor: getEModeCollateralFactor(
                uint8(getEModeCategory(config)), lendingPool
            ),
            isFlashLoanEnabled: getFlashLoanEnabled(config),
            ltv: categoryData.ltv,
            liquidationThreshold: categoryData.liquidationThreshold,
            liquidationBonus: categoryData.liquidationBonus,
            priceSource: categoryData.priceSource,
            label: categoryData.label,
            isActive: isActive,
            isPaused: isPaused,
            isFrozen: isFrozen
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
    /// @param _market Address of SparkPoolAddressesProvider for specific market
    /// @return emodesData Array of e-mode categories
    function getAllEmodes(address _market)
        public
        view
        returns (SparkDataTypes.EModeCategory[] memory emodesData)
    {
        emodesData = new SparkDataTypes.EModeCategory[](256);
        ISparkPool lendingPool = getSparkLendingPool(_market);
        for (uint8 i = 1; i < 255; i++) {
            SparkDataTypes.EModeCategory memory nextEmodeData = getEmodeData(lendingPool, i);
            if (bytes(nextEmodeData.label).length == 0) break;
            emodesData[i - 1] = nextEmodeData;
        }
    }

    /// @notice Fetches the e-mode data for a specific e-mode category
    /// @param _lendingPool Address of the lending pool
    /// @param _id ID of the e-mode category
    /// @return emodeData E-mode data for the specific category
    function getEmodeData(ISparkPool _lendingPool, uint8 _id)
        public
        view
        returns (SparkDataTypes.EModeCategory memory emodeData)
    {
        emodeData = _lendingPool.getEModeCategoryData(_id);
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
        ISparkPool lendingPool = getSparkLendingPool(_market);
        address[] memory reserveList = lendingPool.getReservesList();
        uint256 eMode = lendingPool.getUserEMode(_user);

        SparkDataTypes.EModeCategory memory categoryData =
            lendingPool.getEModeCategoryData(uint8(eMode));

        data = LoanData({
            eMode: eMode,
            user: _user,
            ratio: 0,
            collAddr: new address[](reserveList.length),
            enabledAsColl: new bool[](reserveList.length),
            borrowAddr: new address[](reserveList.length),
            collAmounts: new uint256[](reserveList.length),
            borrowStableAmounts: new uint256[](reserveList.length),
            borrowVariableAmounts: new uint256[](reserveList.length),
            ltv: categoryData.ltv,
            liquidationThreshold: categoryData.liquidationThreshold,
            liquidationBonus: categoryData.liquidationBonus,
            priceSource: categoryData.priceSource,
            label: categoryData.label
        });

        uint64 collPos = 0;
        uint64 borrowPos = 0;

        for (uint256 i = 0; i < reserveList.length; i++) {
            address reserve = reserveList[i];
            uint256 price = getAssetPrice(_market, reserve);
            SparkDataTypes.ReserveData memory reserveData = lendingPool.getReserveData(reserve);
            {
                uint256 aTokenBalance = reserveData.aTokenAddress.getBalance(_user);
                if (aTokenBalance > 0) {
                    data.collAddr[collPos] = reserve;
                    data.enabledAsColl[collPos] = isUsingAsCollateral(
                        lendingPool.getUserConfiguration(_user), reserveData.id
                    );
                    uint256 userTokenBalanceEth =
                        (aTokenBalance * price) / (10 ** (reserve.getTokenDecimals()));
                    data.collAmounts[collPos] = userTokenBalanceEth;
                    collPos++;
                }
            }

            // Sum up debt in Usd
            uint256 borrowsStable = reserveData.stableDebtTokenAddress.getBalance(_user);
            if (borrowsStable > 0) {
                uint256 userBorrowBalanceEth =
                    (borrowsStable * price) / (10 ** (reserve.getTokenDecimals()));
                data.borrowAddr[borrowPos] = reserve;
                data.borrowStableAmounts[borrowPos] = userBorrowBalanceEth;
            }

            // Sum up debt in Usd
            uint256 borrowsVariable = reserveData.variableDebtTokenAddress.getBalance(_user);
            if (borrowsVariable > 0) {
                uint256 userBorrowBalanceEth =
                    (borrowsVariable * price) / (10 ** (reserve.getTokenDecimals()));
                data.borrowAddr[borrowPos] = reserve;
                data.borrowVariableAmounts[borrowPos] = userBorrowBalanceEth;
            }
            if (borrowsStable > 0 || borrowsVariable > 0) {
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

    function getLtv(SparkDataTypes.ReserveConfigurationMap memory self)
        public
        pure
        returns (uint256)
    {
        return self.data & ~LTV_MASK;
    }

    function getReserveFactor(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION;
    }

    function isUsingAsCollateral(
        SparkDataTypes.UserConfigurationMap memory self,
        uint256 reserveIndex
    ) internal pure returns (bool) {
        unchecked {
            return (self.data >> ((reserveIndex << 1) + 1)) & 1 != 0;
        }
    }

    function getLiquidationThreshold(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    }

    function getAssetPrice(address _market, address _tokenAddr)
        public
        view
        returns (uint256 price)
    {
        address priceOracleAddress = ISparkPoolAddressesProvider(_market).getPriceOracle();
        price = ISparkV3Oracle(priceOracleAddress).getAssetPrice(_tokenAddr);
    }

    function getBorrowCap(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & ~BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION;
    }

    function getSupplyCap(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & ~SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION;
    }

    function getEModeCategory(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & ~EMODE_CATEGORY_MASK) >> EMODE_CATEGORY_START_BIT_POSITION;
    }

    function getBorrowingEnabled(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return (self.data & ~BORROWING_MASK) != 0;
    }

    function getStableRateBorrowingEnabled(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return (self.data & ~STABLE_BORROWING_MASK) != 0;
    }

    function getBorrowableInIsolation(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return (self.data & ~BORROWABLE_IN_ISOLATION_MASK) != 0;
    }

    /**
     * @notice Gets the configuration flags of the reserve
     * @param self The reserve configuration
     * @return The state flag representing active
     * @return The state flag representing frozen
     * @return The state flag representing borrowing enabled
     * @return The state flag representing stableRateBorrowing enabled
     * @return The state flag representing paused
     */
    function getFlags(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool, bool, bool, bool, bool)
    {
        uint256 dataLocal = self.data;

        return (
            (dataLocal & ~ACTIVE_MASK) != 0,
            (dataLocal & ~FROZEN_MASK) != 0,
            (dataLocal & ~BORROWING_MASK) != 0,
            (dataLocal & ~STABLE_BORROWING_MASK) != 0,
            (dataLocal & ~PAUSED_MASK) != 0
        );
    }

    /**
     * @notice Gets the debt ceiling for the asset if the asset is in isolation mode
     * @param self The reserve configuration
     * @return The debt ceiling (0 = isolation mode disabled)
     *
     */
    function getDebtCeiling(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return (self.data & ~DEBT_CEILING_MASK) >> DEBT_CEILING_START_BIT_POSITION;
    }

    function isSiloedForBorrowing(address _market, address _tokenAddr)
        internal
        view
        returns (bool)
    {
        ISparkProtocolDataProvider dataProvider = getSparkDataProvider(_market);
        return dataProvider.getSiloedBorrowing(_tokenAddr);
    }

    function getEModeCollateralFactor(uint256 emodeCategory, ISparkPool lendingPool)
        public
        view
        returns (uint16)
    {
        SparkDataTypes.EModeCategory memory categoryData =
            lendingPool.getEModeCategoryData(uint8(emodeCategory));
        return categoryData.ltv;
    }

    function getFlashLoanEnabled(SparkDataTypes.ReserveConfigurationMap memory self)
        internal
        pure
        returns (bool)
    {
        return (self.data & ~FLASHLOAN_ENABLED_MASK) != 0;
    }

    function getApyAfterValuesEstimation(
        address _market,
        LiquidityChangeParams[] memory _reserveParams
    ) public view returns (EstimatedRates[] memory) {
        ISparkPool lendingPool = getSparkLendingPool(_market);
        EstimatedRates[] memory estimatedRates = new EstimatedRates[](_reserveParams.length);
        for (uint256 i = 0; i < _reserveParams.length; ++i) {
            SparkDataTypes.ReserveData memory reserve =
                lendingPool.getReserveData(_reserveParams[i].reserveAddress);

            EstimatedRates memory estimatedRate;
            estimatedRate.reserveAddress = _reserveParams[i].reserveAddress;

            (uint256 currTotalStableDebt, uint256 currAvgStableBorrowRate) =
                ISparkStableDebtToken(reserve.stableDebtTokenAddress).getTotalSupplyAndAvgRate();

            uint256 nextVariableBorrowIndex = _getNextVariableBorrowIndex(reserve);
            uint256 variableDebt =
                ISparkScaledBalanceToken(reserve.variableDebtTokenAddress).scaledTotalSupply();

            uint256 totalVarDebt = variableDebt.rayMul(nextVariableBorrowIndex);

            if (_reserveParams[i].isDebtAsset) {
                totalVarDebt += _reserveParams[i].liquidityTaken;
                totalVarDebt = _reserveParams[i].liquidityAdded >= totalVarDebt
                    ? 0
                    : totalVarDebt - _reserveParams[i].liquidityAdded;
            }

            (estimatedRate.supplyRate,, estimatedRate.variableBorrowRate) = ISparkReserveInterestRateStrategy(
                    reserve.interestRateStrategyAddress
                )
                .calculateInterestRates(
                    SparkDataTypes.CalculateInterestRatesParams({
                        unbacked: reserve.unbacked,
                        liquidityAdded: _reserveParams[i].liquidityAdded,
                        liquidityTaken: _reserveParams[i].liquidityTaken,
                        totalStableDebt: currTotalStableDebt,
                        totalVariableDebt: totalVarDebt,
                        averageStableBorrowRate: currAvgStableBorrowRate,
                        reserveFactor: getReserveFactor(reserve.configuration),
                        reserve: _reserveParams[i].reserveAddress,
                        aToken: reserve.aTokenAddress
                    })
                );

            estimatedRates[i] = estimatedRate;
        }

        return estimatedRates;
    }

    function _getNextVariableBorrowIndex(SparkDataTypes.ReserveData memory _reserve)
        internal
        view
        returns (uint128 variableBorrowIndex)
    {
        uint256 scaledVariableDebt =
            ISparkScaledBalanceToken(_reserve.variableDebtTokenAddress).scaledTotalSupply();
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