// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;










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







interface ITrigger {
    function isTriggered(bytes memory, bytes memory) external returns (bool);
    function isChangeable() external view returns (bool);
    function changedSubData(bytes memory) external view returns (bytes memory);
}











interface IAaveV4Oracle {
    /// @notice Returns the address of the spoke.
    /// @return The address of the spoke.
    function spoke() external view returns (address);

    /// @notice Returns the number of decimals used to return prices.
    /// @return The number of decimals.
    function decimals() external view returns (uint8);

    /// @notice Returns the reserve price with `decimals` precision.
    /// @param reserveId The identifier of the reserve.
    /// @return The price of the reserve.
    function getReservePrice(uint256 reserveId) external view returns (uint256);

    /// @notice Returns the prices of multiple reserves.
    /// @param reserveIds The identifiers of the reserves.
    /// @return prices The prices of the reserves.
    function getReservesPrices(uint256[] calldata reserveIds)
        external
        view
        returns (uint256[] memory);

    /// @notice Returns the price feed source of a reserve.
    /// @param reserveId The identifier of the reserve.
    /// @return source The price feed source of the reserve.
    function getReserveSource(uint256 reserveId) external view returns (address);

    /// @notice Returns the description of the oracle.
    /// @return The description of the oracle.
    function DESCRIPTION() external view returns (string memory);
}










interface ISpoke {
    /**
     *
     *
     *
     *          DATA SPECIFICATION
     *
     *
     *
     */
    /// @notice Reserve level data.
    /// @dev underlying The address of the underlying asset.
    /// @dev hub The address of the associated Hub.
    /// @dev assetId The identifier of the asset in the Hub.
    /// @dev decimals The number of decimals of the underlying asset.
    /// @dev collateralRisk The risk associated with a collateral asset, expressed in BPS.
    /// @dev flags The packed boolean flags of the reserve.
    /// @dev dynamicConfigKey The key of the last reserve dynamic config.
    struct Reserve {
        address underlying;
        address hub;
        uint16 assetId;
        uint8 decimals;
        uint24 collateralRisk;
        uint8 flags;
        uint32 dynamicConfigKey;
    }

    /// @notice Reserve configuration. Subset of the `Reserve` struct.
    /// @dev collateralRisk The risk associated with a collateral asset, expressed in BPS.
    /// @dev paused True if all actions are prevented for the reserve.
    /// @dev frozen True if new activity is prevented for the reserve.
    /// @dev borrowable True if the reserve is borrowable.
    /// @dev receiveSharesEnabled True if the liquidator can receive collateral shares during liquidation.
    struct ReserveConfig {
        uint24 collateralRisk;
        bool paused;
        bool frozen;
        bool borrowable;
        bool receiveSharesEnabled;
    }

    /// @notice Dynamic reserve configuration data.
    /// @dev collateralFactor The proportion of a reserve's value eligible to be used as collateral, expressed in BPS.
    /// @dev maxLiquidationBonus The maximum extra amount of collateral given to the liquidator as bonus, expressed in BPS. 100_00 represents 0.00% bonus.
    /// @dev liquidationFee The protocol fee charged on liquidations, taken from the collateral bonus given to the liquidator, expressed in BPS.
    struct DynamicReserveConfig {
        uint16 collateralFactor;
        uint32 maxLiquidationBonus;
        uint16 liquidationFee;
    }

    /// @notice Liquidation configuration data.
    /// @dev targetHealthFactor The ideal health factor to restore a user position during liquidation, expressed in WAD.
    /// @dev healthFactorForMaxBonus The health factor under which liquidation bonus is maximum, expressed in WAD.
    /// @dev liquidationBonusFactor The value multiplied by `maxLiquidationBonus` to compute the minimum liquidation bonus, expressed in BPS.
    struct LiquidationConfig {
        uint128 targetHealthFactor;
        uint64 healthFactorForMaxBonus;
        uint16 liquidationBonusFactor;
    }

