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






contract MainnetAaveV4Addresses {
    address internal constant GIVER_POSITION_MANAGER = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e;
    address internal constant TAKER_POSITION_MANAGER = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7;
    address internal constant CONFIG_POSITION_MANAGER = 0x51305839CE822a7b4b12AA7D86eA7005052d575c;
}






contract AaveV4Helper is MainnetAaveV4Addresses { }







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











contract AaveV4DelegateBorrowWithSig is ActionBase, AaveV4Helper {
    /// @notice Structured parameters for borrow permit intent.
    /// @param permitData The structured BorrowPermit parameters.
    /// @param signature The EIP712-compliant signature bytes.
    struct Params {
        ITakerPositionManager.BorrowPermit permit;
        bytes signature;
    }

    /// @inheritdoc ActionBase
    function executeAction(
        bytes memory _callData,
        bytes32[] memory,
        uint8[] memory,
        bytes32[] memory
    ) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);
        /// @dev Piping not supported for this action.
        (uint256 amount, bytes memory logData) = _delegateBorrowWithSig(params);
        emit ActionEvent("AaveV4DelegateBorrowWithSig", logData);
        return bytes32(amount);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _delegateBorrowWithSig(params);
        logger.logActionDirectEvent("AaveV4DelegateBorrowWithSig", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _delegateBorrowWithSig(Params memory _params)
        internal
        returns (uint256, bytes memory)
    {
        ITakerPositionManager(TAKER_POSITION_MANAGER)
            .approveBorrowWithSig(_params.permit, _params.signature);
        return (_params.permit.amount, abi.encode(_params));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
