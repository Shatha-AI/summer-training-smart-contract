// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ^0.8.20 ^0.8.4;

// /Users/bala/go/pkg/mod/github.com/smartcontractkit/chainlink-ccip@v0.1.1-solana.0.20260327212517-333f5407977c/chains/evm/contracts/libraries/Client.sol

// End consumer library.
library Client {
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.encode(address) on EVM source chains; abi.decode(sender, (address)) to recover.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains.
    bytes data; // Data payload.
    EVMTokenAmount[] tokenAmounts; // Token transfers.
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV3).
  }

  /// @notice Tag to indicate no execution on the destination chain. Execution will need to be done manually.
  /// @dev Preimage for this tag is: keccak256("NO_EXECUTION_TAG")[:4]
  bytes4 public constant NO_EXECUTION_TAG = 0xeba517d2;
  address public constant NO_EXECUTION_ADDRESS = address(bytes20(NO_EXECUTION_TAG));

  // ================================================================
  // │                           Legacy                             │
  // ================================================================

  // Tag to indicate only a gas limit. Only usable for EVM as destination chain.
  bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;

  struct EVMExtraArgsV1 {
    uint256 gasLimit;
  }

  function _argsToBytes(
    EVMExtraArgsV1 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }

  // Tag to indicate a gas limit (or dest chain equivalent processing units) and Out Of Order Execution. This tag is
  // available for multiple chain families. If there is no chain family specific tag, this is the default available
  // for a chain.
  // Note: not available for Solana or Sui VM based chains.
  bytes4 public constant GENERIC_EXTRA_ARGS_V2_TAG = 0x181dcf10;

  /// @param gasLimit: gas limit for the callback on the destination chain.
  /// @param allowOutOfOrderExecution: if true, it indicates that the message can be executed in any order relative to
  /// other messages from the same sender. This value's default varies by chain. On some chains, a particular value is
  /// enforced, meaning if the expected value is not set, the message request will revert.
  /// @dev Fully compatible with the previously existing EVMExtraArgsV2.
  struct GenericExtraArgsV2 {
    uint256 gasLimit;
    bool allowOutOfOrderExecution;
  }

  // Extra args tag for chains that use the Sui VM.
  bytes4 public constant SUI_EXTRA_ARGS_V1_TAG = 0x21ea4ca9;

  // Extra args tag for chains that use the Solana VM.
  bytes4 public constant SVM_EXTRA_ARGS_V1_TAG = 0x1f3b3aba;

  struct SVMExtraArgsV1 {
    uint32 computeUnits;
    uint64 accountIsWritableBitmap;
    bool allowOutOfOrderExecution;
    bytes32 tokenReceiver;
    // Additional accounts needed for execution of CCIP receiver. Must be empty if message.receiver is zero.
    // Token transfer related accounts are specified in the token pool lookup table on SVM.
    bytes32[] accounts;
  }

  /// @dev The maximum number of accounts that can be passed in SVMExtraArgs.
  uint256 public constant SVM_EXTRA_ARGS_MAX_ACCOUNTS = 64;

  /// @dev The expected static payload size of a token transfer when Borsh encoded and submitted to SVM.
  /// TokenPool extra data and offchain data sizes are dynamic, and should be accounted for separately.
  uint256 public constant SVM_TOKEN_TRANSFER_DATA_OVERHEAD = (4 + 32) // source_pool
    + 32 // token_address
    + 4 // gas_amount
    + 4 // extra_data overhead
    + 32 // amount
    + 32 // size of the token lookup table account
    + 32 // token-related accounts in the lookup table, over-estimated to 32, typically between 11 - 13
    + 32 // token account belonging to the token receiver, e.g ATA, not included in the token lookup table
    + 32 // per-chain token pool config, not included in the token lookup table
    + 32 // per-chain token billing config, not always included in the token lookup table
    + 32; // OffRamp pool signer PDA, not included in the token lookup table

  /// @dev Number of overhead accounts needed for message execution on SVM.
  /// @dev These are message.receiver, and the OffRamp Signer PDA specific to the receiver.
  uint256 public constant SVM_MESSAGING_ACCOUNTS_OVERHEAD = 2;

  /// @dev The size of each SVM account address in bytes.
  uint256 public constant SVM_ACCOUNT_BYTE_SIZE = 32;

  struct SuiExtraArgsV1 {
    uint256 gasLimit;
    bool allowOutOfOrderExecution;
    bytes32 tokenReceiver;
    bytes32[] receiverObjectIds;
  }

  /// @dev The expected static payload size of a token transfer when BCS encoded and submitted to SUI.
  /// TokenPool extra data and offchain data sizes are dynamic, and should be accounted for separately.
  uint256 public constant SUI_TOKEN_TRANSFER_DATA_OVERHEAD = (4 + 32) // source_pool, 4 bytes for length, 32 bytes for address
    + 32 // dest_token_address
    + 4 // dest_gas_amount
    + 4 // extra_data length, the contents are calculated separately
    + 32; // amount

  /// @dev Number of overhead accounts needed for message execution on SUI.
  /// @dev This is the message.receiver.
  uint256 public constant SUI_MESSAGING_ACCOUNTS_OVERHEAD = 1;

  /// @dev The maximum number of receiver object ids that can be passed in SuiExtraArgs.
  uint256 public constant SUI_EXTRA_ARGS_MAX_RECEIVER_OBJECT_IDS = 64;

  /// @dev The size of each SUI account address in bytes.
  uint256 public constant SUI_ACCOUNT_BYTE_SIZE = 32;

  function _argsToBytes(
    GenericExtraArgsV2 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(GENERIC_EXTRA_ARGS_V2_TAG, extraArgs);
  }

  function _svmArgsToBytes(
    SVMExtraArgsV1 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(SVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }

  function _suiArgsToBytes(
    SuiExtraArgsV1 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(SUI_EXTRA_ARGS_V1_TAG, extraArgs);
  }
}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

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

