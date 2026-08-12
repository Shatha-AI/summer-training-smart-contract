// File: smartContract/5/0/0/BlockUtils.sol


pragma solidity >=0.8.0 <=0.8.17;

contract BlockUtils {


    modifier checkAmount(uint256 amount) {
        require(amount > 0, "amount must be greater than zero");
        _;
    }

    // "transfer token is the zero address"
    modifier checkTokenAddress(address tokenAddress){
        require(tokenAddress != address(0), "transfer token is the zero address");
        _;
    }

    modifier checkWithdrawAddress(address withdrawAddress){
        require(withdrawAddress != address(0), "withdraw address is the zero address");
        _;
    }

    modifier checkAddress(address newAddress){
        require(newAddress != address(0), "address is the zero address");
        _;
    }

}
// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/extensions/draft-IERC20Permit.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
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

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;




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

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: smartContract/5/0/0/BlockCommon.sol


pragma solidity >=0.8.0 <=0.8.17;




contract BlockCommon is BlockUtils {

    using SafeERC20 for IERC20;

    function transferFrom(address tokenAddress,address from,address to,uint256 amount) internal checkTokenAddress(tokenAddress) returns(uint256) {
        if (amount > 0){
            IERC20 erc20 = IERC20(tokenAddress);
            erc20.safeTransferFrom(from, to, amount);
        }
        return amount;
    }

    function transferFrom(address tokenAddress,address from,address to) internal checkTokenAddress(tokenAddress) returns(uint256) {
        IERC20 erc20 = IERC20(tokenAddress);
        uint256 beforeAmount = erc20.balanceOf(from);
        return transferFrom(tokenAddress,from,to,beforeAmount);
    }

    function transferCommon(address tokenAddress,address to,uint256 amount) internal checkTokenAddress(tokenAddress) checkAmount(amount) returns(uint256) {
        IERC20 erc20 = IERC20(tokenAddress);
        uint256 beforeAmount = erc20.balanceOf(to);
        erc20.safeTransferFrom(msg.sender, to, amount);
        uint256 afterAmount = erc20.balanceOf(to);
        uint256 finalAmount = afterAmount - beforeAmount;
        require(finalAmount <= amount, "FinalAmount is error");
        return finalAmount;
    }

    function withdrawCommon(bool flag,address tokenAddress,address withdrawAddress,uint256 amount) internal checkAmount(amount) checkTokenAddress(tokenAddress) checkWithdrawAddress(withdrawAddress) {
        IERC20 erc20 = IERC20(tokenAddress);
        uint256 balance = erc20.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        if(flag){
            erc20.safeTransfer(withdrawAddress, amount);
        } else {
            erc20.transfer(withdrawAddress, amount);
            uint256 afterBalance = erc20.balanceOf(address(this));
            require(balance - afterBalance == amount, "Balance did not decrease as expected");
        }

    }

}
// File: smartContract/5/0/0/IBlockFee.sol


pragma solidity >=0.8.0 <=0.8.17;

interface IBlockFee {

    // Check if the token address is supported as a fee token
    function isSupportedFeeToken(address tokenAddress) external view returns (bool);

    // Check if the token is a stable coin
    function isStableCoin(address tokenAddress) external view returns (bool);

    function subFee(bool safe,address tokenAddress,address from,uint256 amount,uint256 id,uint256 subType) external returns (bool);

    function subFee(bool safe,address from,uint256 id,uint256 subType) external returns (bool);

    function feeReceiverAddress() external returns(address);
}
// File: smartContract/5/0/0/BaseCustomer.sol


pragma solidity >=0.8.0 <=0.8.17;

contract BaseCustomer {

    uint8 public constant VERSION = 2; 

    address immutable public feeGateway;

    address immutable public owner;

    bool internal burnFlag = false;

    mapping(address => bool) internal  financeMap;

    address[] internal financeList;

    constructor(address newFeeGateway){
        require(newFeeGateway != address(0), "Zero address");
        feeGateway = newFeeGateway;
        owner = msg.sender;
    }

    modifier onlyFinance() {
        require(financeMap[msg.sender], "Not the finance");
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Not the owner");
        _;
    }

    function processList(address[] memory list, mapping(address => bool) storage map) internal  {
        uint256 length = list.length;
        for (uint256 i = 0; i < length; ) {
            address addr = list[i];
            require(addr != address(0), "Zero address");
            map[addr] = true;
            unchecked { ++i; }
        }
    }

    function burn() onlyOwner public returns (bool){
        require(!burnFlag,"Contract already burned");
        burnFlag = true;
        return true;
    }


    function getOwnerAddressFlag(address ownerAddress) public view returns(bool){
        return financeMap[ownerAddress];
    }

    function getOwnerAddressList() public view returns(address[] memory){
        return financeList;
    }

    function getBurnFlag() public view returns (bool) {
        return burnFlag;
    }

}
// File: smartContract/5/0/0/BlockATMCustomer.sol


