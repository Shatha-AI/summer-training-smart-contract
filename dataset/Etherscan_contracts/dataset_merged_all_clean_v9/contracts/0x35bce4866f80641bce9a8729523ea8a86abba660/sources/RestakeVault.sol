// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

//  reHOOK - RESTAKE VAULT
//
//  Stake REHOOK, earn the swap fees the hook routes here: ETH (from sells) and REHOOK
//  (from buys), distributed by weight. The recursion is restake():
//
//    restake() compounds your pending TOKEN rewards back into your principal AND raises
//    your loop count, which boosts your reward weight. Loop up to MAX_LOOPS times
//    (hook -> hook -> hook) for the full boost. ETH rewards stay separately claimable.
//
//  Optional lock tiers stack an additional boost in exchange for a withdrawal lock.
//  Accounting is MasterChef-style (accPerWeight), correct under changing weights.

interface IREHOOK {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address a) external view returns (uint256);
}

contract RestakeVault {
    IREHOOK public immutable token;      // stake + token-reward asset
    address public immutable distributor; // the reHOOK token/hook that funds rewards
    address public owner;

    uint256 private constant ACC = 1e12;
    uint8   public constant MAX_LOOPS = 3;
    uint256 public constant LOOP_BOOST_BPS = 1500;   // +15% weight per loop

    // lock tiers: index => (lockSeconds, extra boost bps)
    uint32[3] public lockSeconds = [uint32(0), 30 days, 90 days];
    uint16[3] public lockBoostBps = [uint16(0), 2500, 6000]; // +0% / +25% / +60%

    struct U {
        uint256 amount;      // principal staked
        uint256 weight;      // effective weight (principal * multiplier)
        uint8   loops;       // times restaked (0..MAX_LOOPS)
        uint8   lockTier;    // 0..2
        uint64  lockUntil;   // unix time principal unlocks
        uint256 debtEth;
        uint256 debtTok;
        uint256 owedEth;
        uint256 owedTok;
    }
    mapping(address => U) public users;

    uint256 public totalWeight;
    uint256 public totalStaked;
    uint256 public accEthPerW;   // scaled by ACC
    uint256 public accTokPerW;
    uint256 public parkedEth;    // rewards arriving while totalWeight == 0
    uint256 public parkedTok;

    event Staked(address indexed u, uint256 amount, uint8 lockTier, uint256 weight);
    event Restaked(address indexed u, uint256 compounded, uint8 loops, uint256 weight);
    event Unstaked(address indexed u, uint256 amount);
    event Claimed(address indexed u, uint256 ethAmount, uint256 tokAmount);
    event EthReward(uint256 amount);
    event TokReward(uint256 amount);

    error NotOwner(); error NotDistributor(); error Locked(); error BadTier();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier onlyDistributor() { if (msg.sender != distributor) revert NotDistributor(); _; }

    constructor(address _token) {
        token = IREHOOK(_token);
        distributor = _token;   // the reHOOK token contract is the hook that funds rewards
        owner = msg.sender;
    }

    // ─────────────────── reward intake (from the hook) ───────────────────
    function notifyEth() external payable onlyDistributor {
        if (msg.value == 0) return;
        if (totalWeight == 0) { parkedEth += msg.value; return; }
        accEthPerW += ((msg.value + parkedEth) * ACC) / totalWeight;
        parkedEth = 0;
        emit EthReward(msg.value);
    }
    function notifyToken(uint256 amount) external onlyDistributor {
        if (amount == 0) return;
        if (totalWeight == 0) { parkedTok += amount; return; }
        accTokPerW += ((amount + parkedTok) * ACC) / totalWeight;
        parkedTok = 0;
        emit TokReward(amount);
    }

    // ─────────────────── weight / settle helpers ───────────────────
    function _multBps(uint8 loops, uint8 lockTier) internal view returns (uint256) {
        return 10_000 + uint256(loops) * LOOP_BOOST_BPS + uint256(lockBoostBps[lockTier]);
    }
    function _settle(U storage u) internal {
        if (u.weight > 0) {
            u.owedEth += (u.weight * accEthPerW) / ACC - u.debtEth;
            u.owedTok += (u.weight * accTokPerW) / ACC - u.debtTok;
        }
        u.debtEth = (u.weight * accEthPerW) / ACC;
        u.debtTok = (u.weight * accTokPerW) / ACC;
    }
    function _reweight(U storage u) internal {
        uint256 old = u.weight;
        uint256 nw = (u.amount * _multBps(u.loops, u.lockTier)) / 10_000;
        u.weight = nw;
        totalWeight = totalWeight - old + nw;
        u.debtEth = (nw * accEthPerW) / ACC;
        u.debtTok = (nw * accTokPerW) / ACC;
    }

    // ─────────────────── stake / restake / claim / unstake ───────────────────
    function stake(uint256 amount, uint8 lockTier) external {
        if (lockTier > 2) revert BadTier();
        require(amount > 0, "zero");
        U storage u = users[msg.sender];
        _settle(u);
        require(token.transferFrom(msg.sender, address(this), amount), "pull");
        u.amount += amount;
        totalStaked += amount;
        // a longer lock can only extend, never shorten an existing lock
        if (lockTier >= u.lockTier) {
            u.lockTier = lockTier;
            uint64 newUnlock = uint64(block.timestamp + lockSeconds[lockTier]);
            if (newUnlock > u.lockUntil) u.lockUntil = newUnlock;
        }
        _reweight(u);
        emit Staked(msg.sender, amount, lockTier, u.weight);
    }

    //  THE LOOP: compound token rewards into principal and add a boost tier.
    function restake() external {
        U storage u = users[msg.sender];
        _settle(u);
        uint256 comp = u.owedTok;
        require(comp > 0, "nothing to restake");
        u.owedTok = 0;
        u.amount += comp;             // token rewards become principal
        totalStaked += comp;
        if (u.loops < MAX_LOOPS) u.loops += 1;   // deeper loop = bigger boost
        _reweight(u);
        emit Restaked(msg.sender, comp, u.loops, u.weight);
    }

    function claim() external {
        U storage u = users[msg.sender];
        _settle(u);
        uint256 e = u.owedEth; uint256 t = u.owedTok;
        u.owedEth = 0; u.owedTok = 0;
        if (t > 0) require(token.transfer(msg.sender, t), "tok");
        if (e > 0) { (bool ok,) = msg.sender.call{value: e}(""); require(ok, "eth"); }
        emit Claimed(msg.sender, e, t);
    }

    function unstake(uint256 amount) external {
        U storage u = users[msg.sender];
        require(amount > 0 && amount <= u.amount, "amount");
        if (block.timestamp < u.lockUntil) revert Locked();
        _settle(u);
        u.amount -= amount;
        totalStaked -= amount;
        // full exit resets the loop boost; partial keeps it
        if (u.amount == 0) { u.loops = 0; u.lockTier = 0; }
        _reweight(u);
        require(token.transfer(msg.sender, amount), "send");
        emit Unstaked(msg.sender, amount);
    }

    // ─────────────────── views ───────────────────
    function pending(address a) external view returns (uint256 eth, uint256 tok) {
        U storage u = users[a];
        eth = u.owedEth + (u.weight * accEthPerW) / ACC - u.debtEth;
        tok = u.owedTok + (u.weight * accTokPerW) / ACC - u.debtTok;
    }
    function positionOf(address a) external view returns (
        uint256 amount, uint256 weight, uint8 loops, uint8 lockTier, uint64 lockUntil, uint256 boostBps
    ) {
        U storage u = users[a];
        return (u.amount, u.weight, u.loops, u.lockTier, u.lockUntil, _multBps(u.loops, u.lockTier));
    }

    function setOwner(address n) external onlyOwner { require(n != address(0)); owner = n; }
    receive() external payable {}
}