// Sources flattened with hardhat v3.2.0 https://hardhat.org

// SPDX-License-Identifier: MIT

// File npm/@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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


// File npm/@openzeppelin/contracts@5.0.2/token/ERC20/extensions/IERC20Permit.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)


/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// File npm/@openzeppelin/contracts@5.0.2/utils/Address.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)


/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}


// File npm/@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
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
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
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
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
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

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
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
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}


// File npm/@openzeppelin/contracts@5.0.2/utils/ReentrancyGuard.sol

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// File contracts/ScentTokenExchange.sol

// Original license: SPDX_License_Identifier: MIT



/**
 * @title ScentTokenExchange
 * @notice Non-custodial P2P order book exchange for Scent Token.
 * @dev Supports limit orders, market orders, partial fills, and atomic swaps.
 *      Operated by Universal Scent Technology PTE. LTD. (Singapore).
 *
 *      Fee Structure:
 *        - Buy SCENT:  0% (zero fee)
 *        - Sell SCENT: 10% of the non-SCENT proceeds → sent to treasury wallet
 *
 *      Security Features:
 *        - Escrow: Maker tokens are locked in the contract on order creation
 *        - Slippage Protection: fillOrder includes minimumReceived parameter
 *        - Reentrancy Guard: All state-changing functions are protected
 *        - SafeERC20: All token transfers use safe wrappers
 *        - Side Enforcement: Side is derived from token addresses, not user input,
 *          preventing fee evasion via direct contract interaction
 *
 * Token Addresses (Ethereum Mainnet):
 *   SCENT: 0x3034Bc30AfD4EF8FDF13e3a5A3e095169239a425
 *   JPYC:  0xE7C3D8C9a439feDe00D2600032D5dB0Be71C3c29
 *   USDT:  0xdAC17F958D2ee523a2206206994597C13D831ec7
 */
