// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;









contract MainnetAaveV4Addresses {
    address internal constant GIVER_POSITION_MANAGER = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e;
    address internal constant TAKER_POSITION_MANAGER = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7;
    address internal constant CONFIG_POSITION_MANAGER = 0x51305839CE822a7b4b12AA7D86eA7005052d575c;
}






contract AaveV4Helper is MainnetAaveV4Addresses { }











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






interface IConfigPositionManager {
    /// @notice Struct to hold the config permission values.
    /// @dev canSetUsingAsCollateral Whether the delegatee can set using as collateral on behalf of the user.
    /// @dev canUpdateUserRiskPremium Whether the delegatee can update user risk premium on behalf of the user.
    /// @dev canUpdateUserDynamicConfig Whether the delegatee can update user dynamic config on behalf of the user.
    struct ConfigPermissionValues {
        bool canSetUsingAsCollateral;
        bool canUpdateUserRiskPremium;
        bool canUpdateUserDynamicConfig;
    }

    /// @notice Structured parameters for using as collateral permission permit intent.
    /// @dev spoke The address of the Spoke.
    /// @dev delegator The address of the delegator.
    /// @dev delegatee The address of the delegatee.
    /// @dev permission The new permission status.
    /// @dev nonce The key-prefixed nonce for the signature.
    /// @dev deadline The deadline for the intent.
    struct SetCanSetUsingAsCollateralPermissionPermit {
        address spoke;
        address delegator;
        address delegatee;
        bool permission;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Sets the user risk premium permission for a delegatee.
    /// @param spoke The address of the spoke.
    /// @param delegatee The address of the delegatee.
    /// @param permission The new permission status.
    function setCanUpdateUserRiskPremiumPermission(
        address spoke,
        address delegatee,
        bool permission
    ) external;

    /// @notice Sets the user dynamic config permission for a delegatee.
    /// @param spoke The address of the spoke.
    /// @param delegatee The address of the delegatee.
    /// @param permission The new permission status.
    function setCanUpdateUserDynamicConfigPermission(
        address spoke,
        address delegatee,
        bool permission
    ) external;

    /// @notice Sets the using as collateral permission for a delegatee.
    /// @param spoke The address of the spoke.
    /// @param delegatee The address of the delegatee.
    /// @param permission The new permission status.
    function setCanSetUsingAsCollateralPermission(
        address spoke,
        address delegatee,
        bool permission
    ) external;

    /// @notice Sets the using as collateral status on behalf of a user for a specified reserve.
    /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
    /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
    /// @param spoke The address of the spoke.
    /// @param reserveId The id of the reserve.
    /// @param usingAsCollateral The new using as collateral status.
    /// @param onBehalfOf The address of the user.
    function setUsingAsCollateralOnBehalfOf(
        address spoke,
        uint256 reserveId,
        bool usingAsCollateral,
        address onBehalfOf
    ) external;

    /// @notice Updates the user risk premium on behalf of a user.
    /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
    /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
    /// @param spoke The address of the spoke.
    /// @param onBehalfOf The address of the user.
    function updateUserRiskPremiumOnBehalfOf(address spoke, address onBehalfOf) external;

    /// @notice Updates the user dynamic config on behalf of a user.
    /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
    /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
    /// @param spoke The address of the spoke.
    /// @param onBehalfOf The address of the user.
    function updateUserDynamicConfigOnBehalfOf(address spoke, address onBehalfOf) external;

    /// @notice Returns the config permissions for a delegatee on behalf of a user.
    /// @param spoke The address of the spoke.
    /// @param delegatee The address of the delegatee.
    /// @param onBehalfOf The address of the user.
    /// @return The ConfigPermissionValues for the delegatee on behalf of the user.
    function getConfigPermissions(address spoke, address delegatee, address onBehalfOf)
        external
        view
        returns (ConfigPermissionValues memory);

    /// @notice Sets the using as collateral permission for a delegatee using an EIP712-typed intent.
    /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
    /// @param params The structured SetCanSetUsingAsCollateralPermissionPermit parameters.
    /// @param signature The EIP712-compliant signature bytes.
    function setCanSetUsingAsCollateralPermissionWithSig(
        SetCanSetUsingAsCollateralPermissionPermit calldata params,
        bytes calldata signature
    ) external;

    /// @notice Returns the EIP-712 domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Returns the type hash for the SetCanSetUsingAsCollateralPermissionPermit intent.
    function SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH()
        external
        view
        returns (bytes32);

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










interface IHub {
    /**
     *
     *
     *
     *          DATA SPECIFICATION
     *
     *
     *
     */
    /// @notice Asset position and configuration data.
    /// @dev liquidity The liquidity available to be accessed, expressed in asset units.
    /// @dev realizedFees The amount of fees realized but not yet minted, expressed in asset units.
    /// @dev decimals The number of decimals of the underlying asset.
    /// @dev addedShares The total shares added across all spokes.
    /// @dev swept The outstanding liquidity which has been invested by the reinvestment controller, expressed in asset units.
    /// @dev premiumOffsetRay The total premium offset across all spokes, used to calculate the premium, expressed in asset units and scaled by RAY.
    /// @dev drawnShares The total drawn shares across all spokes.
    /// @dev premiumShares The total premium shares across all spokes.
    /// @dev liquidityFee The protocol fee charged on drawn and premium liquidity growth, expressed in BPS.
    /// @dev drawnIndex The drawn index which monotonically increases according to the drawn rate, expressed in RAY.
    /// @dev drawnRate The rate at which drawn assets grow, expressed in RAY.
    /// @dev lastUpdateTimestamp The timestamp of the last accrual.
    /// @dev underlying The address of the underlying asset.
    /// @dev irStrategy The address of the interest rate strategy.
    /// @dev reinvestmentController The address of the reinvestment controller.
    /// @dev feeReceiver The address of the fee receiver spoke.
    /// @dev deficitRay The amount of outstanding bad debt across all spokes, expressed in asset units and scaled by RAY.
    struct Asset {
        uint120 liquidity;
        uint120 realizedFees;
        uint8 decimals;
        //
        uint120 addedShares;
        uint120 swept;
        //
        int200 premiumOffsetRay;
        //
        uint120 drawnShares;
        uint120 premiumShares;
        uint16 liquidityFee;
        //
        uint120 drawnIndex;
        uint96 drawnRate;
        uint40 lastUpdateTimestamp;
        //
        address underlying;
        //
        address irStrategy;
        //
        address reinvestmentController;
        //
        address feeReceiver;
        //
        uint200 deficitRay;
    }

    /// @notice Asset configuration. Subset of the `Asset` struct.
    struct AssetConfig {
        address feeReceiver;
        uint16 liquidityFee;
        address irStrategy;
        address reinvestmentController;
    }

