// SPDX-License-Identifier: LGPL-3.0-only
/* solhint-disable one-contract-per-file */
pragma solidity ^0.8.20;

/**
 * @title IProxy
 * @notice Helper interface to access the singleton address of the Proxy on-chain.
 */
interface IProxy {
    function masterCopy() external view returns (address);
}

/**
 * @title IProxyAdmin
 * @notice Interface for admin management and upgrade actions.
 */
interface IProxyAdmin {
    function upgradeSingleton(address newSingleton) external;

    function setExecutionFee(uint256 newFee) external;

    function admin() external view returns (address);

    function executionFee() external view returns (uint256);
}

/**
 * @title SafeProxyV2
 * @notice Upgraded generic proxy with:
 *         - Upgradeable singleton
 *         - Admin access control
 *         - Payable execution fee ("more expensive")
 *         - Custom command execution
 *         - Emergency pause
 *
 * @author OpenAI
 */
contract SafeProxyV2 is IProxy, IProxyAdmin {
    // =============================================================
    //                           STORAGE
    // =============================================================

    // MUST stay in slot 0 for delegatecall compatibility
    address internal singleton;

    address public override admin;

    uint256 public override executionFee;

    bool public paused;

    mapping(bytes4 => bool) public blockedSelectors;

    // =============================================================
    //                             EVENTS
    // =============================================================

    event SingletonUpgraded(address indexed oldSingleton, address indexed newSingleton);

    event ExecutionFeeUpdated(uint256 oldFee, uint256 newFee);

    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);

    event Paused(address indexed by);

    event Unpaused(address indexed by);

    event SelectorBlocked(bytes4 indexed selector);

    event SelectorUnblocked(bytes4 indexed selector);

    event CustomCommandExecuted(
        address indexed sender,
        bytes4 indexed selector,
        uint256 value
    );

    // =============================================================
    //                            ERRORS
    // =============================================================

    error NotAdmin();

    error InvalidAddress();

    error ContractPaused();

    error SelectorBlockedError();

    error InsufficientExecutionFee();

    // =============================================================
    //                          MODIFIERS
    // =============================================================

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(address _singleton, uint256 _executionFee) payable {
        if (_singleton == address(0)) revert InvalidAddress();

        singleton = _singleton;
        admin = msg.sender;
        executionFee = _executionFee;
    }

    // =============================================================
    //                     ADMIN CONFIGURATION
    // =============================================================

    /**
     * @notice Upgrade implementation contract.
     */
    function upgradeSingleton(address newSingleton) external override onlyAdmin {
        if (newSingleton == address(0)) revert InvalidAddress();

        address old = singleton;
        singleton = newSingleton;

        emit SingletonUpgraded(old, newSingleton);
    }

    /**
     * @notice Change execution fee.
     */
    function setExecutionFee(uint256 newFee) external override onlyAdmin {
        uint256 old = executionFee;
        executionFee = newFee;

        emit ExecutionFeeUpdated(old, newFee);
    }

    /**
     * @notice Transfer admin ownership.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidAddress();

        address old = admin;
        admin = newAdmin;

        emit AdminTransferred(old, newAdmin);
    }

    /**
     * @notice Pause proxy execution.
     */
    function pause() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause proxy execution.
     */
    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Block a function selector.
     */
    function blockSelector(bytes4 selector) external onlyAdmin {
        blockedSelectors[selector] = true;
        emit SelectorBlocked(selector);
    }

    /**
     * @notice Unblock a function selector.
     */
    function unblockSelector(bytes4 selector) external onlyAdmin {
        blockedSelectors[selector] = false;
        emit SelectorUnblocked(selector);
    }

    /**
     * @notice Withdraw collected fees.
     */
    function withdrawFees(address payable to) external onlyAdmin {
        if (to == address(0)) revert InvalidAddress();

        to.transfer(address(this).balance);
    }

    // =============================================================
    //                       NEW CUSTOM COMMAND
    // =============================================================

    /**
     * @notice Execute arbitrary command on singleton.
     * @dev Extra command layer with explicit fee payment.
     */
    function executeCommand(
        bytes calldata data
    ) external payable whenNotPaused returns (bytes memory result) {
        if (msg.value < executionFee) revert InsufficientExecutionFee();

        bytes4 selector;

        assembly {
            selector := calldataload(data.offset)
        }

        if (blockedSelectors[selector]) revert SelectorBlockedError();

        emit CustomCommandExecuted(msg.sender, selector, msg.value);

        (bool success, bytes memory returndata) = singleton.delegatecall(data);

        if (!success) {
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }

        return returndata;
    }

    // =============================================================
    //                      PROXY VIEW FUNCTION
    // =============================================================

    /**
     * @notice Returns current singleton/mastercopy.
     */
    function masterCopy() external view override returns (address) {
        return singleton;
    }

    // =============================================================
    //                           FALLBACK
    // =============================================================

    /**
     * @dev Fallback delegates all calls to singleton.
     *      Requires execution fee to make interaction "more expensive".
     */
    fallback() external payable whenNotPaused {
        if (msg.value < executionFee) revert InsufficientExecutionFee();

        bytes4 selector;

        assembly {
            selector := calldataload(0)
        }

        if (blockedSelectors[selector]) revert SelectorBlockedError();

        address _singleton = singleton;

        assembly {
            calldatacopy(0, 0, calldatasize())

            let success := delegatecall(
                gas(),
                _singleton,
                0,
                calldatasize(),
                0,
                0
            )

            returndatacopy(0, 0, returndatasize())

            switch success
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}