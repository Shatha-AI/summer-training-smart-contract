// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract OpalVault {
    error NotOwner();
    error NotPauseAuthority();
    error Paused();
    error InvalidRecipient();
    error InvalidAsset();
    error InvalidAmount();
    error UnsupportedAttestationVersion();
    error TokenTransferFailed();
    error InvalidRelayConfig();
    error InvalidRelayIndex();
    error InvalidRelaySignature();
    error DuplicateRelaySignature();
    error WithdrawalAlreadyProcessed();
    error InvalidSourceBridge();
    error InvalidFeeConfig();
    error InvalidWhitelistAddress();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PauseOperatorUpdated(address indexed previousOperator, address indexed nextOperator);
    event VaultPausedUpdated(bool paused);
    event AssetConfigured(uint8 indexed assetId, address indexed token, bool enabled);
    event ActiveAttestationVersionUpdated(uint8 previousVersion, uint8 nextVersion);
    event AttestationVersionAcceptanceUpdated(uint8 version, bool accepted);
    event OPNetBridgeHexUpdated(bytes32 previousBridgeHex, bytes32 nextBridgeHex);
    event RelaySignerUpdated(uint8 indexed relayIndex, address indexed signer);
    event RelayThresholdUpdated(uint8 previousThreshold, uint8 nextThreshold);
    event RelayCountUpdated(uint8 previousCount, uint8 nextCount);
    event FeeBpsUpdated(uint16 previousFeeBps, uint16 nextFeeBps);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed nextRecipient);
    event FeeWhitelistUpdated(address indexed account, bool whitelisted);
    event DepositFeeCollected(
        uint256 indexed depositId,
        uint8 indexed assetId,
        address indexed token,
        address feeRecipient,
        uint256 feeAmount
    );
    event WithdrawalFeeCollected(
        uint256 indexed withdrawalId,
        uint8 indexed assetId,
        address indexed token,
        address feeRecipient,
        uint256 feeAmount
    );
    event WithdrawalReleased(
        uint256 indexed withdrawalId,
        uint8 indexed assetId,
        address indexed recipient,
        address token,
        uint256 amount,
        bytes32 opnetUser,
        uint8 attestationVersion
    );
    event DepositInitiated(
        uint256 indexed depositId,
        uint8 indexed assetId,
        address indexed depositor,
        address token,
        uint256 amount,
        bytes32 opnetRecipient,
        uint256 timestamp
    );

    struct AssetConfig {
        address token;
        bool enabled;
    }

    struct ReleaseRequest {
        uint8 assetId;
        bytes32 opnetUser;
        address recipient;
        uint256 amount;
        uint256 withdrawalId;
        uint8 attestationVersion;
    }

    address public owner;
    address public pauseOperator;
    bool public paused;
    uint256 public nextDepositId;
    uint8 public activeAttestationVersion;
    bytes32 public opnetBridgeHex;
    uint8 public relayCount;
    uint8 public relayThreshold;
    uint16 public feeBps;
    address public feeRecipient;
    mapping(uint8 => bool) public isAttestationVersionAccepted;
    mapping(uint8 => AssetConfig) public assets;
    mapping(uint8 => address) public relaySigners;
    mapping(bytes32 => bool) public processedReleaseHashes;
    mapping(address => bool) public feeWhitelist;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert Paused();
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert InvalidRecipient();
        owner = initialOwner;
        paused = true;
        activeAttestationVersion = 1;
        feeBps = 50;
        feeRecipient = initialOwner;
        isAttestationVersionAccepted[1] = true;
        emit OwnershipTransferred(address(0), initialOwner);
        emit VaultPausedUpdated(true);
        emit ActiveAttestationVersionUpdated(0, 1);
        emit AttestationVersionAcceptanceUpdated(1, true);
        emit FeeBpsUpdated(0, 50);
        emit FeeRecipientUpdated(address(0), initialOwner);
    }

    function transferOwnership(address newOwner) external onlyOwner whenPaused {
        if (newOwner == address(0)) revert InvalidRecipient();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setPauseOperator(address nextPauseOperator) external onlyOwner {
        address previousOperator = pauseOperator;
        pauseOperator = nextPauseOperator;
        emit PauseOperatorUpdated(previousOperator, nextPauseOperator);
    }

    function setPaused(bool nextPaused) external {
        if (nextPaused) {
            if (msg.sender != owner && msg.sender != pauseOperator) revert NotPauseAuthority();
        } else {
            if (msg.sender != owner) revert NotOwner();
        }
        paused = nextPaused;
        emit VaultPausedUpdated(nextPaused);
    }

    function setFeeBps(uint16 nextFeeBps) external onlyOwner whenPaused {
        if (nextFeeBps > 10_000) revert InvalidFeeConfig();
        uint16 previous = feeBps;
        feeBps = nextFeeBps;
        emit FeeBpsUpdated(previous, nextFeeBps);
    }

    function setFeeRecipient(address nextFeeRecipient) external onlyOwner {
        if (nextFeeRecipient == address(0)) revert InvalidRecipient();
        address previous = feeRecipient;
        feeRecipient = nextFeeRecipient;
        emit FeeRecipientUpdated(previous, nextFeeRecipient);
    }

    function setFeeWhitelist(address account, bool whitelisted) external onlyOwner {
        if (account == address(0)) revert InvalidWhitelistAddress();
        feeWhitelist[account] = whitelisted;
        emit FeeWhitelistUpdated(account, whitelisted);
    }

    function setAttestationVersionAccepted(uint8 version, bool accepted) external onlyOwner whenPaused {
        isAttestationVersionAccepted[version] = accepted;
        emit AttestationVersionAcceptanceUpdated(version, accepted);
    }

    function setActiveAttestationVersion(uint8 version) external onlyOwner whenPaused {
        if (!isAttestationVersionAccepted[version]) revert UnsupportedAttestationVersion();
        uint8 previous = activeAttestationVersion;
        activeAttestationVersion = version;
        emit ActiveAttestationVersionUpdated(previous, version);
    }

    function configureAsset(
        uint8 assetId,
        address token,
        bool enabled
    ) external onlyOwner whenPaused {
        if (enabled && token == address(0)) revert InvalidAsset();

        assets[assetId] = AssetConfig({
            token: token,
            enabled: enabled
        });
        emit AssetConfigured(assetId, token, enabled);
    }

    function setOpnetBridgeHex(bytes32 nextBridgeHex) external onlyOwner whenPaused {
        if (nextBridgeHex == bytes32(0)) revert InvalidSourceBridge();
        bytes32 previous = opnetBridgeHex;
        opnetBridgeHex = nextBridgeHex;
        emit OPNetBridgeHexUpdated(previous, nextBridgeHex);
    }

    function setRelaySigner(uint8 relayIndex, address signer) external onlyOwner whenPaused {
        if (relayIndex > 31) revert InvalidRelayIndex();
        relaySigners[relayIndex] = signer;
        emit RelaySignerUpdated(relayIndex, signer);
    }

    function setRelayCount(uint8 newRelayCount) external onlyOwner whenPaused {
        if (newRelayCount == 0 || newRelayCount > 32) revert InvalidRelayConfig();
        if (relayThreshold > newRelayCount) revert InvalidRelayConfig();
        uint8 previous = relayCount;
        relayCount = newRelayCount;
        emit RelayCountUpdated(previous, newRelayCount);
    }

    function setRelayThreshold(uint8 newRelayThreshold) external onlyOwner whenPaused {
        if (newRelayThreshold == 0) revert InvalidRelayConfig();
        if (relayCount != 0 && newRelayThreshold > relayCount) revert InvalidRelayConfig();
        uint8 previous = relayThreshold;
        relayThreshold = newRelayThreshold;
        emit RelayThresholdUpdated(previous, newRelayThreshold);
    }

    function computeReleaseAttestationHash(
        uint8 assetId,
        bytes32 opnetUser,
        address ethereumRecipient,
        uint256 amount,
        uint256 withdrawalId,
        uint8 attestationVersion
    ) public view returns (bytes32) {
        return sha256(
            abi.encodePacked(
                attestationVersion,
                bytes32(uint256(uint160(address(this)))),
                opnetBridgeHex,
                bytes32(uint256(uint160(ethereumRecipient))),
                opnetUser,
                assetId,
                amount,
                uint8(2),
                withdrawalId
            )
        );
    }

    function releaseWithRelaySignatures(
        uint8 assetId,
        bytes32 opnetUser,
        address recipient,
        uint256 amount,
        uint256 withdrawalId,
        uint8 attestationVersion,
        bytes calldata relayIndexesPacked,
        bytes calldata relaySignaturesPacked
    ) external whenNotPaused {
        ReleaseRequest memory request = ReleaseRequest({
            assetId: assetId,
            opnetUser: opnetUser,
            recipient: recipient,
            amount: amount,
            withdrawalId: withdrawalId,
            attestationVersion: attestationVersion
        });
        _releaseWithRelaySignatures(request, relayIndexesPacked, relaySignaturesPacked);
    }

    function _releaseWithRelaySignatures(
        ReleaseRequest memory request,
        bytes calldata relayIndexesPacked,
        bytes calldata relaySignaturesPacked
    ) private {
        if (request.recipient == address(0)) revert InvalidRecipient();
        if (request.amount == 0) revert InvalidAmount();
        if (opnetBridgeHex == bytes32(0)) revert InvalidSourceBridge();
        if (!isAttestationVersionAccepted[request.attestationVersion]) revert UnsupportedAttestationVersion();

        AssetConfig memory config = assets[request.assetId];
        if (!config.enabled || config.token == address(0)) revert InvalidAsset();

        uint8 threshold = relayThreshold;
        uint8 count = relayCount;
        if (threshold == 0 || count == 0 || threshold > count) revert InvalidRelayConfig();
        if (relayIndexesPacked.length != threshold) revert InvalidRelaySignature();
        if (relaySignaturesPacked.length != uint256(threshold) * 65) revert InvalidRelaySignature();

        bytes32 attestationHash = computeReleaseAttestationHash(
            request.assetId,
            request.opnetUser,
            request.recipient,
            request.amount,
            request.withdrawalId,
            request.attestationVersion
        );
        if (processedReleaseHashes[attestationHash]) revert WithdrawalAlreadyProcessed();

        _verifyRelaySignatures(attestationHash, threshold, count, relayIndexesPacked, relaySignaturesPacked);

        (uint256 netAmount, uint256 feeAmount) = _splitAmountFee(request.amount, request.recipient);

        processedReleaseHashes[attestationHash] = true;
        _transferAndEmitWithdrawalRelease(
            request,
            config.token,
            netAmount,
            feeAmount
        );
    }

    function _verifyRelaySignatures(
        bytes32 attestationHash,
        uint8 threshold,
        uint8 count,
        bytes calldata relayIndexesPacked,
        bytes calldata relaySignaturesPacked
    ) private view {
        uint8 lastRelayIndex = 0;
        for (uint256 i = 0; i < threshold; i++) {
            uint8 relayIndex = uint8(relayIndexesPacked[i]);
            if (relayIndex >= count) revert InvalidRelayIndex();
            if (i > 0 && relayIndex <= lastRelayIndex) revert DuplicateRelaySignature();
            lastRelayIndex = relayIndex;

            address expectedSigner = relaySigners[relayIndex];
            if (expectedSigner == address(0)) revert InvalidRelaySignature();

            address recovered = _recoverPackedSignatureSigner(attestationHash, relaySignaturesPacked, i * 65);
            if (recovered == address(0) || recovered != expectedSigner) revert InvalidRelaySignature();
        }
    }

    function _recoverPackedSignatureSigner(
        bytes32 digest,
        bytes calldata packed,
        uint256 offset
    ) private pure returns (address recovered) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(add(packed.offset, offset))
            s := calldataload(add(add(packed.offset, offset), 32))
            v := byte(0, calldataload(add(add(packed.offset, offset), 64)))
        }
        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidRelaySignature();
        recovered = ecrecover(digest, v, r, s);
    }

    function _transferAndEmitWithdrawalRelease(
        ReleaseRequest memory request,
        address tokenAddress,
        uint256 netAmount,
        uint256 feeAmount
    ) private {
        if (feeAmount > 0) {
            _safeTransfer(tokenAddress, feeRecipient, feeAmount);
            emit WithdrawalFeeCollected(request.withdrawalId, request.assetId, tokenAddress, feeRecipient, feeAmount);
        }

        _safeTransfer(tokenAddress, request.recipient, netAmount);

        emit WithdrawalReleased(
            request.withdrawalId,
            request.assetId,
            request.recipient,
            tokenAddress,
            netAmount,
            request.opnetUser,
            request.attestationVersion
        );
    }

    function depositERC20(
        uint8 assetId,
        uint256 amount,
        bytes32 opnetRecipient
    ) external whenNotPaused returns (uint256 depositId) {
        if (opnetRecipient == bytes32(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        AssetConfig memory config = assets[assetId];
        if (!config.enabled) revert InvalidAsset();

        depositId = _nextDepositId();
        _safeTransferFrom(config.token, msg.sender, address(this), amount);

        (uint256 netAmount, uint256 feeAmount) = _splitAmountFee(amount, msg.sender);
        if (feeAmount > 0) {
            _safeTransfer(config.token, feeRecipient, feeAmount);
            emit DepositFeeCollected(depositId, assetId, config.token, feeRecipient, feeAmount);
        }
        emit DepositInitiated(
            depositId,
            assetId,
            msg.sender,
            config.token,
            netAmount,
            opnetRecipient,
            block.timestamp
        );
    }

    function _splitAmountFee(uint256 grossAmount, address account) private view returns (uint256 netAmount, uint256 feeAmount) {
        if (feeWhitelist[account]) {
            return (grossAmount, 0);
        }
        if (feeBps > 10_000 || feeRecipient == address(0)) revert InvalidFeeConfig();
        // Overflow-safe equivalent of floor(grossAmount * feeBps / 10_000).
        uint256 whole = grossAmount / 10_000;
        uint256 remainder = grossAmount % 10_000;
        feeAmount = (whole * feeBps) + ((remainder * feeBps) / 10_000);
        netAmount = grossAmount - feeAmount;
        if (netAmount == 0) revert InvalidAmount();
    }

    function _nextDepositId() private returns (uint256 currentDepositId) {
        currentDepositId = nextDepositId;
        nextDepositId = currentDepositId + 1;
    }

    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!ok) revert TokenTransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TokenTransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!ok) revert TokenTransferFailed();
        if (data.length > 0 && !abi.decode(data, (bool))) revert TokenTransferFailed();
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external;
    function transfer(address to, uint256 amount) external;
}