    /// @notice Spoke position and configuration data.
    /// @dev drawnShares The drawn shares of a spoke for a given asset.
    /// @dev premiumShares The premium shares of a spoke for a given asset.
    /// @dev premiumOffsetRay The premium offset of a spoke for a given asset, used to calculate the premium, expressed in asset units and scaled by RAY.
    /// @dev addedShares The added shares of a spoke for a given asset.
    /// @dev addCap The maximum amount that can be added by a spoke, expressed in whole assets (not scaled by decimals). A value of `MAX_ALLOWED_SPOKE_CAP` indicates no cap.
    /// @dev drawCap The maximum amount that can be drawn by a spoke, expressed in whole assets (not scaled by decimals). A value of `MAX_ALLOWED_SPOKE_CAP` indicates no cap.
    /// @dev riskPremiumThreshold The maximum ratio of premium to drawn shares a spoke can have, expressed in BPS. A value of `MAX_RISK_PREMIUM_THRESHOLD` indicates no threshold.
    /// @dev active False if the spoke is prevented from performing any actions.
    /// @dev halted True if the spoke is prevented from performing any user-facing actions.
    /// @dev deficitRay The deficit reported by a spoke for a given asset, expressed in asset units and scaled by RAY.
    struct SpokeData {
        uint120 drawnShares;
        uint120 premiumShares;
        //
        int200 premiumOffsetRay;
        //
        uint120 addedShares;
        uint40 addCap;
        uint40 drawCap;
        uint24 riskPremiumThreshold;
        bool active;
        bool halted;
        //
        uint200 deficitRay;
    }

    /// @notice Spoke configuration data. Subset of the `SpokeData` struct.
    struct SpokeConfig {
        uint40 addCap;
        uint40 drawCap;
        uint24 riskPremiumThreshold;
        bool active;
        bool halted;
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
    /// @notice Updates the configuration of a spoke for a specific asset.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke to update.
    /// @param config The new configuration for the spoke.
    function updateSpokeConfig(uint256 assetId, address spoke, SpokeConfig calldata config) external;

    /**
     *
     *
     *
     *          READ OPERATIONS
     *
     *
     *
     */
    /// @notice Converts the specified amount of assets to shares upon an `add` action.
    /// @dev Rounds down to the nearest shares amount.
    /// @param assetId The identifier of the asset.
    /// @param assets The amount of assets to convert to shares amount.
    /// @return The amount of shares converted from assets amount.
    function previewAddByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

    /// @notice Converts the specified shares amount to assets amount added upon an `add` action.
    /// @dev Rounds up to the nearest assets amount.
    /// @param assetId The identifier of the asset.
    /// @param shares The amount of shares to convert to assets amount.
    /// @return The amount of assets converted from shares amount.
    function previewAddByShares(uint256 assetId, uint256 shares) external view returns (uint256);

    /// @notice Converts the specified amount of assets to shares amount removed upon a `remove` action.
    /// @dev Rounds up to the nearest shares amount.
    /// @param assetId The identifier of the asset.
    /// @param assets The amount of assets to convert to shares amount.
    /// @return The amount of shares converted from assets amount.
    function previewRemoveByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

    /// @notice Converts the specified amount of shares to assets amount removed upon a `remove` action.
    /// @dev Rounds down to the nearest assets amount.
    /// @param assetId The identifier of the asset.
    /// @param shares The amount of shares to convert to assets amount.
    /// @return The amount of assets converted from shares amount.
    function previewRemoveByShares(uint256 assetId, uint256 shares) external view returns (uint256);

    /// @notice Converts the specified amount of assets to shares amount drawn upon a `draw` action.
    /// @dev Rounds up to the nearest shares amount.
    /// @param assetId The identifier of the asset.
    /// @param assets The amount of assets to convert to shares amount.
    /// @return The amount of shares converted from assets amount.
    function previewDrawByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

    /// @notice Converts the specified amount of shares to assets amount drawn upon a `draw` action.
    /// @dev Rounds down to the nearest assets amount.
    /// @param assetId The identifier of the asset.
    /// @param shares The amount of shares to convert to assets amount.
    /// @return The amount of assets converted from shares amount.
    function previewDrawByShares(uint256 assetId, uint256 shares) external view returns (uint256);

    /// @notice Converts the specified amount of assets to shares amount restored upon a `restore` action.
    /// @dev Rounds down to the nearest shares amount.
    /// @param assetId The identifier of the asset.
    /// @param assets The amount of assets to convert to shares amount.
    /// @return The amount of shares converted from assets amount.
    function previewRestoreByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

    /// @notice Converts the specified amount of shares to assets amount restored upon a `restore` action.
    /// @dev Rounds up to the nearest assets amount.
    /// @param assetId The identifier of the asset.
    /// @param shares The amount of drawn shares to convert to assets amount.
    /// @return The amount of assets converted from shares amount.
    function previewRestoreByShares(uint256 assetId, uint256 shares) external view returns (uint256);

    /// @notice Returns the underlying address and decimals of the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The underlying address of the asset.
    /// @return The decimals of the asset.
    function getAssetUnderlyingAndDecimals(uint256 assetId) external view returns (address, uint8);

    /// @notice Calculates the current drawn index for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The current drawn index of the asset.
    function getAssetDrawnIndex(uint256 assetId) external view returns (uint256);

    /// @notice Returns the total amount of the specified asset added to the Hub.
    /// @param assetId The identifier of the asset.
    /// @return The amount of the asset added.
    function getAddedAssets(uint256 assetId) external view returns (uint256);

    /// @notice Returns the total amount of shares of the specified asset added to the Hub.
    /// @param assetId The identifier of the asset.
    /// @return The amount of shares of the asset added.
    function getAddedShares(uint256 assetId) external view returns (uint256);

    /// @notice Returns the amount of owed drawn and premium assets for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The amount of owed drawn assets.
    /// @return The amount of owed premium assets.
    function getAssetOwed(uint256 assetId) external view returns (uint256, uint256);

    /// @notice Returns the total amount of assets owed to the Hub.
    /// @param assetId The identifier of the asset.
    /// @return The total amount of the assets owed.
    function getAssetTotalOwed(uint256 assetId) external view returns (uint256);

    /// @notice Returns the amount of owed premium with full precision for specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The amount of premium owed, expressed in asset units and scaled by RAY.
    function getAssetPremiumRay(uint256 assetId) external view returns (uint256);

    /// @notice Returns the amount of drawn shares of the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The amount of drawn shares.
    function getAssetDrawnShares(uint256 assetId) external view returns (uint256);

    /// @notice Returns the information regarding premium shares of the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The amount of premium shares owed to the asset.
    /// @return The premium offset of the asset, expressed in asset units and scaled by RAY.
    function getAssetPremiumData(uint256 assetId) external view returns (uint256, int256);

    /// @notice Returns the amount of available liquidity for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The amount of available liquidity.
    function getAssetLiquidity(uint256 assetId) external view returns (uint256);

    /// @notice Returns the amount of deficit with full precision of the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The amount of deficit, expressed in asset units and scaled by RAY.
    function getAssetDeficitRay(uint256 assetId) external view returns (uint256);

    /// @notice Returns the total amount of the specified assets added to the Hub by the specified spoke.
    /// @dev If spoke is `asset.feeReceiver`, includes converted `unrealizedFeeShares` in return value.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The amount of added assets.
    function getSpokeAddedAssets(uint256 assetId, address spoke) external view returns (uint256);