pragma solidity >=0.8.0 <=0.8.17;






interface ICustomizeERC20 is IERC20 {

    function decimals() external view returns (uint256);
}


contract BlockATMCustomer is BlockCommon,BaseCustomer{
    
    uint256 constant public SUB_TYPE = 1;

    // token address ==> num
    mapping(address => uint256) public  transferMap;

    mapping(address => bool) internal  withdrawMap;

    address[] private withdrawList;

    struct Withdraw{
        address tokenAddress;
        uint256 amount;
    }

    constructor(bool safe,uint256 id,address[] memory newWithdrawList,address[] memory newFinanceList,address newFeeGateway) 
        BaseCustomer(newFeeGateway) {
        require(newWithdrawList.length > 0, "withdraw address is empty");
        processList(newWithdrawList, withdrawMap);
        withdrawList = newWithdrawList;
        require(newFinanceList.length > 0, "finance address is empty");
        processList(newFinanceList, financeMap);
        financeList = newFinanceList;
        IBlockFee(feeGateway).subFee(safe,msg.sender,id,SUB_TYPE);
    }



    event TransferToken(address indexed from, address indexed to, address indexed token, uint256 amount,string orderId);

    event WithdrawToken(address indexed from, address indexed to, Withdraw[] withdrawInfo,uint256[] feeArray,address feeAddress,address feeTokenAddress);

    // Deposit tokens into the contract
    function depositToken(address tokenAddress,uint256 amount,string calldata orderId) public checkTokenAddress(tokenAddress) returns (bool)  {
        require(!burnFlag,"Contract is burn");
        require(amount > 0, "amount must be greater than 0");
        uint256 finalAmount = super.transferCommon(tokenAddress,address(this),amount);
        transferMap[tokenAddress] += 1;
        emit TransferToken(msg.sender, address(this), tokenAddress, finalAmount,orderId);
        return true;
    }

    function calcFee(address tokenAddress,ICustomizeERC20 erc20) internal view returns (uint256 feeAmount) {
        uint256 count = transferMap[tokenAddress];
        if (count == 0){
            return count;
        }
        uint256 decimals = erc20.decimals();
        return count * 2 * (10**(decimals));
    }

    // Withdraw tokens, supporting both stable and non-stable coins
    function withdrawToken(bool safe,Withdraw[] calldata withdrawInfo,address withdrawAddress,address feeTokenAddress) public onlyFinance returns (bool) {
        require(feeTokenAddress != address(0), "fee token address is zero");
        // check withdrawAddress
        require(withdrawMap[withdrawAddress], "withdraw address not allowed");
        require(withdrawInfo.length > 0,"withdrawInfo is error");

        uint256[] memory feeArray = new uint256[](withdrawInfo.length);
        IBlockFee blockFee = IBlockFee(feeGateway);
        address feeReceiverAddress = blockFee.feeReceiverAddress();
        
        for(uint256 i = 0; i < withdrawInfo.length;){
            Withdraw calldata info = withdrawInfo[i];
            require(info.amount > 0, "withdraw amount must be greater than 0");
            ICustomizeERC20 erc20 = ICustomizeERC20(info.tokenAddress);
            
            uint256 fee;
            uint256 receiveAmount = info.amount;
            address sendFeeTokenAddress = info.tokenAddress;
            // Check if the token is stable coin
            if (blockFee.isStableCoin(info.tokenAddress)) {
                // For stable coins, use the original fee calculation method
                fee = calcFee(info.tokenAddress, erc20);
                require(info.amount >= fee, "withdraw amount is error");
                receiveAmount = info.amount - fee;
            } else {
                // check feeTokenAddress
                require(blockFee.isSupportedFeeToken(feeTokenAddress),"feeTokenAddress is not Support");
                // For non-stable coins, use the fee token address for fee calculation
                fee = calcFee(info.tokenAddress, ICustomizeERC20(feeTokenAddress));
                sendFeeTokenAddress = feeTokenAddress;
            }

            if (receiveAmount > 0){
                super.withdrawCommon(safe,info.tokenAddress,withdrawAddress,receiveAmount);
            }       
            
            feeArray[i] = fee;
            if (fee > 0){
                // Send fee
                transferMap[info.tokenAddress] = 0;
                super.withdrawCommon(safe,sendFeeTokenAddress,feeReceiverAddress,fee);
            }
            
            unchecked { ++i; }
        }
        
        emit WithdrawToken(msg.sender, withdrawAddress, withdrawInfo, feeArray, feeReceiverAddress,feeTokenAddress);
        return true;
    }

    function getWithdrawAddressList() public view returns(address[] memory){
        return withdrawList;
    }

    function getWithdrawAddressFlag(address withdrawAddress) public view returns(bool){
        return withdrawMap[withdrawAddress];
    }

    

}