// /Users/bala/go/pkg/mod/github.com/smartcontractkit/chainlink-ccip@v0.1.1-solana.0.20260327212517-333f5407977c/chains/evm/contracts/interfaces/IAny2EVMMessageReceiver.sol

/// @notice Application contracts that intend to receive messages from  the router should implement this interface.
interface IAny2EVMMessageReceiver {
  /// @notice Called by the Router to deliver a message. If this reverts, any token transfers also revert.
  /// The message will move to a FAILED state and become available for manual execution.
  /// @param message CCIP Message.
  /// @dev Note ensure you check the msg.sender is the Router.
  function ccipReceive(
    Client.Any2EVMMessage calldata message
  ) external;
}

// /Users/bala/go/pkg/mod/github.com/smartcontractkit/chainlink-ccip@v0.1.1-solana.0.20260327212517-333f5407977c/chains/evm/contracts/interfaces/IAny2EVMMessageReceiverV2.sol

interface IAny2EVMMessageReceiverV2 is IAny2EVMMessageReceiver {
  /// @notice Get the CCV configuration & minimum accepted block confirmations for a source chain and sender.
  /// @dev Implementations must return an appropriate minBlockConfirmations value. Returning 0 signals that only fully finalized
  /// messages are accepted. Returning a non-zero value allows faster-than-finality (FTF) messages whose requested block
  /// depth is at least minBlockConfirmations. If a suitable minBlockConfirmations is not returned, anyone will be able to send messages
  /// with any level of finality to the receiver. In most cases, the receiver will want to require a certain level of
  /// finality. When a trusted sender is used (and verified by the receiver), this is less critical as the trusted sender
  /// will only send messages with a certain level of finality. The simplest way to implement this is to either allow FTF
  /// messages when sender-verification is used, or require finality for all messages. That means the config can be a
  /// simple boolean instead of n^2 config where for each source, some safe block confirmations must be chosen.
  ///
  /// A few methods to check the block confirmations requirement are:
  /// - Only allow trusted senders, always return `1` to signal any level of FTF
  /// - Return a single threshold (e.g. 10 blocks) for all chains
  /// - Return a threshold specific to the source chain (e.g. 10 blocks for chain A, 20 blocks for chain B)
  /// - Do not allow FTF messages at all, always return `0`
  ///
  /// @param sourceChainSelector The source chain selector of the incoming message. This can be used to specify
  /// different CCV requirements for different source chains, and provides context for the blockConfirmationsRequested parameter.
  /// @param sender The sender of the message on the source chain. This can be used to implement sender-specific
  /// security policies, such as allowing FTF only for trusted senders.
  /// @dev Messages are executable when either the required block confirmations has been reached, or the chain has marked the
  /// block as finalized. Whichever one comes first will allow the message to be executed.
  /// @return requiredCCVs The list of required CCVs for messages from this source chain. All of these CCVs must pass
  /// verification for a message to be accepted.
  /// @return optionalCCVs The list of optional CCVs for messages from this source chain. These CCVs can be used to
  /// increase the security of messages from this source chain, but are not strictly required. If any optional CCVs are
  /// included, the optionalThreshold parameter must also be set to indicate how many of the optional CCVs must pass
  /// verification for a message to be accepted.
  /// @return optionalThreshold The number of optional CCVs that must pass verification for a message to be accepted.
  /// @return minBlockConfirmations The minimum block confirmations the receiver requires for FTF messages. A value of 0 means only
  /// finalized messages are accepted. A non-zero value allows FTF messages whose requested block confirmations meets or
  /// exceeds this threshold.
  function getCCVsAndMinBlockConfirmations(
    uint64 sourceChainSelector,
    bytes calldata sender
  )
    external
    view
    returns (
      address[] memory requiredCCVs,
      address[] memory optionalCCVs,
      uint8 optionalThreshold,
      uint16 minBlockConfirmations
    );
}

