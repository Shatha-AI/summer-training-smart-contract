// SPDX-License-Identifier: MIT
pragma solidity <0.9.0 >=0.4.16 >=0.7.0 ^0.8.18 ^0.8.24;

// PENTxAuthenticator.flat.fixed.sol

// lib/sx-evm/src/authenticators/Authenticator.sol

/// @title Base Authenticator abstract contract
abstract contract Authenticator {
    bytes4 internal constant PROPOSE_SELECTOR = bytes4(keccak256("propose(address,string,(address,bytes),bytes)"));
    bytes4 internal constant VOTE_SELECTOR = bytes4(keccak256("vote(address,uint256,uint8,(uint8,bytes)[],string)"));
    bytes4 internal constant UPDATE_PROPOSAL_SELECTOR =
        bytes4(keccak256("updateProposal(address,uint256,(address,bytes),string)"));

    /// @dev Forwards a call to the target contract.
    function _call(address target, bytes4 functionSelector, bytes memory data) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = target.call(abi.encodePacked(functionSelector, data));
        if (!success) {
            // If the call failed, we revert with the propagated error message.
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let returnDataSize := returndatasize()
                returndatacopy(0, 0, returnDataSize)
                revert(0, returnDataSize)
            }
        }
    }
}

// lib/safe-smart-account/contracts/common/Enum.sol

/**
 * @title Enum - Collection of enums used in Safe contracts.
 * @author Richard Meissner - @rmeissner
 */
abstract contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

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

// src/interfaces/ISeatToken.sol

/// @notice Custom (non-ERC20) surface of the PEN seat token. Use IERC20 separately for standard ERC-20 calls.
interface ISeatToken {
    function supplyCap() external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function isInactive(address account) external view returns (bool);

    function recordActivity(address account) external;
}

// lib/sx-evm/src/interfaces/IExecutionStrategy.sol

/// @title Execution Strategy Interface
interface IExecutionStrategyErrors {
    /// @notice Thrown when the current status of a proposal does not allow the desired action.
    /// @param status The current status of the proposal.
    error InvalidProposalStatus(ProposalStatus status);

    /// @notice Thrown when the execution of a proposal fails.
    error ExecutionFailed();
}

interface IExecutionStrategy is IExecutionStrategyErrors {
    function execute(
        uint256 proposalId,
        Proposal memory proposal,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votesAbstain,
        bytes memory payload
    ) external;

    function getProposalStatus(
        Proposal memory proposal,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votesAbstain
    ) external view returns (ProposalStatus);

    function getStrategyType() external view returns (string memory);
}

// lib/sx-evm/src/interfaces/execution-strategies/IExecutionStrategyErrors.sol

/// @title Execution Strategy Errors
// lib/sx-evm/src/types.sol

/// @dev Constants used to replace the `bool` type in mappings for gas efficiency.
uint256 constant TRUE = 1;
uint256 constant FALSE = 0;

/// @notice The data stored for each proposal when it is created.
/// @dev Packed into 4 256-bit slots.
struct Proposal {
    // SLOT 1:
    // The address of the proposal creator.
    address author;
    // The block number at which the voting period starts.
    // This is also the snapshot block number where voting power is calculated at.
    uint32 startBlockNumber;
    //
    // SLOT 2:
    // The address of execution strategy used for the proposal.
    IExecutionStrategy executionStrategy;
    // The minimum block number at which the proposal can be finalized.
    uint32 minEndBlockNumber;
    // The maximum block number at which the proposal can be finalized.
    uint32 maxEndBlockNumber;
    // An enum that stores whether a proposal is pending, executed, or cancelled.
    FinalizationStatus finalizationStatus;
    //
    // SLOT 3:
    // The hash of the execution payload. We do not store the payload itself to save gas.
    bytes32 executionPayloadHash;
    //
    // SLOT 4:
    // Bit array where the index of each each bit corresponds to whether the voting strategy.
    // at that index is active at the time of proposal creation.
    uint256 activeVotingStrategies;
}

/// @notice The data stored for each strategy.
struct Strategy {
    // The address of the strategy contract.
    address addr;
    // The parameters of the strategy.
    bytes params;
}

