// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;


// ===== FILE: IMarketBalanceFuse.sol =====

/// @title Interface for Fuses responsible for providing the balance of the PlasmaVault address in the market in USD
interface IMarketBalanceFuse {
    /// @notice Get the balance of the Plasma Vault in the market in USD
    /// @dev Notice! Every Balance Fuse have to implement this exact function signature, because it is used by Plasma Vault engine
    /// @return balanceValue The balance of the Plasma Vault in the market in USD, represented in 18 decimals
    function balanceOf() external returns (uint256 balanceValue);
}


// ===== FILE: IFuseCommon.sol =====

/// @title Interface for Fuses Common functions
interface IFuseCommon {
    /// @notice Market ID associated with the Fuse
    //solhint-disable-next-line
    function MARKET_ID() external view returns (uint256);
}


// ===== FILE: ICurveStableswapNG.sol =====

/**
 * @dev address on Arbitrum Mainnet 0xf6841C27fe35ED7069189aFD5b81513578AFD7FF
 * @dev https://vscode.blockscan.com/arbitrum-one/0xf6841C27fe35ED7069189aFD5b81513578AFD7FF
 */

/* solhint-disable */
interface ICurveStableswapNG {
    /**
     * @dev Return the number of coins in the pool
     * @return Number of coins in the pool
     */
    function N_COINS() external view returns (uint256);

    /**
     * @dev Return the coin address at index i
     * @param i Index of the coin
     * @return Address of the coin
     */
    function coins(uint256 i) external view returns (address);

    /**
     * @dev Calculate addition or reduction in token supply from a deposit or withdrawal
     * @param _amounts Amount of each coin being deposited or withdrawn
     * @param _is_deposit Flag set to True for deposits and False for withhdrawals
     * @return Expected amount of LP tokens received
     */
    function calc_token_amount(uint256[] calldata _amounts, bool _is_deposit) external view returns (uint256);

    /**
     * @dev Add liquidity to the pool
     * @param _amounts List of amounts of coins to deposit
     * @param _min_mint_amount Minimum amount of LP tokens to mint from the deposit
     * @param _receiver Address to receive the minted LP tokens (defaults to msg.sender)
     * @return Amount of LP tokens received by depositing
     */
    function add_liquidity(
        uint256[] calldata _amounts,
        uint256 _min_mint_amount,
        address _receiver
    ) external returns (uint256);

    /**
     * @dev Calculate the amount of coin i to receive from burning _burn_amount of LP tokens
     * @param _burn_amount Amount of LP tokens to burn / withdraw
     * @param i Index value of the coin to receive
     * @return Amount of coin i to receive
     */
    function calc_withdraw_one_coin(uint256 _burn_amount, int128 i) external view returns (uint256);

    /**
     * @dev Remove a minimum of _min_received of coin i by burining _burn_amount of LP tokens
     * @param _burn_amount Amount of LP tokens to burn / withdraw
     * @param i Index value of the coin to receive
     * @param _min_received Minimum amount of coin i to receive
     * @param _receiver Address to receive the withdrawn coins (defaults to msg.sender)
     */
    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received,
        address _receiver
    ) external returns (uint256);

    /**
     * @dev Return the total supply of LP tokens
     * @return Total supply of LP tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Return the balance of coin at index i held by the pool
     * @param i Index of the coin
     * @return Balance of the coin
     */
    function balances(uint256 i) external view returns (uint256);

    /**
     * @dev Return the number of decimals of the LP token
     * @return Number of decimals
     */
    function decimals() external view returns (uint256);
}


// ===== FILE: IPriceOracleMiddleware.sol =====

/// @title Interface to an aggregator of price feeds for assets, responsible for providing the prices of assets in a given quote currency
interface IPriceOracleMiddleware {
    error EmptyArrayNotSupported();
    error ArrayLengthMismatch();
    error UnexpectedPriceResult();
    error UnsupportedAsset();
    error ZeroAddress(string variableName);
    error WrongDecimals();
    error InvalidExpectedPrice();
    error PriceDeltaTooHigh();
    error AssetPriceSourceAlreadySet();

    /// @notice Returns the price of the given asset in given decimals
    /// @return assetPrice price in QUOTE_CURRENCY of the asset
    /// @return decimals number of decimals of the asset price
    function getAssetPrice(address asset) external view returns (uint256 assetPrice, uint256 decimals);

    /// @notice Returns the prices of the given assets in given decimals
    /// @return assetPrices prices in QUOTE_CURRENCY of the assets represented in defined decimals QUOTE_CURRENCY_DECIMALS
    /// @return decimalsList number of decimals of the asset prices
    function getAssetsPrices(
        address[] calldata assets
    ) external view returns (uint256[] memory assetPrices, uint256[] memory decimalsList);

    /// @notice Returns address of source of the asset price - it could be IPOR Price Feed or Chainlink Aggregator or any other source of price for a given asset
    /// @param asset address of the asset
    /// @return address of the source of the asset price
    function getSourceOfAssetPrice(address asset) external view returns (address);

    /// @notice Sets the sources of the asset prices
    /// @param assets array of addresses of the assets
    function setAssetsPricesSources(address[] calldata assets, address[] calldata sources) external;

    /// @notice Returns the address of the quote currency to which all the prices are relative, in IPOR Fusion it is the USD
    //solhint-disable-next-line
    function QUOTE_CURRENCY() external view returns (address);

    /// @notice Returns the number of decimals of the quote currency, can be different for other types of Price Oracles Middlewares
    //solhint-disable-next-line
    function QUOTE_CURRENCY_DECIMALS() external view returns (uint256);
}


// ===== FILE: OZ_IERC6093.sol =====

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}


// ===== FILE: OZ_IERC20.sol =====

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)


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


// ===== FILE: OZ_IERC20Metadata.sol =====

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)



/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// ===== FILE: OZ_Context.sol =====

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// ===== FILE: OZ_Address.sol =====

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


// ===== FILE: OZ_Math.sol =====

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)


/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}


// ===== FILE: OZ_SafeCast.sol =====

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.


/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }
}


// ===== FILE: OZ_ERC20.sol =====

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)



/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}


// ===== FILE: Errors.sol =====

/// @title Errors in Ipor Fusion
library Errors {
    /// @notice Error when wrong address is used
    error WrongAddress();
    /// @notice Error when wrong value is used
    error WrongValue();
    /// @notice Error when wrong decimals are used
    error WrongDecimals();
    /// @notice Error when wrong array length is used
    error WrongArrayLength();
    /// @notice Error when wrong caller is used
    error WrongCaller(address caller);
    /// @notice Error when wrong quote currency is used
    error UnsupportedQuoteCurrencyFromOracle();
    /// @notice Error when unsupported price oracle middleware is used
    error UnsupportedPriceOracleMiddleware();
}


// ===== FILE: IporMath.sol =====

/// @title Ipor Math library with math functions
library IporMath {
    uint256 private constant WAD_DECIMALS = 18;
    uint256 public constant BASIS_OF_POWER = 10;

    /// @dev The index of the most significant bit in a 256-bit signed integer
    uint256 private constant MSB = 255;

    /// @notice Error when math operation would overflow
    error MathOverflow();

    function min(uint256 a_, uint256 b_) internal pure returns (uint256) {
        return a_ < b_ ? a_ : b_;
    }

    /// @notice Converts the value to WAD decimals, WAD decimals are 18
    /// @param value_ The value to convert
    /// @param assetDecimals_ The decimals of the asset
    /// @return The value in WAD decimals
    function convertToWad(uint256 value_, uint256 assetDecimals_) internal pure returns (uint256) {
        if (value_ > 0) {
            if (assetDecimals_ == WAD_DECIMALS) {
                return value_;
            } else if (assetDecimals_ > WAD_DECIMALS) {
                return division(value_, BASIS_OF_POWER ** (assetDecimals_ - WAD_DECIMALS));
            } else {
                return value_ * BASIS_OF_POWER ** (WAD_DECIMALS - assetDecimals_);
            }
        } else {
            return value_;
        }
    }

    /// @notice Converts the value to WAD decimals, WAD decimals are 18
    /// @param value_ The value to convert
    /// @param assetDecimals_ The decimals of the asset
    /// @return The value in WAD decimals
    function convertWadToAssetDecimals(uint256 value_, uint256 assetDecimals_) internal pure returns (uint256) {
        if (assetDecimals_ == WAD_DECIMALS) {
            return value_;
        } else if (assetDecimals_ > WAD_DECIMALS) {
            return value_ * BASIS_OF_POWER ** (assetDecimals_ - WAD_DECIMALS);
        } else {
            return division(value_, BASIS_OF_POWER ** (WAD_DECIMALS - assetDecimals_));
        }
    }

    /// @notice Converts the int value to WAD decimals, WAD decimals are 18
    /// @param value_ The int value to convert
    /// @param assetDecimals_ The decimals of the asset
    /// @return The value in WAD decimals, int
    /// @dev Reverts with MathOverflow if the result would overflow int256
    function convertToWadInt(int256 value_, uint256 assetDecimals_) internal pure returns (int256) {
        if (value_ == 0) {
            return 0;
        }
        if (assetDecimals_ == WAD_DECIMALS) {
            return value_;
        } else if (assetDecimals_ > WAD_DECIMALS) {
            return divisionInt(value_, int256(BASIS_OF_POWER ** (assetDecimals_ - WAD_DECIMALS)));
        } else {
            int256 scaleFactor = int256(BASIS_OF_POWER ** (WAD_DECIMALS - assetDecimals_));
            // Check for overflow before multiplication
            // |value_| * scaleFactor must not exceed type(int256).max
            // Handle type(int256).min special case - cannot safely negate
            if (value_ == type(int256).min) {
                revert MathOverflow();
            }
            int256 absValue = value_ < 0 ? -value_ : value_;
            if (absValue > type(int256).max / scaleFactor) {
                revert MathOverflow();
            }
            return value_ * scaleFactor;
        }
    }

    /// @notice Divides two int256 numbers and rounds the result to the nearest integer
    /// @param x_ The numerator
    /// @param y_ The denominator
    /// @return z The result of the division
    /// @dev Reverts with MathOverflow if x_ or y_ is type(int256).min (cannot negate)
    function divisionInt(int256 x_, int256 y_) internal pure returns (int256 z) {
        // Handle type(int256).min special case - cannot safely negate
        if (x_ == type(int256).min || y_ == type(int256).min) {
            revert MathOverflow();
        }

        uint256 absX_ = uint256(x_ < 0 ? -x_ : x_);
        uint256 absY_ = uint256(y_ < 0 ? -y_ : y_);

        // Use bitwise XOR to get the sign on MBS bit then shift to LSB
        // sign == 0x0000...0000 ==  0 if the number is non-negative
        // sign == 0xFFFF...FFFF == -1 if the number is negative
        int256 sign = (x_ ^ y_) >> MSB;

        uint256 divAbs;
        uint256 remainder;

        unchecked {
            divAbs = absX_ / absY_;
            remainder = absX_ % absY_;
        }
        // Check if we need to round
        if (sign < 0) {
            // remainder << 1 left shift is equivalent to multiplying by 2
            if (remainder << 1 > absY_) {
                ++divAbs;
            }
        } else {
            if (remainder << 1 >= absY_) {
                ++divAbs;
            }
        }

        // (sign | 1) is cheaper than (sign < 0) ? -1 : 1;
        unchecked {
            z = int256(divAbs) * (sign | 1);
        }
    }

    /// @notice Divides two uint256 numbers and rounds the result to the nearest integer
    /// @param x_ The numerator
    /// @param y_ The denominator
    /// @return z_ The result of the division
    function division(uint256 x_, uint256 y_) internal pure returns (uint256 z_) {
        z_ = x_ / y_;
    }
}


// ===== FILE: FuseStorageLib.sol =====