contract ScentTokenExchange is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── Constants ──────────────────────────────────────────────────────

    /// @notice Fee rate for SCENT sell orders: 10% = 1000 basis points
    uint256 public constant SELL_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ─── Enums ──────────────────────────────────────────────────────────

    enum OrderType { LIMIT, MARKET }
    enum OrderStatus { Open, PartiallyFilled, Filled, Cancelled }
    enum Side { Buy, Sell }

    // ─── Structs ────────────────────────────────────────────────────────

    struct Order {
        bytes32 orderId;
        address maker;
        address makerToken;   // Token the maker is selling (locked in escrow)
        address takerToken;   // Token the maker wants to receive
        uint256 makerAmount;  // Total amount of makerToken offered (escrowed)
        uint256 takerAmount;  // Total amount of takerToken requested
        uint256 filledMakerAmount;
        uint256 filledTakerAmount;
        OrderType orderType;
        OrderStatus status;
        Side side;
        uint256 expiry;       // 0 = no expiry (limit), timestamp for market orders
        uint256 createdAt;
    }

    // ─── State ──────────────────────────────────────────────────────────

    mapping(bytes32 => Order) public orders;
    bytes32[] public orderIds;
    uint256 public orderCount;

    // Allowed tokens for trading
    mapping(address => bool) public allowedTokens;

    // SCENT token address — used to determine sell-side fee
    address public immutable scentToken;

    // Treasury wallet — receives sell fees
    address public treasury;

    // Owner — can update treasury address (immutable for gas savings & safety)
    address public immutable owner;

    // Accumulated fees (for transparency / accounting)
    uint256 public totalFeesCollected;

    // ─── Events ─────────────────────────────────────────────────────────

    event OrderCreated(
        bytes32 indexed orderId,
        address indexed maker,
        address makerToken,
        address takerToken,
        uint256 makerAmount,
        uint256 takerAmount,
        OrderType orderType,
        Side side
    );

    event OrderFilled(
        bytes32 indexed orderId,
        address indexed taker,
        uint256 makerAmountFilled,
        uint256 takerAmountFilled,
        uint256 feeAmount,
        bool isFullyFilled
    );

    event OrderCancelled(bytes32 indexed orderId, address indexed maker);

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    event FeeCollected(
        bytes32 indexed orderId,
        address indexed payer,
        uint256 feeAmount
    );

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    // ─── Constructor ────────────────────────────────────────────────────

    constructor(
        address[] memory _allowedTokens,
        address _scentToken,
        address _treasury
    ) {
        require(_scentToken != address(0), "Invalid SCENT address");
        require(_treasury != address(0), "Invalid treasury address");

        for (uint256 i = 0; i < _allowedTokens.length; i++) {
            allowedTokens[_allowedTokens[i]] = true;
        }

        scentToken = _scentToken;
        treasury = _treasury;
        owner = msg.sender;
    }

    // ─── Modifiers ──────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyValidTokens(address _makerToken, address _takerToken) {
        require(allowedTokens[_makerToken], "Maker token not allowed");
        require(allowedTokens[_takerToken], "Taker token not allowed");
        require(_makerToken != _takerToken, "Tokens must differ");
        _;
    }

    modifier onlyOrderMaker(bytes32 _orderId) {
        require(orders[_orderId].maker == msg.sender, "Not order maker");
        _;
    }

    // ─── Admin Functions ────────────────────────────────────────────────

    /**
     * @notice Update the treasury wallet address.
     * @param _newTreasury New treasury address
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        address old = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(old, _newTreasury);
    }

    /**
     * @notice Add a token to the allowed trading whitelist.
     * @param _token Address of the ERC-20 token to allow
     */
    function addToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        require(!allowedTokens[_token], "Token already allowed");
        allowedTokens[_token] = true;
        emit TokenAdded(_token);
    }

    /**
     * @notice Remove a token from the allowed trading whitelist.
     * @dev Existing orders with this token can still be filled/cancelled,
     *      but no new orders can be created with it.
     * @param _token Address of the ERC-20 token to remove
     */
    function removeToken(address _token) external onlyOwner {
        require(allowedTokens[_token], "Token not in whitelist");
        allowedTokens[_token] = false;
        emit TokenRemoved(_token);
    }

    // ─── External Functions ─────────────────────────────────────────────

    /**
     * @notice Create a limit order. Maker tokens are transferred to escrow.
     * @dev Maker must have approved this contract to spend `_makerAmount` of `_makerToken`.
     *      Tokens are locked in the contract until the order is filled or cancelled.
     *      This prevents fake orders (見せ板) since tokens must actually be committed.
     *
     *      SECURITY: The `side` is enforced from token addresses, not user input.
     *        - makerToken == SCENT → Sell (maker is selling SCENT)
     *        - takerToken == SCENT → Buy (maker is buying SCENT)
     *      This prevents fee evasion via direct contract interaction.
     *
     *      IMPORTANT: At least one of makerToken/takerToken MUST be SCENT.
     *      Non-SCENT ↔ Non-SCENT pairs are not supported (e.g., JPYC ↔ USDT).
     *
     * @param _makerToken Address of the token the maker is selling
     * @param _takerToken Address of the token the maker wants to buy
     * @param _makerAmount Amount of makerToken to sell (will be escrowed)
     * @param _takerAmount Amount of takerToken requested
     * @param _side Buy or Sell — NOTE: this parameter is validated against token addresses
     *        and will revert if inconsistent. It is kept for ABI compatibility and event logging.
     */
    function createLimitOrder(
        address _makerToken,
        address _takerToken,
        uint256 _makerAmount,
        uint256 _takerAmount,
        Side _side
    )
        external
        nonReentrant
        onlyValidTokens(_makerToken, _takerToken)
        returns (bytes32)
    {
        require(_makerAmount > 0, "Maker amount must be > 0");
        require(_takerAmount > 0, "Taker amount must be > 0");

        // ─── SECURITY: Enforce that at least one token is SCENT ───
        require(
            _makerToken == scentToken || _takerToken == scentToken,
            "One token must be SCENT"
        );

        // ─── SECURITY: Derive and enforce correct Side from token addresses ───
        // This prevents fee evasion by submitting a mismatched Side parameter.
        Side derivedSide = _makerToken == scentToken ? Side.Sell : Side.Buy;
        require(_side == derivedSide, "Side mismatch: inconsistent with tokens");

        bytes32 orderId = keccak256(
            abi.encode(msg.sender, _makerToken, _takerToken, _makerAmount, _takerAmount, block.timestamp, orderCount)
        );

        // ─── CEI Pattern: Effects (state updates) before Interactions (external calls) ───
        orders[orderId] = Order({
            orderId: orderId,
            maker: msg.sender,
            makerToken: _makerToken,
            takerToken: _takerToken,
            makerAmount: _makerAmount,
            takerAmount: _takerAmount,
            filledMakerAmount: 0,
            filledTakerAmount: 0,
            orderType: OrderType.LIMIT,
            status: OrderStatus.Open,
            side: derivedSide,
            expiry: 0, // No expiry for limit orders
            createdAt: block.timestamp
        });

        orderIds.push(orderId);
        orderCount++;

        emit OrderCreated(orderId, msg.sender, _makerToken, _takerToken, _makerAmount, _takerAmount, OrderType.LIMIT, derivedSide);

        // ─── Interaction: Escrow maker tokens into this contract ───
        // This prevents fake orders (見せ板) — maker must actually commit tokens
        IERC20(_makerToken).safeTransferFrom(msg.sender, address(this), _makerAmount);

        return orderId;
    }

    /**
     * @notice Execute a market order against the best available limit orders.
     * @dev Added _minimumReceived for slippage/front-running protection.
     * @param _orderIds Array of order IDs to fill against, sorted by best price
     * @param _totalTakerAmount Total amount the taker wants to spend
     * @param _minimumReceived Minimum total makerToken the taker expects to receive.
     *        Reverts if the actual received amount is less. Protects against front-running.
     */
    function executeMarketOrder(
        bytes32[] calldata _orderIds,
        uint256 _totalTakerAmount,
        uint256 _minimumReceived
    )
        external
        nonReentrant
    {
        require(_orderIds.length > 0, "No orders to fill");
        require(_totalTakerAmount > 0, "Amount must be > 0");

        uint256 remainingTakerAmount = _totalTakerAmount;
        uint256 totalReceived = 0;

        for (uint256 i = 0; i < _orderIds.length && remainingTakerAmount > 0; i++) {
            Order storage order = orders[_orderIds[i]];

            if (order.status != OrderStatus.Open && order.status != OrderStatus.PartiallyFilled) {
                continue;
            }

            // Check expiry — CEI pattern: update state before external call
            if (order.expiry > 0 && block.timestamp > order.expiry) {
                order.status = OrderStatus.Cancelled;
                emit OrderCancelled(order.orderId, order.maker);
                // Return escrowed tokens to maker on expiry (after state update)
                uint256 remainingEscrow = order.makerAmount - order.filledMakerAmount;
                if (remainingEscrow > 0) {
                    IERC20(order.makerToken).safeTransfer(order.maker, remainingEscrow);
                }
                continue;
            }

            uint256 availableTakerAmount = order.takerAmount - order.filledTakerAmount;

            uint256 fillTakerAmount = remainingTakerAmount > availableTakerAmount
                ? availableTakerAmount
                : remainingTakerAmount;

            // Calculate proportional maker amount
            uint256 fillMakerAmount = (fillTakerAmount * order.makerAmount) / order.takerAmount;

            if (fillMakerAmount == 0 || fillTakerAmount == 0) continue;

            // Execute atomic swap with fee
            _executeSwap(order, msg.sender, fillMakerAmount, fillTakerAmount);

            totalReceived += fillMakerAmount;
            remainingTakerAmount -= fillTakerAmount;
        }

        // Slippage protection: revert if received less than minimum
        require(totalReceived >= _minimumReceived, "Slippage: received less than minimum");
    }

    /**
     * @notice Fill a specific limit order (fully or partially).
     * @dev Taker must have approved this contract to spend the required takerToken amount.
     *      Fee is determined by token addresses (not user-supplied Side), preventing evasion.
     *      Added _minimumReceived for front-running protection.
     * @param _orderId The order to fill
     * @param _fillMakerAmount Amount of makerToken to receive from the maker
     * @param _minimumReceived Minimum amount of tokens the taker expects to actually receive
     *        (after fees). Reverts if actual received is less. Set to 0 to skip check.
     */
    function fillOrder(
        bytes32 _orderId,
        uint256 _fillMakerAmount,
        uint256 _minimumReceived
    )
        external
        nonReentrant
    {
        Order storage order = orders[_orderId];

        require(order.maker != address(0), "Order does not exist");
        require(order.maker != msg.sender, "Cannot fill own order");
        require(
            order.status == OrderStatus.Open || order.status == OrderStatus.PartiallyFilled,
            "Order not fillable"
        );
        require(order.expiry == 0 || block.timestamp <= order.expiry, "Order expired");

        uint256 availableMakerAmount = order.makerAmount - order.filledMakerAmount;
        require(_fillMakerAmount > 0 && _fillMakerAmount <= availableMakerAmount, "Invalid fill amount");

        // Calculate proportional taker amount
        uint256 fillTakerAmount = (_fillMakerAmount * order.takerAmount) / order.makerAmount;
        require(fillTakerAmount > 0, "Fill too small");

        // Verify taker has approved sufficient allowance
        require(
            IERC20(order.takerToken).allowance(msg.sender, address(this)) >= fillTakerAmount,
            "Insufficient taker allowance"
        );

        uint256 actualReceived = _executeSwap(order, msg.sender, _fillMakerAmount, fillTakerAmount);

        // Slippage protection: revert if received less than minimum
        if (_minimumReceived > 0) {
            require(actualReceived >= _minimumReceived, "Slippage: received less than minimum");
        }
    }

    /**
     * @notice Cancel an open order. Only the maker can cancel their own order.
     * @dev Returns escrowed maker tokens back to the maker.
     * @param _orderId The order to cancel
     */
    function cancelOrder(bytes32 _orderId)
        external
        onlyOrderMaker(_orderId)
        nonReentrant
    {
        Order storage order = orders[_orderId];
        require(
            order.status == OrderStatus.Open || order.status == OrderStatus.PartiallyFilled,
            "Order not cancellable"
        );

        order.status = OrderStatus.Cancelled;

        // Return remaining escrowed tokens to maker
        uint256 remainingEscrow = order.makerAmount - order.filledMakerAmount;
        if (remainingEscrow > 0) {
            IERC20(order.makerToken).safeTransfer(order.maker, remainingEscrow);
        }

        emit OrderCancelled(_orderId, msg.sender);
    }

    // ─── View Functions ─────────────────────────────────────────────────

    /**
     * @notice Get full order details.
     */
    function getOrder(bytes32 _orderId) external view returns (Order memory) {
        return orders[_orderId];
    }

    /**
     * @notice Calculate the fee for a given amount on a sell order.
     * @param _amount The amount to calculate fee for
     * @return feeAmount The fee (10%)
     */
    function calculateSellFee(uint256 _amount) public pure returns (uint256 feeAmount) {
        feeAmount = (_amount * SELL_FEE_BPS) / BPS_DENOMINATOR;
    }

    /**
     * @notice Get total number of orders created.
     */
    function getOrderCount() external view returns (uint256) {
        return orderCount;
    }

    // ─── Internal Functions ─────────────────────────────────────────────

    /**
     * @dev Determine if this trade involves selling SCENT based on token addresses.
     *
     *      SECURITY: This function uses token addresses (immutable on-chain data),
     *      NOT the user-supplied `side` field, to determine fee applicability.
     *      This prevents fee evasion via direct contract interaction with a
     *      mismatched Side parameter.
     *
     *      A SCENT sell occurs when:
     *        - The order's makerToken is SCENT (maker is selling SCENT), OR
     *        - The order's takerToken is SCENT (taker is selling SCENT to fill)
     *
     *      In both cases, SCENT is being sold and a fee applies to the
     *      non-SCENT token proceeds.
     */
    function _isScentSell(Order storage _order) internal view returns (bool) {
        // Any trade involving SCENT has a sell side — fee always applies
        // to the non-SCENT token proceeds
        return _order.makerToken == scentToken || _order.takerToken == scentToken;
    }

    /**
     * @dev Identify which token in the order is the non-SCENT (quote) token.
     *      Returns the address of the non-SCENT token.
     */
    function _getQuoteToken(Order storage _order) internal view returns (address) {
        if (_order.makerToken == scentToken) {
            return _order.takerToken;
        }
        return _order.makerToken;
    }

    /**
     * @dev Execute the atomic token swap between maker and taker.
     *      Fee is determined by token addresses, not user-supplied Side.
     *      Maker tokens are paid from escrow (this contract), not from maker's wallet.
     *
     *      Fee logic:
     *        - When makerToken == SCENT (Sell order):
     *          Maker sells SCENT, receives quote token from taker.
     *          Fee is deducted from the quote token (taker pays fee from their payment).
     *        - When takerToken == SCENT (Buy order being filled):
     *          Taker sells SCENT, receives quote token from escrow.
     *          Fee is deducted from the quote token (escrowed makerToken) before sending to taker.
     *
     *      Returns the actual amount of tokens received by the taker (after fees).
     */
    function _executeSwap(
        Order storage _order,
        address _taker,
        uint256 _fillMakerAmount,
        uint256 _fillTakerAmount
    ) internal returns (uint256 takerActualReceived) {
        uint256 feeAmount = 0;

        // ─── CEI Pattern: Update state BEFORE external calls ───
        _order.filledMakerAmount += _fillMakerAmount;
        _order.filledTakerAmount += _fillTakerAmount;

        bool isFullyFilled = _order.filledMakerAmount >= _order.makerAmount;
        _order.status = isFullyFilled ? OrderStatus.Filled : OrderStatus.PartiallyFilled;

        // ─── Interactions: External token transfers ───
        if (_isScentSell(_order)) {
            if (_order.makerToken == scentToken) {
                // Maker sells SCENT (escrowed), receives quote token from taker
                // Fee is deducted from the quote token that the taker pays
                feeAmount = calculateSellFee(_fillTakerAmount);
                uint256 makerReceives = _fillTakerAmount - feeAmount;

                // Transfer SCENT from escrow to taker
                IERC20(_order.makerToken).safeTransfer(_taker, _fillMakerAmount);

                // Transfer quote token from taker: (amount - fee) to maker, fee to treasury
                IERC20(_order.takerToken).safeTransferFrom(_taker, _order.maker, makerReceives);
                if (feeAmount > 0) {
                    IERC20(_order.takerToken).safeTransferFrom(_taker, treasury, feeAmount);
                }

                // Taker receives full SCENT amount (fee is on quote token side)
                takerActualReceived = _fillMakerAmount;
            } else {
                // takerToken == SCENT: Buy order being filled
                // Taker sells SCENT, receives quote token (makerToken) from escrow
                // Fee is deducted from the quote token (escrowed makerToken)
                feeAmount = calculateSellFee(_fillMakerAmount);
                uint256 takerReceives = _fillMakerAmount - feeAmount;

                // Transfer quote token from escrow: (amount - fee) to taker, fee to treasury
                IERC20(_order.makerToken).safeTransfer(_taker, takerReceives);
                if (feeAmount > 0) {
                    IERC20(_order.makerToken).safeTransfer(treasury, feeAmount);
                }

                // Transfer SCENT from taker to maker
                IERC20(_order.takerToken).safeTransferFrom(_taker, _order.maker, _fillTakerAmount);

                takerActualReceived = takerReceives;
            }
        } else {
            // No SCENT involved — no fee (this case shouldn't happen with the
            // "One token must be SCENT" requirement, but kept for safety)
            IERC20(_order.makerToken).safeTransfer(_taker, _fillMakerAmount);
            IERC20(_order.takerToken).safeTransferFrom(_taker, _order.maker, _fillTakerAmount);

            takerActualReceived = _fillMakerAmount;
        }

        if (feeAmount > 0) {
            totalFeesCollected += feeAmount;
            emit FeeCollected(_order.orderId, _taker, feeAmount);
        }

        emit OrderFilled(_order.orderId, _taker, _fillMakerAmount, _fillTakerAmount, feeAmount, isFullyFilled);
    }
}