    /// @notice User position data per reserve.
    /// @dev drawnShares The drawn shares of the user position.
    /// @dev premiumShares The premium shares of the user position.
    /// @dev premiumOffsetRay The premium offset of the user position, used to calculate the premium, expressed in asset units and scaled by RAY.
    /// @dev suppliedShares The supplied shares of the user position.
    /// @dev dynamicConfigKey The key of the user position dynamic config.
    struct UserPosition {
        uint120 drawnShares;
        uint120 premiumShares;
        //
        int200 premiumOffsetRay;
        //
        uint120 suppliedShares;
        uint32 dynamicConfigKey;
    }

    /// @notice User account data describing a user position and its health.
    /// @dev riskPremium The risk premium of the user position, expressed in BPS.
    /// @dev avgCollateralFactor The weighted average collateral factor of the user position, expressed in WAD.
    /// @dev healthFactor The health factor of the user position, expressed in WAD. 1e18 represents a health factor of 1.00.
    /// @dev totalCollateralValue The total collateral value of the user position, expressed in units of Value.
    /// @dev totalDebtValueRay The total debt value of the user position, expressed in units of Value and scaled by RAY.
    /// @dev activeCollateralCount The number of active collaterals, which includes reserves with `collateralFactor` > 0, `enabledAsCollateral` and `suppliedAmount` > 0.
    /// @dev borrowCount The number of borrowed reserves of the user position.
    struct UserAccountData {
        uint256 riskPremium;
        uint256 avgCollateralFactor;
        uint256 healthFactor;
        uint256 totalCollateralValue;
        uint256 totalDebtValueRay;
        uint256 activeCollateralCount;
        uint256 borrowCount;
    }

    /// @notice Sub-Intent data to apply position manager update for user.
    /// @param positionManager The address of the position manager.
    /// @param approve True to approve the position manager, false to revoke approval.
    struct PositionManagerUpdate {
        address positionManager;
        bool approve;
    }

    /// @notice Intent data to set user position managers with EIP712-typed signature.
    /// @param onBehalfOf The address of the user on whose behalf position manager can act.
    /// @param updates The array of position manager updates.
    /// @param nonce The nonce for the signature.
    /// @param deadline The deadline for the signature.
    struct SetUserPositionManagers {
        address onBehalfOf;
        PositionManagerUpdate[] updates;
        uint256 nonce;
        uint256 deadline;
    }

    /**
     *
     *
     *
     *          WRITE OPERATIONS
     *
     *
     *
     */
    /// @notice Supplies an amount of underlying asset of the specified reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev The Spoke pulls the underlying asset from the caller, so prior token approval is required.
    /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
    /// @param reserveId The reserve identifier.
    /// @param amount The amount of asset to supply.
    /// @param onBehalfOf The owner of the position to add supply shares to.
    /// @return The amount of shares supplied.
    /// @return The amount of assets supplied.
    function supply(uint256 reserveId, uint256 amount, address onBehalfOf)
        external
        returns (uint256, uint256);