/// @title Fuses storage library responsible for managing storage fuses in the Plasma Vault
library FuseStorageLib {
    /**
     * @dev Storage slot for managing supported fuses in the Plasma Vault
     * @notice Maps fuse addresses to their index in the fuses array for tracking supported fuses
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgFuses")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks which fuses are supported by the vault
     * - Enables efficient fuse validation
     * - Maps fuse addresses to their array indices
     * - Core component of fuse management system
     *
     * Storage Layout:
     * - Points to Fuses struct containing:
     *   - value: mapping(address fuse => uint256 index)
     *     - Zero index indicates unsupported fuse
     *     - Non-zero index (index + 1) indicates supported fuse
     *
     * Usage Pattern:
     * - Checked during fuse operations via isFuseSupported()
     * - Updated when adding/removing fuses
     * - Used for fuse validation in vault operations
     * - Maintains synchronization with fuses array
     *
     * Integration Points:
     * - FusesLib.isFuseSupported: Validates fuse status
     * - FusesLib.addFuse: Updates supported fuses
     * - FusesLib.removeFuse: Removes fuse support
     * - PlasmaVault: References for operation validation
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for controlling vault integrations
     * - Must maintain consistency with fuses array
     * - Key component of vault security
     */
    bytes32 private constant CFG_FUSES = 0x48932b860eb451ad240d4fe2b46522e5a0ac079d201fe50d4e0be078c75b5400;

    /**
     * @dev Storage slot for storing the array of supported fuses in the Plasma Vault
     * @notice Maintains ordered list of all supported fuse addresses
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgFusesArray")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Stores complete list of supported fuses
     * - Enables iteration over all supported fuses
     * - Maintains order of fuse addition
     * - Provides efficient fuse removal mechanism
     *
     * Storage Layout:
     * - Points to FusesArray struct containing:
     *   - value: address[] array of fuse addresses
     *     - Each element is a supported fuse contract address
     *     - Array index corresponds to (mapping index - 1) in CFG_FUSES
     *
     * Usage Pattern:
     * - Referenced when listing all supported fuses
     * - Updated during fuse addition/removal
     * - Used for fuse enumeration
     * - Maintains parallel structure with CFG_FUSES mapping
     *
     * Integration Points:
     * - FusesLib.getFusesArray: Retrieves complete fuse list
     * - FusesLib.addFuse: Appends new fuses
     * - FusesLib.removeFuse: Manages array updates
     * - Governance: References for fuse management
     *
     * Security Considerations:
     * - Must stay synchronized with CFG_FUSES mapping
     * - Array operations must handle index updates correctly
     * - Critical for fuse system integrity
     * - Requires careful management during removals
     */
    bytes32 private constant CFG_FUSES_ARRAY = 0xad43e358bd6e59a5a0c80f6bf25fa771408af4d80f621cdc680c8dfbf607ab00;

    /**
     * @dev Storage slot for managing Uniswap V3 NFT position token IDs in the Plasma Vault
     * @notice Tracks and manages Uniswap V3 LP positions held by the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.UniswapV3TokenIds")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks all Uniswap V3 NFT positions owned by the vault
     * - Enables efficient position management and lookup
     * - Supports liquidity provision operations
     * - Facilitates position value calculations
     *
     * Storage Layout:
     * - Points to UniswapV3TokenIds struct containing:
     *   - tokenIds: uint256[] array of Uniswap V3 NFT position IDs
     *   - indexes: mapping(uint256 tokenId => uint256 index) for position lookup
     *     - Maps each token ID to its index in the tokenIds array
     *     - Zero index indicates non-existent position
     *
     * Usage Pattern:
     * - Updated when creating new Uniswap V3 positions
     * - Referenced during position management
     * - Used for position value calculations
     * - Maintains efficient position tracking
     *
     * Integration Points:
     * - UniswapV3NewPositionFuse: Position creation and management
     * - PositionValue: NFT position valuation
     * - Balance calculation systems
     * - Withdrawal and rebalancing operations
     *
     * Security Considerations:
     * - Must accurately track all vault positions
     * - Critical for proper liquidity management
     * - Requires careful index management
     * - Essential for position ownership verification
     */
    bytes32 private constant UNISWAP_V3_TOKEN_IDS = 0x3651659bd419f7c37743f3e14a337c9f9d1cfc4d650d91508f44d1acbe960f00;

    /**
     * @dev Storage slot for managing Ramses V2 NFT position token IDs in the Plasma Vault
     * @notice Tracks and manages Ramses V2 LP positions held by the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.RamsesV2TokenIds")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks all Ramses V2 NFT positions owned by the vault
     * - Enables efficient position management and lookup
     * - Supports concentrated liquidity position tracking
     * - Mirrors Uniswap V3-style position management for Arbitrum
     *
     * Storage Layout:
     * - Points to RamsesV2TokenIds struct containing:
     *   - tokenIds: uint256[] array of Ramses V2 NFT position IDs
     *   - indexes: mapping(uint256 tokenId => uint256 index) for position lookup
     *     - Maps each token ID to its index in the tokenIds array
     *     - Zero index indicates non-existent position
     *
     * Usage Pattern:
     * - Updated when creating new Ramses V2 positions
     * - Referenced during position management
     * - Used for position value calculations
     * - Maintains efficient position tracking on Arbitrum
     *
     * Integration Points:
     * - Ramses V2 position management fuses
     * - Position value calculation systems
     * - Balance tracking mechanisms
     * - Arbitrum-specific liquidity operations
     *
     * Security Considerations:
     * - Must accurately track all vault positions
     * - Critical for Arbitrum liquidity management
     * - Requires careful index management
     * - Essential for position ownership verification
     * - Parallel structure to Uniswap V3 position tracking
     */
    bytes32 private constant RAMSES_V2_TOKEN_IDS = 0x1a3831a406f27d4d5d820158b29ce95a1e8e840bf416921917aa388e2461b700;

    /**
     * @dev Storage slot for managing Ebisu Troves position token IDs in the Plasma Vault
     * @notice Tracks and manages Ebisu Troves positions held by the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.EbisuTroveIds")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks all Ebisu Troves positions owned by the vault
     * - Enables efficient position management and lookup
     * - Supports concentrated liquidity position tracking
     * - Mirrors Uniswap V3-style position management for Arbitrum
     *
     * Storage Layout:
     * - Points to EbisuTroveIds struct containing:
     * -  uint256 latestOwnerIndex; the ownerIndex of the latest (only) open trove
     * -  mapping(address zapper => uint256 id) troveIds; mapping of troveId by zapper (for balance fuse)
     *
     * Usage Pattern:
     * - Updated when creating new Ebisu
     * - Referenced during position management
     * - Used for position value calculations
     * - Maintains efficient position tracking on Arbitrum
     *
     * Integration Points:
     * - Ebisu position management fuses
     * - Position value calculation systems
     * - Balance tracking mechanisms
     * - Arbitrum-specific liquidity operations
     *
     * Security Considerations:
     * - Must accurately track all vault positions
     * - Critical for Arbitrum liquidity management
     * - Requires careful index management
     * - Essential for position ownership verification
     * - Parallel structure to Uniswap V3 position tracking
     */
    bytes32 private constant EBISU_TROVE_IDS = 0x9b098fe9de431f116cec9bcef5a806a02e41a628f070feb12cb5ddc28d703300;

    /**
     * @dev Storage slot for managing Velodrome Superchain Slipstream NFT position token IDs in the Plasma Vault
     * @notice Tracks and manages Velodrome Superchain Slipstream LP positions held by the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.VelodromeSuperchainSlipstreamTokenIds")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks all Velodrome Superchain Slipstream NFT positions owned by the vault
     * - Enables efficient position management and lookup
     * - Supports concentrated liquidity position tracking
     * - Prevents DoS attacks via unbounded NFT enumeration
     *
     * Storage Layout:
     * - Points to VelodromeSuperchainSlipstreamTokenIds struct containing:
     *   - tokenIds: uint256[] array of Velodrome Superchain Slipstream NFT position IDs
     *   - indexes: mapping(uint256 tokenId => uint256 index) for position lookup
     *     - Maps each token ID to its index in the tokenIds array
     *     - Zero index indicates non-existent position
     *
     * Usage Pattern:
     * - Updated when creating new Velodrome Superchain Slipstream positions
     * - Referenced during position management
     * - Used for position value calculations
     * - Maintains efficient position tracking
     *
     * Integration Points:
     * - VelodromeSuperchainSlipstreamNewPositionFuse: Position creation and management
     * - VelodromeSuperchainSlipstreamBalanceFuse: Balance calculation systems
     * - Withdrawal and rebalancing operations
     *
     * Security Considerations:
     * - Must accurately track all vault positions
     * - Critical for proper liquidity management
     * - Requires careful index management
     * - Essential for position ownership verification
     * - Prevents DoS via malicious NFT transfers to vault
     */
    bytes32 private constant VELODROME_SUPERCHAIN_SLIPSTREAM_TOKEN_IDS =
        0xadec8ab8bc14c5c231913cd378fa94ac5788a64fe4296974cef061d370402200;

    /**
     * @dev Storage slot for managing Aerodrome Slipstream NFT position token IDs in the Plasma Vault
     * @notice Tracks and manages Aerodrome Slipstream LP positions held by the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.AerodromeSlipstreamTokenIds")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks all Aerodrome Slipstream NFT positions owned by the vault
     * - Enables efficient position management and lookup
     * - Supports concentrated liquidity position tracking
     * - Prevents DoS attacks via unbounded NFT enumeration
     *
     * Storage Layout:
     * - Points to AerodromeSlipstreamTokenIds struct containing:
     *   - tokenIds: uint256[] array of Aerodrome Slipstream NFT position IDs
     *   - indexes: mapping(uint256 tokenId => uint256 index) for position lookup
     *     - Maps each token ID to its index in the tokenIds array
     *     - Zero index indicates non-existent position
     *
     * Usage Pattern:
     * - Updated when creating new Aerodrome Slipstream positions
     * - Referenced during position management
     * - Used for position value calculations
     * - Maintains efficient position tracking
     *
     * Integration Points:
     * - AerodromeSlipstreamNewPositionFuse: Position creation and management
     * - AerodromeSlipstreamBalanceFuse: Balance calculation systems
     * - Withdrawal and rebalancing operations
     *
     * Security Considerations:
     * - Must accurately track all vault positions
     * - Critical for proper liquidity management
     * - Requires careful index management
     * - Essential for position ownership verification
     * - Prevents DoS via malicious NFT transfers to vault
     */
    bytes32 private constant AERODROME_SLIPSTREAM_TOKEN_IDS =
        0x0c954f82f9216b16230a9847b4d73bfde1ddedf5d9a25bf9eb22e669cbfcd600;

    /// @custom:storage-location erc7201:io.ipor.CfgFuses
    struct Fuses {
        /// @dev fuse address => If index = 0 - is not granted, otherwise - granted
        mapping(address fuse => uint256 index) value;
    }

    /// @custom:storage-location erc7201:io.ipor.CfgFusesArray
    struct FusesArray {
        /// @dev value is a fuse address
        address[] value;
    }

    /// @custom:storage-location erc7201:io.ipor.UniswapV3TokenIds
    struct UniswapV3TokenIds {
        uint256[] tokenIds;
        mapping(uint256 tokenId => uint256 index) indexes;
    }

    /// @custom:storage-location erc7201:io.ipor.RamsesV2TokenIds
    struct RamsesV2TokenIds {
        uint256[] tokenIds;
        mapping(uint256 tokenId => uint256 index) indexes;
    }

    /// @custom:storage-location erc7201:io.ipor.EbisuTroveIds
    struct EbisuTroveIds {
        uint256 latestOwnerIndex;
        mapping(address zapper => uint256 id) troveIds;
    }

    /// @custom:storage-location erc7201:io.ipor.VelodromeSuperchainSlipstreamTokenIds
    struct VelodromeSuperchainSlipstreamTokenIds {
        uint256[] tokenIds;
        mapping(uint256 tokenId => uint256 index) indexes;
    }

    /// @custom:storage-location erc7201:io.ipor.AerodromeSlipstreamTokenIds
    struct AerodromeSlipstreamTokenIds {
        uint256[] tokenIds;
        mapping(uint256 tokenId => uint256 index) indexes;
    }

    /// @notice Gets the fuses storage pointer
    function getFuses() internal pure returns (Fuses storage fuses) {
        assembly {
            fuses.slot := CFG_FUSES
        }
    }

    /// @notice Gets the fuses array storage pointer
    function getFusesArray() internal pure returns (FusesArray storage fusesArray) {
        assembly {
            fusesArray.slot := CFG_FUSES_ARRAY
        }
    }

    /// @notice Gets the UniswapV3TokenIds storage pointer
    function getUniswapV3TokenIds() internal pure returns (UniswapV3TokenIds storage uniswapV3TokenIds) {
        assembly {
            uniswapV3TokenIds.slot := UNISWAP_V3_TOKEN_IDS
        }
    }

    /// @notice Gets the RamsesV2TokenIds storage pointer
    function getRamsesV2TokenIds() internal pure returns (RamsesV2TokenIds storage ramsesV2TokenIds) {
        assembly {
            ramsesV2TokenIds.slot := RAMSES_V2_TOKEN_IDS
        }
    }

    /// @notice Gets the EbisuTroveIds storage pointer
    function getEbisuTroveIds() internal pure returns (EbisuTroveIds storage ebisuTroveIds) {
        assembly {
            ebisuTroveIds.slot := EBISU_TROVE_IDS
        }
    }

    /// @notice Gets the VelodromeSuperchainSlipstreamTokenIds storage pointer
    function getVelodromeSuperchainSlipstreamTokenIds()
        internal
        pure
        returns (VelodromeSuperchainSlipstreamTokenIds storage velodromeSuperchainSlipstreamTokenIds)
    {
        assembly {
            velodromeSuperchainSlipstreamTokenIds.slot := VELODROME_SUPERCHAIN_SLIPSTREAM_TOKEN_IDS
        }
    }

    /// @notice Gets the AerodromeSlipstreamTokenIds storage pointer
    function getAerodromeSlipstreamTokenIds()
        internal
        pure
        returns (AerodromeSlipstreamTokenIds storage aerodromeSlipstreamTokenIds)
    {
        assembly {
            aerodromeSlipstreamTokenIds.slot := AERODROME_SLIPSTREAM_TOKEN_IDS
        }
    }
}


// ===== FILE: FusesLib.sol =====

/**
 * @title Fuses Library - Core Component for Plasma Vault's Fuse Management System
 * @notice Library managing the lifecycle and configuration of fuses - specialized contracts that enable
 * the Plasma Vault to interact with external DeFi protocols
 * @dev This library is a critical component that:
 * 1. Manages the addition and removal of fuses to the vault system
 * 2. Handles balance fuse associations with specific markets
 * 3. Provides validation and access functions for fuse operations
 * 4. Maintains the integrity of fuse-market relationships
 *
 * Key Components:
 * - Fuse Management: Adding/removing supported fuses
 * - Balance Fuse Control: Market-specific balance tracking
 * - Validation Functions: Fuse support verification
 * - Storage Integration: Uses FuseStorageLib for persistent storage
 *
 * Integration Points:
 * - Used by PlasmaVault.execute() to validate fuse operations
 * - Used by PlasmaVaultGovernance.sol for fuse configuration
 * - Interacts with FuseStorageLib for storage management
 * - Coordinates with PlasmaVaultStorageLib for market data
 *
 * Security Considerations:
 * - Enforces strict validation of fuse addresses
 * - Prevents duplicate fuse registrations
 * - Ensures proper market-fuse relationships
 * - Manages balance fuse removal conditions
 * - Critical for vault's protocol integration security
 *
 * @custom:security-contact security@ipor.io
 */
