// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/// @dev OpenZeppelin IERC20 minimal interface.
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @dev OpenZeppelin IERC20Permit minimal interface.
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

/// @dev OpenZeppelin Address library subset required by SafeERC20.
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

/// @dev OpenZeppelin SafeERC20 subset required by this fuse.
library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation failed");
    }

    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        if (!Address.isContract(address(token))) {
            return false;
        }

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool)));
    }
}

/// @dev Minimal IPOR fuse common interface.
interface IFuseCommon {
    function MARKET_ID() external view returns (uint256);
}

/// @dev Minimal IPOR math library subset.
library IporMath {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

/// @dev Minimal PlasmaVault storage library needed by PlasmaVaultConfigLib.
library PlasmaVaultStorageLib {
    bytes32 internal constant PLASMA_VAULT_STORAGE_SLOT =
        keccak256("io.ipor.fusion.plasma.vault.storage");

    struct MarketSubstratesStruct {
        mapping(uint256 => mapping(bytes32 => uint256)) substrateAllowances;
    }

    struct PlasmaVaultStorage {
        MarketSubstratesStruct marketSubstrates;
    }

    function getPlasmaVaultStorage() internal pure returns (PlasmaVaultStorage storage s) {
        bytes32 slot = PLASMA_VAULT_STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}

/// @dev Minimal PlasmaVault config library subset used by this fuse.
///      A substrate is treated as granted when the allowance for its encoded bytes32 form is non-zero.
library PlasmaVaultConfigLib {
    function isSubstrateAsAssetGranted(uint256 marketId, address substrate) internal view returns (bool) {
        PlasmaVaultStorageLib.PlasmaVaultStorage storage s = PlasmaVaultStorageLib.getPlasmaVaultStorage();
        return s.marketSubstrates.substrateAllowances[marketId][bytes32(uint256(uint160(substrate)))] != 0;
    }
}

/// @notice Minimal Beefy vault interface for standard Beefy vault deposits and withdrawals.
interface IBeefyVault {
    function want() external view returns (address);
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
    function getPricePerFullShare() external view returns (uint256);
}

/// @notice Data structure for depositing into a Beefy vault.
struct BeefyVaultSupplyFuseEnterData {
    address vault;
    uint256 wantAmount;
    uint256 minMooSharesOut;
}

/// @notice Data structure for withdrawing from a Beefy vault.
struct BeefyVaultSupplyFuseExitData {
    address vault;
    uint256 mooSharesAmount;
    uint256 minWantAmountOut;
}

/// @title BeefyVaultSupplyFuse
/// @notice Generic IPOR Fusion fuse for standard Beefy vaults.
/// @dev This version is flattened and contains no transient-storage code.
contract BeefyVaultSupplyFuse is IFuseCommon {
    using SafeERC20 for IERC20;

    event BeefyVaultSupplyFuseEnter(
        address version,
        address vault,
        address want,
        uint256 wantAmount,
        uint256 mooSharesReceived
    );

    event BeefyVaultSupplyFuseExit(
        address version,
        address vault,
        address want,
        uint256 mooSharesBurned,
        uint256 wantAmountReceived
    );

    error BeefyVaultSupplyFuseUnsupportedVault(string action, address vault);
    error BeefyVaultSupplyFuseInsufficientMooShares(uint256 received, uint256 minExpected);
    error BeefyVaultSupplyFuseInsufficientWantOut(uint256 received, uint256 minExpected);

    address public immutable VERSION;
    uint256 public immutable MARKET_ID;

    constructor(uint256 marketId_) {
        VERSION = address(this);
        MARKET_ID = marketId_;
    }

    /// @notice Deposit want into a granted Beefy vault and receive moo shares.
    /// @dev The contract must already hold the correct want token for the target vault.
    function enter(
        BeefyVaultSupplyFuseEnterData memory data_
    ) external returns (uint256 finalWantAmount, uint256 mooSharesReceived) {
        if (data_.wantAmount == 0) {
            return (0, 0);
        }

        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, data_.vault)) {
            revert BeefyVaultSupplyFuseUnsupportedVault("enter", data_.vault);
        }

        address want = IBeefyVault(data_.vault).want();

        finalWantAmount = IporMath.min(data_.wantAmount, IERC20(want).balanceOf(address(this)));

        if (finalWantAmount == 0) {
            return (0, 0);
        }

        uint256 mooBefore = IERC20(data_.vault).balanceOf(address(this));

        IERC20(want).forceApprove(data_.vault, 0);
        IERC20(want).forceApprove(data_.vault, finalWantAmount);
        IBeefyVault(data_.vault).deposit(finalWantAmount);

        uint256 mooAfter = IERC20(data_.vault).balanceOf(address(this));
        mooSharesReceived = mooAfter - mooBefore;

        if (mooSharesReceived < data_.minMooSharesOut) {
            revert BeefyVaultSupplyFuseInsufficientMooShares(mooSharesReceived, data_.minMooSharesOut);
        }

        emit BeefyVaultSupplyFuseEnter(VERSION, data_.vault, want, finalWantAmount, mooSharesReceived);
    }

    /// @notice Burn moo shares in a granted Beefy vault and receive want.
    function exit(
        BeefyVaultSupplyFuseExitData memory data_
    ) external returns (uint256 finalMooSharesBurned, uint256 wantAmountReceived) {
        if (data_.mooSharesAmount == 0) {
            return (0, 0);
        }

        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, data_.vault)) {
            revert BeefyVaultSupplyFuseUnsupportedVault("exit", data_.vault);
        }

        address want = IBeefyVault(data_.vault).want();

        finalMooSharesBurned = IporMath.min(data_.mooSharesAmount, IERC20(data_.vault).balanceOf(address(this)));

        if (finalMooSharesBurned == 0) {
            return (0, 0);
        }

        uint256 wantBefore = IERC20(want).balanceOf(address(this));

        IBeefyVault(data_.vault).withdraw(finalMooSharesBurned);

        uint256 wantAfter = IERC20(want).balanceOf(address(this));
        wantAmountReceived = wantAfter - wantBefore;

        if (wantAmountReceived < data_.minWantAmountOut) {
            revert BeefyVaultSupplyFuseInsufficientWantOut(wantAmountReceived, data_.minWantAmountOut);
        }

        emit BeefyVaultSupplyFuseExit(VERSION, data_.vault, want, finalMooSharesBurned, wantAmountReceived);
    }
}