    /// @notice Withdraws a specified amount of underlying asset from the given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
    /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
    /// @dev Caller receives the underlying asset withdrawn.
    /// @param reserveId The identifier of the reserve.
    /// @param amount The amount of asset to withdraw.
    /// @param onBehalfOf The owner of position to remove supply shares from.
    /// @return The amount of shares withdrawn.
    /// @return The amount of assets withdrawn.
    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf)
        external
        returns (uint256, uint256);

    /// @notice Borrows a specified amount of underlying asset from the given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev It reverts if the user would borrow more than the maximum allowed number of borrowed reserves.
    /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
    /// @dev Caller receives the underlying asset borrowed.
    /// @param reserveId The identifier of the reserve.
    /// @param amount The amount of asset to borrow.
    /// @param onBehalfOf The owner of the position against which debt is generated.
    /// @return The amount of shares borrowed.
    /// @return The amount of assets borrowed.
    function borrow(uint256 reserveId, uint256 amount, address onBehalfOf)
        external
        returns (uint256, uint256);

    /// @notice Repays a specified amount of underlying asset to a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev The Spoke pulls the underlying asset from the caller, so prior approval is required.
    /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
    /// @param reserveId The identifier of the reserve.
    /// @param amount The amount of asset to repay.
    /// @param onBehalfOf The owner of the position whose debt is repaid.
    /// @return The amount of shares repaid.
    /// @return The amount of assets repaid.
    function repay(uint256 reserveId, uint256 amount, address onBehalfOf)
        external
        returns (uint256, uint256);

    /// @notice Allows suppliers to enable/disable a specific supplied reserve as collateral.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev It reverts if the user exceeds the maximum allowed collateral reserves when enabling.
    /// @dev Reserves with zero supplied or zero collateral factor count towards the max allowed collateral reserves.
    /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
    /// @param reserveId The reserve identifier of the underlying asset.
    /// @param usingAsCollateral True if the user wants to use the supply as collateral.
    /// @param onBehalfOf The owner of the position being modified.
    function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral, address onBehalfOf)
        external;

    /// @notice Allows updating the risk premium on onBehalfOf position.
    /// @dev Caller must be `onBehalfOf`, an authorized position manager for `onBehalfOf`, or admin.
    /// @param onBehalfOf The owner of the position being modified.
    function updateUserRiskPremium(address onBehalfOf) external;

    /// @notice Allows updating the dynamic configuration for all collateral reserves on onBehalfOf position.
    /// @dev Caller must be `onBehalfOf`, an authorized position manager for `onBehalfOf`, or admin.
    /// @param onBehalfOf The owner of the position being modified.
    function updateUserDynamicConfig(address onBehalfOf) external;

    /// @notice Enables a user to grant or revoke approval for a position manager.
    /// @dev Allows approving inactive position managers.
    /// @param positionManager The address of the position manager.
    /// @param approve True to approve the position manager, false to revoke approval.
    function setUserPositionManager(address positionManager, bool approve) external;

    /// @notice Enables a user to grant or revoke approval for an array of position managers using an EIP712-typed intent.
    /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
    /// @dev Allows duplicated updates and the last one is persisted. Allows approving inactive position managers.
    /// @param params The structured setUserPositionManagers parameter.
    /// @param signature The EIP712-compliant signature bytes.
    function setUserPositionManagersWithSig(
        SetUserPositionManagers calldata params,
        bytes calldata signature
    ) external;

    /// @notice Allows position manager (as caller) to renounce their approval given by the user.
    /// @param user The address of the user.
    function renouncePositionManagerRole(address user) external;

    /// @notice Allows consuming a permit signature for the given reserve's underlying asset.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev The Spoke must be configured as the spender.
    /// @param reserveId The identifier of the reserve.
    /// @param onBehalfOf The address of the user on whose behalf the permit is being used.
    /// @param value The amount of the underlying asset to permit.
    /// @param deadline The deadline for the permit.
    function permitReserve(
        uint256 reserveId,
        address onBehalfOf,
        uint256 value,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;

    /// @notice Call multiple functions in the current contract and return the data from each if they all succeed.
    /// @param data The encoded function data for each of the calls to make to this contract.
    /// @return results The results from each of the calls passed in via data.
    function multicall(bytes[] calldata data) external returns (bytes[] memory);

    /**
     *
     *
     *
     *          READ OPERATIONS
     *
     *
     *
     */
    /// @notice Returns the total amount of supplied assets of a given reserve.
    /// @param reserveId The identifier of the reserve.
    /// @return The amount of supplied assets.
    function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256);

    /// @notice Returns the total amount of supplied shares of a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @return The amount of supplied shares.
    function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256);

    /// @notice Returns the debt of a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev The total debt of the reserve is the sum of drawn debt and premium debt.
    /// @param reserveId The identifier of the reserve.
    /// @return The amount of drawn debt.
    /// @return The amount of premium debt.
    function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

    /// @notice Returns the total debt of a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev The total debt of the reserve is the sum of drawn debt and premium debt.
    /// @param reserveId The identifier of the reserve.
    /// @return The total debt amount.
    function getReserveTotalDebt(uint256 reserveId) external view returns (uint256);

    /// @notice Returns the amount of assets supplied by a specific user for a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @return The amount of assets supplied by the user.
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);

    /// @notice Returns the amount of shares supplied by a specific user for a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @return The amount of shares supplied by the user.
    function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256);

    /// @notice Returns the debt of a specific user for a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev The total debt of the user is the sum of drawn debt and premium debt.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @return The amount of drawn debt.
    /// @return The amount of premium debt.
    function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);

    /// @notice Returns the total debt of a specific user for a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev The total debt of the user is the sum of drawn debt and premium debt.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @return The total debt amount.
    function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

    /// @notice Returns the full precision premium debt of a specific user for a given reserve.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @return The amount of premium debt, expressed in asset units and scaled by RAY.
    function getUserPremiumDebtRay(uint256 reserveId, address user) external view returns (uint256);

    /// @notice Returns the liquidation config struct.
    function getLiquidationConfig() external view returns (LiquidationConfig memory);

    /// @notice Returns the number of listed reserves on the spoke.
    /// @dev Count includes reserves that are not currently active.
    function getReserveCount() external view returns (uint256);

    /// @notice Returns the reserve identifier for a given assetId in a Hub.
    /// @dev It reverts if no reserve is associated with the given assetId.
    /// @param hub The address of the Hub.
    /// @param assetId The identifier of the asset on the Hub.
    /// @return The identifier of the reserve.
    function getReserveId(address hub, uint256 assetId) external view returns (uint256);

    /// @notice Returns the reserve struct data in storage.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @return The reserve struct.
    function getReserve(uint256 reserveId) external view returns (Reserve memory);

    /// @notice Returns the reserve configuration struct data in storage.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @return The reserve configuration struct.
    function getReserveConfig(uint256 reserveId) external view returns (ReserveConfig memory);

    /// @notice Returns the dynamic reserve configuration struct at the specified key.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev Does not revert if `dynamicConfigKey` is unset.
    /// @param reserveId The identifier of the reserve.
    /// @param dynamicConfigKey The key of the dynamic config.
    /// @return The dynamic reserve configuration struct.
    function getDynamicReserveConfig(uint256 reserveId, uint32 dynamicConfigKey)
        external
        view
        returns (DynamicReserveConfig memory);

    /// @notice Returns two flags indicating whether the reserve is used as collateral and whether it is borrowed by the user.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @dev Even if enabled as collateral, it will only count towards user position if the collateral factor is greater than 0.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @return True if the reserve is enabled as collateral by the user.
    /// @return True if the reserve is borrowed by the user.
    function getUserReserveStatus(uint256 reserveId, address user)
        external
        view
        returns (bool, bool);

    /// @notice Returns the user position struct in storage.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @return The user position struct.
    function getUserPosition(uint256 reserveId, address user)
        external
        view
        returns (UserPosition memory);

    /// @notice Returns the most up-to-date user account data information.
    /// @dev Utilizes user's current dynamic configuration of user position.
    /// @param user The address of the user.
    /// @return The user account data struct.
    function getUserAccountData(address user) external view returns (UserAccountData memory);

    /// @notice Returns the risk premium from the user's last position update.
    /// @param user The address of the user.
    /// @return The risk premium of the user from the last position update, expressed in BPS.
    function getUserLastRiskPremium(address user) external view returns (uint256);

    /// @notice Returns the liquidation bonus for a given health factor, based on the user's current dynamic configuration.
    /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
    /// @param reserveId The identifier of the reserve.
    /// @param user The address of the user.
    /// @param healthFactor The health factor of the user.
    function getLiquidationBonus(uint256 reserveId, address user, uint256 healthFactor)
        external
        view
        returns (uint256);

    /// @notice Returns whether positionManager is currently activated by governance.
    /// @param positionManager The address of the position manager.
    /// @return True if positionManager is currently active.
    function isPositionManagerActive(address positionManager) external view returns (bool);

    /// @notice Returns whether positionManager is active and approved by user.
    /// @param user The address of the user.
    /// @param positionManager The address of the position manager.
    /// @return True if positionManager is active and approved by user.
    function isPositionManager(address user, address positionManager) external view returns (bool);

    /// @notice Returns the address of the AaveOracle contract.
    function ORACLE() external view returns (address);

    /// @notice Returns the maximum allowed number of collateral and borrow reserves per user (each counted separately).
    function MAX_USER_RESERVES_LIMIT() external view returns (uint16);

    /// @notice Returns the EIP-712 domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Returns the type hash for the SetUserPositionManagers intent.
    /// @return The bytes-encoded EIP-712 struct hash representing the intent.
    function SET_USER_POSITION_MANAGERS_TYPEHASH() external view returns (bytes32);

    /// @notice Allows caller to revoke their next sequential nonce at specified `key`.
    /// @dev This does not invalidate nonce at other `key`s namespace.
    /// @param key The key which specifies namespace of the nonce.
    /// @return keyNonce The revoked key-prefixed nonce.
    function useNonce(uint192 key) external returns (uint256 keyNonce);

    /// @notice Returns the next unused nonce for an address and key. Result contains the key prefix.
    /// @param owner The address of the nonce owner.
    /// @param key The key which specifies namespace of the nonce.
    /// @return keyNonce The first 24 bytes are for the key, & the last 8 bytes for the nonce.
    function nonces(address owner, uint192 key) external view returns (uint256 keyNonce);

    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}