library FusesLib {
    using Address for address;

    event FuseAdded(address fuse);
    event FuseRemoved(address fuse);
    event BalanceFuseAdded(uint256 marketId, address fuse);
    event BalanceFuseRemoved(uint256 marketId, address fuse);

    error FuseAlreadyExists();
    error FuseDoesNotExist();
    error FuseUnsupported(address fuse);
    error BalanceFuseAlreadyExists(uint256 marketId, address fuse);
    error BalanceFuseDoesNotExist(uint256 marketId, address fuse);
    error BalanceFuseNotReadyToRemove(uint256 marketId, address fuse, uint256 currentBalance);
    error BalanceFuseMarketIdMismatch(uint256 marketId, address fuse);
    /**
     * @notice Validates if a fuse contract is registered and supported by the Plasma Vault
     * @dev Checks the FuseStorageLib mapping to verify fuse registration status
     * - A non-zero value in the mapping indicates the fuse is supported
     * - The value represents (index + 1) in the fusesArray
     * - Used by PlasmaVault.execute() to validate fuse operations
     * - Critical for security as it prevents unauthorized protocol integrations
     *
     * Integration Context:
     * - Called before any fuse operation in PlasmaVault.execute()
     * - Used by PlasmaVaultGovernance for fuse management
     * - Part of the vault's protocol integration security layer
     *
     * @param fuse_ The address of the fuse contract to check
     * @return bool Returns true if the fuse is supported, false otherwise
     *
     * Security Notes:
     * - Zero address returns false
     * - Only fuses added through governance can return true
     * - Non-existent fuses return false
     */
    function isFuseSupported(address fuse_) internal view returns (bool) {
        return FuseStorageLib.getFuses().value[fuse_] != 0;
    }

    /**
     * @notice Validates if a fuse is configured as the balance fuse for a specific market
     * @dev Checks the PlasmaVaultStorageLib mapping to verify balance fuse assignment
     * - Each market can have only one balance fuse at a time
     * - Balance fuses are responsible for tracking market-specific asset balances
     * - Used for market balance validation and updates
     *
     * Integration Context:
     * - Used during market balance updates in PlasmaVault._updateMarketsBalances()
     * - Referenced during balance fuse configuration in PlasmaVaultGovernance
     * - Critical for asset distribution protection system
     *
     * Market Balance System:
     * - Balance fuses track protocol-specific positions (e.g., Compound, Aave positions)
     * - Provides standardized balance reporting across different protocols
     * - Essential for maintaining accurate vault accounting
     *
     * @param marketId_ The unique identifier of the market to check
     * @param fuse_ The address of the balance fuse contract to verify
     * @return bool Returns true if the fuse is the designated balance fuse for the market
     *
     * Security Notes:
     * - Returns false for non-existent market-fuse pairs
     * - Only one balance fuse can be active per market
     * - Critical for preventing unauthorized balance reporting
     */
    function isBalanceFuseSupported(uint256 marketId_, address fuse_) internal view returns (bool) {
        return PlasmaVaultStorageLib.getBalanceFuses().fuseAddresses[marketId_] == fuse_;
    }

    /**
     * @notice Retrieves the designated balance fuse contract address for a specific market
     * @dev Provides direct access to the balance fuse mapping in PlasmaVaultStorageLib
     * - Returns zero address if no balance fuse is configured for the market
     * - Each market can have only one active balance fuse at a time
     *
     * Integration Context:
     * - Used by PlasmaVault._updateMarketsBalances() for balance tracking
     * - Called during market balance validation and updates
     * - Referenced by AssetDistributionProtectionLib for limit checks
     *
     * Use Cases:
     * - Balance calculation during vault operations
     * - Market position valuation
     * - Asset distribution protection checks
     * - Protocol-specific balance queries
     *
     * @param marketId_ The unique identifier of the market
     * @return address The address of the balance fuse contract for the market
     *         Returns address(0) if no balance fuse is configured
     *
     * Related Components:
     * - CompoundV3BalanceFuse
     * - AaveV3BalanceFuse
     * - Other protocol-specific balance fuses
     */
    function getBalanceFuse(uint256 marketId_) internal view returns (address) {
        return PlasmaVaultStorageLib.getBalanceFuses().fuseAddresses[marketId_];
    }

    /**
     * @notice Retrieves the complete array of supported fuse contracts in the Plasma Vault
     * @dev Provides direct access to the fuses array from FuseStorageLib
     * - Array order is NOT guaranteed to match insertion order; removeFuse uses swap-and-pop which reorders elements
     * - Used for fuse enumeration and management
     * - Critical for vault configuration and auditing
     *
     * Storage Pattern:
     * - Array indices correspond to (mapping value - 1) in FuseStorageLib.Fuses
     * - Maintains parallel structure with fuse mapping
     * - No duplicates allowed
     *
     * Integration Context:
     * - Used by PlasmaVaultGovernance for fuse management
     * - Referenced during vault configuration
     * - Used for fuse system auditing and verification
     * - Supports protocol integration management
     *
     * Use Cases:
     * - Fuse system configuration validation
     * - Protocol integration auditing
     * - Governance operations
     * - System state inspection
     *
     * @return address[] Array of all supported fuse contract addresses
     *
     * Related Functions:
     * - addFuse(): Appends to this array
     * - removeFuse(): Uses swap-and-pop; does NOT preserve array ordering
     * - getFuseArrayIndex(): Maps addresses to indices
     */
    function getFusesArray() internal view returns (address[] memory) {
        return FuseStorageLib.getFusesArray().value;
    }

    /**
     * @notice Retrieves the storage index for a given fuse contract
     * @dev Maps fuse addresses to their position in the fuses array
     * - Returns the value from FuseStorageLib.Fuses mapping
     * - Return value is (array index + 1) to distinguish from unsupported fuses
     * - Zero return value indicates fuse is not supported
     *
     * Storage Pattern:
     * - Mapping value = array index + 1
     * - Example: value 1 means index 0 in fusesArray
     * - Zero value means fuse not supported
     *
     * Integration Context:
     * - Used during fuse removal operations
     * - Supports array maintenance in removeFuse()
     * - Helps maintain storage consistency
     *
     * Use Cases:
     * - Fuse removal operations
     * - Storage validation
     * - Fuse support verification
     * - Array index lookups
     *
     * @param fuse_ The address of the fuse contract to look up
     * @return uint256 The storage index value (array index + 1) of the fuse
     *         Returns 0 if fuse is not supported
     *
     * Related Functions:
     * - addFuse(): Sets this index
     * - removeFuse(): Uses this for array maintenance
     * - getFusesArray(): Contains fuses at these indices
     */
    function getFuseArrayIndex(address fuse_) internal view returns (uint256) {
        return FuseStorageLib.getFuses().value[fuse_];
    }

    /**
     * @notice Registers a new fuse contract in the Plasma Vault's supported fuses list
     * @dev Manages the addition of fuses to both mapping and array storage
     * - Updates FuseStorageLib.Fuses mapping
     * - Appends to FuseStorageLib.FusesArray
     * - Maintains storage consistency between mapping and array
     *
     * Storage Updates:
     * 1. Checks for existing fuse to prevent duplicates
     * 2. Assigns new index (length + 1) in mapping
     * 3. Appends fuse address to array
     * 4. Emits FuseAdded event
     *
     * Integration Context:
     * - Called by PlasmaVaultGovernance.addFuses()
     * - Part of vault's protocol integration system
     * - Used during initial vault setup and protocol expansion
     *
     * Error Conditions:
     * - Reverts with FuseAlreadyExists if fuse is already registered
     * - Zero address handling done at governance level
     *
     * @param fuse_ The address of the fuse contract to add
     * @custom:events Emits FuseAdded when successful
     *
     * Security Considerations:
     * - Only callable through governance
     * - Critical for protocol integration security
     * - Must maintain storage consistency
     * - Affects vault's supported protocol list
     *
     * Gas Considerations:
     * - One SSTORE for mapping update
     * - One SSTORE for array push
     * - Event emission
     */
    function addFuse(address fuse_) internal {
        FuseStorageLib.Fuses storage fuses = FuseStorageLib.getFuses();

        uint256 keyIndexValue = fuses.value[fuse_];

        if (keyIndexValue != 0) {
            revert FuseAlreadyExists();
        }

        uint256 newLastFuseId = FuseStorageLib.getFusesArray().value.length + 1;

        /// @dev for balance fuses, value is a index + 1 in the fusesArray
        fuses.value[fuse_] = newLastFuseId;

        FuseStorageLib.getFusesArray().value.push(fuse_);

        emit FuseAdded(fuse_);
    }

    /**
     * @notice Removes a fuse contract from the Plasma Vault's supported fuses list
     * @dev Manages removal while maintaining storage consistency using swap-and-pop pattern
     * - Updates both FuseStorageLib.Fuses mapping and FusesArray
     * - Uses efficient swap-and-pop for array maintenance
     *
     * Storage Updates:
     * 1. Verifies fuse exists and gets its index
     * 2. Moves last array element to removed fuse's position
     * 3. Updates mapping for moved element
     * 4. Clears removed fuse's mapping entry
     * 5. Pops last array element
     * 6. Emits FuseRemoved event
     *
     * Integration Context:
     * - Called by PlasmaVaultGovernance.removeFuses()
     * - Part of protocol integration management
     * - Used during vault maintenance and protocol removal
     *
     * Error Conditions:
     * - Reverts with FuseDoesNotExist if fuse not found
     * - Zero address handling done at governance level
     *
     * @param fuse_ The address of the fuse contract to remove
     * @custom:events Emits FuseRemoved when successful
     *
     * Security Considerations:
     * - Only callable through governance
     * - Must maintain mapping-array consistency
     * - Critical for protocol integration security
     * - Affects vault's supported protocol list
     *
     * Gas Optimization:
     * - Uses swap-and-pop instead of shifting array
     * - Minimizes storage operations
     * - Three SSTORE operations:
     *   1. Update moved element's mapping
     *   2. Clear removed fuse's mapping
     *   3. Pop array
     */
    function removeFuse(address fuse_) internal {
        FuseStorageLib.Fuses storage fuses = FuseStorageLib.getFuses();

        uint256 indexToRemove = fuses.value[fuse_];

        if (indexToRemove == 0) {
            revert FuseDoesNotExist();
        }

        address lastKeyInArray = FuseStorageLib.getFusesArray().value[FuseStorageLib.getFusesArray().value.length - 1];

        fuses.value[lastKeyInArray] = indexToRemove;

        fuses.value[fuse_] = 0;

        /// @dev balanceFuses mapping contains values as index + 1
        FuseStorageLib.getFusesArray().value[indexToRemove - 1] = lastKeyInArray;

        FuseStorageLib.getFusesArray().value.pop();

        emit FuseRemoved(fuse_);
    }

    /**
     * @notice Associates a balance tracking fuse with a specific market in the Plasma Vault
     * @dev Manages market-specific balance fuse assignments and maintains market tracking data structures
     * - Updates both fuse mapping and market tracking arrays
     * - Maintains O(1) lookup capabilities through index mapping
     *
     * Storage Updates:
     * 1. Validates no duplicate fuse assignment
     * 2. Updates fuseAddresses mapping with new fuse
     * 3. Adds market to tracking array
     * 4. Updates index mapping for O(1) lookup
     * 5. Emits BalanceFuseAdded event
     *
     * Storage Pattern:
     * - balanceFuses.indexes[marketId_] stores (array index + 1)
     * - Example: value 1 means index 0 in marketIds array
     * - Matches pattern used in FuseStorageLib.Fuses mapping
     * - Allows distinguishing between non-existent (0) and first position (1)
     *
     * Integration Context:
     * - Called by PlasmaVaultGovernance.addBalanceFuse()
     * - Part of market setup and configuration
     * - Integrates with PlasmaVaultStorageLib.BalanceFuses
     * - Supports multi-market balance tracking system
     *
     * Market Tracking:
     * - Maintains ordered list of active markets
     * - Enables efficient market iteration
     * - Supports O(1) market existence checks
     * - Critical for balance update operations
     *
     * Error Conditions:
     * - Reverts with BalanceFuseAlreadyExists if:
     *   - Market already has this balance fuse
     *   - Prevents duplicate assignments
     *
     * @param marketId_ The unique identifier of the market
     * @param fuse_ The address of the balance fuse contract
     * @custom:events Emits BalanceFuseAdded when successful
     *
     * Security Considerations:
     * - Only callable through governance
     * - Must maintain array-mapping consistency
     * - Critical for market balance tracking
     * - Affects asset distribution protection
     * - Requires proper fuse validation
     *
     * Integration Points:
     * - PlasmaVault._updateMarketsBalances: Uses registered fuses
     * - AssetDistributionProtectionLib: Market balance checks
     * - Balance Fuses: Protocol-specific balance tracking
     * - Market Operations: Balance validation and updates
     */
    function addBalanceFuse(uint256 marketId_, address fuse_) internal {
        address currentFuse = PlasmaVaultStorageLib.getBalanceFuses().fuseAddresses[marketId_];

        if (currentFuse == fuse_) {
            revert BalanceFuseAlreadyExists(marketId_, fuse_);
        }

        if (marketId_ != IFuseCommon(fuse_).MARKET_ID()) {
            revert BalanceFuseMarketIdMismatch(marketId_, fuse_);
        }

        _updateBalanceFuseStructWhenAdding(marketId_, fuse_);

        emit BalanceFuseAdded(marketId_, fuse_);
    }

    /**
     * @notice Removes a balance tracking fuse from a specific market in the Plasma Vault
     * @dev Manages safe removal of market-fuse associations and updates market tracking data structures
     * - Uses swap-and-pop pattern for efficient array maintenance
     * - Maintains O(1) lookup capabilities through index mapping
     *
     * Storage Updates:
     * 1. Validates correct fuse-market association
     * 2. Verifies balance is below dust threshold via delegatecall
     * 3. Clears fuseAddresses mapping entry
     * 4. Updates marketIds array using swap-and-pop
     * 5. Updates indexes mapping for moved market
     * 6. Emits BalanceFuseRemoved event
     *
     * Storage Pattern:
     * - balanceFuses.indexes[marketId_] stores (array index + 1)
     * - Example: value 1 means index 0 in marketIds array
     * - Matches pattern used in FuseStorageLib.Fuses mapping
     * - Allows distinguishing between non-existent (0) and first position (1)
     *
     * Integration Context:
     * - Called by PlasmaVaultGovernance.removeBalanceFuse()
     * - Part of market decommissioning process
     * - Integrates with PlasmaVaultStorageLib.BalanceFuses
     * - Coordinates with balance fuse contracts
     *
     * Market Tracking:
     * - Maintains integrity of active markets list
     * - Updates market indexes after removal
     * - Preserves O(1) lookup capability
     * - Ensures proper market list maintenance
     *
     * Balance Validation:
     * - Uses delegatecall to check current balance
     * - Compares against dust threshold based on decimals
     * - Prevents removal of active positions
     * - Dust threshold scales with token precision
     *
     * Error Conditions:
     * - Reverts with BalanceFuseDoesNotExist if:
     *   - Fuse not assigned to market
     *   - Wrong fuse-market pair provided
     * - Reverts with BalanceFuseNotReadyToRemove if:
     *   - Balance exceeds dust threshold
     *   - Active positions exist
     *
     * @param marketId_ The unique identifier of the market
     * @param fuse_ The address of the balance fuse contract to remove
     * @custom:events Emits BalanceFuseRemoved when successful
     *
     * Security Considerations:
     * - Only callable through governance
     * - Must maintain array-mapping consistency
     * - Requires safe delegatecall handling
     * - Critical for market decommissioning
     * - Protects against premature removal
     *
     * Integration Points:
     * - PlasmaVault._updateMarketsBalances: Affected by removals
     * - Balance Fuses: Balance validation
     * - Asset Protection: Market tracking updates
     * - Market Operations: State consistency
     *
     * Gas Optimization:
     * - Uses swap-and-pop for array maintenance
     * - Minimizes storage operations
     * - Efficient market list updates
     * - Optimized for minimal gas usage
     */
    function removeBalanceFuse(uint256 marketId_, address fuse_) internal {
        address currentBalanceFuse = PlasmaVaultStorageLib.getBalanceFuses().fuseAddresses[marketId_];

        if (marketId_ != IFuseCommon(fuse_).MARKET_ID()) {
            revert BalanceFuseMarketIdMismatch(marketId_, fuse_);
        }

        if (currentBalanceFuse != fuse_) {
            revert BalanceFuseDoesNotExist(marketId_, fuse_);
        }

        uint256 wadBalanceAmountInUSD = abi.decode(
            currentBalanceFuse.functionDelegateCall(abi.encodeWithSignature("balanceOf()")),
            (uint256)
        );

        if (wadBalanceAmountInUSD > _calculateAllowedDustInBalanceFuse()) {
            revert BalanceFuseNotReadyToRemove(marketId_, fuse_, wadBalanceAmountInUSD);
        }

        _updateBalanceFuseStructWhenRemoving(marketId_);

        emit BalanceFuseRemoved(marketId_, fuse_);
    }

    /**
     * @notice Retrieves the list of all active markets with registered balance fuses
     * @dev Provides direct access to the ordered array of active market IDs from BalanceFuses storage
     * - Returns the complete marketIds array without modifications
     * - Order of markets matches their registration sequence
     *
     * Storage Access:
     * - Reads from PlasmaVaultStorageLib.BalanceFuses.marketIds
     * - No storage modifications
     * - O(1) operation for array access
     * - Returns reference to complete array
     *
     * Integration Context:
     * - Used by PlasmaVault._updateMarketsBalances for iteration
     * - Referenced during multi-market operations
     * - Supports balance update coordination
     * - Essential for market state management
     *
     * Use Cases:
     * - Market balance updates
     * - Asset distribution checks
     * - Market state validation
     * - Protocol-wide operations
     *
     * Array Properties:
     * - Maintained by addBalanceFuse/removeBalanceFuse
     * - No duplicates allowed
     * - Order may change during removals (swap-and-pop)
     * - Empty array possible if no active markets
     *
     * @return uint256[] Array of active market IDs with registered balance fuses
     *
     * Integration Points:
     * - Balance Update System: Market iteration
     * - Asset Protection: Market validation
     * - Governance: Market monitoring
     * - Protocol Operations: State checks
     *
     * Performance Notes:
     * - Returns a memory copy of the storage array (not a storage reference)
     * - Gas cost scales linearly with the number of active markets due to the copy
     * - Suitable for view function calls
     */
    function getActiveMarketsInBalanceFuses() internal view returns (uint256[] memory) {
        return PlasmaVaultStorageLib.getBalanceFuses().marketIds;
    }

    /// @dev Returns dust threshold in WAD (18 decimals) to match balanceOf() which returns USD in WAD
    /// IL-6962 fix: Balance fuses return values in WAD format, so dust threshold must also be in WAD
    function _calculateAllowedDustInBalanceFuse() private view returns (uint256) {
        uint8 underlyingDecimals = PlasmaVaultStorageLib.getERC4626Storage().underlyingDecimals;
        return IporMath.convertToWad(10 ** (underlyingDecimals / 2), underlyingDecimals);
    }

    function _updateBalanceFuseStructWhenAdding(uint256 marketId_, address fuse_) private {
        PlasmaVaultStorageLib.BalanceFuses storage balanceFuses = PlasmaVaultStorageLib.getBalanceFuses();

        balanceFuses.fuseAddresses[marketId_] = fuse_;

        // @dev If marketId already has a fuse assigned, it's already in marketIds array,
        // @dev so skip adding it again to prevent duplicates. Only update the fuse address
        if (balanceFuses.indexes[marketId_] == 0) {
            uint256 newMarketIdIndexValue = balanceFuses.marketIds.length + 1;
            balanceFuses.marketIds.push(marketId_);
            balanceFuses.indexes[marketId_] = newMarketIdIndexValue;
        }
    }
    
    function _updateBalanceFuseStructWhenRemoving(uint256 marketId_) private {
        PlasmaVaultStorageLib.BalanceFuses storage balanceFuses = PlasmaVaultStorageLib.getBalanceFuses();

        delete balanceFuses.fuseAddresses[marketId_];

        uint256 indexValue = balanceFuses.indexes[marketId_];
        uint256 marketIdsLength = balanceFuses.marketIds.length;

        if (indexValue != marketIdsLength) {
            balanceFuses.marketIds[indexValue - 1] = balanceFuses.marketIds[marketIdsLength - 1];
            balanceFuses.indexes[balanceFuses.marketIds[marketIdsLength - 1]] = indexValue;
        }
        balanceFuses.marketIds.pop();

        delete balanceFuses.indexes[marketId_];
    }
}


// ===== FILE: PlasmaVaultStorageLib.sol =====

/**
 * @title Plasma Vault Storage Library
 * @notice Library managing storage layout and access for the PlasmaVault system using ERC-7201 namespaced storage pattern
 * @dev This library is a core component of the PlasmaVault system that:
 * 1. Defines and manages all storage structures using ERC-7201 namespaced storage pattern
 * 2. Provides storage access functions for PlasmaVault.sol, PlasmaVaultBase.sol and PlasmaVaultGovernance.sol
 * 3. Ensures storage safety for the upgradeable vault system
 *
 * Storage Components:
 * - Core ERC4626 vault storage (asset, decimals)
 * - Market management (assets, balances, substrates)
 * - Fee system storage (performance, management fees)
 * - Access control and execution state
 * - Fuse system configuration
 * - Price oracle and rewards management
 *
 * Key Integrations:
 * - Used by PlasmaVault.sol for core vault operations and asset management
 * - Used by PlasmaVaultGovernance.sol for configuration and admin functions
 * - Used by PlasmaVaultBase.sol for ERC20 functionality and access control
 *
 * Security Considerations:
 * - Uses ERC-7201 namespaced storage pattern to prevent storage collisions
 * - Each storage struct has a unique namespace derived from its purpose
 * - Critical for maintaining storage integrity in upgradeable contracts
 * - Storage slots are carefully chosen and must not be modified
 *
 * @custom:security-contact security@ipor.io
 */