    /// @notice Returns the total amount of shares of the specified asset added to the Hub by the specified spoke.
    /// @dev If spoke is `asset.feeReceiver`, includes `unrealizedFeeShares` in return value.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The amount of added shares.
    function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256);

    /// @notice Returns the amount of the specified assets owed to the Hub by the specified spoke.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The amount of owed drawn assets.
    /// @return The amount of owed premium assets.
    function getSpokeOwed(uint256 assetId, address spoke) external view returns (uint256, uint256);

    /// @notice Returns the total amount of the specified asset owed to the Hub by the specified spoke.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The total amount of the asset owed.
    function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256);

    /// @notice Returns the amount of owed premium with full precision for specified asset and spoke.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The amount of owed premium assets, expressed in asset units and scaled by RAY.
    function getSpokePremiumRay(uint256 assetId, address spoke) external view returns (uint256);

    /// @notice Returns the amount of drawn shares of the specified asset by the specified spoke.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The amount of drawn shares.
    function getSpokeDrawnShares(uint256 assetId, address spoke) external view returns (uint256);

    /// @notice Returns the information regarding premium shares of the specified asset for the specified spoke.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The amount of premium shares.
    /// @return The premium offset, expressed in asset units and scaled by RAY.
    function getSpokePremiumData(uint256 assetId, address spoke)
        external
        view
        returns (uint256, int256);

    /// @notice Returns whether the underlying is listed as an asset.
    /// @param underlying The address of the underlying asset.
    /// @return True if the underlying asset is listed.
    function isUnderlyingListed(address underlying) external view returns (bool);

    /// @notice Returns the asset identifier for the specified underlying asset.
    /// @dev Reverts with `AssetNotListed` if the underlying is not listed.
    /// @param underlying The address of the underlying asset.
    /// @return The `assetId` of the underlying asset.
    function getAssetId(address underlying) external view returns (uint256);

    /// @notice Returns the number of listed assets.
    /// @return The number of listed assets.
    function getAssetCount() external view returns (uint256);

    /// @notice Returns information regarding the specified asset.
    /// @dev `drawnIndex`, `drawnRate` and `lastUpdateTimestamp` can be outdated due to passage of time.
    /// @param assetId The identifier of the asset.
    /// @return The asset struct.
    function getAsset(uint256 assetId) external view returns (Asset memory);

    /// @notice Returns the asset configuration for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The asset configuration struct.
    function getAssetConfig(uint256 assetId) external view returns (AssetConfig memory);

    /// @notice Returns the accrued fees for the asset, expressed in asset units.
    /// @dev Accrued fees are excluded from total added assets.
    /// @param assetId The identifier of the asset.
    /// @return The amount of accrued fees.
    function getAssetAccruedFees(uint256 assetId) external view returns (uint256);

    /// @notice Returns the amount of liquidity swept by the reinvestment controller for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The amount of liquidity swept.
    function getAssetSwept(uint256 assetId) external view returns (uint256);

    /// @notice Calculates the current drawn rate for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The current drawn rate of the asset.
    function getAssetDrawnRate(uint256 assetId) external view returns (uint256);

    /// @notice Returns the number of spokes listed for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @return The number of spokes.
    function getSpokeCount(uint256 assetId) external view returns (uint256);

    /// @notice Returns whether the spoke is listed for the specified asset.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return True if the spoke is listed.
    function isSpokeListed(uint256 assetId, address spoke) external view returns (bool);

    /// @notice Returns the address of the spoke for an asset at the given index.
    /// @param assetId The identifier of the asset.
    /// @param index The index of the spoke.
    /// @return The address of the spoke.
    function getSpokeAddress(uint256 assetId, uint256 index) external view returns (address);

    /// @notice Returns the spoke data struct.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The spoke data struct.
    function getSpoke(uint256 assetId, address spoke) external view returns (SpokeData memory);

    /// @notice Returns the spoke configuration struct.
    /// @param assetId The identifier of the asset.
    /// @param spoke The address of the spoke.
    /// @return The spoke configuration struct.
    function getSpokeConfig(uint256 assetId, address spoke)
        external
        view
        returns (SpokeConfig memory);

    /// @notice Returns the maximum allowed number of decimals for the underlying asset.
    /// @return The maximum number of decimals (inclusive).
    function MAX_ALLOWED_UNDERLYING_DECIMALS() external view returns (uint8);

    /// @notice Returns the minimum allowed number of decimals for the underlying asset.
    /// @return The minimum number of decimals (inclusive).
    function MIN_ALLOWED_UNDERLYING_DECIMALS() external view returns (uint8);

    /// @notice Returns the maximum value for any spoke cap (add or draw).
    /// @dev The value is not inclusive; using the maximum value indicates no cap.
    /// @return The maximum cap value, expressed in asset units.
    function MAX_ALLOWED_SPOKE_CAP() external view returns (uint40);

    /// @notice Returns the maximum value for any spoke risk premium threshold.
    /// @dev The value is not inclusive; using the maximum value indicates no threshold.
    /// @return The maximum risk premium threshold, expressed in BPS.
    function MAX_RISK_PREMIUM_THRESHOLD() external view returns (uint24);

    /// @notice Returns the current authority.
    function authority() external view returns (address);
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






interface ITakerPositionManager {
    /// @notice Structured parameters for withdraw permit intent.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param amount The amount of allowance.
    /// @param nonce The key-prefixed nonce for the signature.
    /// @param deadline The deadline for the intent.
    struct WithdrawPermit {
        address spoke;
        uint256 reserveId;
        address owner;
        address spender;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Structured parameters for borrow permit intent.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param amount The amount of allowance.
    /// @param nonce The key-prefixed nonce for the signature.
    /// @param deadline The deadline for the intent.
    struct BorrowPermit {
        address spoke;
        uint256 reserveId;
        address owner;
        address spender;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Executes a supply on behalf of a user.
    /// @notice Approves a spender to withdraw assets from the specified reserve.
    /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param spender The address of the spender to receive the allowance.
    /// @param amount The amount of allowance.
    function approveWithdraw(address spoke, uint256 reserveId, address spender, uint256 amount)
        external;

    /// @notice Approves a borrow allowance for a spender.
    /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param spender The address of the spender to receive the allowance.
    /// @param amount The amount of allowance.
    function approveBorrow(address spoke, uint256 reserveId, address spender, uint256 amount)
        external;

    /// @notice Executes a withdraw on behalf of a user.
    /// @dev The caller must have sufficient withdraw allowance from onBehalfOf.
    /// @dev The caller receives the withdrawn assets.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param amount The amount to withdraw.
    /// @param onBehalfOf The address of the user to withdraw on behalf of.
    /// @return The amount of shares withdrawn.
    /// @return The amount of assets withdrawn.
    function withdrawOnBehalfOf(
        address spoke,
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256, uint256);

    /// @notice Executes a borrow on behalf of a user.
    /// @dev The caller must have sufficient borrow allowance from onBehalfOf.
    /// @dev The caller receives the borrowed assets.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param amount The amount to borrow.
    /// @param onBehalfOf The address of the user to borrow on behalf of.
    /// @return The amount of shares borrowed.
    /// @return The amount of assets borrowed.
    function borrowOnBehalfOf(address spoke, uint256 reserveId, uint256 amount, address onBehalfOf)
        external
        returns (uint256, uint256);

