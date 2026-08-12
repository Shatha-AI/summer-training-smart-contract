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






interface IGiverPositionManager {
    /// @notice Executes a supply on behalf of a user.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param amount The amount to supply.
    /// @param onBehalfOf The address of the user to supply on behalf of.
    /// @return The amount of shares supplied.
    /// @return The amount of assets supplied.
    function supplyOnBehalfOf(address spoke, uint256 reserveId, uint256 amount, address onBehalfOf)
        external
        returns (uint256, uint256);

    /// @notice Executes a repay on behalf of a user.
    /// @dev If the amount exceeds the user's current debt, the entire debt is repaid.
    /// @dev Using `type(uint256).max` to repay the full debt is not allowed with this method.
    /// @param spoke The address of the spoke.
    /// @param reserveId The identifier of the reserve.
    /// @param amount The amount to repay.
    /// @param onBehalfOf The address of the user to repay on behalf of.
    /// @return The amount of shares repaid.
    /// @return The amount of assets repaid.
    function repayOnBehalfOf(address spoke, uint256 reserveId, uint256 amount, address onBehalfOf)
        external
        returns (uint256, uint256);
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

















contract AaveV4Supply is ActionBase, AaveV4Helper {
    using TokenUtils for address;

    /// @param spoke Address of the spoke.
    /// @param onBehalf Address to supply tokens on behalf of. Defaults to the user's wallet if not provided.
    /// @param from Address from which to pull collateral asset.
    /// @param reserveId Reserve id.
    /// @param amount Amount of tokens to supply.
    /// @param useAsCollateral Whether to use the tokens as collateral.
    struct Params {
        address spoke;
        address onBehalf;
        address from;
        uint256 reserveId;
        uint256 amount;
        bool useAsCollateral;
    }

    /// @inheritdoc ActionBase
    function executeAction(
        bytes memory _callData,
        bytes32[] memory _subData,
        uint8[] memory _paramMapping,
        bytes32[] memory _returnValues
    ) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        params.spoke = _parseParamAddr(params.spoke, _paramMapping[0], _subData, _returnValues);
        params.onBehalf =
            _parseParamAddr(params.onBehalf, _paramMapping[1], _subData, _returnValues);
        params.from = _parseParamAddr(params.from, _paramMapping[2], _subData, _returnValues);
        params.reserveId =
            _parseParamUint(params.reserveId, _paramMapping[3], _subData, _returnValues);
        params.amount = _parseParamUint(params.amount, _paramMapping[4], _subData, _returnValues);
        params.useAsCollateral =
            _parseParamUint(
                    params.useAsCollateral ? 1 : 0, _paramMapping[5], _subData, _returnValues
                ) == 1;

        (uint256 amount, bytes memory logData) = _supply(params);
        emit ActionEvent("AaveV4Supply", logData);
        return bytes32(amount);
    }

    /// @inheritdoc ActionBase
    function executeActionDirect(bytes memory _callData) public payable override {
        Params memory params = parseInputs(_callData);
        (, bytes memory logData) = _supply(params);
        logger.logActionDirectEvent("AaveV4Supply", logData);
    }

    /// @inheritdoc ActionBase
    function actionType() public pure virtual override returns (uint8) {
        return uint8(ActionType.STANDARD_ACTION);
    }

    /*//////////////////////////////////////////////////////////////
                            ACTION LOGIC
    //////////////////////////////////////////////////////////////*/
    function _supply(Params memory _params) internal returns (uint256, bytes memory) {
        ISpoke spoke = ISpoke(_params.spoke);
        address underlying = spoke.getReserve(_params.reserveId).underlying;

        address onBehalf = _params.onBehalf == address(0) ? address(this) : _params.onBehalf;
        uint256 amount = underlying.pullTokensIfNeeded(_params.from, _params.amount);

        bool supplyForSmartWallet = onBehalf == address(this);

        // Supply tokens.
        // -------------------------------
        if (supplyForSmartWallet) {
            underlying.approveToken(address(spoke), amount);
            (, amount) = spoke.supply(_params.reserveId, amount, onBehalf);
        } else {
            underlying.approveToken(GIVER_POSITION_MANAGER, amount);
            (, amount) = IGiverPositionManager(GIVER_POSITION_MANAGER)
                .supplyOnBehalfOf(address(spoke), _params.reserveId, amount, onBehalf);
        }

        // Enable as collateral if needed.
        // -------------------------------
        (bool isUsingAsCollateral,) = spoke.getUserReserveStatus(_params.reserveId, onBehalf);

        if (_params.useAsCollateral && !isUsingAsCollateral) {
            if (supplyForSmartWallet) {
                spoke.setUsingAsCollateral(_params.reserveId, true, onBehalf);
            } else {
                IConfigPositionManager(CONFIG_POSITION_MANAGER)
                    .setUsingAsCollateralOnBehalfOf(
                        address(spoke), _params.reserveId, true, onBehalf
                    );
            }
        }

        bytes memory logData = abi.encode(
            address(spoke), onBehalf, _params.from, underlying, amount, _params.useAsCollateral
        );

        return (amount, logData);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