library PlasmaVaultStorageLib {
    /**
     * @dev Storage slot for ERC4626 vault configuration following ERC-7201 namespaced storage pattern
     * @notice This storage location is used to store the core ERC4626 vault data (asset address and decimals)
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC4626")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Important:
     * - This value MUST NOT be changed as it's used by OpenZeppelin's ERC4626 implementation
     * - Changing this value would break storage compatibility with existing deployments
     * - Used by PlasmaVault.sol for core vault operations like deposit/withdraw
     *
     * Storage Layout:
     * - Points to ERC4626Storage struct containing:
     *   - asset: address of the underlying token
     *   - underlyingDecimals: decimals of the underlying token
     */
    bytes32 private constant ERC4626_STORAGE_LOCATION =
        0x0773e532dfede91f04b12a73d3d2acd361424f41f76b4fb79f090161e36b4e00;

    /**
     * @dev Storage slot for ERC20Capped configuration following ERC-7201 namespaced storage pattern
     * @notice This storage location manages the total supply cap functionality for the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20Capped")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Important:
     * - This value MUST NOT be changed as it's used by OpenZeppelin's ERC20Capped implementation
     * - Changing this value would break storage compatibility with existing deployments
     * - Used by PlasmaVault.sol and PlasmaVaultBase.sol for supply cap enforcement
     *
     * Storage Layout:
     * - Points to ERC20CappedStorage struct containing:
     *   - cap: maximum total supply denominated in shares (not in underlying asset decimals)
     *
     * Usage:
     * - Enforces maximum supply limits during minting operations
     * - Can be temporarily disabled for fee-related minting operations
     * - Critical for maintaining vault supply control
     */
    bytes32 private constant ERC20_CAPPED_STORAGE_LOCATION =
        0x0f070392f17d5f958cc1ac31867dabecfc5c9758b4a419a200803226d7155d00;

    /**
     * @dev Storage slot for managing the ERC20 supply cap validation state
     * @notice Controls whether total supply cap validation is active or temporarily disabled
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.Erc20CappedValidationFlag")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Provides a mechanism to temporarily disable supply cap checks
     * - Essential for special minting operations like fee distribution
     * - Used by PlasmaVault.sol during performance and management fee minting
     *
     * Storage Layout:
     * - Points to ERC20CappedValidationFlag struct containing:
     *   - value: flag indicating if cap validation is enabled (0) or disabled (1)
     *
     * Usage Pattern:
     * - Default state: Enabled (0) - enforces supply cap
     * - Temporarily disabled (1) during:
     *   - Performance fee minting
     *   - Management fee minting
     * - Always re-enabled after special minting operations
     *
     * Security Note:
     * - Critical for maintaining controlled token supply
     * - Only disabled briefly during authorized fee operations
     * - Must be properly re-enabled to prevent unlimited minting
     */
    bytes32 private constant ERC20_CAPPED_VALIDATION_FLAG =
        0xaef487a7a52e82ae7bbc470b42be72a1d3c066fb83773bf99cce7e6a7df2f900;

    /**
     * @dev Storage slot for tracking total assets across all markets in the Plasma Vault
     * @notice Maintains the global accounting of all assets managed by the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PlasmaVaultTotalAssetsInAllMarkets")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks the total value of assets managed by the vault across all markets
     * - Used for global vault accounting and share price calculations
     * - Critical for ERC4626 compliance and vault operations
     *
     * Storage Layout:
     * - Points to TotalAssets struct containing:
     *   - value: total assets in underlying token decimals
     *
     * Usage:
     * - Updated during deposit/withdraw operations
     * - Used in share price calculations
     * - Referenced for fee calculations
     * - Key component in asset distribution checks
     *
     * Integration Points:
     * - PlasmaVault.sol: Used in totalAssets() calculations
     * - Fee System: Used as base for fee calculations
     * - Asset Protection: Used in distribution limit checks
     *
     * Security Considerations:
     * - Must be accurately maintained for proper vault operation
     * - Critical for share price accuracy
     * - Any updates must consider all asset sources (markets, rewards, etc.)
     */
    bytes32 private constant PLASMA_VAULT_TOTAL_ASSETS_IN_ALL_MARKETS =
        0x24e02552e88772b8e8fd15f3e6699ba530635ffc6b52322da922b0b497a77300;

    /**
     * @dev Storage slot for tracking assets per individual market in the Plasma Vault
     * @notice Maintains per-market asset accounting for the vault's distributed positions
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PlasmaVaultTotalAssetsInMarket")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks assets allocated to each market individually
     * - Enables market-specific asset distribution control
     * - Used for market balance validation and limits enforcement
     *
     * Storage Layout:
     * - Points to MarketTotalAssets struct containing:
     *   - value: mapping(uint256 marketId => uint256 assets)
     *   - Assets stored in underlying token decimals
     *
     * Usage:
     * - Updated during market operations via fuses
     * - Used in market balance checks
     * - Referenced for market limit validations
     * - Key for asset distribution protection
     *
     * Integration Points:
     * - Balance Fuses: Update market balances
     * - Asset Distribution Protection: Enforce market limits
     * - Withdrawal Logic: Check available assets per market
     *
     * Security Considerations:
     * - Critical for market-specific asset limits
     * - Must be synchronized with actual market positions
     * - Updates protected by balance fuse system
     */
    bytes32 private constant PLASMA_VAULT_TOTAL_ASSETS_IN_MARKET =
        0x656f5ca8c676f20b936e991a840e1130bdd664385322f33b6642ec86729ee600;

    /**
     * @dev Storage slot for market substrates configuration in the Plasma Vault
     * @notice Manages the configuration of supported assets and sub-markets for each market
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultMarketSubstrates")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Defines which assets/sub-markets are supported in each market
     * - Controls market-specific asset allowances
     * - Essential for market integration configuration
     *
     * Storage Layout:
     * - Points to MarketSubstrates struct containing:
     *   - value: mapping(uint256 marketId => MarketSubstratesStruct)
     *     where MarketSubstratesStruct contains:
     *     - substrateAllowances: mapping(bytes32 => uint256) for permission control
     *     - substrates: bytes32[] list of supported substrates
     *
     * Usage:
     * - Configured by governance for each market
     * - Referenced during market operations
     * - Used by fuses to validate operations
     * - Controls which assets can be used in each market
     *
     * Integration Points:
     * - Fuse System: Validates allowed substrates
     * - Market Operations: Controls available assets
     * - Governance: Manages market configurations
     *
     * Security Considerations:
     * - Critical for controlling market access
     * - Only modifiable through governance
     * - Impacts market operation permissions
     */
    bytes32 private constant CFG_PLASMA_VAULT_MARKET_SUBSTRATES =
        0x78e40624004925a4ef6749756748b1deddc674477302d5b7fe18e5335cde3900;

    /**
     * @dev Storage slot for pre-hooks configuration in the Plasma Vault
     * @notice Manages function-specific pre-execution hooks and their implementations
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultPreHooks")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Maps function selectors to their pre-execution hook implementations
     * - Enables customizable pre-execution validation and logic
     * - Provides extensible function-specific behavior
     * - Coordinates cross-function state updates
     *
     * Storage Layout:
     * - Points to PreHooksConfig struct containing:
     *   - hooksImplementation: mapping(bytes4 selector => address implementation)
     *   - selectors: bytes4[] array of registered function selectors
     *   - indexes: mapping(bytes4 selector => uint256 index) for O(1) selector lookup
     *
     * Usage Pattern:
     * - Each function can have one designated pre-hook
     * - Hooks execute before main function logic
     * - Selector array enables efficient iteration over registered hooks
     * - Index mapping provides quick hook existence checks
     *
     * Integration Points:
     * - PlasmaVault.execute: Pre-execution hook invocation
     * - PreHooksHandler: Hook execution coordination
     * - PlasmaVaultGovernance: Hook configuration
     * - Function-specific hooks: Custom validation logic
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for function execution control
     * - Must validate hook implementations
     * - Requires careful state management
     * - Key component of vault security layer
     */
    bytes32 private constant CFG_PLASMA_VAULT_PRE_HOOKS =
        0xd334d8b26e68f82b7df26f2f64b6ffd2aaae5e2fc0e8c144c4b3598dcddd4b00;

    /**
     * @dev Storage slot for balance fuses configuration in the Plasma Vault
     * @notice Maps markets to their balance fuses and maintains an ordered list of active markets
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultBalanceFuses")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Associates balance fuses with specific markets for asset tracking
     * - Maintains ordered list of active markets for efficient iteration
     * - Enables market balance validation and updates
     * - Coordinates multi-market balance operations
     *
     * Storage Layout:
     * - Points to BalanceFuses struct containing:
     *   - fuseAddresses: mapping(uint256 marketId => address fuseAddress)
     *   - marketIds: uint256[] array of active market IDs
     *   - indexes: Maps market IDs to their position+1 in marketIds array
     *
     * Usage Pattern:
     * - Each market has one designated balance fuse
     * - Market IDs array enables efficient iteration over active markets
     * - Index mapping provides quick market existence checks
     * - Used during balance updates and market operations
     *
     * Integration Points:
     * - PlasmaVault._updateMarketsBalances: Market balance tracking
     * - Balance Fuses: Market position management
     * - PlasmaVaultGovernance: Fuse configuration
     * - Asset Protection: Balance validation
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for accurate asset tracking
     * - Must maintain market list integrity
     * - Requires proper fuse address validation
     * - Key component of vault accounting
     */
    bytes32 private constant CFG_PLASMA_VAULT_BALANCE_FUSES =
        0x150144dd6af711bac4392499881ec6649090601bd196a5ece5174c1400b1f700;

    /**
     * @dev Storage slot for instant withdrawal fuses configuration
     * @notice Stores ordered array of fuses that can be used for instant withdrawals
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultInstantWithdrawalFusesArray")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Maintains list of fuses available for instant withdrawals
     * - Defines order of withdrawal attempts
     * - Enables efficient withdrawal path selection
     *
     * Storage Layout:
     * - Points to InstantWithdrawalFuses struct containing:
     *   - value: address[] array of fuse addresses
     *   - Order of fuses in array determines withdrawal priority
     *
     * Usage:
     * - Referenced during withdrawal operations
     * - Used by PlasmaVault.sol in _withdrawFromMarkets
     * - Determines withdrawal execution sequence
     *
     * Integration Points:
     * - Withdrawal System: Defines available withdrawal paths
     * - Fuse System: Lists supported instant withdrawal fuses
     * - Governance: Manages withdrawal configuration
     *
     * Security Considerations:
     * - Order of fuses is critical for optimal withdrawals
     * - Same fuse can appear multiple times with different params
     * - Must be carefully managed to ensure withdrawal efficiency
     */
    bytes32 private constant CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_ARRAY =
        0xd243afa3da07e6bdec20fdd573a17f99411aa8a62ae64ca2c426d3a86ae0ac00;

    /**
     * @dev Storage slot for price oracle middleware configuration
     * @notice Stores the address of the price oracle middleware used for asset price conversions
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PriceOracleMiddleware")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Provides price feed access for asset valuations
     * - Essential for market value calculations
     * - Used in balance conversions and limit checks
     *
     * Storage Layout:
     * - Points to PriceOracleMiddleware struct containing:
     *   - value: address of the price oracle middleware contract
     *
     * Usage:
     * - Used during market balance updates
     * - Required for USD value calculations
     * - Critical for asset distribution checks
     *
     * Integration Points:
     * - Balance Fuses: Asset value calculations
     * - Market Operations: Price conversions
     * - Asset Protection: Value-based limits
     *
     * Security Considerations:
     * - Must point to a valid and secure price oracle
     * - Critical for accurate vault valuations
     * - Only updatable through governance
     */
    bytes32 private constant PRICE_ORACLE_MIDDLEWARE =
        0x0d761ae54d86fc3be4f1f2b44ade677efb1c84a85fc6bb1d087dc42f1e319a00;

    /**
     * @dev Storage slot for instant withdrawal fuse parameters configuration
     * @notice Maps fuses to their specific withdrawal parameters for instant withdrawal execution
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultInstantWithdrawalFusesParams")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Stores configuration parameters for each instant withdrawal fuse
     * - Enables customized withdrawal behavior per fuse
     * - Supports multiple parameter sets for the same fuse at different indices
     *
     * Storage Layout:
     * - Points to InstantWithdrawalFusesParams struct containing:
     *   - value: mapping(bytes32 => bytes32[]) where:
     *     - key: keccak256(abi.encodePacked(fuse address, index))
     *     - value: array of parameters specific to the fuse
     *
     * Parameter Structure:
     * - params[0]: Always represents withdrawal amount in underlying token
     * - params[1+]: Fuse-specific parameters (e.g., slippage, path, market-specific data)
     *
     * Usage Pattern:
     * - Referenced during instant withdrawal operations in PlasmaVault
     * - Parameters are passed to fuse's instantWithdraw function
     * - Supports multiple parameter sets for same fuse with different indices
     *
     * Integration Points:
     * - PlasmaVault._withdrawFromMarkets: Uses params for withdrawal execution
     * - PlasmaVaultGovernance: Manages parameter configuration
     * - Fuse Contracts: Receive and interpret parameters during withdrawal
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for controlling withdrawal behavior
     * - Parameters must be carefully validated per fuse requirements
     * - Order of parameters must match fuse expectations
     */
    bytes32 private constant CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_PARAMS =
        0x45a704819a9dcb1bb5b8cff129eda642cf0e926a9ef104e27aa53f1d1fa47b00;

    /**
     * @dev Storage slot for fee configuration in the Plasma Vault
     * @notice Manages the fee configuration including performance and management fees
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultFeeConfig")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Stores comprehensive fee configuration for the vault
     * - Manages both IPOR DAO and recipient-specific fee settings
     * - Enables flexible fee distribution model
     *
     * Storage Layout:
     * - Points to FeeConfig struct containing:
     *   - feeFactory: address of the FeeManagerFactory contract
     *   - iporDaoManagementFee: management fee percentage for IPOR DAO
     *   - iporDaoPerformanceFee: performance fee percentage for IPOR DAO
     *   - iporDaoFeeRecipientAddress: address receiving IPOR DAO fees
     *   - recipientManagementFees: array of management fee percentages for other recipients
     *   - recipientPerformanceFees: array of performance fee percentages for other recipients
     *
     * Fee Structure:
     * - Management fees: Continuous time-based fees on AUM
     * - Performance fees: Charged on positive vault performance
     * - All fees in basis points (1/10000)
     *
     * Integration Points:
     * - FeeManagerFactory: Deploys fee management contracts
     * - FeeManager: Handles fee calculations and distributions
     * - PlasmaVault: References for fee realizations
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Fee percentages must be within reasonable bounds
     * - Critical for vault economics and sustainability
     * - Must maintain proper recipient configurations
     */
    bytes32 private constant CFG_PLASMA_VAULT_FEE_CONFIG =
        0x78b5ce597bdb64d5aa30a201c7580beefe408ff13963b5d5f3dce2dc09e89c00;

    /**
     * @dev Storage slot for performance fee data in the Plasma Vault
     * @notice Stores current performance fee configuration and recipient information
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PlasmaVaultPerformanceFeeData")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Manages performance fee settings and collection
     * - Tracks fee recipient address
     * - Controls performance-based revenue sharing
     *
     * Storage Layout:
     * - Points to PerformanceFeeData struct containing:
     *   - feeAccount: address receiving performance fees
     *   - feeInPercentage: current fee rate (basis points, 1/10000)
     *
     * Fee Mechanics:
     * - Calculated on positive vault performance
     * - Applied during execute() operations
     * - Minted as new vault shares to fee recipient
     * - Charged only on realized gains
     *
     * Integration Points:
     * - PlasmaVault._addPerformanceFee: Fee calculation and minting
     * - FeeManager: Fee configuration management
     * - PlasmaVaultGovernance: Fee settings updates
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Fee percentage must be within defined limits
     * - Critical for fair value distribution
     * - Must maintain valid fee recipient address
     * - Requires careful handling during share minting
     */
    bytes32 private constant PLASMA_VAULT_PERFORMANCE_FEE_DATA =
        0x9399757a27831a6cfb6cf4cd5c97a908a2f8f41e95a5952fbf83a04e05288400;

    /**
     * @notice Stores management fee configuration and time tracking data
     * @dev Manages continuous fee collection with time-based accrual
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultManagementFeeData
     */
    bytes32 private constant PLASMA_VAULT_MANAGEMENT_FEE_DATA =
        0x239dd7e43331d2af55e2a25a6908f3bcec2957025f1459db97dcdc37c0003f00;

    /**
     * @dev Storage slot for rewards claim manager address
     * @notice Stores the address of the contract managing external protocol rewards
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.RewardsClaimManagerAddress")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Manages external protocol reward claims
     * - Tracks claimable rewards across integrated protocols
     * - Centralizes reward collection logic
     *
     * Storage Layout:
     * - Points to RewardsClaimManagerAddress struct containing:
     *   - value: address of the rewards claim manager contract
     *
     * Functionality:
     * - Coordinates reward claims from multiple protocols
     * - Tracks unclaimed rewards in underlying asset terms
     * - Included in total assets calculations when active
     * - Optional component (can be set to address(0))
     *
     * Integration Points:
     * - PlasmaVault._getGrossTotalAssets: Includes rewards in total assets
     * - PlasmaVault.claimRewards: Executes reward collection
     * - External protocols: Source of claimable rewards
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Must handle protocol-specific claim logic safely
     * - Critical for accurate reward accounting
     * - Requires careful integration testing
     * - Should handle failed claims gracefully
     */
    bytes32 private constant REWARDS_CLAIM_MANAGER_ADDRESS =
        0x08c469289c3f85d9b575f3ae9be6831541ff770a06ea135aa343a4de7c962d00;

    /**
     * @dev Storage slot for market allocation limits
     * @notice Controls maximum asset allocation per market in the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.MarketLimits")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Enforces market-specific allocation limits
     * - Prevents over-concentration in single markets
     * - Enables risk management through diversification
     *
     * Storage Layout:
     * - Points to MarketLimits struct containing:
     *   - limitInPercentage: mapping(uint256 marketId => uint256 limit)
     *   - Limits stored in basis points (1e18 = 100%)
     *
     * Limit Mechanics:
     * - Each market has independent allocation limit
     * - Limits are percentage of total vault assets
     * - Zero limit for marketId 0 deactivates all limits
     * - Non-zero limit for marketId 0 activates limit system
     *
     * Integration Points:
     * - AssetDistributionProtectionLib: Enforces limits
     * - PlasmaVault._updateMarketsBalances: Checks limits
     * - PlasmaVaultGovernance: Limit configuration
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for risk management
     * - Must handle percentage calculations carefully
     * - Requires proper market balance tracking
     * - Should prevent concentration risk
     */
    bytes32 private constant MARKET_LIMITS = 0xc2733c187287f795e2e6e84d35552a190e774125367241c3e99e955f4babf000;

    /**
     * @dev Storage slot for market balance dependency relationships
     * @notice Manages interconnected market balance update requirements
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.DependencyBalanceGraph")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks dependencies between market balances
     * - Ensures atomic balance updates across related markets
     * - Maintains consistency in cross-market positions
     *
     * Storage Layout:
     * - Points to DependencyBalanceGraph struct containing:
     *   - dependencyGraph: mapping(uint256 marketId => uint256[] marketIds)
     *   - Each market maps to array of dependent market IDs
     *
     * Dependency Mechanics:
     * - Markets can depend on multiple other markets
     * - When updating a market balance, all dependent markets must be updated
     * - Dependencies are unidirectional (A->B doesn't imply B->A)
     * - Empty dependency array means no dependencies
     *
     * Integration Points:
     * - PlasmaVault._checkBalanceFusesDependencies: Resolves update order
     * - PlasmaVault._updateMarketsBalances: Ensures complete updates
     * - PlasmaVaultGovernance: Dependency configuration
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Must prevent circular dependencies
     * - Critical for market balance integrity
     * - Requires careful dependency chain validation
     * - Should handle deep dependency trees efficiently
     */
    bytes32 private constant DEPENDENCY_BALANCE_GRAPH =
        0x82411e549329f2815579116a6c5e60bff72686c93ab5dba4d06242cfaf968900;

    /**
     * @dev Storage slot for tracking execution state of vault operations
     * @notice Controls execution flow and prevents concurrent operations in the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.executeRunning")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Prevents concurrent execution of vault operations
     * - Enables callback handling during execution
     * - Acts as a reentrancy guard for execute() operations
     *
     * Storage Layout:
     * - Points to ExecuteState struct containing:
     *   - value: uint256 flag indicating execution state
     *     - 0: No execution in progress
     *   - 1: Execution in progress
     *
     * Usage Pattern:
     * - Set to 1 at start of execute() operation
     * - Checked during callback handling
     * - Reset to 0 when execution completes
     * - Used by PlasmaVault.execute() and callback system
     *
     * Integration Points:
     * - PlasmaVault.execute: Sets/resets execution state
     * - CallbackHandlerLib: Validates callbacks during execution
     * - Fallback function: Routes callbacks during execution
     *
     * Security Considerations:
     * - Critical for preventing concurrent operations
     * - Must be properly reset after execution
     * - Protects against malicious callbacks
     * - Part of vault's security architecture
     */
    bytes32 private constant EXECUTE_RUNNING = 0x054644eb87255c1c6a2d10801735f52fa3b9d6e4477dbed74914d03844ab6600;

    /**
     * @dev Storage slot for callback handler mapping in the Plasma Vault
     * @notice Maps protocol-specific callbacks to their handler contracts
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.callbackHandler")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Routes protocol-specific callbacks to appropriate handlers
     * - Enables dynamic callback handling during vault operations
     * - Supports integration with external protocols
     * - Manages protocol-specific callback logic
     *
     * Storage Layout:
     * - Points to CallbackHandler struct containing:
     *   - callbackHandler: mapping(bytes32 => address)
     *     - key: keccak256(abi.encodePacked(sender, sig))
     *     - value: address of the handler contract
     *
     * Usage Pattern:
     * - Callbacks received during execute() operations
     * - Key generated from sender address and function signature
     * - Handler contract processes protocol-specific logic
     * - Only accessible when execution is in progress
     *
     * Integration Points:
     * - PlasmaVault.fallback: Routes incoming callbacks
     * - CallbackHandlerLib: Processes callback routing
     * - Protocol-specific handlers: Implement callback logic
     * - PlasmaVaultGovernance: Manages handler configuration
     *
     * Security Considerations:
     * - Only callable during active execution
     * - Handler addresses must be trusted
     * - Prevents unauthorized callback processing
     * - Critical for secure protocol integration
     * - Must validate callback sources
     */
    bytes32 private constant CALLBACK_HANDLER = 0xb37e8684757599da669b8aea811ee2b3693b2582d2c730fab3f4965fa2ec3e00;

    /**
     * @dev Storage slot for withdraw manager contract address
     * @notice Manages withdrawal controls and permissions in the Plasma Vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.WithdrawManager")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Controls withdrawal permissions and limits
     * - Manages withdrawal schedules and timing
     * - Enforces withdrawal restrictions
     * - Coordinates withdrawal validation
     *
     * Storage Layout:
     * - Points to WithdrawManager struct containing:
     *   - manager: address of the withdraw manager contract
     *   - Zero address indicates disabled withdrawal controls
     *
     * Usage Pattern:
     * - Checked during withdraw() and redeem() operations
     * - Validates withdrawal permissions
     * - Enforces withdrawal schedules
     * - Can be disabled by setting to address(0)
     *
     * Integration Points:
     * - PlasmaVault.withdraw: Checks withdrawal permissions
     * - PlasmaVault.redeem: Validates redemption requests
     * - PlasmaVaultGovernance: Manager configuration
     * - AccessManager: Permission coordination
     *
     * Security Considerations:
     * - Critical for controlling asset outflows
     * - Only modifiable through governance
     * - Must maintain withdrawal restrictions
     * - Coordinates with access control system
     * - Key component of vault security
     */
    bytes32 private constant WITHDRAW_MANAGER = 0x465d2ff0062318fe6f4c7e9ac78cfcd70bc86a1d992722875ef83a9770513100;

    /**
     * @dev Storage slot for plasma vault base address. Computed as:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.fusion.PlasmaVaultBase")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant PLASMA_VAULT_BASE_SLOT =
        0x708fd1151214a098976e0893cd3883792c21aeb94a31cd7733c8947c13c23000;

    /**
     * @dev Storage slot for share scale multiplier. Computed as:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.fusion.param.ShareScaleMultiplier")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SHARE_SCALE_MULTIPLIER_SLOT =
        0x5bb34fc23414cfe7e422518e1d8590877bcc5dcacad5f8689bfd98e9a05ac600;

    /**
     * @dev Storage slot for PlasmaVaultVotesPlugin address. Computed as:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.fusion.PlasmaVaultVotesPlugin")) - 1)) & ~bytes32(uint256(0xff))
     * @notice Stores address of PlasmaVaultVotesPlugin contract which provides optional ERC20Votes functionality
     */
    bytes32 private constant PLASMA_VAULT_VOTES_PLUGIN_SLOT =
        0x9a54c2c1797818ee85d1850742208f80368867ad13d3e45052e701201fa4af00;

    /**
     * @notice Maps callback signatures to their handler contracts
     * @dev Stores routing information for protocol-specific callbacks
     * @custom:storage-location erc7201:io.ipor.callbackHandler
     */
    struct CallbackHandler {
        /// @dev key: keccak256(abi.encodePacked(sender, sig)), value: handler address
        mapping(bytes32 key => address handler) callbackHandler;
    }

    /**
     * @notice Stores and manages per-market allocation limits for the vault
     * @custom:storage-location erc7201:io.ipor.MarketLimits
     */
    struct MarketLimits {
        mapping(uint256 marketId => uint256 limit) limitInPercentage;
    }

    /**
     * @notice Core storage for ERC4626 vault implementation
     * @dev Value taken from OpenZeppelin's ERC4626 implementation - DO NOT MODIFY
     * @custom:storage-location erc7201:openzeppelin.storage.ERC4626
     */
    struct ERC4626Storage {
        /// @dev underlying asset in Plasma Vault
        address asset;
        /// @dev underlying asset decimals in Plasma Vault
        uint8 underlyingDecimals;
    }

    /// @dev Value taken from ERC20VotesUpgradeable contract, don't change it!
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20Capped
    struct ERC20CappedStorage {
        /// @dev Maximum total supply cap denominated in shares (not in underlying asset decimals)
        uint256 cap;
    }

    /// @notice ERC20CappedValidationFlag is used to enable or disable the total supply cap validation during execution
    /// Required for situation when performance fee or management fee is minted for fee managers
    /// @custom:storage-location erc7201:io.ipor.Erc20CappedValidationFlag
    struct ERC20CappedValidationFlag {
        uint256 value;
    }

    /**
     * @notice Stores address of the contract managing protocol reward claims
     * @dev Optional component - can be set to address(0) to disable rewards
     * @custom:storage-location erc7201:io.ipor.RewardsClaimManagerAddress
     */
    struct RewardsClaimManagerAddress {
        /// @dev total assets in the Plasma Vault
        address value;
    }

    /**
     * @notice Tracks total assets across all markets in the vault
     * @dev Used for global accounting and share price calculations
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultTotalAssetsInAllMarkets
     */
    struct TotalAssets {
        /// @dev total assets in the Plasma Vault
        uint256 value;
    }

    /**
     * @notice Tracks per-market asset balances in the vault
     * @dev Used for market-specific accounting and limit enforcement
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultTotalAssetsInMarket
     */
    struct MarketTotalAssets {
        /// @dev marketId => total assets in the vault in the market
        mapping(uint256 => uint256) value;
    }

    /**
     * @notice Market Substrates configuration
     * @dev Substrate - abstract item in the market, could be asset or sub market in the external protocol, it could be any item required to calculate balance in the market
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultMarketSubstrates
     */
    struct MarketSubstratesStruct {
        /// @notice Define which substrates are allowed and supported in the market
        /// @dev key can be specific asset or sub market in a specific external protocol (market), value - 1 - granted, otherwise - not granted
        mapping(bytes32 => uint256) substrateAllowances;
        /// @dev it could be list of assets or sub markets in a specific protocol or any other ids required to calculate balance in the market (external protocol)
        bytes32[] substrates;
    }

    /**
     * @notice Maps markets to their supported substrate configurations
     * @dev Stores per-market substrate allowances and lists
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultMarketSubstrates
     */
    struct MarketSubstrates {
        /// @dev marketId => MarketSubstratesStruct
        mapping(uint256 => MarketSubstratesStruct) value;
    }

    /**
     * @notice Manages market-to-fuse mappings and active market tracking
     * @dev Provides efficient market lookup and iteration capabilities
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultBalanceFuses
     *
     * Storage Components:
     * - fuseAddresses: Maps each market to its designated balance fuse
     * - marketIds: Maintains ordered list of active markets for iteration
     * - indexes: Maps market IDs to their position+1 in marketIds array
     *
     * Key Features:
     * - Efficient market-fuse relationship management
     * - Fast market existence validation (index 0 means not present)
     * - Optimized iteration over active markets
     * - Maintains market list integrity
     *
     * Usage:
     * - Market balance tracking and validation
     * - Fuse assignment and management
     * - Market activation/deactivation
     * - Multi-market operations coordination
     *
     * Index Mapping Pattern:
     * - Stored value = actual array index + 1
     * - Value of 0 indicates market not present
     * - To get array index, subtract 1 from stored value
     * - Enables distinction between unset markets and first position
     *
     * Security Notes:
     * - Market IDs must be unique
     * - Index mapping must stay synchronized with array
     * - Fuse addresses must be validated before assignment
     * - Critical for vault's balance tracking system
     */
    struct BalanceFuses {
        /// @dev Maps market IDs to their corresponding balance fuse addresses
        mapping(uint256 marketId => address fuseAddress) fuseAddresses;
        /// @dev Ordered array of active market IDs for efficient iteration
        uint256[] marketIds;
        /// @dev Maps market IDs to their position+1 in the marketIds array (0 means not present)
        mapping(uint256 marketId => uint256 index) indexes;
    }

    /**
     * @notice Manages pre-execution hooks configuration for vault functions
     * @dev Provides efficient hook lookup and management for function-specific pre-execution logic
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultPreHooks
     *
     * Storage Components:
     * - hooksImplementation: Maps function selectors to their hook implementation contracts
     * - selectors: Maintains ordered list of registered function selectors
     * - indexes: Enables O(1) selector existence checks and array access
     *
     * Key Features:
     * - Efficient function-to-hook mapping management
     * - Fast hook implementation lookup
     * - Optimized iteration over registered hooks
     * - Maintains hook registry integrity
     *
     * Usage:
     * - Pre-execution validation and checks
     * - Custom function-specific behavior
     * - Hook registration and management
     * - Cross-function state coordination
     *
     * Security Notes:
     * - Function selectors must be unique
     * - Index mapping must stay synchronized with array
     * - Hook implementations must be validated before assignment
     * - Critical for vault's execution security layer
     */
    struct PreHooksConfig {
        /// @dev Maps function selectors to their corresponding hook implementation addresses
        mapping(bytes4 => address) hooksImplementation;
        /// @dev Ordered array of registered function selectors for efficient iteration
        bytes4[] selectors;
        /// @dev Maps function selectors to their position in the selectors array for O(1) lookup
        mapping(bytes4 selector => uint256 index) indexes;
        /// @dev Maps function selectors and addresses to their corresponding substrate ids
        /// @dev key is keccak256(abi.encodePacked(address, selector))
        mapping(bytes32 key => bytes32[] substrates) substrates;
    }

    /**
     * @notice Tracks dependencies between market balances for atomic updates
     * @dev Maps markets to their dependent markets requiring simultaneous balance updates
     * @custom:storage-location erc7201:io.ipor.BalanceDependenceGraph
     */
    struct DependencyBalanceGraph {
        mapping(uint256 marketId => uint256[] marketIds) dependencyGraph;
    }

    /**
     * @notice Stores ordered list of fuses available for instant withdrawals
     * @dev Order determines withdrawal attempt sequence, same fuse can appear multiple times
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultInstantWithdrawalFusesArray
     */
    struct InstantWithdrawalFuses {
        /// @dev value is a Fuse address used for instant withdrawal
        address[] value;
    }

    /**
     * @notice Stores parameters for instant withdrawal fuse operations
     * @dev Maps fuse+index pairs to their withdrawal configuration parameters
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultInstantWithdrawalFusesParams
     */
    struct InstantWithdrawalFusesParams {
        /// @dev key: fuse address and index in InstantWithdrawalFuses array, value: list of parameters used for instant withdrawal
        /// @dev first param always amount in underlying asset of PlasmaVault, second and next params are specific for the fuse and market
        mapping(bytes32 => bytes32[]) value;
    }

    /**
     * @notice Stores performance fee configuration and recipient data
     * @dev Manages fee percentage and recipient account for performance-based fees
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultPerformanceFeeData
     */
    struct PerformanceFeeData {
        address feeAccount;
        uint16 feeInPercentage;
    }

    /**
     * @notice Stores management fee configuration and time tracking data
     * @dev Manages continuous fee collection with time-based accrual
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultManagementFeeData
     */
    struct ManagementFeeData {
        address feeAccount;
        uint16 feeInPercentage;
        uint32 lastUpdateTimestamp;
    }

    /**
     * @notice Stores address of price oracle middleware for asset valuations
     * @dev Provides standardized price feed access for vault operations
     * @custom:storage-location erc7201:io.ipor.PriceOracleMiddleware
     */
    struct PriceOracleMiddleware {
        address value;
    }

    /**
     * @notice Tracks execution state of vault operations
     * @dev Used as a flag to prevent concurrent execution and manage callbacks
     * @custom:storage-location erc7201:io.ipor.executeRunning
     */
    struct ExecuteState {
        uint256 value;
    }

    /**
     * @notice Stores address of the contract managing withdrawal controls
     * @dev Handles withdrawal permissions, schedules and limits
     * @custom:storage-location erc7201:io.ipor.WithdrawManager
     */
    struct WithdrawManager {
        address manager;
    }

    function getERC4626Storage() internal pure returns (ERC4626Storage storage $) {
        assembly {
            $.slot := ERC4626_STORAGE_LOCATION
        }
    }

    function getERC20CappedStorage() internal pure returns (ERC20CappedStorage storage $) {
        assembly {
            $.slot := ERC20_CAPPED_STORAGE_LOCATION
        }
    }

    function getERC20CappedValidationFlag() internal pure returns (ERC20CappedValidationFlag storage $) {
        assembly {
            $.slot := ERC20_CAPPED_VALIDATION_FLAG
        }
    }

    function getTotalAssets() internal pure returns (TotalAssets storage totalAssets) {
        assembly {
            totalAssets.slot := PLASMA_VAULT_TOTAL_ASSETS_IN_ALL_MARKETS
        }
    }

    function getExecutionState() internal pure returns (ExecuteState storage executeRunning) {
        assembly {
            executeRunning.slot := EXECUTE_RUNNING
        }
    }

    function getCallbackHandler() internal pure returns (CallbackHandler storage handler) {
        assembly {
            handler.slot := CALLBACK_HANDLER
        }
    }

    function getDependencyBalanceGraph() internal pure returns (DependencyBalanceGraph storage dependencyBalanceGraph) {
        assembly {
            dependencyBalanceGraph.slot := DEPENDENCY_BALANCE_GRAPH
        }
    }

    function getMarketTotalAssets() internal pure returns (MarketTotalAssets storage marketTotalAssets) {
        assembly {
            marketTotalAssets.slot := PLASMA_VAULT_TOTAL_ASSETS_IN_MARKET
        }
    }

    function getMarketSubstrates() internal pure returns (MarketSubstrates storage marketSubstrates) {
        assembly {
            marketSubstrates.slot := CFG_PLASMA_VAULT_MARKET_SUBSTRATES
        }
    }

    function getBalanceFuses() internal pure returns (BalanceFuses storage balanceFuses) {
        assembly {
            balanceFuses.slot := CFG_PLASMA_VAULT_BALANCE_FUSES
        }
    }

    function getPreHooksConfig() internal pure returns (PreHooksConfig storage preHooksConfig) {
        assembly {
            preHooksConfig.slot := CFG_PLASMA_VAULT_PRE_HOOKS
        }
    }

    function getInstantWithdrawalFusesArray()
        internal
        pure
        returns (InstantWithdrawalFuses storage instantWithdrawalFuses)
    {
        assembly {
            instantWithdrawalFuses.slot := CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_ARRAY
        }
    }

    function getInstantWithdrawalFusesParams()
        internal
        pure
        returns (InstantWithdrawalFusesParams storage instantWithdrawalFusesParams)
    {
        assembly {
            instantWithdrawalFusesParams.slot := CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_PARAMS
        }
    }

    function getPriceOracleMiddleware() internal pure returns (PriceOracleMiddleware storage oracle) {
        assembly {
            oracle.slot := PRICE_ORACLE_MIDDLEWARE
        }
    }

    function getPerformanceFeeData() internal pure returns (PerformanceFeeData storage performanceFeeData) {
        assembly {
            performanceFeeData.slot := PLASMA_VAULT_PERFORMANCE_FEE_DATA
        }
    }

    function getManagementFeeData() internal pure returns (ManagementFeeData storage managementFeeData) {
        assembly {
            managementFeeData.slot := PLASMA_VAULT_MANAGEMENT_FEE_DATA
        }
    }

    function getRewardsClaimManagerAddress()
        internal
        pure
        returns (RewardsClaimManagerAddress storage rewardsClaimManagerAddress)
    {
        assembly {
            rewardsClaimManagerAddress.slot := REWARDS_CLAIM_MANAGER_ADDRESS
        }
    }

    function getMarketsLimits() internal pure returns (MarketLimits storage marketLimits) {
        assembly {
            marketLimits.slot := MARKET_LIMITS
        }
    }

    /// @dev IMPORTANT: The WITHDRAW_MANAGER slot was corrected in IL-6952 (audit R4H7).
    /// The previous slot value collided with CALLBACK_HANDLER at offset +0x11.
    /// All fuses that read/write this slot via delegatecall must use the corrected PlasmaVaultStorageLib.
    /// Affected fuses: BurnRequestFeeFuse, PlasmaVaultRequestSharesFuse, UpdateWithdrawManagerMaintenanceFuse.
    function getWithdrawManager() internal pure returns (WithdrawManager storage withdrawManager) {
        assembly {
            withdrawManager.slot := WITHDRAW_MANAGER
        }
    }

    /// @notice Gets the plasma vault base address from storage
    /// @return The address of the plasma vault base contract
    function getPlasmaVaultBase() internal view returns (address) {
        address base;
        assembly {
            base := sload(PLASMA_VAULT_BASE_SLOT)
        }
        return base;
    }

    /// @notice Sets the plasma vault base address in storage
    /// @param base_ The address of the plasma vault base contract
    function setPlasmaVaultBase(address base_) internal {
        assembly {
            sstore(PLASMA_VAULT_BASE_SLOT, base_)
        }
    }

    /// @notice Gets the share scale multiplier from storage
    /// @return The share scale multiplier value
    function getShareScaleMultiplier() internal view returns (uint256) {
        uint256 multiplier;
        assembly {
            multiplier := sload(SHARE_SCALE_MULTIPLIER_SLOT)
        }
        return multiplier;
    }

    /// @notice Sets the share scale multiplier in storage
    /// @param multiplier_ The share scale multiplier value
    function setShareScaleMultiplier(uint256 multiplier_) internal {
        assembly {
            sstore(SHARE_SCALE_MULTIPLIER_SLOT, multiplier_)
        }
    }

    /// @notice Gets the PlasmaVaultVotesPlugin address from storage
    /// @return The address of the PlasmaVaultVotesPlugin contract (optional ERC20Votes functionality)
    function getPlasmaVaultVotesPlugin() internal view returns (address) {
        address votesPlugin;
        assembly {
            votesPlugin := sload(PLASMA_VAULT_VOTES_PLUGIN_SLOT)
        }
        return votesPlugin;
    }

    /// @notice Sets the PlasmaVaultVotesPlugin address in storage
    /// @param votesPlugin_ The address of the PlasmaVaultVotesPlugin contract
    function setPlasmaVaultVotesPlugin(address votesPlugin_) internal {
        assembly {
            sstore(PLASMA_VAULT_VOTES_PLUGIN_SLOT, votesPlugin_)
        }
    }
}


