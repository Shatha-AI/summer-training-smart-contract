// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

//  HOOKSENSOR — SUBNET OPERATOR REGISTRY
//
//  The set of TAO validators authorized to relay subnet consensus on-chain. Operators
//  register a hotkey and a stake weight; the oracle uses stake to weight their votes and
//  to test quorum. Misbehaviour (a proven bad batch) is slashable by the governor, so the
//  security of the fee/risk signal is economic, not custodial.

contract SubnetRegistry {
    struct Operator {
        bytes32 hotkey;      // TAO hotkey (ss58 pubkey lower 32 bytes)
        uint256 stake;       // weight in the consensus
        bool    active;
        uint64  sinceEpoch;
    }

    uint16  public immutable netuid;         // Bittensor subnet id this registry tracks
    address public owner;                    // governor
    uint256 public totalStake;
    uint256 public quorumBps = 6_667;        // 2/3 stake must attest

    address[] public operatorList;
    mapping(address => Operator) public operators;

    event OperatorRegistered(address indexed op, bytes32 hotkey, uint256 stake);
    event OperatorSlashed(address indexed op, uint256 amount);
    event OperatorDeactivated(address indexed op);
    event QuorumSet(uint256 bps);
    event OwnerSet(address indexed owner);

    error NotOwner();
    error Exists();
    error Unknown();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }

    constructor(uint16 _netuid) {
        owner  = msg.sender;
        netuid = _netuid;
    }

    function registerOperator(address op, bytes32 hotkey, uint256 stake, uint64 epoch) external onlyOwner {
        if (operators[op].hotkey != bytes32(0)) revert Exists();
        operators[op] = Operator(hotkey, stake, true, epoch);
        operatorList.push(op);
        totalStake += stake;
        emit OperatorRegistered(op, hotkey, stake);
    }

    function setStake(address op, uint256 newStake) external onlyOwner {
        Operator storage o = operators[op];
        if (o.hotkey == bytes32(0)) revert Unknown();
        totalStake = totalStake - o.stake + newStake;
        o.stake = newStake;
    }

    function slash(address op, uint256 amount) external onlyOwner {
        Operator storage o = operators[op];
        if (o.hotkey == bytes32(0)) revert Unknown();
        uint256 cut = amount > o.stake ? o.stake : amount;
        o.stake -= cut;
        totalStake -= cut;
        if (o.stake == 0) { o.active = false; emit OperatorDeactivated(op); }
        emit OperatorSlashed(op, cut);
    }

    //  Sum the stake of a set of claimed attesters and test it against quorum.
    function meetsQuorum(address[] calldata attesters) external view returns (bool, uint256 attesting) {
        uint256 sum;
        for (uint256 i; i < attesters.length; ++i) {
            Operator storage o = operators[attesters[i]];
            if (o.active) sum += o.stake;
        }
        uint256 need = (totalStake * quorumBps) / 10_000;
        return (sum >= need && totalStake > 0, sum);
    }

    function operatorCount() external view returns (uint256) { return operatorList.length; }
    function setQuorum(uint256 bps) external onlyOwner { require(bps <= 10_000 && bps >= 5_000, "range"); quorumBps = bps; emit QuorumSet(bps); }
    function setOwner(address n) external onlyOwner { require(n != address(0), "zero"); owner = n; emit OwnerSet(n); }
}