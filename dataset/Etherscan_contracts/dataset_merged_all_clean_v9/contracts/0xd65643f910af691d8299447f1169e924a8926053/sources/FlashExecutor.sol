// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

// ─────────────── lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol ───────────────
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)


/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// ─────────────── lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol ───────────────
// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)


/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// ─────────────── lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol ───────────────
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)



// ─────────────── lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol ───────────────
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)



// ─────────────── lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol ───────────────
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)



/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// ─────────────── lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol ───────────────
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC20/utils/SafeERC20.sol)



/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_safeApprove(token, spender, value, false)) {
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Oppositely, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity `token.transfer(to, value)` call, relaxing the requirement on the return value: the
     * return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    /**
     * @dev Imitates a Solidity `token.transferFrom(from, to, value)` call, relaxing the requirement on the return
     * value: the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param from The sender of the tokens
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            mstore(0x60, 0)
        }
    }

    /**
     * @dev Imitates a Solidity `token.approve(spender, value)` call, relaxing the requirement on the return value:
     * the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param spender The spender of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(spender, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }
}

// ─────────────── src/FlashExecutor.sol ───────────────


interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IAaveV3Pool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @dev Minimal subset of Aave V3 / Spark's `IFlashLoanSimpleReceiver`. Aave's
///      official interface also requires `ADDRESSES_PROVIDER()` and `POOL()`, but
///      the Pool never calls them at runtime (selector-dispatched callback).
interface IAaveFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

/// @title  FlashExecutor
/// @notice Access-controlled executor for arbitrary call bundles, optionally
///         wrapped in a Morpho, Aave V3, or Spark flash loan.
/// @dev    See `./README.md` for trust model, lifecycle, and integration notes.
contract FlashExecutor is IMorphoFlashLoanCallback, IAaveFlashLoanSimpleReceiver {
    using SafeERC20 for IERC20;

    struct Call {
        address target;
        bytes data;
        uint256 value;
        bool skipRevert;
    }

    address public immutable admin;
    IMorpho public immutable morpho;
    address public immutable aaveV3Pool;
    address public immutable sparkPool;

    mapping(address => bool) internal isCaller;

    /// @notice Whether a target contract is on the bundled-call allowlist.
    /// @dev    Auto-generated public getter: callers can introspect what this deployment trusts.
    mapping(address => bool) public isTargetAllowlisted;

    /// @notice Whether target-allowlist enforcement is currently active.
    /// @dev    When true, every `Call.target` in a bundle must be in `isTargetAllowlisted`.
    ///         When false, bundles may call any contract (entry points are still gated by `onlyCaller`).
    bool public targetAllowlistEnabled;

    /// @dev Iterable copy of the target allowlist for `getAllowlistedTargets()`. Kept in sync
    ///      with `isTargetAllowlisted` via `setTarget`. Removal uses swap-and-pop, so order is not stable.
    address[] internal _targetList;
    /// @dev 1-based index into `_targetList` (0 = absent). Used for O(1) removal.
    mapping(address => uint256) internal _targetIndex;

    bytes32 private transient expectedCallbackHash;
    address private transient expectedCallbackSender;
    /// @dev True while an allowlisted entry point is executing. Used by `receive`
    ///      to accept ETH refunds (e.g., WETH9 unwraps) only during legitimate
    ///      bundles. Auto-clears at end of transaction (EIP-1153).
    bool private transient _executing;

    /// @dev Cap on returndata copied from bundled calls. Bounds gas/memory an
    ///      arbitrary target can force the keeper to spend via a returndata bomb.
    ///      256 bytes fits a standard `Error(string)` or `Panic(uint256)` revert
    ///      plus a short custom-error payload.
    uint256 private constant _MAX_RETURN_COPY = 256;

    event CallerSet(address indexed caller, bool allowed);
    event TargetSet(address indexed target, bool allowed);
    event TargetAllowlistEnabledSet(bool enabled);
    event Swept(address indexed token, address indexed to, uint256 amount);
    event CallSkipped(uint256 indexed index, address indexed target, bytes returnData);

    error Unauthorized();
    error NotCaller();
    error TargetNotAllowed(address target);
    error UnexpectedSender();
    error UnexpectedCallback();
    error UnexpectedInitiator();
    error AssetMismatch();
    error AmountMismatch();
    error MorphoNotConfigured();
    error AaveV3NotConfigured();
    error SparkNotConfigured();
    error CallbackNotInvoked();
    error ZeroAddress();
    error UnsolicitedEth();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyCaller() {
        if (!isCaller[msg.sender]) revert NotCaller();
        _;
    }

    /// @dev Marks the contract as actively executing while the body runs. Permits
    ///      `receive` to accept ETH from any sender during the bundle (e.g., WETH
    ///      unwraps, protocol refunds), while still blocking unsolicited transfers
    ///      from arbitrary EOAs outside any bundle. Saves/restores the previous
    ///      value so nested entry-point calls don't clobber the outer scope's flag.
    modifier executing() {
        bool prev = _executing;
        _executing = true;
        _;
        _executing = prev;
    }

    /// @param _admin         Admin address (recommended: multisig). Immutable. Must be non-zero.
    /// @param _morpho        Morpho Blue singleton, or address(0) to disable Morpho flash loans.
    /// @param _aaveV3Pool    Aave V3 Pool, or address(0) to disable Aave V3 flash loans.
    /// @param _sparkPool     Spark Pool, or address(0) to disable Spark flash loans.
    /// @param initialCallers Addresses to seed the caller allowlist. Any address(0) entries revert.
    constructor(
        address _admin,
        address _morpho,
        address _aaveV3Pool,
        address _sparkPool,
        address[] memory initialCallers
    ) {
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        morpho = IMorpho(_morpho);
        aaveV3Pool = _aaveV3Pool;
        sparkPool = _sparkPool;
        for (uint256 i; i < initialCallers.length; ++i) {
            address c = initialCallers[i];
            if (c == address(0)) revert ZeroAddress();
            isCaller[c] = true;
        }
    }

    /// @notice Add or remove a keeper from the caller allowlist.
    function setCaller(address caller, bool allowed) external onlyAdmin {
        isCaller[caller] = allowed;
        emit CallerSet(caller, allowed);
    }

    /// @notice Check whether a single address is on the caller allowlist.
    /// @dev    Pointwise lookup only — no function exposes the full list of allowlisted callers.
    function isCallerAllowlisted(address caller) external view returns (bool) {
        return isCaller[caller];
    }

    /// @notice Add or remove a contract from the bundled-call target allowlist.
    /// @dev    Has no effect on execution unless `targetAllowlistEnabled == true`.
    ///         Maintains an iterable list alongside the mapping for `getAllowlistedTargets()`.
    function setTarget(address target, bool allowed) external onlyAdmin {
        if (target == address(0)) revert ZeroAddress();
        bool current = isTargetAllowlisted[target];
        if (allowed && !current) {
            isTargetAllowlisted[target] = true;
            _targetList.push(target);
            _targetIndex[target] = _targetList.length;
            emit TargetSet(target, true);
        } else if (!allowed && current) {
            isTargetAllowlisted[target] = false;
            uint256 idx = _targetIndex[target] - 1;
            uint256 last = _targetList.length - 1;
            if (idx != last) {
                address swapped = _targetList[last];
                _targetList[idx] = swapped;
                _targetIndex[swapped] = idx + 1;
            }
            _targetList.pop();
            delete _targetIndex[target];
            emit TargetSet(target, false);
        }
    }

    /// @notice Enable or disable target-allowlist enforcement.
    /// @dev    Populate `isTargetAllowlisted` with required targets before enabling, otherwise all
    ///         bundles will revert with `TargetNotAllowed`.
    function setTargetAllowlistEnabled(bool enabled) external onlyAdmin {
        targetAllowlistEnabled = enabled;
        emit TargetAllowlistEnabledSet(enabled);
    }

    /// @notice Returns the full list of currently allowlisted target addresses.
    /// @dev    Order is not stable across additions/removals (swap-and-pop).
    function getAllowlistedTargets() external view returns (address[] memory) {
        return _targetList;
    }

    /// @notice Returns the number of currently allowlisted targets.
    function targetAllowlistCount() external view returns (uint256) {
        return _targetList.length;
    }

    /// @notice Recover stuck tokens or native ETH. Admin-only escape hatch.
    /// @param token  ERC20 to sweep, or address(0) for native ETH.
    function sweep(address token, address to, uint256 amount) external onlyAdmin {
        if (token == address(0)) {
            (bool ok, ) = to.call{value: amount}("");
            require(ok, "eth sweep failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        emit Swept(token, to, amount);
    }

    /// @notice Execute a bundle of calls atomically. No flash loan.
    function execute(Call[] calldata calls) external payable onlyCaller executing {
        _runCalls(calls);
    }

    /// @notice Execute `calls` inside a Morpho flash loan callback.
    /// @dev    By the end of the bundle, this contract must hold >= `amount` of `token`.
    function executeWithMorphoFlashLoan(
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (address(morpho) == address(0)) revert MorphoNotConfigured();

        bytes memory data = abi.encode(token, amount, calls);
        expectedCallbackHash = keccak256(data);
        expectedCallbackSender = address(morpho);

        morpho.flashLoan(token, amount, data);

        if (expectedCallbackHash != bytes32(0)) revert CallbackNotInvoked();
    }

    /// @notice Execute `calls` inside an Aave V3 flash loan callback.
    /// @dev    By the end of the bundle, this contract must hold >= `amount + premium` of `token`.
    function executeWithAaveV3FlashLoan(
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (aaveV3Pool == address(0)) revert AaveV3NotConfigured();
        _runAaveFlashLoan(aaveV3Pool, token, amount, calls);
    }

    /// @notice Execute `calls` inside a Spark flash loan callback.
    /// @dev    By the end of the bundle, this contract must hold >= `amount + premium` of `token`.
    function executeWithSparkFlashLoan(
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (sparkPool == address(0)) revert SparkNotConfigured();
        _runAaveFlashLoan(sparkPool, token, amount, calls);
    }

    /// @inheritdoc IMorphoFlashLoanCallback
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != expectedCallbackSender) revert UnexpectedSender();
        if (keccak256(data) != expectedCallbackHash) revert UnexpectedCallback();

        address sender = expectedCallbackSender;
        expectedCallbackHash = bytes32(0);
        expectedCallbackSender = address(0);

        (address token, uint256 expectedAmount, Call[] memory calls) =
            abi.decode(data, (address, uint256, Call[]));
        if (assets != expectedAmount) revert AmountMismatch();
        _runCalls(calls);
        IERC20(token).forceApprove(sender, assets);
    }

    /// @inheritdoc IAaveFlashLoanSimpleReceiver
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender != expectedCallbackSender) revert UnexpectedSender();
        if (initiator != address(this)) revert UnexpectedInitiator();
        if (keccak256(params) != expectedCallbackHash) revert UnexpectedCallback();

        address sender = expectedCallbackSender;
        expectedCallbackHash = bytes32(0);
        expectedCallbackSender = address(0);

        (address token, uint256 expectedAmount, Call[] memory calls) =
            abi.decode(params, (address, uint256, Call[]));
        if (asset != token) revert AssetMismatch();
        if (amount != expectedAmount) revert AmountMismatch();

        _runCalls(calls);
        IERC20(token).forceApprove(sender, amount + premium);
        return true;
    }

    function _runAaveFlashLoan(
        address pool,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) internal {
        bytes memory params = abi.encode(token, amount, calls);
        expectedCallbackHash = keccak256(params);
        expectedCallbackSender = pool;

        IAaveV3Pool(pool).flashLoanSimple(address(this), token, amount, params, 0);

        if (expectedCallbackHash != bytes32(0)) revert CallbackNotInvoked();
    }

    function _runCalls(Call[] memory calls) internal {
        bool gate = targetAllowlistEnabled;
        uint256 len = calls.length;
        for (uint256 i; i < len; ++i) {
            address to = calls[i].target;
            if (gate && !isTargetAllowlisted[to]) revert TargetNotAllowed(to);

            bytes memory callData = calls[i].data;
            uint256 callValue = calls[i].value;
            bytes memory ret = new bytes(_MAX_RETURN_COPY);
            bool ok;
            assembly {
                ok := call(gas(), to, callValue, add(callData, 0x20), mload(callData), 0, 0)
                let toCopy := returndatasize()
                if gt(toCopy, _MAX_RETURN_COPY) { toCopy := _MAX_RETURN_COPY }
                mstore(ret, toCopy)
                returndatacopy(add(ret, 0x20), 0, toCopy)
            }
            if (!ok) {
                if (calls[i].skipRevert) {
                    emit CallSkipped(i, to, ret);
                } else {
                    assembly {
                        revert(add(ret, 32), mload(ret))
                    }
                }
            }
        }
    }

    /// @notice Accept native ETH only during an active bundle (e.g., WETH unwraps,
    ///         protocol refunds) or from the admin (for funding gas / topping up).
    ///         Unsolicited transfers from any other sender revert.
    receive() external payable {
        if (!_executing && msg.sender != admin) revert UnsolicitedEth();
    }
}