// ===== FILE: PlasmaVaultConfigLib.sol =====

/// @title Plasma Vault Configuration Library responsible for managing the configuration of the Plasma Vault
library PlasmaVaultConfigLib {
    event MarketSubstratesGranted(uint256 marketId, bytes32[] substrates);

    /// @notice Checks if a given asset address is granted as a substrate for a specific market
    /// @dev This function is part of the Plasma Vault's substrate management system that controls which assets can be used in specific markets
    ///
    /// @param marketId_ The ID of the market to check
    /// @param substrateAsAsset The address of the asset to verify as a substrate
    /// @return bool True if the asset is granted as a substrate for the market, false otherwise
    ///
    /// @custom:security-notes
    /// - Substrates are stored internally as bytes32 values
    /// - Asset addresses are converted to bytes32 for storage efficiency
    /// - Part of the vault's asset distribution protection system
    ///
    /// @custom:context The function is used in conjunction with:
    /// - PlasmaVault's execute() function for validating market operations
    /// - PlasmaVaultGovernance's grantMarketSubstrates() for configuration
    /// - Asset distribution protection system for market limit enforcement
    ///
    /// @custom:example
    /// ```solidity
    /// // Check if USDC is granted for market 1
    /// bool isGranted = isSubstrateAsAssetGranted(1, USDC_ADDRESS);
    /// ```
    ///
    /// @custom:permissions
    /// - View function, no special permissions required
    /// - Substrate grants are managed by ATOMIST_ROLE through PlasmaVaultGovernance
    ///
    /// @custom:related-functions
    /// - grantMarketSubstrates(): For granting substrates to markets
    /// - isMarketSubstrateGranted(): For checking non-asset substrates
    /// - getMarketSubstrates(): For retrieving all granted substrates
    function isSubstrateAsAssetGranted(uint256 marketId_, address substrateAsAsset) internal view returns (bool) {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);
        return marketSubstrates.substrateAllowances[addressToBytes32(substrateAsAsset)] == 1;
    }

    /// @notice Validates if a substrate is granted for a specific market
    /// @dev Part of the Plasma Vault's substrate management system that enables flexible market configurations
    ///
    /// @param marketId_ The ID of the market to check
    /// @param substrate_ The bytes32 identifier of the substrate to verify
    /// @return bool True if the substrate is granted for the market, false otherwise
    ///
    /// @custom:security-notes
    /// - Substrates are stored and compared as raw bytes32 values
    /// - Used for both asset and non-asset substrates (e.g., vaults, parameters)
    /// - Critical for market access control and security
    ///
    /// @custom:context The function is used for:
    /// - Validating market operations in PlasmaVault.execute()
    /// - Checking substrate permissions before market interactions
    /// - Supporting various substrate types:
    ///   * Asset addresses (converted to bytes32)
    ///   * Protocol-specific vault identifiers
    ///   * Market parameters and configuration values
    ///
    /// @custom:example
    /// ```solidity
    /// // Check if a compound vault substrate is granted
    /// bytes32 vaultId = keccak256(abi.encode("compound-vault-1"));
    /// bool isGranted = isMarketSubstrateGranted(1, vaultId);
    ///
    /// // Check if a market parameter is granted
    /// bytes32 param = bytes32("max-leverage");
    /// bool isParamGranted = isMarketSubstrateGranted(1, param);
    /// ```
    ///
    /// @custom:permissions
    /// - View function, no special permissions required
    /// - Substrate grants are managed by ATOMIST_ROLE through PlasmaVaultGovernance
    ///
    /// @custom:related-functions
    /// - isSubstrateAsAssetGranted(): For checking asset-specific substrates
    /// - grantMarketSubstrates(): For granting substrates to markets
    /// - getMarketSubstrates(): For retrieving all granted substrates
    function isMarketSubstrateGranted(uint256 marketId_, bytes32 substrate_) internal view returns (bool) {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);
        return marketSubstrates.substrateAllowances[substrate_] == 1;
    }

    /// @notice Retrieves all granted substrates for a specific market
    /// @dev Part of the Plasma Vault's substrate management system that provides visibility into market configurations
    ///
    /// @param marketId_ The ID of the market to query
    /// @return bytes32[] Array of all granted substrate identifiers for the market
    ///
    /// @custom:security-notes
    /// - Returns raw bytes32 values that may represent different substrate types
    /// - Order of substrates in array is preserved from grant operations
    /// - Empty array indicates no substrates are granted
    ///
    /// @custom:context The function is used for:
    /// - Auditing market configurations
    /// - Validating substrate grants during governance operations
    /// - Supporting UI/external systems that need market configuration data
    /// - Debugging and monitoring market setups
    ///
    /// @custom:substrate-types The returned array may contain:
    /// - Asset addresses (converted to bytes32)
    /// - Protocol-specific vault identifiers
    /// - Market parameters and configuration values
    /// - Any other substrate type granted to the market
    ///
    /// @custom:example
    /// ```solidity
    /// // Get all substrates for market 1
    /// bytes32[] memory substrates = getMarketSubstrates(1);
    ///
    /// // Process different substrate types
    /// for (uint256 i = 0; i < substrates.length; i++) {
    ///     if (isSubstrateAsAssetGranted(1, bytes32ToAddress(substrates[i]))) {
    ///         // Handle asset substrate
    ///     } else {
    ///         // Handle other substrate type
    ///     }
    /// }
    /// ```
    ///
    /// @custom:permissions
    /// - View function, no special permissions required
    /// - Useful for both governance and user interfaces
    ///
    /// @custom:related-functions
    /// - isMarketSubstrateGranted(): For checking individual substrate grants
    /// - grantMarketSubstrates(): For modifying substrate grants
    /// - bytes32ToAddress(): For converting asset substrates back to addresses
    function getMarketSubstrates(uint256 marketId_) internal view returns (bytes32[] memory) {
        return _getMarketSubstrates(marketId_).substrates;
    }

    /// @notice Grants or updates substrate permissions for a specific market
    /// @dev Core function for managing market substrate configurations in the Plasma Vault system
    ///
    /// @param marketId_ The ID of the market to configure
    /// @param substrates_ Array of substrate identifiers to grant to the market
    ///
    /// @custom:security-notes
    /// - Revokes all existing substrate grants before applying new ones
    /// - Atomic operation - either all substrates are granted or none
    /// - Emits MarketSubstratesGranted event for tracking changes
    /// - Critical for market security and access control
    ///
    /// @custom:context The function is used for:
    /// - Initial market setup by governance
    /// - Updating market configurations
    /// - Managing protocol integrations
    /// - Controlling asset access per market
    ///
    /// @custom:substrate-handling
    /// - Accepts both asset and non-asset substrates:
    ///   * Asset addresses (converted to bytes32)
    ///   * Protocol-specific vault identifiers
    ///   * Market parameters
    ///   * Configuration values
    /// - Maintains a list of active substrates
    /// - Updates allowance mapping for each substrate
    ///
    /// @custom:example
    /// ```solidity
    /// // Grant multiple substrates to market 1
    /// bytes32[] memory substrates = new bytes32[](2);
    /// substrates[0] = addressToBytes32(USDC_ADDRESS);
    /// substrates[1] = keccak256(abi.encode("compound-vault-1"));
    /// grantMarketSubstrates(1, substrates);
    /// ```
    ///
    /// @custom:permissions
    /// - Should only be called by authorized governance functions
    /// - Typically restricted to ATOMIST_ROLE
    /// - Critical for vault security
    ///
    /// @custom:related-functions
    /// - isMarketSubstrateGranted(): For checking granted substrates
    /// - getMarketSubstrates(): For viewing current grants
    /// - grantSubstratesAsAssetsToMarket(): For asset-specific grants
    ///
    /// @custom:events
    /// - Emits MarketSubstratesGranted(marketId, substrates)
    function grantMarketSubstrates(uint256 marketId_, bytes32[] memory substrates_) internal {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);

        _revokeMarketSubstrates(marketSubstrates);

        bytes32[] memory list = new bytes32[](substrates_.length);
        for (uint256 i; i < substrates_.length; ++i) {
            marketSubstrates.substrateAllowances[substrates_[i]] = 1;
            list[i] = substrates_[i];
        }

        marketSubstrates.substrates = list;

        emit MarketSubstratesGranted(marketId_, substrates_);
    }

    /// @notice Grants asset-specific substrates to a market
    /// @dev Specialized function for managing asset-type substrates in the Plasma Vault system
    ///
    /// @param marketId_ The ID of the market to configure
    /// @param substratesAsAssets_ Array of asset addresses to grant as substrates
    ///
    /// @custom:security-notes
    /// - Revokes all existing substrate grants before applying new ones
    /// - Converts addresses to bytes32 for storage efficiency
    /// - Atomic operation - either all assets are granted or none
    /// - Emits MarketSubstratesGranted event with converted addresses
    /// - Critical for market asset access control
    ///
    /// @custom:context The function is used for:
    /// - Setting up asset permissions for markets
    /// - Managing DeFi protocol integrations
    /// - Controlling which tokens can be used in specific markets
    /// - Implementing asset-based strategies
    ///
    /// @custom:implementation-details
    /// - Converts each address to bytes32 using addressToBytes32()
    /// - Updates both allowance mapping and substrate list
    /// - Maintains consistency between address and bytes32 representations
    /// - Ensures proper event emission with converted values
    ///
    /// @custom:example
    /// ```solidity
    /// // Grant USDC and DAI access to market 1
    /// address[] memory assets = new address[](2);
    /// assets[0] = USDC_ADDRESS;
    /// assets[1] = DAI_ADDRESS;
    /// grantSubstratesAsAssetsToMarket(1, assets);
    /// ```
    ///
    /// @custom:permissions
    /// - Should only be called by authorized governance functions
    /// - Typically restricted to ATOMIST_ROLE
    /// - Critical for vault security and asset management
    ///
    /// @custom:related-functions
    /// - grantMarketSubstrates(): For granting general substrates
    /// - isSubstrateAsAssetGranted(): For checking asset grants
    /// - addressToBytes32(): For address conversion
    ///
    /// @custom:events
    /// - Emits MarketSubstratesGranted(marketId, convertedSubstrates)
    function grantSubstratesAsAssetsToMarket(uint256 marketId_, address[] calldata substratesAsAssets_) internal {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);

        _revokeMarketSubstrates(marketSubstrates);

        bytes32[] memory list = new bytes32[](substratesAsAssets_.length);

        for (uint256 i; i < substratesAsAssets_.length; ++i) {
            marketSubstrates.substrateAllowances[addressToBytes32(substratesAsAssets_[i])] = 1;
            list[i] = addressToBytes32(substratesAsAssets_[i]);
        }

        marketSubstrates.substrates = list;

        emit MarketSubstratesGranted(marketId_, list);
    }

    /// @notice Converts an Ethereum address to its bytes32 representation for substrate storage
    /// @dev Core utility function for substrate address handling in the Plasma Vault system
    ///
    /// @param address_ The Ethereum address to convert
    /// @return bytes32 The bytes32 representation of the address
    ///
    /// @custom:security-notes
    /// - Performs unchecked conversion from address to bytes32
    /// - Pads the address (20 bytes) with zeros to fill bytes32 (32 bytes)
    /// - Used for storage efficiency in substrate mappings
    /// - Critical for consistent substrate identifier handling
    ///
    /// @custom:context The function is used for:
    /// - Converting asset addresses for substrate storage
    /// - Maintaining consistent substrate identifier format
    /// - Supporting the substrate allowance system
    /// - Enabling efficient storage and comparison operations
    ///
    /// @custom:implementation-details
    /// - Uses uint160 casting to handle address bytes
    /// - Follows standard Solidity type conversion patterns
    /// - Zero-pads the upper bytes implicitly
    /// - Maintains compatibility with bytes32ToAddress()
    ///
    /// @custom:example
    /// ```solidity
    /// // Convert USDC address to substrate identifier
    /// bytes32 usdcSubstrate = addressToBytes32(USDC_ADDRESS);
    ///
    /// // Use in substrate allowance mapping
    /// marketSubstrates.substrateAllowances[usdcSubstrate] = 1;
    /// ```
    ///
    /// @custom:permissions
    /// - Pure function, no state modifications
    /// - Can be called by any function
    /// - Used internally for substrate management
    ///
    /// @custom:related-functions
    /// - bytes32ToAddress(): Complementary conversion function
    /// - grantSubstratesAsAssetsToMarket(): Uses this for address conversion
    /// - isSubstrateAsAssetGranted(): Uses converted values for comparison
    function addressToBytes32(address address_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(address_)));
    }

    /// @notice Converts a bytes32 substrate identifier to its corresponding address representation
    /// @dev Core utility function for substrate address handling in the Plasma Vault system
    ///
    /// @param substrate_ The bytes32 substrate identifier to convert
    /// @return address The resulting Ethereum address
    ///
    /// @custom:security-notes
    /// - Performs unchecked conversion from bytes32 to address
    /// - Only the last 20 bytes (160 bits) are used
    /// - Should only be used for known substrate conversions
    /// - Critical for proper asset substrate handling
    ///
    /// @custom:context The function is used for:
    /// - Converting stored substrate identifiers back to asset addresses
    /// - Processing asset-type substrates in market operations
    /// - Interfacing with external protocols using addresses
    /// - Validating asset substrate configurations
    ///
    /// @custom:implementation-details
    /// - Uses uint160 casting to ensure proper address size
    /// - Follows standard Solidity address conversion pattern
    /// - Maintains compatibility with addressToBytes32()
    /// - Zero-pads the upper bytes implicitly
    ///
    /// @custom:example
    /// ```solidity
    /// // Convert a stored substrate back to an asset address
    /// bytes32 storedSubstrate = marketSubstrates.substrates[0];
    /// address assetAddress = bytes32ToAddress(storedSubstrate);
    ///
    /// // Use in asset validation
    /// if (assetAddress == USDC_ADDRESS) {
    ///     // Handle USDC-specific logic
    /// }
    /// ```
    ///
    /// @custom:related-functions
    /// - addressToBytes32(): Complementary conversion function
    /// - isSubstrateAsAssetGranted(): Uses this for address comparison
    /// - getMarketSubstrates(): Returns values that may need conversion
    function bytes32ToAddress(bytes32 substrate_) internal pure returns (address) {
        return address(uint160(uint256(substrate_)));
    }

    /// @notice Gets the market substrates configuration for a specific market
    function _getMarketSubstrates(
        uint256 marketId_
    ) private view returns (PlasmaVaultStorageLib.MarketSubstratesStruct storage) {
        return PlasmaVaultStorageLib.getMarketSubstrates().value[marketId_];
    }

    function getMarketSubstratesStorage(
        uint256 marketId_
    ) internal view returns (PlasmaVaultStorageLib.MarketSubstratesStruct storage) {
        return PlasmaVaultStorageLib.getMarketSubstrates().value[marketId_];
    }

    function _revokeMarketSubstrates(PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates) private {
        uint256 length = marketSubstrates.substrates.length;
        for (uint256 i; i < length; ++i) {
            marketSubstrates.substrateAllowances[marketSubstrates.substrates[i]] = 0;
        }
    }
}


