// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/// @notice Minimal ERC20 interface.
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Minimal ERC4626 interface.
interface IERC4626 {
    function asset() external view returns (address);
}

/// @notice Minimal ERC20 metadata interface.
interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

/// @notice Interface for market balance fuses.
interface IMarketBalanceFuse {
    function MARKET_ID() external view returns (uint256);
    function balanceOf() external view returns (uint256);
}

/// @notice Minimal price oracle middleware interface.
interface IPriceOracleMiddleware {
    function getAssetPrice(address asset) external view returns (uint256 price, uint256 priceDecimals);
}

/// @notice Minimal math library used by the fuse.
library IporMath {
    function convertToWad(uint256 value, uint256 decimals_) internal pure returns (uint256) {
        if (decimals_ == 18) {
            return value;
        } else if (decimals_ > 18) {
            return value / (10 ** (decimals_ - 18));
        } else {
            return value * (10 ** (18 - decimals_));
        }
    }
}

/// @notice Minimal Plasma Vault storage library needed by config and vault libs.
library PlasmaVaultStorageLib {
    bytes32 internal constant PLASMA_VAULT_STORAGE_SLOT =
        keccak256("io.ipor.fusion.plasma.vault.storage");

    struct MarketSubstratesStruct {
        mapping(uint256 => bytes32[]) grantedSubstrates;
    }

    struct PlasmaVaultStorage {
        MarketSubstratesStruct marketSubstrates;
        address priceOracleMiddleware;
    }

    function getPlasmaVaultStorage() internal pure returns (PlasmaVaultStorage storage s) {
        bytes32 slot = PLASMA_VAULT_STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}

/// @notice Minimal Plasma Vault config library subset used by this fuse.
library PlasmaVaultConfigLib {
    function getMarketSubstrates(uint256 marketId_) internal view returns (bytes32[] memory) {
        return PlasmaVaultStorageLib.getPlasmaVaultStorage().marketSubstrates.grantedSubstrates[marketId_];
    }

    function bytes32ToAddress(bytes32 value_) internal pure returns (address) {
        return address(uint160(uint256(value_)));
    }
}

/// @notice Minimal Plasma Vault library subset used by this fuse.
library PlasmaVaultLib {
    function getPriceOracleMiddleware() internal view returns (address) {
        return PlasmaVaultStorageLib.getPlasmaVaultStorage().priceOracleMiddleware;
    }
}

/**
 * @title ERC20BalanceFuse
 * @notice Calculates the total USD value of tracked ERC20 tokens held directly by the Plasma Vault,
 *         excluding the vault's primary underlying asset.
 * @dev This flattened version is intended for direct paste into Remix and deployment.
 *      Deploy this contract with marketId = 7 for ERC20_VAULT_BALANCE tracking.
 */
contract ERC20BalanceFuse is IMarketBalanceFuse {
    /// @notice Thrown when market ID is zero.
    error Erc20BalanceFuseInvalidMarketId();

    /// @notice Address of this fuse contract version.
    address public immutable VERSION;

    /// @notice Market ID this fuse operates on.
    uint256 public immutable MARKET_ID;

    /**
     * @notice Initializes the ERC20BalanceFuse with a specific market ID.
     * @param marketId_ The market ID used to identify the ERC20 token substrates.
     */
    constructor(uint256 marketId_) {
        if (marketId_ == 0) {
            revert Erc20BalanceFuseInvalidMarketId();
        }
        VERSION = address(this);
        MARKET_ID = marketId_;
    }

    /**
     * @notice Calculates the total balance of ERC20 tokens held by the Plasma Vault.
     * @dev This function:
     *      1. Retrieves all substrates (ERC20 token addresses) configured for the market.
     *      2. Skips the vault's primary underlying asset to avoid double counting.
     *      3. Reads each token balance held directly by the Plasma Vault.
     *      4. Retrieves the token price from the price oracle middleware.
     *      5. Converts the token balance value to WAD (18 decimals).
     *      6. Returns the total USD value across all tracked ERC20 tokens.
     * @return The total value normalized to WAD (18 decimals).
     */
    function balanceOf() external view override returns (uint256) {
        bytes32[] memory vaults = PlasmaVaultConfigLib.getMarketSubstrates(MARKET_ID);

        uint256 len = vaults.length;
        if (len == 0) {
            return 0;
        }

        uint256 balance;
        address asset;
        uint256 price;
        uint256 priceDecimals;
        address underlyingAsset = IERC4626(address(this)).asset();
        address priceOracleMiddleware = PlasmaVaultLib.getPriceOracleMiddleware();

        for (uint256 i; i < len; ++i) {
            asset = PlasmaVaultConfigLib.bytes32ToAddress(vaults[i]);

            if (asset == underlyingAsset) {
                continue;
            }

            (price, priceDecimals) = IPriceOracleMiddleware(priceOracleMiddleware).getAssetPrice(asset);

            balance += IporMath.convertToWad(
                IERC20(asset).balanceOf(address(this)) * price,
                uint256(IERC20Metadata(asset).decimals()) + priceDecimals
            );
        }

        return balance;
    }
}