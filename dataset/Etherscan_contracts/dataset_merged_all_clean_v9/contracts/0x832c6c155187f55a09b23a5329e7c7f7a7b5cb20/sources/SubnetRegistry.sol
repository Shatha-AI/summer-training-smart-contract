// SPDX-License-Identifier: MIT
/*
EMAXIS — SUBNET REGISTRY

Mirrors the validator set of an Emaxis Bittensor subnet onto Ethereum: each
validator's hotkey, stake weight, and epoch participation. Signals are only
accepted when backed by a stake-weighted threshold of registered validators,
attested via EIP-712 and anchored to a per-epoch Merkle root of the set.

Scaffold status: registry + attestation verification are real; the link to the
live Subtensor consensus (the relayer that updates the root each epoch) is
operated off-chain and trusted until the ZK light-client lands.

Build: 2026-R2 (fresh bytecode revision)
*/
pragma solidity 0.8.24;

contract SubnetRegistry {

    struct Validator {
        bytes32 hotkey;       // Subtensor ss58 hotkey, packed
        uint256 stake;        // TAO-denominated stake weight
        uint64  joinedEpoch;
        bool    active;
    }

    struct Attestation {
        address validator;    // ethereum operator key for the hotkey
        bytes32 signalCommitment;
        uint64  epoch;
        uint8   v; bytes32 r; bytes32 s;
    }

    // ── State ────────────────────────────────────────────────────────────────
    address public owner;
    uint16  public immutable netuid;        // Bittensor subnet id
    uint64  public currentEpoch;
    uint256 public totalStake;
    uint256 public thresholdBps = 6_667;    // 2/3 stake-weighted quorum

    mapping(address => Validator) public validators;
    mapping(uint64 => bytes32)    public epochRoot;     // Merkle root of the set per epoch
    address[] public validatorSet;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant ATTEST_TYPEHASH =
        keccak256("Attestation(bytes32 signalCommitment,uint64 epoch)");

    event ValidatorRegistered(address indexed op, bytes32 indexed hotkey, uint256 stake);
    event ValidatorSlashed(address indexed op, uint256 stake);
    event EpochAdvanced(uint64 indexed epoch, bytes32 root, uint256 totalStake);

    error NotOwner(); error Exists(); error Unknown();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }

    constructor(uint16 _netuid) {
        owner = msg.sender;
        netuid = _netuid;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("EmaxisSubnet"), keccak256("1"), block.chainid, address(this)
        ));
    }

    // ── Validator lifecycle ────────────────────────────────────────────────────
    function registerValidator(address op, bytes32 hotkey, uint256 stake) external onlyOwner {
        if (validators[op].active) revert Exists();
        validators[op] = Validator(hotkey, stake, currentEpoch, true);
        validatorSet.push(op);
        totalStake += stake;
        emit ValidatorRegistered(op, hotkey, stake);
    }

    function slash(address op, uint256 amount) external onlyOwner {
        Validator storage val = validators[op];
        if (!val.active) revert Unknown();
        uint256 cut = amount > val.stake ? val.stake : amount;
        val.stake -= cut;
        totalStake -= cut;
        if (val.stake == 0) val.active = false;
        emit ValidatorSlashed(op, cut);
    }

    function advanceEpoch(bytes32 root) external onlyOwner {
        currentEpoch += 1;
        epochRoot[currentEpoch] = root;
        emit EpochAdvanced(currentEpoch, root, totalStake);
    }

    function setThreshold(uint256 bps) external onlyOwner { require(bps <= 10_000); thresholdBps = bps; }
    function setOwner(address n) external onlyOwner { require(n != address(0)); owner = n; }

    // ── Quorum verification ────────────────────────────────────────────────────

    /// @notice Returns true if the attestations carry >= thresholdBps of stake
    ///         for the given signal commitment, with valid EIP-712 signatures.
    function hasQuorum(bytes32 signalCommitment, uint64 epoch, Attestation[] calldata atts)
        external view returns (bool)
    {
        uint256 acc;
        address last;
        for (uint256 i = 0; i < atts.length; i++) {
            Attestation calldata a = atts[i];
            require(a.validator > last, "EMAXIS/att-order"); // strictly increasing => no dupes
            last = a.validator;
            if (a.signalCommitment != signalCommitment || a.epoch != epoch) continue;

            Validator storage val = validators[a.validator];
            if (!val.active) continue;

            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR,
                keccak256(abi.encode(ATTEST_TYPEHASH, signalCommitment, epoch))));
            if (ecrecover(digest, a.v, a.r, a.s) != a.validator) continue;

            acc += val.stake;
        }
        return totalStake > 0 && acc * 10_000 >= totalStake * thresholdBps;
    }

    function validatorCount() external view returns (uint256) { return validatorSet.length; }

    // ── Merkle membership of a validator in an epoch's set ──────────────────────
    function verifyMembership(uint64 epoch, bytes32 leaf, bytes32[] calldata proof)
        external view returns (bool)
    {
        bytes32 node = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            node = node <= proof[i]
                ? keccak256(abi.encodePacked(node, proof[i]))
                : keccak256(abi.encodePacked(proof[i], node));
        }
        return node == epochRoot[epoch];
    }
}