// /Users/bala/go/pkg/mod/github.com/smartcontractkit/chainlink-ccip@v0.1.1-solana.0.20260327212517-333f5407977c/chains/evm/contracts/applications/CCIPReceiver.sol

/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
abstract contract CCIPReceiver is IAny2EVMMessageReceiverV2, IERC165 {
  address internal immutable i_ccipRouter;

  constructor(
    address router
  ) {
    if (router == address(0)) revert InvalidRouter(address(0));
    i_ccipRouter = router;
  }

  /// @notice IERC165 supports an interfaceId.
  /// @param interfaceId The interfaceId to check.
  /// @return true if the interfaceId is supported.
  /// @dev Should indicate whether the contract implements IAny2EVMMessageReceiver.
  /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
  /// This allows CCIP to check if ccipReceive is available before calling it.
  /// - If this returns false or reverts, only tokens are transferred to the receiver.
  /// - If this returns true, tokens are transferred and ccipReceive is called atomically.
  /// Additionally, if the receiver address does not have code associated with it at the time of
  /// execution (EXTCODESIZE returns 0), only tokens will be transferred.
  function supportsInterface(
    bytes4 interfaceId
  ) public pure virtual override returns (bool) {
    return interfaceId == type(IAny2EVMMessageReceiver).interfaceId
      || interfaceId == type(IAny2EVMMessageReceiverV2).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IAny2EVMMessageReceiver
  function ccipReceive(
    Client.Any2EVMMessage calldata message
  ) external virtual override onlyRouter {
    _ccipReceive(message);
  }

  /// @notice Override this function in your implementation.
  /// @param message Any2EVMMessage.
  function _ccipReceive(
    Client.Any2EVMMessage memory message
  ) internal virtual;

  /// @notice Return the current router
  /// @return CCIP router address
  function getRouter() public view virtual returns (address) {
    return address(i_ccipRouter);
  }

  /// @notice Return the CCVs required/optional and min block confirmations for a source chain.
  /// @dev This can be overridden to specify different CCVs per source chain. The current implementation means the
  /// default CCV is used and finality is required (minBlockConfirmations = 0).
  function getCCVsAndMinBlockConfirmations(
    uint64,
    bytes calldata
  )
    external
    view
    virtual
    returns (
      address[] memory requiredCCVs,
      address[] memory optionalCCVs,
      uint8 optionalThreshold,
      uint16 minBlockConfirmations
    )
  {
    // By default no specific CCVs are required or optional. This means the default CCV is chosen.
    // minBlockConfirmations = 0 means finality is required.
    return (new address[](0), new address[](0), 0, 0);
  }

  error InvalidRouter(address router);

  /// @dev only calls from the set router are accepted.
  modifier onlyRouter() {
    if (msg.sender != getRouter()) revert InvalidRouter(msg.sender);
    _;
  }
}

// src/gaswaster.sol

// This receiver contract will use the *almost* all the exec gas that it is provided
contract ConsumeAllGasNoRevert is CCIPReceiver {

    event GasConsumed(
        bytes32 messageId,
        uint256 initialGas,
        uint256 remainingGas
    );

    constructor(address router) CCIPReceiver(router) {}

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {

        uint256 initialGas = gasleft();

        bytes32 accumulator;

        // Leave small buffer so we don't revert
        uint256 GAS_BUFFER = 25_000;

        accumulator = keccak256(message.data);

        while (gasleft() > GAS_BUFFER) {
            // Deterministic gas burn (cheap but continuous)
            accumulator = keccak256(
                abi.encodePacked(accumulator, gasleft())
            );
        }

        // Use accumulator so optimizer doesn't remove loop
        if (accumulator == bytes32(0)) {
            accumulator = keccak256("force-use");
        }

        emit GasConsumed(
            message.messageId,
            initialGas,
            gasleft()
        );
    }
}