contract MainnetTriggerAddresses {
    address public constant UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public constant MCD_PRICE_VERIFIER = 0xeAa474cbFFA87Ae0F1a6f68a3aBA6C77C656F72c;
    address public constant TRANSIENT_STORAGE = 0x2F7Ef2ea5E8c97B8687CA703A0e50Aa5a49B7eb2;
    address public constant TRANSIENT_STORAGE_CANCUN = 0x0304E27cccE28bAB4d78C6cb7AfD4cd01c87c1e4;
}







contract TriggerHelper is MainnetTriggerAddresses { }















contract AaveV4QuotePriceRangeTrigger is ITrigger, AdminAuth, TriggerHelper {
    /// @dev Expected subbed price scale.
    uint256 public constant PRICE_SCALE = 1e18;

    /// @param spoke Address of the spoke.
    /// @param baseTokenId Reserve id of the base token which is quoted.
    /// @param quoteTokenId Reserve id of the quote token.
    /// @param lowerPrice Lower price of the base token in terms of the quote token that represents the triggerable point.
    /// @param upperPrice Upper price of the base token in terms of the quote token that represents the triggerable point.
    struct SubParams {
        address spoke;
        uint256 baseTokenId;
        uint256 quoteTokenId;
        uint256 lowerPrice;
        uint256 upperPrice;
    }

    /// @notice Function that determines whether to trigger based on current token price ratio for aaveV4 spoke.
    /// @param _subData Encoded subscription data.
    /// @return triggered Whether to trigger or not.
    function isTriggered(bytes memory, bytes memory _subData)
        public
        view
        override
        returns (bool triggered)
    {
        SubParams memory sub = parseSubInputs(_subData);
        uint256 currPrice = getPrice(sub.spoke, sub.baseTokenId, sub.quoteTokenId);

        // Only check lowerPrice if upperPrice is not set.
        if (sub.upperPrice == 0) return currPrice < sub.lowerPrice;

        triggered = currPrice < sub.lowerPrice || currPrice > sub.upperPrice;
    }

    /// @notice Function that returns current token price ratio for aaveV4 spoke.
    /// @param _spoke Address of the spoke.
    /// @param _baseTokenId Reserve id of the base token which is quoted.
    /// @param _quoteTokenId Reserve id of the quote token.
    /// @return price Current token price ratio for aaveV4 spoke.
    function getPrice(address _spoke, uint256 _baseTokenId, uint256 _quoteTokenId)
        public
        view
        returns (uint256 price)
    {
        IAaveV4Oracle oracle = IAaveV4Oracle(ISpoke(_spoke).ORACLE());

        uint256[] memory reserveIds = new uint256[](2);
        reserveIds[0] = _baseTokenId;
        reserveIds[1] = _quoteTokenId;
        uint256[] memory prices = oracle.getReservesPrices(reserveIds);

        price = prices[0] * PRICE_SCALE / prices[1];
    }

    function changedSubData(bytes memory _subData) public pure override returns (bytes memory) { }

    function isChangeable() public pure override returns (bool) {
        return false;
    }

    function parseSubInputs(bytes memory _callData) public pure returns (SubParams memory params) {
        params = abi.decode(_callData, (SubParams));
    }
}