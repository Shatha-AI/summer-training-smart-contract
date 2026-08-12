// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract MultiChainStaking {

    // ─── Constants ───────────────────────────────────────────────────────────

    address constant NATIVE = address(0); // sentinel for native-coin stakes

    struct Plan {
        uint8   lockDays;    // lock period in days
        uint16  dailyRateBP; // daily rate in basis points (100 BP = 1%)
    }

    Plan[3] public plans;

    // ─── State ────────────────────────────────────────────────────────────────

    struct StakeInfo {
        uint8   planId;
        address token;        // NATIVE or ERC-20 address
        uint256 amount;       // principal
        uint256 startTime;    // timestamp of stake
        uint256 unlockTime;   // timestamp when lock expires
        uint256 lastClaim;    // last time rewards were claimed
        uint256 claimedRewards;
        bool    active;
    }

    mapping(address => StakeInfo[]) public stakes;

    address public owner;
    address public treasury;  // receives unstaked principal when contract is refilled
    bool    public paused;

    // Whitelisted ERC-20 tokens (optional — set acceptAllTokens = true to skip)
    bool    public acceptAllTokens = true;
    mapping(address => bool) public allowedToken;

    // ─── Events ───────────────────────────────────────────────────────────────

    event Staked(address indexed user, uint256 indexed index, uint8 planId, address token, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed index, uint256 principal, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 indexed index, uint256 rewards);
    event Funded(address indexed funder, address token, uint256 amount);
    event PlanUpdated(uint8 planId, uint8 lockDays, uint16 dailyRateBP);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier notPaused() { require(!paused, "Paused"); _; }

    // ─── Constructor ─────────────────────────────────────────────────────────

    /**
     * @param _treasury Address that can refill the contract with rewards.
     *                  Set to your multisig / deployer wallet.
     */
    constructor(address _treasury) {
        owner    = msg.sender;
        treasury = _treasury;

        // planId 0: 1-day lock, 3% daily = 300 BP
        plans[0] = Plan({ lockDays: 1,  dailyRateBP: 300 });
        // planId 1: 7-day lock, 5% daily = 500 BP
        plans[1] = Plan({ lockDays: 7,  dailyRateBP: 500 });
        // planId 2: 14-day lock, 7% daily = 700 BP
        plans[2] = Plan({ lockDays: 14, dailyRateBP: 700 });
    }

    // ─── Public: Stake native coin ────────────────────────────────────────────

    /**
     * @notice Stake native coin (ETH / BNB / POL / ARB-ETH / SOL-EVM).
     * @param planId  0, 1, or 2
     */
    function stake(uint8 planId) external payable notPaused {
        require(planId < 3, "Bad plan");
        require(msg.value > 0, "Zero amount");

        _createStake(msg.sender, planId, NATIVE, msg.value);
    }

    // ─── Public: Stake ERC-20 token ───────────────────────────────────────────

    /**
     * @notice Stake an ERC-20 token (USDT, USDC, …).
     *         User must first approve(contractAddress, amount).
     * @param planId  0, 1, or 2
     * @param token   ERC-20 token address
     * @param amount  Token amount in token's native decimals
     */
    function stakeToken(uint8 planId, address token, uint256 amount) external notPaused {
        require(planId < 3, "Bad plan");
        require(token != NATIVE, "Use stake() for native");
        require(amount > 0, "Zero amount");
        if (!acceptAllTokens) require(allowedToken[token], "Token not allowed");

        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(ok, "Transfer failed");

        _createStake(msg.sender, planId, token, amount);
    }

    // ─── Public: Claim accrued rewards (anytime) ──────────────────────────────

    /**
     * @notice Claim accrued rewards for a specific stake position.
     *         Works at any time, even during the lock period.
     * @param stakeIndex Index in msg.sender's stakes array
     */
    function claimRewards(uint256 stakeIndex) external notPaused {
        StakeInfo storage s = stakes[msg.sender][stakeIndex];
        require(s.active, "Not active");

        uint256 rewards = _pendingRewards(s);
        require(rewards > 0, "No rewards yet");

        s.lastClaim      = block.timestamp;
        s.claimedRewards += rewards;

        _transfer(s.token, msg.sender, rewards);

        emit RewardsClaimed(msg.sender, stakeIndex, rewards);
    }

    // ─── Public: Unstake ──────────────────────────────────────────────────────

    /**
     * @notice Unstake principal (and auto-claim any unclaimed rewards).
     *         Can be called anytime — lock has no penalty in this implementation.
     *         If you want early-exit penalties, add logic here.
     * @param stakeIndex Index in msg.sender's stakes array
     */
    function unstake(uint256 stakeIndex) external {
        StakeInfo storage s = stakes[msg.sender][stakeIndex];
        require(s.active, "Not active");

        uint256 rewards    = _pendingRewards(s);
        uint256 principal  = s.amount;

        s.active         = false;
        s.claimedRewards += rewards;

        // Return principal
        _transfer(s.token, msg.sender, principal);

        // Pay out any unclaimed rewards
        if (rewards > 0) {
            _transfer(s.token, msg.sender, rewards);
        }

        emit Unstaked(msg.sender, stakeIndex, principal, rewards);
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getUserStakes(address user) external view returns (StakeInfo[] memory) {
        return stakes[user];
    }

    function pendingRewards(address user, uint256 stakeIndex) external view returns (uint256) {
        return _pendingRewards(stakes[user][stakeIndex]);
    }

    function stakeCount(address user) external view returns (uint256) {
        return stakes[user].length;
    }

    // ─── Internal ────────────────────────────────────────────────────────────

    function _createStake(
        address user,
        uint8   planId,
        address token,
        uint256 amount
    ) internal {
        Plan memory p = plans[planId];
        uint256 unlock = block.timestamp + uint256(p.lockDays) * 1 days;

        stakes[user].push(StakeInfo({
            planId:         planId,
            token:          token,
            amount:         amount,
            startTime:      block.timestamp,
            unlockTime:     unlock,
            lastClaim:      block.timestamp,
            claimedRewards: 0,
            active:         true
        }));

        uint256 index = stakes[user].length - 1;
        emit Staked(user, index, planId, token, amount);
    }

    /**
     * @dev Rewards accrue per second based on daily rate.
     *      dailyRate = dailyRateBP / 10000
     *      rewards   = amount * dailyRateBP * elapsed / (10000 * 1 days)
     */
    function _pendingRewards(StakeInfo storage s) internal view returns (uint256) {
        if (!s.active) return 0;
        uint256 elapsed = block.timestamp - s.lastClaim;
        if (elapsed == 0) return 0;
        Plan memory p = plans[s.planId];
        return (s.amount * p.dailyRateBP * elapsed) / (10_000 * 1 days);
    }

    function _transfer(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        if (token == NATIVE) {
            (bool ok,) = payable(to).call{ value: amount }("");
            require(ok, "Native transfer failed");
        } else {
            bool ok = IERC20(token).transfer(to, amount);
            require(ok, "Token transfer failed");
        }
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    /// @notice Fund the contract with native coin (for reward payouts)
    receive() external payable {
        emit Funded(msg.sender, NATIVE, msg.value);
    }

    /// @notice Fund the contract with ERC-20 tokens (for reward payouts)
    function fundToken(address token, uint256 amount) external {
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(ok, "Fund transfer failed");
        emit Funded(msg.sender, token, amount);
    }

    /// @notice Update a plan's parameters (owner only)
    function updatePlan(uint8 planId, uint8 lockDays, uint16 dailyRateBP) external onlyOwner {
        require(planId < 3, "Bad plan");
        require(dailyRateBP <= 10_000, "Rate too high"); // max 100% daily
        plans[planId] = Plan({ lockDays: lockDays, dailyRateBP: dailyRateBP });
        emit PlanUpdated(planId, lockDays, dailyRateBP);
    }

    /// @notice Add / remove allowed token (when acceptAllTokens = false)
    function setAllowedToken(address token, bool allowed) external onlyOwner {
        allowedToken[token] = allowed;
    }

    function setAcceptAllTokens(bool _accept) external onlyOwner {
        acceptAllTokens = _accept;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    /// @notice Emergency withdraw (owner only, for stuck funds)
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        _transfer(token, owner, amount);
    }
}