    /// @notice Returns the withdraw allowance for a spender on behalf of an owner.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @return The amount of withdraw allowance.
    function withdrawAllowance(address spoke, uint256 reserveId, address owner, address spender)
        external
        view
        returns (uint256);

    /// @notice Returns the credit delegation allowance for a spender on behalf of an owner.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @return The amount of credit delegation allowance.
    function borrowAllowance(address spoke, uint256 reserveId, address owner, address spender)
        external
        view
        returns (uint256);

    /// @notice Approves a spender to borrow from the specified reserve using an EIP712-typed intent.
    /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
    /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
    /// @param params The structured BorrowPermit parameters.
    /// @param signature The EIP712-compliant signature bytes.
    function approveBorrowWithSig(BorrowPermit calldata params, bytes calldata signature) external;

    /// @notice Approves a spender to withdraw from the specified reserve using an EIP712-typed intent.
    /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
    /// @dev Using `type(uint256).max` as the amount results in an infinite approval, so the allowance is never decreased.
    /// @param params The structured WithdrawPermit parameters.
    /// @param signature The EIP712-compliant signature bytes.
    function approveWithdrawWithSig(WithdrawPermit calldata params, bytes calldata signature)
        external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);

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






interface ITokenizationSpoke {
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function hub() external view returns (address);
    function assetId() external view returns (uint256);
    function asset() external view returns (address);
    function decimals() external view returns (uint8);
    function maxDeposit(address) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
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














contract AaveV4View is AaveV4Helper {
    /**
     *
     *
     *
     *          DATA SPECIFICATION
     *
     *
     *
     */
    /// @notice User reserve data.
    struct UserReserveData {
        uint256 reserveId; // The identifier of the reserve. Doesn't have to match the assetId in the Hub.
        uint16 assetId; // The identifier of the asset in the Hub.
        address underlying; // The address of the underlying asset.
        uint256 supplied; // The amount of supplied assets, expressed in asset units.
        uint256 drawn; // The amount of user-drawn assets, expressed in asset units.
        uint256 premium; // The amount of user-premium assets, expressed in asset units.
        uint256 totalDebt; // The total amount of user-debt (drawn + premium), expressed in asset units.
        uint16 collateralFactor; // The collateral factor of the reserve, expressed in BPS. (E.g 8500 = 85%).
        uint32 maxLiquidationBonus; // The maximum extra amount of collateral given to the liquidator as bonus, expressed in BPS. 10000 represents 0.00% bonus. E.g 10500 = 5% bonus.
        uint16 liquidationFee; // The protocol fee charged on liquidations, taken from the collateral bonus given to the liquidator, expressed in BPS. (E.g 1000 = 10%)
        bool isUsingAsCollateral; // True if the reserve is being used as collateral.
        bool isBorrowing; // True if the reserve is being borrowed.
    }

    /// @notice Loan data with reserves data.
    struct LoanData {
        address user; // The address of the user.
        uint256 riskPremium; // The risk premium of the user position, expressed in BPS.
        uint256 avgCollateralFactor; // The weighted average collateral factor of the user position, expressed in WAD.
        uint256 healthFactor; // The health factor of the user position, expressed in WAD. 1e18 represents a health factor of 1.00.
        uint256 totalCollateralInUsd; // The total collateral value of the user position, expressed in units of base currency. 1e26 represents 1 USD.
        uint256 totalDebtInUsdRay; // The total debt value of the user position, expressed in units of base currency and scaled by RAY. 1e26 represents 1 USD.
        uint256 activeCollateralCount; // The number of active collateral reserves.
        uint256 borrowCount; // The number of borrowed reserves.
        UserReserveData[] reserves; // The user's reserve data.
    }

    /// @notice Same as regular UserReserveData, but with full reserve data
    struct UserReserveDataFull {
        uint256 reserveId; // The identifier of the reserve. Doesn't have to match the assetId in the Hub.
        address underlying; // The address of the underlying asset.
        uint256 price; // The price of the underlying asset, expressed in oracle decimals.
        uint8 decimals; // The number of decimals of the underlying asset.
        // --------------------------
        bool isUsingAsCollateral; // True if the reserve is being used as collateral.
        bool isBorrowing; // True if the reserve is being borrowed.
        bool reservePaused; // True if the reserve is paused for given spoke.
        bool reserveFrozen; // True if the reserve is frozen for given spoke.
        bool borrowable; // True if the reserve is borrowable.
        bool spokeActive; // True if the spoke is active for this reserve and hub.
        bool spokeHalted; // True if the spoke is halted for this reserve and hub.
        // --------------------------
        uint256 userSupplied; // The amount of user-supplied assets, expressed in asset units.
        uint256 userDrawn; // The amount of user-drawn assets, expressed in asset units.
        uint256 userPremium; // The amount of user-premium assets, expressed in asset units.
        uint256 userTotalDebt; // The total amount of user-debt (drawn + premium), expressed in asset units.
        // --------------------------
        uint24 collateralRisk; // The risk associated with a collateral asset, expressed in BPS. (E.g 1500 = 15%). This is global for spoke and reserveId.
        // --------------------------
        // This uses user dynamic config key
        uint16 userCollateralFactor; // The collateral factor of the user position, expressed in BPS. (E.g 8500 = 85%).
        uint32 userMaxLiquidationBonus; // The maximum extra amount of collateral given to the liquidator as bonus, expressed in BPS. 10000 represents 0.00% bonus. E.g 10500 = 5% bonus.
        uint16 userLiquidationFee; // The protocol fee charged on liquidations, taken from the collateral bonus given to the liquidator, expressed in BPS. (E.g 1000 = 10%)
        // --------------------------
        // This uses latest dynamic config key
        uint16 latestCollateralFactor; // The collateral factor of the reserve, expressed in BPS. (E.g 8500 = 85%).
        uint32 latestMaxLiquidationBonus; // The maximum extra amount of collateral given to the liquidator as bonus, expressed in BPS. 10000 represents 0.00% bonus. E.g 10500 = 5% bonus.
        uint16 latestLiquidationFee; // The protocol fee charged on liquidations, taken from the collateral bonus given to the liquidator, expressed in BPS. (E.g 1000 = 10%)
        // --------------------------
        address hub; // The address of the associated Hub.
        uint16 hubAssetId; // The identifier of the asset in the Hub.
        uint256 hubLiquidity; // The liquidity available to be accessed, expressed in asset units.
        uint96 drawnRate; // The rate at which drawn assets grows, expressed in RAY.
        uint120 drawnIndex; // The drawn index which monotonically increases according to the drawn rate, expressed in RAY.
        // --------------------------
        uint256 spokeTotalSupplied; // The total amount of spoke-supplied assets, expressed in asset units.
        uint256 spokeTotalDrawn; // The total amount of spoke-drawn assets, expressed in asset units.
        uint256 spokeTotalPremium; // The total amount of spoke-premium assets, expressed in asset units.
        uint256 spokeTotalDebt; // The total amount of spoke-debt (drawn + premium), expressed in asset units.
        // --------------------------
        uint256 spokeSupplyCap; // The supply cap of the spoke, expressed in asset units.
        uint256 spokeBorrowCap; // The borrow cap of the spoke, expressed in asset units.
        uint256 spokeDeficitRay; // The deficit reported by a spoke for a given asset, expressed in asset units and scaled by RAY.
    }

    /// @notice Same as regular LoanData, but with full reserves data
    struct LoanDataWithFullReserves {
        address user;
        uint256 riskPremium;
        uint256 avgCollateralFactor;
        uint256 healthFactor;
        uint256 totalCollateralInUsd;
        uint256 totalDebtInUsdRay;
        uint256 activeCollateralCount;
        uint256 borrowCount;
        UserReserveDataFull[] reserves;
    }

    /// @notice Minimal reserve data.
    struct ReserveData {
        address underlying; // The address of the underlying asset.
        uint16 collateralFactor; // The collateral factor of the reserve, expressed in BPS. (E.g 8500 = 85%).
        uint256 price; // The price of the underlying asset, expressed in oracle decimals.
    }

    /// @notice Full reserve data.
    struct ReserveDataFull {
        address underlying; // The address of the underlying asset.
        address hub; // The address of the associated Hub.
        uint16 assetId; // The identifier of the asset in the Hub.
        uint8 decimals; // The number of decimals of the underlying asset.
        bool paused; // True if all actions are prevented for the reserve.
        bool frozen; // True if new activity is prevented for the reserve.
        bool borrowable; // True if the reserve is borrowable.
        uint24 collateralRisk; // The risk associated with a collateral asset, expressed in BPS. (E.g 1500 = 15%)
        uint16 collateralFactor; // The collateral factor of the reserve, expressed in BPS. (E.g 8500 = 85%).
        uint32 maxLiquidationBonus; // The maximum extra amount of collateral given to the liquidator as bonus, expressed in BPS. 10000 represents 0.00% bonus. E.g 10500 = 5% bonus.
        uint16 liquidationFee; // The protocol fee charged on liquidations, taken from the collateral bonus given to the liquidator, expressed in BPS. (E.g 1000 = 10%)
        uint256 price; // The price of the underlying asset, expressed in oracle decimals.
        uint256 totalSupplied; // The total amount of spoke-supplied assets, expressed in asset units.
        uint256 totalDrawn; // The total amount of spoke-drawn assets, expressed in asset units.
        uint256 totalPremium; // The total amount of spoke-premium assets, expressed in asset units.
        uint256 totalDebt; // The total amount of spoke-debt (drawn + premium), expressed in asset units.
        uint256 supplyCap; // The supply cap of the spoke, expressed in asset units.
        uint256 borrowCap; // The borrow cap of the spoke, expressed in asset units.
        uint256 deficitRay; // The deficit reported by a spoke for a given asset, expressed in asset units and scaled by RAY.
        bool spokeActive; // True if the spoke is active for this reserve.
        bool spokeHalted; // True if the spoke is halted for this reserve.
    }

    /// @notice Spoke data.
    struct SpokeData {
        uint128 targetHealthFactor; // The ideal health factor to restore a user position during liquidation, expressed in WAD.
        uint64 healthFactorForMaxBonus; // The health factor under which liquidation bonus is maximum, expressed in WAD.
        uint16 liquidationBonusFactor; // The value multiplied by `maxLiquidationBonus` to compute the minimum liquidation bonus, expressed in BPS.
        address oracle; // The address of the oracle.
        uint256 oracleDecimals; // The number of decimals of the oracle.
        uint256 reserveCount; // The number of reserves in the spoke.
    }

    /// @notice Asset data from the Hub.
    struct HubAssetData {
        uint16 assetId; // The identifier of the asset in the Hub.
        uint8 decimals; // The number of decimals of the underlying asset.
        address underlying; // The address of the underlying asset.
        uint256 liquidity; // The liquidity available to be accessed, expressed in asset units.
        uint256 totalSupplied; // The total amount of spoke-supplied assets, expressed in asset units.
        uint256 totalDrawn; // The total amount of drawn assets, expressed in asset units.
        uint256 totalPremium; // The total amount of premium assets, expressed in asset units.
        uint256 totalDebt; // The total amount of debt (drawn + premium), expressed in asset units.
        uint256 totalDrawnShares; // The total amount of drawn shares.
        uint256 totalPremiumShares; // The total amount of premium shares.
        uint256 swept; // The outstanding liquidity which has been invested by the reinvestment controller, expressed in asset units.
        uint16 liquidityFee; // The protocol fee charged on drawn and premium liquidity growth, expressed in BPS.
        uint120 drawnIndex; // The drawn index which monotonically increases according to the drawn rate, expressed in RAY.
        uint96 drawnRate; // The rate at which drawn assets grows, expressed in RAY.
        uint40 lastUpdateTimestamp; // The timestamp of the last accrual.
        address irStrategy; // The address of the interest rate strategy.
        address reinvestmentController; // The address of the reinvestment controller.
        address feeReceiver; // The address of the fee receiver spoke.
        uint256 deficitRay; // The amount of outstanding bad debt across all spokes, expressed in asset units and scaled by RAY.
    }

    /// @notice EOA reserve approval data.
    struct EOAReserveApprovalData {
        uint256 reserveId; // The identifier of the reserve.
        address underlying; // The address of the underlying asset.
        uint256 delegateeBorrowApproval; // The approval of the delegatee to borrow on behalf of the user.
        uint256 delegateeWithdrawApproval; // The approval of the delegatee to withdraw on behalf of the user.
        uint256 eoaReserveBalance; // The EOA's balance of the reserve.
    }

    /// @notice EOA approval data.
    struct EOAApprovalData {
        address eoa; // The address of the EOA.
        address proxy; // The address of the proxy which acts on behalf of the EOA (delegatee).
        address spoke; // The address of the spoke.
        // --------------------------
        bool giverPositionManagerEnabled; // True if the supply/payback manager is enabled globally for the user.
        bool takerPositionManagerEnabled; // True if the withdraw/borrow manager is enabled globally for the user.
        bool configPositionManagerEnabled; // True if the config manager is enabled globally for the user.
        // --------------------------
        bool canSetUsingAsCollateral; // True if the delegatee can set using as collateral on behalf of the user.
        bool canUpdateUserRiskPremium; // True if the delegatee can update user risk premium on behalf of the user.
        bool canUpdateUserDynamicConfig; // True if the delegatee can update user dynamic config on behalf of the user.
        // --------------------------
        EOAReserveApprovalData[] reserveApprovals; // The approval data for each reserve inside the spoke.
    }

    /// @notice Tokenization spoke data with optional user data.
    /// @dev Tokenization spoke is ERC4626 compliant wrapper to tokenize one listed asset of the connected Hub.
    struct TokenizationSpokeData {
        // ---- Asset ----
        address underlyingAsset; // The address of the underlying asset.
        uint256 assetId; // The identifier of the asset in the Hub.
        uint8 decimals; // The number of decimals of the underlying asset.
        // ---- Spoke ----
        address spoke; // The address of the spoke.
        bool spokeActive; // True if the spoke is active.
        bool spokeHalted; // True if the spoke is halted.
        uint256 spokeDepositCap; // The deposit cap of the spoke, expressed in asset units.
        uint256 spokeTotalAssets; // The total amount of spoke-supplied assets, expressed in asset units.
        uint256 spokeTotalShares; // The total amount of spoke-supplied shares, expressed in shares.
        // ---- Hub ----
        address hub; // The address of the associated Hub.
        uint256 hubLiquidity; // The liquidity available to be accessed, expressed in asset units.
        uint96 hubDrawnRate; // The rate at which drawn assets grows, expressed in RAY.
        uint256 convertToShares; // The conversion rate from assets to shares expressed in asset units.
        uint256 convertToAssets; // The conversion rate from shares to assets expressed in asset units.
        // ---- User ---- (Optional)
        address user; // The address of the user.
        uint256 userSuppliedAssets; // The amount of user-supplied assets, expressed in asset units.
        uint256 userSuppliedShares; // The amount of user-supplied shares, expressed in asset units.
    }

    /**
     *
     *
     *
     *          EXTERNAL FUNCTIONS
     *
     *
     *
     */

    function getReserveData(address _spoke, uint256 _reserveId)
        external
        view
        returns (ReserveData memory reserveData)
    {
        return _getReserveData(_spoke, _reserveId);
    }

    function getReservesData(address _spoke, uint256[] calldata _reserveIds)
        external
        view
        returns (ReserveData[] memory reserveData)
    {
        reserveData = new ReserveData[](_reserveIds.length);
        for (uint256 i = 0; i < _reserveIds.length; ++i) {
            reserveData[i] = _getReserveData(_spoke, _reserveIds[i]);
        }
    }

    function getReserveDataFull(address _spoke, uint256 _reserveId)
        external
        view
        returns (ReserveDataFull memory reserveData)
    {
        return _getReserveDataFull(_spoke, _reserveId);
    }

    function getReservesDataFull(address _spoke, uint256[] calldata _reserveIds)
        external
        view
        returns (ReserveDataFull[] memory reserveData)
    {
        reserveData = new ReserveDataFull[](_reserveIds.length);
        for (uint256 i = 0; i < _reserveIds.length; ++i) {
            reserveData[i] = _getReserveDataFull(_spoke, _reserveIds[i]);
        }
    }

    function getSpokeData(address _spoke)
        external
        view
        returns (SpokeData memory spokeData, ReserveData[] memory reserves)
    {
        spokeData = _getSpokeData(_spoke);
        reserves = new ReserveData[](spokeData.reserveCount);
        for (uint256 i = 0; i < spokeData.reserveCount; ++i) {
            reserves[i] = _getReserveData(_spoke, i);
        }
    }

    function getSpokeDataFull(address _spoke)
        external
        view
        returns (SpokeData memory spokeData, ReserveDataFull[] memory reserves)
    {
        spokeData = _getSpokeData(_spoke);
        reserves = new ReserveDataFull[](spokeData.reserveCount);
        for (uint256 i = 0; i < spokeData.reserveCount; ++i) {
            reserves[i] = _getReserveDataFull(_spoke, i);
        }
    }

    function getLoanData(address _spoke, address _user)
        public
        view
        returns (LoanData memory loanData)
    {
        ISpoke spoke = ISpoke(_spoke);

        ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(_user);
        uint256 reserveCount = spoke.getReserveCount();

        loanData = LoanData({
            user: _user,
            riskPremium: userAccountData.riskPremium,
            avgCollateralFactor: userAccountData.avgCollateralFactor,
            healthFactor: userAccountData.healthFactor,
            totalCollateralInUsd: userAccountData.totalCollateralValue,
            totalDebtInUsdRay: userAccountData.totalDebtValueRay,
            activeCollateralCount: userAccountData.activeCollateralCount,
            borrowCount: userAccountData.borrowCount,
            reserves: new UserReserveData[](reserveCount)
        });

        for (uint256 i = 0; i < reserveCount; ++i) {
            loanData.reserves[i] = _getUserReserveData(_spoke, _user, i);
        }
    }

    function getLoanDataFull(address _spoke, address _user)
        public
        view
        returns (LoanDataWithFullReserves memory loanData)
    {
        ISpoke spoke = ISpoke(_spoke);

        ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(_user);
        uint256 reserveCount = spoke.getReserveCount();

        loanData = LoanDataWithFullReserves({
            user: _user,
            riskPremium: userAccountData.riskPremium,
            avgCollateralFactor: userAccountData.avgCollateralFactor,
            healthFactor: userAccountData.healthFactor,
            totalCollateralInUsd: userAccountData.totalCollateralValue,
            totalDebtInUsdRay: userAccountData.totalDebtValueRay,
            activeCollateralCount: userAccountData.activeCollateralCount,
            borrowCount: userAccountData.borrowCount,
            reserves: new UserReserveDataFull[](reserveCount)
        });

        for (uint256 i = 0; i < reserveCount; ++i) {
            loanData.reserves[i] = _getUserReserveDataFull(_spoke, _user, i);
        }
    }

    function getLoanDataForMultipleSpokes(address _user, address[] calldata _spokes)
        public
        view
        returns (LoanData[] memory loans)
    {
        loans = new LoanData[](_spokes.length);
        for (uint256 i = 0; i < _spokes.length; ++i) {
            loans[i] = getLoanData(_spokes[i], _user);
        }
    }

    function getLoanDataForMultipleUsers(address _spoke, address[] calldata _users)
        public
        view
        returns (LoanData[] memory loans)
    {
        loans = new LoanData[](_users.length);

        for (uint256 i = 0; i < _users.length; ++i) {
            loans[i] = getLoanData(_spoke, _users[i]);
        }
    }

    function getReservePrices(address _spoke, uint256[] calldata _reserveIds)
        public
        view
        returns (uint256[] memory prices)
    {
        prices = IAaveV4Oracle(ISpoke(_spoke).ORACLE()).getReservesPrices(_reserveIds);
    }

    function getReservePrice(address _spoke, uint256 _reserveId)
        public
        view
        returns (uint256 price)
    {
        price = IAaveV4Oracle(ISpoke(_spoke).ORACLE()).getReservePrice(_reserveId);
    }

    function getHealthFactor(address _spoke, address _user)
        public
        view
        returns (uint256 healthFactor)
    {
        return ISpoke(_spoke).getUserAccountData(_user).healthFactor;
    }

    function getUserReserveData(address _spoke, address _user, uint256[] calldata _reserveIds)
        public
        view
        returns (UserReserveData[] memory _userReserves)
    {
        _userReserves = new UserReserveData[](_reserveIds.length);
        for (uint256 i = 0; i < _reserveIds.length; ++i) {
            _userReserves[i] = _getUserReserveData(_spoke, _user, _reserveIds[i]);
        }
    }

    function getHubAssetData(address _hub, uint256 _assetId)
        public
        view
        returns (HubAssetData memory hubAssetData)
    {
        return _getHubAssetData(_hub, _assetId);
    }

    function getHubAllAssetsData(address _hub)
        public
        view
        returns (HubAssetData[] memory hubAssetData)
    {
        uint256 assetCount = IHub(_hub).getAssetCount();
        hubAssetData = new HubAssetData[](assetCount);
        for (uint256 i = 0; i < assetCount; ++i) {
            hubAssetData[i] = _getHubAssetData(_hub, i);
        }
    }

    function getSpokesForAsset(address _hub, uint256 _assetId)
        public
        view
        returns (address[] memory spokes)
    {
        IHub hub = IHub(_hub);
        uint256 spokeCount = hub.getSpokeCount(_assetId);
        spokes = new address[](spokeCount);
        for (uint256 i = 0; i < spokeCount; ++i) {
            spokes[i] = hub.getSpokeAddress(_assetId, i);
        }
    }

    function getEOAApprovalsAndBalances(address _eoa, address _proxy, address _spoke)
        public
        view
        returns (EOAApprovalData memory data)
    {
        ISpoke spoke = ISpoke(_spoke);
        uint256 reserveCount = spoke.getReserveCount();

        data.eoa = _eoa;
        data.proxy = _proxy;
        data.spoke = _spoke;

        data.giverPositionManagerEnabled = spoke.isPositionManager(_eoa, GIVER_POSITION_MANAGER);
        data.takerPositionManagerEnabled = spoke.isPositionManager(_eoa, TAKER_POSITION_MANAGER);
        data.configPositionManagerEnabled = spoke.isPositionManager(_eoa, CONFIG_POSITION_MANAGER);

        IConfigPositionManager.ConfigPermissionValues memory configPerms = IConfigPositionManager(
                CONFIG_POSITION_MANAGER
            ).getConfigPermissions(_spoke, _proxy, _eoa);
        data.canSetUsingAsCollateral = configPerms.canSetUsingAsCollateral;
        data.canUpdateUserRiskPremium = configPerms.canUpdateUserRiskPremium;
        data.canUpdateUserDynamicConfig = configPerms.canUpdateUserDynamicConfig;

        data.reserveApprovals = new EOAReserveApprovalData[](reserveCount);
        ITakerPositionManager takerPM = ITakerPositionManager(TAKER_POSITION_MANAGER);

        for (uint256 i = 0; i < reserveCount; ++i) {
            ISpoke.Reserve memory reserve = spoke.getReserve(i);
            data.reserveApprovals[i] = EOAReserveApprovalData({
                reserveId: i,
                underlying: reserve.underlying,
                delegateeBorrowApproval: takerPM.borrowAllowance(_spoke, i, _eoa, _proxy),
                delegateeWithdrawApproval: takerPM.withdrawAllowance(_spoke, i, _eoa, _proxy),
                eoaReserveBalance: IERC20(reserve.underlying).balanceOf(_eoa)
            });
        }
    }

    function getTokenizationSpokesData(address[] calldata _spokes, address _user)
        public
        view
        returns (TokenizationSpokeData[] memory spokeData)
    {
        spokeData = new TokenizationSpokeData[](_spokes.length);
        for (uint256 i = 0; i < _spokes.length; ++i) {
            spokeData[i] = getTokenizationSpokeData(_spokes[i], _user);
        }
    }

    function getTokenizationSpokeData(address _spoke, address _user)
        public
        view
        returns (TokenizationSpokeData memory spokeData)
    {
        ITokenizationSpoke ts = ITokenizationSpoke(_spoke);
        spokeData.spoke = _spoke;
        spokeData.hub = ts.hub();
        spokeData.assetId = ts.assetId();

        IHub.Asset memory hubAsset = IHub(spokeData.hub).getAsset(spokeData.assetId);
        IHub.SpokeConfig memory tsConfig =
            IHub(spokeData.hub).getSpokeConfig(spokeData.assetId, _spoke);

        spokeData.underlyingAsset = hubAsset.underlying;
        spokeData.decimals = hubAsset.decimals;
        spokeData.spokeTotalAssets = ts.totalAssets();
        spokeData.spokeTotalShares = ts.totalSupply();
        spokeData.spokeActive = tsConfig.active;
        spokeData.spokeHalted = tsConfig.halted;
        spokeData.spokeDepositCap = tsConfig.addCap != IHub(spokeData.hub).MAX_ALLOWED_SPOKE_CAP()
            ? tsConfig.addCap * (10 ** spokeData.decimals)
            : type(uint256).max;
        spokeData.hubLiquidity = hubAsset.liquidity;
        spokeData.hubDrawnRate = hubAsset.drawnRate;
        spokeData.convertToShares = ts.convertToShares(10 ** spokeData.decimals);
        spokeData.convertToAssets = ts.convertToAssets(10 ** spokeData.decimals);
        if (_user != address(0)) {
            spokeData.user = _user;
            spokeData.userSuppliedShares = IERC20(_spoke).balanceOf(_user);
            spokeData.userSuppliedAssets = ts.convertToAssets(spokeData.userSuppliedShares);
        }
    }

    /**
     *
     *
     *
     *          INTERNAL FUNCTIONS
     *
     *
     *
     */
    function _getReserveData(address _spoke, uint256 _reserveId)
        internal
        view
        returns (ReserveData memory reserveData)
    {
        ISpoke spoke = ISpoke(_spoke);
        ISpoke.Reserve memory reserve = spoke.getReserve(_reserveId);
        ISpoke.DynamicReserveConfig memory config =
            spoke.getDynamicReserveConfig(_reserveId, reserve.dynamicConfigKey);
        reserveData = ReserveData({
            underlying: reserve.underlying,
            collateralFactor: config.collateralFactor,
            price: getReservePrice(_spoke, _reserveId)
        });
    }

    function _getReserveDataFull(address _spoke, uint256 _reserveId)
        internal
        view
        returns (ReserveDataFull memory reserveData)
    {
        ISpoke.Reserve memory reserve = ISpoke(_spoke).getReserve(_reserveId);
        ISpoke.ReserveConfig memory reserveConfig = ISpoke(_spoke).getReserveConfig(_reserveId);
        ISpoke.DynamicReserveConfig memory dynamicReserveConfig =
            ISpoke(_spoke).getDynamicReserveConfig(_reserveId, reserve.dynamicConfigKey);

        IHub.SpokeData memory spokeData = IHub(reserve.hub).getSpoke(reserve.assetId, _spoke);
        (uint256 totalDrawn, uint256 totalPremium) =
            IHub(reserve.hub).getSpokeOwed(reserve.assetId, _spoke);
        uint256 maxCap = IHub(reserve.hub).MAX_ALLOWED_SPOKE_CAP();

        reserveData = ReserveDataFull({
            underlying: reserve.underlying,
            hub: reserve.hub,
            assetId: reserve.assetId,
            decimals: reserve.decimals,
            paused: reserveConfig.paused,
            frozen: reserveConfig.frozen,
            borrowable: reserveConfig.borrowable,
            collateralRisk: reserve.collateralRisk,
            collateralFactor: dynamicReserveConfig.collateralFactor,
            maxLiquidationBonus: dynamicReserveConfig.maxLiquidationBonus,
            liquidationFee: dynamicReserveConfig.liquidationFee,
            price: getReservePrice(_spoke, _reserveId),
            totalSupplied: IHub(reserve.hub).getSpokeAddedAssets(reserve.assetId, _spoke),
            totalDrawn: totalDrawn,
            totalPremium: totalPremium,
            totalDebt: totalDrawn + totalPremium,
            supplyCap: spokeData.addCap != maxCap
                ? spokeData.addCap * (10 ** reserve.decimals)
                : type(uint256).max,
            borrowCap: spokeData.drawCap != maxCap
                ? spokeData.drawCap * (10 ** reserve.decimals)
                : type(uint256).max,
            deficitRay: spokeData.deficitRay,
            spokeActive: spokeData.active,
            spokeHalted: spokeData.halted
        });
    }

    function _getUserReserveData(address _spoke, address _user, uint256 _reserveId)
        internal
        view
        returns (UserReserveData memory)
    {
        ISpoke spoke = ISpoke(_spoke);
        ISpoke.Reserve memory reserve = spoke.getReserve(_reserveId);
        ISpoke.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(
            _reserveId, spoke.getUserPosition(_reserveId, _user).dynamicConfigKey
        );

        (uint256 drawn, uint256 premium) = spoke.getUserDebt(_reserveId, _user);
        (bool isUsingAsCollateral, bool isBorrowing) = spoke.getUserReserveStatus(_reserveId, _user);

        return UserReserveData({
            reserveId: _reserveId,
            assetId: reserve.assetId,
            underlying: reserve.underlying,
            supplied: spoke.getUserSuppliedAssets(_reserveId, _user),
            drawn: drawn,
            premium: premium,
            totalDebt: drawn + premium,
            collateralFactor: config.collateralFactor,
            maxLiquidationBonus: config.maxLiquidationBonus,
            liquidationFee: config.liquidationFee,
            isUsingAsCollateral: isUsingAsCollateral,
            isBorrowing: isBorrowing
        });
    }

    function _getUserReserveDataFull(address _spoke, address _user, uint256 _reserveId)
        internal
        view
        returns (UserReserveDataFull memory data)
    {
        ISpoke spoke = ISpoke(_spoke);
        ISpoke.Reserve memory reserve = spoke.getReserve(_reserveId);
        ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(_reserveId);

        data.reserveId = _reserveId;
        data.underlying = reserve.underlying;
        data.price = getReservePrice(_spoke, _reserveId);
        data.decimals = reserve.decimals;

        data.reservePaused = reserveConfig.paused;
        data.reserveFrozen = reserveConfig.frozen;
        data.borrowable = reserveConfig.borrowable;

        data.userSupplied = spoke.getUserSuppliedAssets(_reserveId, _user);
        (data.userDrawn, data.userPremium) = spoke.getUserDebt(_reserveId, _user);
        data.userTotalDebt = data.userDrawn + data.userPremium;

        (data.isUsingAsCollateral, data.isBorrowing) = spoke.getUserReserveStatus(_reserveId, _user);

        data.collateralRisk = reserve.collateralRisk;

        {
            uint32 userKey = spoke.getUserPosition(_reserveId, _user).dynamicConfigKey;
            ISpoke.DynamicReserveConfig memory userCfg =
                spoke.getDynamicReserveConfig(_reserveId, userKey);
            data.userCollateralFactor = userCfg.collateralFactor;
            data.userMaxLiquidationBonus = userCfg.maxLiquidationBonus;
            data.userLiquidationFee = userCfg.liquidationFee;
        }

        {
            ISpoke.DynamicReserveConfig memory latestCfg =
                spoke.getDynamicReserveConfig(_reserveId, reserve.dynamicConfigKey);
            data.latestCollateralFactor = latestCfg.collateralFactor;
            data.latestMaxLiquidationBonus = latestCfg.maxLiquidationBonus;
            data.latestLiquidationFee = latestCfg.liquidationFee;
        }

        data.hub = reserve.hub;
        data.hubAssetId = reserve.assetId;

        data.hubLiquidity = IHub(data.hub).getAssetLiquidity(reserve.assetId);
        data.drawnRate = uint96(IHub(data.hub).getAssetDrawnRate(reserve.assetId));
        data.drawnIndex = uint120(IHub(data.hub).getAssetDrawnIndex(reserve.assetId));

        data.spokeTotalSupplied = IHub(data.hub).getSpokeAddedAssets(reserve.assetId, _spoke);
        (data.spokeTotalDrawn, data.spokeTotalPremium) =
            IHub(data.hub).getSpokeOwed(reserve.assetId, _spoke);
        data.spokeTotalDebt = data.spokeTotalDrawn + data.spokeTotalPremium;

        {
            IHub.SpokeData memory hubSpokeData = IHub(data.hub).getSpoke(reserve.assetId, _spoke);
            data.spokeActive = hubSpokeData.active;
            data.spokeHalted = hubSpokeData.halted;
            data.spokeDeficitRay = hubSpokeData.deficitRay;

            uint40 maxCap = IHub(data.hub).MAX_ALLOWED_SPOKE_CAP();
            data.spokeSupplyCap = hubSpokeData.addCap != maxCap
                ? uint256(hubSpokeData.addCap) * (10 ** reserve.decimals)
                : type(uint256).max;
            data.spokeBorrowCap = hubSpokeData.drawCap != maxCap
                ? uint256(hubSpokeData.drawCap) * (10 ** reserve.decimals)
                : type(uint256).max;
        }
    }

    function _getSpokeData(address _spoke) internal view returns (SpokeData memory spokeData) {
        ISpoke spoke = ISpoke(_spoke);
        ISpoke.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
        address oracle = spoke.ORACLE();
        spokeData = SpokeData({
            targetHealthFactor: liqConfig.targetHealthFactor,
            healthFactorForMaxBonus: liqConfig.healthFactorForMaxBonus,
            liquidationBonusFactor: liqConfig.liquidationBonusFactor,
            oracle: oracle,
            oracleDecimals: IAaveV4Oracle(oracle).decimals(),
            reserveCount: spoke.getReserveCount()
        });
    }

    function _getHubAssetData(address _hub, uint256 _assetId)
        internal
        view
        returns (HubAssetData memory hubAssetData)
    {
        IHub hub = IHub(_hub);
        IHub.Asset memory asset = hub.getAsset(_assetId);

        (uint256 totalDrawn, uint256 totalPremium) = hub.getAssetOwed(_assetId);

        (uint256 totalPremiumShares,) = hub.getAssetPremiumData(_assetId);

        hubAssetData = HubAssetData({
            assetId: uint16(_assetId),
            decimals: asset.decimals,
            underlying: asset.underlying,
            liquidity: asset.liquidity,
            totalSupplied: hub.getAddedAssets(_assetId),
            totalDrawn: totalDrawn,
            totalPremium: totalPremium,
            totalDebt: totalDrawn + totalPremium,
            totalDrawnShares: hub.getAssetDrawnShares(_assetId),
            totalPremiumShares: totalPremiumShares,
            swept: asset.swept,
            liquidityFee: asset.liquidityFee,
            drawnIndex: asset.drawnIndex,
            drawnRate: asset.drawnRate,
            lastUpdateTimestamp: asset.lastUpdateTimestamp,
            irStrategy: asset.irStrategy,
            reinvestmentController: asset.reinvestmentController,
            feeReceiver: asset.feeReceiver,
            deficitRay: asset.deficitRay
        });
    }
}