// ===== FILE: PlasmaVaultLib.sol =====

/// @title InstantWithdrawalFusesParamsStruct
/// @notice A technical struct used to configure instant withdrawal fuses and their parameters in the Plasma Vault system
/// @dev This struct is used primarily in configureInstantWithdrawalFuses function to set up withdrawal paths
struct InstantWithdrawalFusesParamsStruct {
    /// @notice The address of the fuse contract that handles a specific withdrawal path
    /// @dev Must be a valid and supported fuse contract address that implements instant withdrawal logic
    address fuse;
    /// @notice Array of parameters specific to the fuse's withdrawal logic
    /// @dev Parameter structure:
    /// - params[0]: Always represents the withdrawal amount in underlying token decimals (set during withdrawal, not during configuration)
    /// - params[1+]: Additional fuse-specific parameters such as:
    ///   - Asset addresses
    ///   - Market IDs
    ///   - Slippage tolerances
    ///   - Protocol-specific parameters
    /// @dev The same fuse can appear multiple times with different params for different withdrawal paths
    bytes32[] params;
}

/// @title Plasma Vault Library
/// @notice Core library responsible for managing the Plasma Vault's state and operations
/// @dev Provides centralized management of vault operations, fees, configuration and state updates
///
/// Key responsibilities:
/// - Asset management and accounting
/// - Fee configuration and calculations
/// - Market balance tracking and updates
/// - Withdrawal system configuration
/// - Access control and execution state
/// - Price oracle integration
/// - Rewards claim management
library PlasmaVaultLib {
    using SafeCast for uint256;
    using SafeCast for int256;

    /// @dev Hard CAP for the performance fee in percentage - 50%
    uint256 public constant PERFORMANCE_MAX_FEE_IN_PERCENTAGE = 5000;

    /// @dev Hard CAP for the management fee in percentage - 5%
    uint256 public constant MANAGEMENT_MAX_FEE_IN_PERCENTAGE = 500;

    /// @dev The offset for the underlying asset decimals in the Plasma Vault
    uint8 public constant DECIMALS_OFFSET = 2;

    error InvalidPerformanceFee(uint256 feeInPercentage);
    error InvalidManagementFee(uint256 feeInPercentage);
    /// @notice Error thrown when instant withdrawal fuse index is out of bounds
    error InstantWithdrawalFuseIndexOutOfBounds(uint256 index, uint256 arrayLength);

    event InstantWithdrawalFusesConfigured(InstantWithdrawalFusesParamsStruct[] fuses);
    event PriceOracleMiddlewareChanged(address newPriceOracleMiddleware);
    event PerformanceFeeDataConfigured(address feeAccount, uint256 feeInPercentage);
    event ManagementFeeDataConfigured(address feeAccount, uint256 feeInPercentage);
    event RewardsClaimManagerAddressChanged(address newRewardsClaimManagerAddress);
    event DependencyBalanceGraphChanged(uint256 marketId, uint256[] newDependenceGraph);
    event WithdrawManagerChanged(address newWithdrawManager);
    event TotalSupplyCapChanged(uint256 newTotalSupplyCap);

    /// @notice Gets the total assets in the vault for all markets
    /// @dev Retrieves the total value of assets across all integrated markets and protocols
    /// @return uint256 The total assets in the vault, represented in decimals of the underlying asset
    ///
    /// This function:
    /// - Returns the raw total of assets without considering:
    ///   - Unrealized management fees
    ///   - Unrealized performance fees
    ///   - Pending rewards
    ///   - Current vault balance
    ///
    /// Used by:
    /// - PlasmaVault.totalAssets() for share price calculations
    /// - Fee calculations and accrual
    /// - Asset distribution checks
    /// - Market limit validations
    ///
    /// @dev Important: This value represents only the tracked assets in markets,
    /// for full vault assets see PlasmaVault._getGrossTotalAssets()
    function getTotalAssetsInAllMarkets() internal view returns (uint256) {
        return PlasmaVaultStorageLib.getTotalAssets().value;
    }

    /// @notice Gets the total assets in the vault for a specific market
    /// @param marketId_ The ID of the market to query
    /// @return uint256 The total assets in the vault for the market, represented in decimals of the underlying asset
    ///
    /// @dev This function provides market-specific asset tracking and is used for:
    /// - Market balance validation
    /// - Asset distribution checks
    /// - Market limit enforcement
    /// - Balance dependency resolution
    ///
    /// Important considerations:
    /// - Returns raw balance without considering fees
    /// - Value is updated by balance fuses during market interactions
    /// - Used in conjunction with market dependency graphs
    /// - Critical for maintaining proper asset distribution across markets
    ///
    /// Integration points:
    /// - Balance Fuses: Update market balances
    /// - Asset Distribution Protection: Check market limits
    /// - Withdrawal System: Verify available assets
    /// - Market Dependencies: Track related market updates
    function getTotalAssetsInMarket(uint256 marketId_) internal view returns (uint256) {
        return PlasmaVaultStorageLib.getMarketTotalAssets().value[marketId_];
    }

    /// @notice Gets the dependency balance graph for a specific market
    /// @param marketId_ The ID of the market to query
    /// @return uint256[] Array of market IDs that depend on the queried market
    ///
    /// @dev The dependency balance graph is critical for maintaining consistent state across related markets:
    /// - Ensures atomic balance updates across dependent markets
    /// - Prevents inconsistent states in interconnected protocols
    /// - Manages complex market relationships
    ///
    /// Use cases:
    /// - Market balance updates
    /// - Withdrawal validations
    /// - Asset rebalancing
    /// - Protocol integrations
    ///
    /// Example dependencies:
    /// - Lending markets depending on underlying asset markets
    /// - LP token markets depending on constituent token markets
    /// - Derivative markets depending on base asset markets
    ///
    /// Important considerations:
    /// - Dependencies are unidirectional (A->B doesn't imply B->A)
    /// - Empty array means no dependencies
    /// - Order of dependencies may matter for some operations
    /// - Used by _checkBalanceFusesDependencies() during balance updates
    function getDependencyBalanceGraph(uint256 marketId_) internal view returns (uint256[] memory) {
        return PlasmaVaultStorageLib.getDependencyBalanceGraph().dependencyGraph[marketId_];
    }

    /// @notice Updates the dependency balance graph for a specific market
    /// @param marketId_ The ID of the market to update
    /// @param newDependenceGraph_ Array of market IDs that should depend on this market
    /// @dev Updates the market dependency relationships and emits an event
    ///
    /// This function:
    /// - Overwrites existing dependencies for the market
    /// - Establishes new dependency relationships
    /// - Triggers event for dependency tracking
    ///
    /// Security considerations:
    /// - Only callable by authorized governance functions
    /// - Critical for maintaining market balance consistency
    /// - Must prevent circular dependencies
    /// - Should validate market existence
    ///
    /// Common update scenarios:
    /// - Adding new market dependencies
    /// - Removing obsolete dependencies
    /// - Modifying existing dependency chains
    /// - Protocol integration changes
    ///
    /// @dev Important: Changes to dependency graph affect:
    /// - Balance update order
    /// - Withdrawal validations
    /// - Market rebalancing operations
    /// - Protocol interaction flows
    function updateDependencyBalanceGraph(uint256 marketId_, uint256[] memory newDependenceGraph_) internal {
        PlasmaVaultStorageLib.getDependencyBalanceGraph().dependencyGraph[marketId_] = newDependenceGraph_;
        emit DependencyBalanceGraphChanged(marketId_, newDependenceGraph_);
    }

    /// @notice Adds or subtracts an amount from the total assets in the Plasma Vault
    /// @param amount_ The signed amount to adjust total assets by, represented in decimals of the underlying asset
    /// @dev Updates the global total assets tracker based on market operations
    ///
    /// Function behavior:
    /// - Positive amount: Increases total assets
    /// - Negative amount: Decreases total assets
    /// - Zero amount: No effect
    ///
    /// Used during:
    /// - Market balance updates
    /// - Fee realizations
    /// - Asset rebalancing
    /// - Withdrawal processing
    ///
    /// Security considerations:
    /// - Handles signed integers safely using SafeCast
    /// - Only called during validated operations
    /// - Must maintain accounting consistency
    /// - Critical for share price calculations
    ///
    /// @dev Important: This function affects:
    /// - Total vault valuation
    /// - Share price calculations
    /// - Fee calculations
    /// - Asset distribution checks
    function addToTotalAssetsInAllMarkets(int256 amount_) internal {
        if (amount_ < 0) {
            PlasmaVaultStorageLib.getTotalAssets().value -= (-amount_).toUint256();
        } else {
            PlasmaVaultStorageLib.getTotalAssets().value += amount_.toUint256();
        }
    }

    /// @notice Updates the total assets in the Plasma Vault for a specific market
    /// @param marketId_ The ID of the market to update
    /// @param newTotalAssetsInUnderlying_ The new total assets value for the market
    /// @return deltaInUnderlying The net change in assets (positive or negative), represented in underlying decimals
    /// @dev Updates market-specific asset tracking and calculates the change in total assets
    ///
    /// Function behavior:
    /// - Stores new total assets for the market
    /// - Calculates delta between old and new values
    /// - Returns signed delta for total asset updates
    ///
    /// Used during:
    /// - Balance fuse updates
    /// - Market rebalancing
    /// - Protocol interactions
    /// - Asset redistribution
    ///
    /// Security considerations:
    /// - Handles asset value transitions safely
    /// - Uses SafeCast for integer conversions
    /// - Must be called within proper market context
    /// - Critical for maintaining accurate balances
    ///
    /// Integration points:
    /// - Called by balance fuses after market operations
    /// - Used in _updateMarketsBalances for batch updates
    /// - Triggers market limit validations
    /// - Affects total asset calculations
    ///
    /// @dev Important: The returned delta is used by:
    /// - addToTotalAssetsInAllMarkets
    /// - Asset distribution protection checks
    /// - Market balance event emissions
    function updateTotalAssetsInMarket(
        uint256 marketId_,
        uint256 newTotalAssetsInUnderlying_
    ) internal returns (int256 deltaInUnderlying) {
        uint256 oldTotalAssetsInUnderlying = PlasmaVaultStorageLib.getMarketTotalAssets().value[marketId_];
        PlasmaVaultStorageLib.getMarketTotalAssets().value[marketId_] = newTotalAssetsInUnderlying_;
        deltaInUnderlying = newTotalAssetsInUnderlying_.toInt256() - oldTotalAssetsInUnderlying.toInt256();
    }

    /// @notice Gets the management fee configuration data
    /// @return managementFeeData The current management fee configuration containing:
    ///         - feeAccount: Address receiving management fees
    ///         - feeInPercentage: Current fee rate (basis points, 1/10000)
    ///         - lastUpdateTimestamp: Last time fees were realized
    /// @dev Retrieves the current management fee settings from storage
    ///
    /// Fee structure:
    /// - Continuous time-based fee on assets under management (AUM)
    /// - Fee percentage limited by MANAGEMENT_MAX_FEE_IN_PERCENTAGE (5%)
    /// - Fees accrue linearly over time
    /// - Realized during vault operations
    ///
    /// Used for:
    /// - Fee calculations in totalAssets()
    /// - Fee realization during operations
    /// - Management fee distribution
    /// - Governance fee adjustments
    ///
    /// Integration points:
    /// - PlasmaVault._realizeManagementFee()
    /// - PlasmaVault.totalAssets()
    /// - FeeManager contract
    /// - Governance configuration
    ///
    /// @dev Important: Management fees:
    /// - Are calculated based on total vault assets
    /// - Affect share price calculations
    /// - Must be realized before major vault operations
    /// - Are distributed to configured fee recipients
    function getManagementFeeData()
        internal
        view
        returns (PlasmaVaultStorageLib.ManagementFeeData memory managementFeeData)
    {
        return PlasmaVaultStorageLib.getManagementFeeData();
    }

    /// @notice Configures the management fee settings for the vault
    /// @param feeAccount_ The address that will receive management fees
    /// @param feeInPercentage_ The management fee rate in basis points (100 = 1%)
    /// @dev Updates fee configuration and emits event
    ///
    /// Parameter requirements:
    /// - feeAccount_: Must be non-zero address. The address of the technical Management Fee Account that will receive the management fee collected by the Plasma Vault and later on distributed to IPOR DAO and recipients by FeeManager
    /// - feeInPercentage_: Must not exceed MANAGEMENT_MAX_FEE_IN_PERCENTAGE (5%)
    ///
    /// Fee account types:
    /// - FeeManager contract: Distributes fees to IPOR DAO and other recipients
    /// - EOA/MultiSig: Receives fees directly without distribution
    /// - Technical account: Temporary fee collection before distribution
    ///
    /// Fee percentage format:
    /// - Uses 2 decimal places (basis points)
    /// - Examples:
    ///   - 10000 = 100%
    ///   - 100 = 1%
    ///   - 1 = 0.01%
    ///
    /// Security considerations:
    /// - Only callable by authorized governance functions
    /// - Validates fee percentage against maximum limit
    /// - Emits event for tracking changes
    /// - Critical for vault economics
    ///
    /// @dev Important: Changes affect:
    /// - Future fee calculations
    /// - Share price computations
    /// - Vault revenue distribution
    /// - Total asset calculations
    function configureManagementFee(address feeAccount_, uint256 feeInPercentage_) internal {
        if (feeAccount_ == address(0)) {
            revert Errors.WrongAddress();
        }
        if (feeInPercentage_ > MANAGEMENT_MAX_FEE_IN_PERCENTAGE) {
            revert InvalidManagementFee(feeInPercentage_);
        }

        PlasmaVaultStorageLib.ManagementFeeData storage managementFeeData = PlasmaVaultStorageLib
            .getManagementFeeData();

        managementFeeData.feeAccount = feeAccount_;
        managementFeeData.feeInPercentage = feeInPercentage_.toUint16();

        emit ManagementFeeDataConfigured(feeAccount_, feeInPercentage_);
    }

    /// @notice Gets the performance fee configuration data
    /// @return performanceFeeData The current performance fee configuration containing:
    ///         - feeAccount: The address of the technical Performance Fee Account that will receive the performance fee collected by the Plasma Vault and later on distributed to IPOR DAO and recipients by FeeManager
    ///         - feeInPercentage: Current fee rate (basis points, 1/10000)
    /// @dev Retrieves the current performance fee settings from storage
    ///
    /// Fee structure:
    /// - Charged on positive vault performance
    /// - Fee percentage limited by PERFORMANCE_MAX_FEE_IN_PERCENTAGE (50%)
    /// - Calculated on realized gains only
    /// - Applied during execute() operations
    ///
    /// Used for:
    /// - Performance fee calculations
    /// - Fee realization during profitable operations
    /// - Performance fee distribution
    /// - Governance fee adjustments
    ///
    /// Integration points:
    /// - PlasmaVault._addPerformanceFee()
    /// - PlasmaVault.execute()
    /// - FeeManager contract
    /// - Governance configuration
    ///
    /// @dev Important: Performance fees:
    /// - Only charged on positive performance
    /// - Calculated based on profit since last fee realization
    /// - Minted as new vault shares
    /// - Distributed to configured fee recipients
    function getPerformanceFeeData()
        internal
        view
        returns (PlasmaVaultStorageLib.PerformanceFeeData memory performanceFeeData)
    {
        return PlasmaVaultStorageLib.getPerformanceFeeData();
    }

    /// @notice Configures the performance fee settings for the vault
    /// @param feeAccount_ The address that will receive performance fees
    /// @param feeInPercentage_ The performance fee rate in basis points (100 = 1%)
    /// @dev Updates fee configuration and emits event
    ///
    /// Parameter requirements:
    /// - feeAccount_: Must be non-zero address. The address of the technical Performance Fee Account that will receive the performance fee collected by the Plasma Vault and later on distributed to IPOR DAO and recipients by FeeManager
    /// - feeInPercentage_: Must not exceed PERFORMANCE_MAX_FEE_IN_PERCENTAGE (50%)
    ///
    /// Fee account types:
    /// - FeeManager contract: Distributes fees to IPOR DAO and other recipients
    /// - EOA/MultiSig: Receives fees directly without distribution
    /// - Technical account: Temporary fee collection before distribution
    ///
    /// Fee percentage format:
    /// - Uses 2 decimal places (basis points)
    /// - Examples:
    ///   - 10000 = 100%
    ///   - 100 = 1%
    ///   - 1 = 0.01%
    ///
    /// Security considerations:
    /// - Only callable by authorized governance functions
    /// - Validates fee percentage against maximum limit
    /// - Emits event for tracking changes
    /// - Critical for vault incentive structure
    ///
    /// @dev Important: Changes affect:
    /// - Profit sharing calculations
    /// - Alpha incentive alignment
    /// - Vault performance metrics
    /// - Revenue distribution model
    function configurePerformanceFee(address feeAccount_, uint256 feeInPercentage_) internal {
        if (feeAccount_ == address(0)) {
            revert Errors.WrongAddress();
        }
        if (feeInPercentage_ > PERFORMANCE_MAX_FEE_IN_PERCENTAGE) {
            revert InvalidPerformanceFee(feeInPercentage_);
        }

        PlasmaVaultStorageLib.PerformanceFeeData storage performanceFeeData = PlasmaVaultStorageLib
            .getPerformanceFeeData();

        performanceFeeData.feeAccount = feeAccount_;
        performanceFeeData.feeInPercentage = feeInPercentage_.toUint16();

        emit PerformanceFeeDataConfigured(feeAccount_, feeInPercentage_);
    }

    /// @notice Updates the management fee timestamp for fee accrual tracking
    /// @dev Updates lastUpdateTimestamp to current block timestamp for fee calculations
    ///
    /// Function behavior:
    /// - Sets lastUpdateTimestamp to current block.timestamp
    /// - Used to mark points of fee realization
    /// - Critical for time-based fee calculations
    ///
    /// Called during:
    /// - Fee realization operations
    /// - Deposit transactions
    /// - Withdrawal transactions
    /// - Share minting/burning
    ///
    /// Integration points:
    /// - PlasmaVault._realizeManagementFee()
    /// - PlasmaVault.deposit()
    /// - PlasmaVault.withdraw()
    /// - PlasmaVault.mint()
    ///
    /// @dev Important considerations:
    /// - Must be called after fee realization
    /// - Affects future fee calculations
    /// - Uses uint32 for timestamp storage
    /// - Critical for fee accounting accuracy
    function updateManagementFeeData() internal {
        PlasmaVaultStorageLib.ManagementFeeData storage feeData = PlasmaVaultStorageLib.getManagementFeeData();
        feeData.lastUpdateTimestamp = block.timestamp.toUint32();
    }

    /// @notice Gets the ordered list of instant withdrawal fuses
    /// @return address[] Array of fuse addresses in withdrawal priority order
    /// @dev Retrieves the configured withdrawal path sequence
    ///
    /// Function behavior:
    /// - Returns ordered array of fuse addresses
    /// - Empty array if no withdrawal paths configured
    /// - Order determines withdrawal attempt sequence
    /// - Same fuse can appear multiple times with different params
    ///
    /// Used during:
    /// - Withdrawal operations
    /// - Instant withdrawal processing
    /// - Withdrawal path validation
    /// - Withdrawal strategy execution
    ///
    /// Integration points:
    /// - PlasmaVault._withdrawFromMarkets()
    /// - Withdrawal execution logic
    /// - Balance validation
    /// - Fuse interaction coordination
    ///
    /// @dev Important considerations:
    /// - Order is critical for withdrawal efficiency
    /// - Multiple entries of same fuse allowed
    /// - Each fuse needs corresponding params
    /// - Used in conjunction with getInstantWithdrawalFusesParams
    function getInstantWithdrawalFuses() internal view returns (address[] memory) {
        return PlasmaVaultStorageLib.getInstantWithdrawalFusesArray().value;
    }

    /// @notice Gets the parameters for a specific instant withdrawal fuse at a given index
    /// @param fuse_ The address of the withdrawal fuse contract
    /// @param index_ The position of the fuse in the withdrawal sequence
    /// @return bytes32[] Array of parameters configured for this fuse instance
    /// @dev Retrieves withdrawal configuration parameters for specific fuse execution
    ///
    /// Parameter structure:
    /// - params[0]: Reserved for withdrawal amount (set during execution)
    /// - params[1+]: Fuse-specific parameters such as:
    ///   - Market identifiers
    ///   - Asset addresses
    ///   - Slippage tolerances
    ///   - Protocol-specific configuration
    ///
    /// Storage pattern:
    /// - Uses keccak256(abi.encodePacked(fuse_, index_)) as key
    /// - Allows same fuse to have different params at different indices
    /// - Supports protocol-specific parameter requirements
    ///
    /// Used during:
    /// - Withdrawal execution
    /// - Parameter validation
    /// - Withdrawal path configuration
    /// - Fuse interaction setup
    ///
    /// @dev Important considerations:
    /// - Parameters must match fuse expectations
    /// - Index must correspond to getInstantWithdrawalFuses array
    /// - First parameter reserved for withdrawal amount
    /// - Critical for proper withdrawal execution
    ///
    /// @custom:revert InstantWithdrawalFuseIndexOutOfBounds When index_ is greater than or equal to
    /// the length of the instant withdrawal fuses array
    function getInstantWithdrawalFusesParams(address fuse_, uint256 index_) internal view returns (bytes32[] memory) {
        uint256 fusesArrayLength = PlasmaVaultStorageLib.getInstantWithdrawalFusesArray().value.length;
        if (index_ >= fusesArrayLength) {
            revert InstantWithdrawalFuseIndexOutOfBounds(index_, fusesArrayLength);
        }
        return
            PlasmaVaultStorageLib.getInstantWithdrawalFusesParams().value[keccak256(abi.encodePacked(fuse_, index_))];
    }

    /// @notice Configures the instant withdrawal fuse sequence and parameters
    /// @param fuses_ Array of fuse configurations with their respective parameters
    /// @dev Sets up withdrawal paths and their execution parameters
    ///
    /// Configuration process:
    /// - Creates ordered list of withdrawal fuses
    /// - Stores parameters for each fuse instance, in most cases are substrates used for instant withdraw
    /// - Validates fuse support status
    /// - Updates storage and emits event
    ///
    /// Parameter validation:
    /// - Each fuse must be supported
    /// - Parameters must match fuse requirements
    /// - Fuse order determines execution priority
    /// - Same fuse can appear multiple times
    ///
    /// Storage updates:
    /// - Clears existing configuration
    /// - Stores new fuse sequence
    /// - Maps parameters to fuse+index combinations
    /// - Maintains parameter ordering
    ///
    /// Security considerations:
    /// - Only callable by authorized governance
    /// - Validates all fuse addresses
    /// - Prevents invalid configurations
    /// - Critical for withdrawal security
    ///
    /// @dev Important: Configuration affects:
    /// - Withdrawal path selection
    /// - Execution sequence
    /// - Protocol interactions
    /// - Withdrawal efficiency
    ///
    /// Common configurations:
    /// - Multiple paths through same protocol
    /// - Different slippage per path
    /// - Market-specific parameters
    /// - Fallback withdrawal routes
    function configureInstantWithdrawalFuses(InstantWithdrawalFusesParamsStruct[] calldata fuses_) internal {
        // Get previous configuration to clean up stale entries
        address[] memory previousFuses = PlasmaVaultStorageLib.getInstantWithdrawalFusesArray().value;

        address[] memory fusesList = new address[](fuses_.length);

        PlasmaVaultStorageLib.InstantWithdrawalFusesParams storage instantWithdrawalFusesParams = PlasmaVaultStorageLib
            .getInstantWithdrawalFusesParams();

        bytes32 key;

        // Clean up stale entries from previous configuration
        for (uint256 i; i < previousFuses.length; ++i) {
            key = keccak256(abi.encodePacked(previousFuses[i], i));
            delete instantWithdrawalFusesParams.value[key];
        }

        for (uint256 i; i < fuses_.length; ++i) {
            if (!FusesLib.isFuseSupported(fuses_[i].fuse)) {
                revert FusesLib.FuseUnsupported(fuses_[i].fuse);
            }

            fusesList[i] = fuses_[i].fuse;
            key = keccak256(abi.encodePacked(fuses_[i].fuse, i));

            for (uint256 j; j < fuses_[i].params.length; ++j) {
                instantWithdrawalFusesParams.value[key].push(fuses_[i].params[j]);
            }
        }

        delete PlasmaVaultStorageLib.getInstantWithdrawalFusesArray().value;

        PlasmaVaultStorageLib.getInstantWithdrawalFusesArray().value = fusesList;

        emit InstantWithdrawalFusesConfigured(fuses_);
    }

    /// @notice Gets the Price Oracle Middleware address
    /// @return address The current price oracle middleware contract address
    /// @dev Retrieves the address of the price oracle middleware used for asset valuations
    ///
    /// Price Oracle Middleware:
    /// - Provides standardized price feeds for vault assets
    /// - Must support USD as quote currency
    /// - Critical for asset valuation and calculations
    /// - Required for market operations
    ///
    /// Used during:
    /// - Asset valuation calculations
    /// - Market balance updates
    /// - Fee computations
    /// - Share price determinations
    ///
    /// Integration points:
    /// - Balance fuses for market valuations
    /// - Withdrawal calculations
    /// - Performance tracking
    /// - Asset distribution checks
    ///
    /// @dev Important considerations:
    /// - Must be properly initialized
    /// - Critical for vault operations
    /// - Required for accurate share pricing
    /// - Core component for market interactions
    function getPriceOracleMiddleware() internal view returns (address) {
        return PlasmaVaultStorageLib.getPriceOracleMiddleware().value;
    }

    /// @notice Sets the Price Oracle Middleware address for the vault
    /// @param priceOracleMiddleware_ The new price oracle middleware contract address
    /// @dev Updates the price oracle middleware and emits event
    ///
    /// Validation requirements:
    /// - Must support USD as quote currency
    /// - Must maintain same quote currency decimals
    /// - Must be compatible with existing vault operations
    /// - Address must be non-zero
    ///
    /// Security considerations:
    /// - Only callable by authorized governance
    /// - Critical for vault operations
    /// - Must validate oracle compatibility
    /// - Affects all price-dependent operations
    ///
    /// Integration impacts:
    /// - Asset valuations
    /// - Share price calculations
    /// - Market balance updates
    /// - Fee computations
    ///
    /// @dev Important: Changes affect:
    /// - All price-dependent calculations
    /// - Market operations
    /// - Withdrawal validations
    /// - Performance tracking
    ///
    /// Called during:
    /// - Initial vault setup
    /// - Oracle upgrades
    /// - Protocol improvements
    /// - Emergency oracle changes
    function setPriceOracleMiddleware(address priceOracleMiddleware_) internal {
        PlasmaVaultStorageLib.getPriceOracleMiddleware().value = priceOracleMiddleware_;
        emit PriceOracleMiddlewareChanged(priceOracleMiddleware_);
    }

    /// @notice Gets the Rewards Claim Manager address
    /// @return address The current rewards claim manager contract address
    /// @dev Retrieves the address of the contract managing reward claims and distributions
    ///
    /// Rewards Claim Manager:
    /// - Handles protocol reward claims
    /// - Manages reward token distributions
    /// - Tracks claimable rewards
    /// - Coordinates reward strategies
    ///
    /// Used during:
    /// - Reward claim operations
    /// - Total asset calculations
    /// - Fee computations
    /// - Performance tracking
    ///
    /// Integration points:
    /// - Protocol reward systems
    /// - Asset valuation calculations
    /// - Performance fee assessments
    /// - Governance operations
    ///
    /// @dev Important considerations:
    /// - Can be zero address (rewards disabled)
    /// - Critical for reward accounting
    /// - Affects total asset calculations
    /// - Impacts performance metrics
    function getRewardsClaimManagerAddress() internal view returns (address) {
        return PlasmaVaultStorageLib.getRewardsClaimManagerAddress().value;
    }

    /// @notice Sets the Rewards Claim Manager address for the vault
    /// @param rewardsClaimManagerAddress_ The new rewards claim manager contract address
    /// @dev Updates rewards manager configuration and emits event
    ///
    /// Configuration options:
    /// - Non-zero address: Enables reward claiming functionality
    /// - Zero address: Disables reward claiming system
    ///
    /// Security considerations:
    /// - Only callable by authorized governance
    /// - Critical for reward system operation
    /// - Affects total asset calculations
    /// - Impacts performance metrics
    ///
    /// Integration impacts:
    /// - Protocol reward claiming
    /// - Asset valuation calculations
    /// - Performance tracking
    /// - Fee computations
    ///
    /// @dev Important: Changes affect:
    /// - Reward claiming capability
    /// - Total asset calculations
    /// - Performance measurements
    /// - Protocol integrations
    ///
    /// Called during:
    /// - Initial vault setup
    /// - Rewards system upgrades
    /// - Protocol improvements
    /// - Emergency system changes
    function setRewardsClaimManagerAddress(address rewardsClaimManagerAddress_) internal {
        PlasmaVaultStorageLib.getRewardsClaimManagerAddress().value = rewardsClaimManagerAddress_;
        emit RewardsClaimManagerAddressChanged(rewardsClaimManagerAddress_);
    }

    /// @notice Gets the total supply cap for the vault
    /// @return uint256 The maximum allowed total supply denominated in shares
    /// @dev Retrieves the configured supply cap that limits total vault shares
    ///
    /// Supply cap usage:
    /// - Enforces maximum vault size
    /// - Limits total value locked (TVL)
    /// - Guards against excessive concentration
    /// - Supports gradual scaling
    ///
    /// Used during:
    /// - Deposit validation
    /// - Share minting checks
    /// - Fee minting operations
    /// - Governance monitoring
    ///
    /// Integration points:
    /// - ERC4626 deposit/mint functions
    /// - Fee realization operations
    /// - Governance configuration
    /// - Risk management systems
    ///
    /// @dev Important considerations:
    /// - Cap applies to total shares outstanding
    /// - Can be temporarily bypassed for fees
    /// - Critical for risk management
    /// - Affects deposit availability
    function getTotalSupplyCap() internal view returns (uint256) {
        return PlasmaVaultStorageLib.getERC20CappedStorage().cap;
    }

    /// @notice Sets the total supply cap for the vault
    /// @param cap_ The new maximum total supply in shares
    /// @dev Updates the vault's total supply limit and validates input
    ///
    /// Validation requirements:
    /// - Must be non-zero value
    /// - Must be sufficient for expected vault operations
    ///
    /// Security considerations:
    /// - Only callable by authorized governance
    /// - Critical for vault size control
    /// - Affects deposit availability
    /// - Impacts risk management
    ///
    /// Integration impacts:
    /// - Deposit operations
    /// - Share minting limits
    /// - Fee realization
    /// - TVL management
    ///
    /// @dev Important: Changes affect:
    /// - Maximum vault capacity
    /// - Deposit availability
    /// - Fee minting headroom
    /// - Risk parameters
    ///
    /// Called during:
    /// - Initial vault setup
    /// - Capacity adjustments
    /// - Growth management
    /// - Risk parameter updates
    function setTotalSupplyCap(uint256 cap_) internal {
        if (cap_ == 0) {
            revert Errors.WrongValue();
        }
        PlasmaVaultStorageLib.getERC20CappedStorage().cap = cap_;
        emit TotalSupplyCapChanged(cap_);
    }

    /// @notice Controls validation of the total supply cap
    /// @param flag_ The validation control flag (0 = enabled, 1 = disabled)
    /// @dev Manages temporary bypassing of supply cap checks for fee minting
    ///
    /// Flag values:
    /// - 0: Supply cap validation enabled (default)
    ///   - Enforces maximum supply limit
    ///   - Applies to deposits and mints
    ///   - Maintains TVL controls
    ///
    /// - 1: Supply cap validation disabled
    ///   - Allows exceeding supply cap
    ///   - Used during fee minting
    ///   - Temporary state only
    ///
    /// Used during:
    /// - Performance fee minting
    /// - Management fee realization
    /// - Emergency operations
    /// - System maintenance
    ///
    /// Security considerations:
    /// - Only callable by authorized functions
    /// - Should be re-enabled after fee operations
    /// - Critical for supply control
    /// - Temporary bypass only
    ///
    /// @dev Important: State affects:
    /// - Supply cap enforcement
    /// - Fee minting operations
    /// - Deposit availability
    /// - System security
    function setTotalSupplyCapValidation(uint256 flag_) internal {
        PlasmaVaultStorageLib.getERC20CappedValidationFlag().value = flag_;
    }

    /// @notice Checks if the total supply cap validation is enabled
    /// @return bool True if validation is enabled (flag = 0), false if disabled (flag = 1)
    /// @dev Provides current state of supply cap enforcement
    ///
    /// Validation states:
    /// - Enabled (true):
    ///   - Normal operation mode
    ///   - Enforces supply cap limits
    ///   - Required for deposits/mints
    ///   - Default state
    ///
    /// - Disabled (false):
    ///   - Temporary bypass mode
    ///   - Allows exceeding cap
    ///   - Used for fee minting
    ///   - Special operations only
    ///
    /// Used during:
    /// - Deposit validation
    /// - Share minting checks
    /// - Fee operations
    /// - System monitoring
    ///
    /// @dev Important considerations:
    /// - Should generally be enabled
    /// - Temporary disable for fees only
    /// - Critical for supply control
    /// - Check before cap-sensitive operations
    function isTotalSupplyCapValidationEnabled() internal view returns (bool) {
        return PlasmaVaultStorageLib.getERC20CappedValidationFlag().value == 0;
    }

    /// @notice Sets the execution state to started for Alpha operations
    /// @dev Marks the beginning of a multi-action execution sequence
    ///
    /// Execution state usage:
    /// - Tracks active Alpha operations
    /// - Enables multi-action sequences
    /// - Prevents concurrent executions
    /// - Maintains operation atomicity
    ///
    /// Used during:
    /// - Alpha strategy execution
    /// - Complex market operations
    /// - Multi-step transactions
    /// - Protocol interactions
    ///
    /// Security considerations:
    /// - Only callable by authorized Alpha
    /// - Must be paired with executeFinished
    /// - Critical for operation integrity
    /// - Prevents execution overlap
    ///
    /// @dev Important: State affects:
    /// - Operation validation
    /// - Reentrancy protection
    /// - Transaction boundaries
    /// - Error handling
    function executeStarted() internal {
        PlasmaVaultStorageLib.getExecutionState().value = 1;
    }

    /// @notice Sets the execution state to finished after Alpha operations
    /// @dev Marks the end of a multi-action execution sequence
    ///
    /// Function behavior:
    /// - Resets execution state to 0
    /// - Marks completion of Alpha operations
    /// - Enables new execution sequences
    /// - Required for proper state management
    ///
    /// Called after:
    /// - Strategy execution completion
    /// - Market operation finalization
    /// - Protocol interaction completion
    /// - Multi-step transaction end
    ///
    /// Security considerations:
    /// - Must be called after executeStarted
    /// - Critical for execution state cleanup
    /// - Prevents execution state lock
    /// - Required for new operations
    ///
    /// @dev Important: State cleanup:
    /// - Enables new operations
    /// - Releases execution lock
    /// - Required for system stability
    /// - Prevents state corruption
    function executeFinished() internal {
        PlasmaVaultStorageLib.getExecutionState().value = 0;
    }

    /// @notice Checks if an Alpha execution sequence is currently active
    /// @return bool True if execution is in progress (state = 1), false otherwise
    /// @dev Verifies current execution state for operation validation
    ///
    /// State meanings:
    /// - True (1):
    ///   - Execution sequence active
    ///   - Alpha operation in progress
    ///   - Transaction sequence ongoing
    ///   - State modifications allowed
    ///
    /// - False (0):
    ///   - No active execution
    ///   - Ready for new operations
    ///   - Normal vault state
    ///   - Awaiting next sequence
    ///
    /// Used during:
    /// - Operation validation
    /// - State modification checks
    /// - Execution flow control
    /// - Error handling
    ///
    /// @dev Important considerations:
    /// - Critical for operation safety
    /// - Part of execution control flow
    /// - Affects state modification permissions
    /// - Used in reentrancy checks
    function isExecutionStarted() internal view returns (bool) {
        return PlasmaVaultStorageLib.getExecutionState().value == 1;
    }

    /// @notice Updates the Withdraw Manager address for the vault
    /// @param newWithdrawManager_ The new withdraw manager contract address
    /// @dev Updates withdraw manager configuration and emits event
    ///
    /// Configuration options:
    /// - Non-zero address: Enables scheduled withdrawals
    ///   - Enforces withdrawal schedules
    ///   - Manages withdrawal queues
    ///   - Handles withdrawal limits
    ///   - Coordinates withdrawal timing
    ///
    /// - Zero address: Disables scheduled withdrawals
    ///   - Turns off withdrawal scheduling
    ///   - Enables instant withdrawals only
    ///   - Bypasses withdrawal queues
    ///   - Removes withdrawal timing constraints
    ///
    /// Security considerations:
    /// - Only callable by authorized governance
    /// - Critical for withdrawal control
    /// - Affects user withdrawal options
    /// - Impacts liquidity management
    ///
    /// Integration impacts:
    /// - Withdrawal mechanisms
    /// - User withdrawal experience
    /// - Liquidity planning
    /// - Market stability
    ///
    /// @dev Important: Changes affect:
    /// - Withdrawal availability
    /// - Withdrawal timing
    /// - Liquidity management
    /// - User operations
    function updateWithdrawManager(address newWithdrawManager_) internal {
        PlasmaVaultStorageLib.getWithdrawManager().manager = newWithdrawManager_;
        emit WithdrawManagerChanged(newWithdrawManager_);
    }
}