/// @notice The data stored for each indexed strategy.
struct IndexedStrategy {
    uint8 index;
    bytes params;
}

/// @notice The set of possible finalization statuses for a proposal.
///         This is stored inside each Proposal struct.
enum FinalizationStatus {
    Pending,
    Executed,
    Cancelled
}

/// @notice The set of possible statuses for a proposal.
enum ProposalStatus {
    VotingDelay,
    VotingPeriod,
    VotingPeriodAccepted,
    Accepted,
    Executed,
    Rejected,
    Cancelled
}

/// @notice The set of possible choices for a vote.
enum Choice {
    Against,
    For,
    Abstain
}

/// @notice Transaction struct that can be used to represent transactions inside a proposal.
struct MetaTransaction {
    address to;
    uint256 value;
    bytes data;
    Enum.Operation operation;
    // We require a salt so that the struct can always be unique and we can use its hash as a unique identifier.
    uint256 salt;
}

/// @dev    Structure used for the function `initialize` of the Space contract because of solidity's stack constraints.
///         For more information, see `ISpaceActions.sol`.
struct InitializeCalldata {
    address owner;
    uint32 votingDelay;
    uint32 minVotingDuration;
    uint32 maxVotingDuration;
    Strategy proposalValidationStrategy;
    string proposalValidationStrategyMetadataURI;
    string daoURI;
    string metadataURI;
    Strategy[] votingStrategies;
    string[] votingStrategyMetadataURIs;
    address[] authenticators;
}

/// @dev    Structure used for the function `updateSettings` of the Space contract because of solidity's stack constraints.
///         For more information, see `ISpaceOwnerActions.sol`.
struct UpdateSettingsCalldata {
    uint32 minVotingDuration;
    uint32 maxVotingDuration;
    uint32 votingDelay;
    string metadataURI;
    string daoURI;
    Strategy proposalValidationStrategy;
    string proposalValidationStrategyMetadataURI;
    address[] authenticatorsToAdd;
    address[] authenticatorsToRemove;
    Strategy[] votingStrategiesToAdd;
    string[] votingStrategyMetadataURIsToAdd;
    uint8[] votingStrategiesToRemove;
}

// src/governance/PENTxAuthenticator.sol

/// @notice PENTxAuthenticator that records seat activity after a successful authenticated call.
/// @dev Holds `ACTIVITY_ROLE` on the seat token. Skips activity recording for zero-balance actors
///      to avoid reverting on SeatToken._recordActivity's NotSeatHolder check.
contract PENTxAuthenticator is Authenticator {
    error InvalidFunctionSelector();
    error InvalidMessageSender();
    error InvalidTarget();

    ISeatToken public immutable seat;
    address public immutable space;

    constructor(ISeatToken seat_, address space_) {
        seat = seat_;
        space = space_;
    }

    /// @notice Authenticates the caller, forwards the call to the Space, then records activity.
    function authenticate(address target, bytes4 functionSelector, bytes calldata data) external {
        if (target != space) revert InvalidTarget();
        address actor = _extractActor(functionSelector, data);
        if (actor != msg.sender) revert InvalidMessageSender();

        _call(target, functionSelector, data); // reverts on Space rejection; activity is not recorded

        if (IERC20(address(seat)).balanceOf(actor) > 0) {
            seat.recordActivity(actor);
        }
    }

    /// @dev Decodes the first address (voter/author) from calldata for each supported selector.
    function _extractActor(bytes4 selector, bytes calldata data) internal pure returns (address actor) {
        if (selector == PROPOSE_SELECTOR) {
            (actor,,,) = abi.decode(data, (address, string, Strategy, bytes));
        } else if (selector == VOTE_SELECTOR) {
            (actor,,,) = abi.decode(data, (address, uint256, Choice, IndexedStrategy[]));
        } else if (selector == UPDATE_PROPOSAL_SELECTOR) {
            (actor,,,) = abi.decode(data, (address, uint256, Strategy, string));
        } else {
            revert InvalidFunctionSelector();
        }
    }
}