// ===== FILE: CurveStableswapNGSingleSideBalanceFuse.sol =====

/// @notice Balance Fuse for Curve StableswapNG pools using pro-rata share valuation
contract CurveStableswapNGSingleSideBalanceFuse is IMarketBalanceFuse {
    uint256 public immutable MARKET_ID;

    constructor(uint256 marketId_) {
        MARKET_ID = marketId_;
    }

    /// @return The balance of the Plasma Vault in the market in USD, represented in 18 decimals
    function balanceOf() external view override returns (uint256) {
        bytes32[] memory assetsRaw = PlasmaVaultConfigLib.getMarketSubstrates(MARKET_ID);

        uint256 len = assetsRaw.length;

        if (len == 0) {
            return 0;
        }

        uint256 balance;
        address plasmaVault = address(this);
        address priceOracleMiddleware = PlasmaVaultLib.getPriceOracleMiddleware();
        address lpTokenAddress;
        uint256 lpTokenBalance; 
        uint256 totalSupply ;
        uint256 nCoins;
        address coin;
        uint256 coinAmount;
        uint256 coinPrice;
        uint256 coinPriceDecimals;
        
        for (uint256 i; i < len; ++i) {
            lpTokenAddress = PlasmaVaultConfigLib.bytes32ToAddress(assetsRaw[i]);
            lpTokenBalance = ERC20(lpTokenAddress).balanceOf(plasmaVault);
            if (lpTokenBalance == 0) {
                continue;
            }

            totalSupply = ICurveStableswapNG(lpTokenAddress).totalSupply();
            if (totalSupply == 0) {
                continue;
            }

            nCoins = ICurveStableswapNG(lpTokenAddress).N_COINS();
            for (uint256 j; j < nCoins; ++j) {
                
                coin = ICurveStableswapNG(lpTokenAddress).coins(j);
                
                coinAmount = Math.mulDiv(
                    ICurveStableswapNG(lpTokenAddress).balances(j),
                    lpTokenBalance,
                    totalSupply
                );


                    ( coinPrice,  coinPriceDecimals) = IPriceOracleMiddleware(priceOracleMiddleware)
                    .getAssetPrice(coin);
                
                balance += IporMath.convertToWad(
                    coinAmount * coinPrice,
                    ERC20(coin).decimals() + coinPriceDecimals
                );
            }
        }
        return balance;
    }
}