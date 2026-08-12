// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title NoxExitVault — Mainnet LP vault that pre-fills DBK fast exits
/// @notice Relayer calls fillExit after seeing FastExitRequested on DBK.
///         Operator recycles L2 ETH via the 7-day bridge and repay()s the vault.
contract NoxExitVault {
    // ─── errors ───────────────────────────────────────────────────────────────
    error NotOwner();
    error NotRelayer();
    error ZeroAddress();
    error Paused();
    error BelowMinDeposit();
    error ZeroShares();
    error Locked();
    error InsufficientLiquidity();
    error AlreadyFilled();
    error ExceedsMaxGross();
    error ExceedsDailyCap();
    error BadRefundCap();
    error BadWithdrawLock();
    error TransferFailed();

    // ─── events ───────────────────────────────────────────────────────────────
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256 amount);
    event FastExitFilled(
        bytes32 indexed id,
        address indexed recipient,
        uint256 gross,
        uint256 net
    );
    event Repaid(uint256 amount, uint256 inTransitAfter);
    event RelayerUpdated(address indexed relayer);
    event TreasuryUpdated(address indexed treasury);
    event PausedSet(bool paused);
    event ParamsUpdated(
        uint256 maxGross,
        uint256 dailyCap,
        uint256 maxRefund,
        uint256 minDeposit,
        uint256 withdrawLock
    );
    event FeesSwept(address indexed to, uint256 amount);

    // ─── immutables / storage ──────────────────────────────────────────────────
    address public owner;
    address public relayer;
    address public treasury;

    bool public paused;

    uint256 public totalShares;
    uint256 public inTransit;
    uint256 public fees;

    uint256 public maxGross = 0.5 ether;
    uint256 public dailyCap = 10 ether;
    uint256 public maxRefund = 0.005 ether;
    uint256 public minDeposit = 0.001 ether;
    uint256 public withdrawLock = 1 days;

    mapping(address => uint256) public sharesOf;
    mapping(address => uint256) public withdrawUnlock;
    mapping(bytes32 => bool) public filled;

    // calendar-day bucket (UTC) → ETH filled that day
    mapping(uint256 => uint256) public dailyFilled;

    // ─── modifiers ────────────────────────────────────────────────────────────
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert NotRelayer();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(address relayer_, address treasury_) {
        if (relayer_ == address(0) || treasury_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        relayer = relayer_;
        treasury = treasury_;
    }

    // ─── views ────────────────────────────────────────────────────────────────
    /// @notice ETH belonging to LPs (excludes accrued admin fees).
    function availableLiquidity() public view returns (uint256) {
        uint256 bal = address(this).balance;
        return bal > fees ? bal - fees : 0;
    }

    /// @notice LP assets = available liquidity (fees excluded). Used for share pricing.
    function totalAssets() public view returns (uint256) {
        return availableLiquidity();
    }

    function assetsOf(address user) public view returns (uint256) {
        uint256 s = sharesOf[user];
        if (s == 0 || totalShares == 0) return 0;
        return (s * totalAssets()) / totalShares;
    }

    function dailyRemaining() public view returns (uint256) {
        uint256 day = block.timestamp / 1 days;
        uint256 used = dailyFilled[day];
        return used >= dailyCap ? 0 : dailyCap - used;
    }

    // ─── LP ───────────────────────────────────────────────────────────────────
    function deposit() external payable whenNotPaused returns (uint256 shares) {
        uint256 amount = msg.value;
        if (amount < minDeposit) revert BelowMinDeposit();

        // Balance already includes msg.value; price against pre-deposit assets.
        // Virtual offset (totalShares+1000)/(preAssets+1) dampens inflation attacks.
        uint256 preAssets = availableLiquidity() > amount
            ? availableLiquidity() - amount
            : 0;
        shares = (amount * (totalShares + 1000)) / (preAssets + 1);
        if (shares == 0) revert ZeroShares();

        sharesOf[msg.sender] += shares;
        totalShares += shares;
        // Reset unlock clock on every deposit (conservative).
        withdrawUnlock[msg.sender] = block.timestamp + withdrawLock;

        emit Deposit(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external whenNotPaused returns (uint256 amount) {
        if (shares == 0) revert ZeroShares();
        if (sharesOf[msg.sender] < shares) revert InsufficientLiquidity();
        if (block.timestamp < withdrawUnlock[msg.sender]) revert Locked();

        amount = (shares * totalAssets()) / totalShares;
        if (amount == 0) revert ZeroShares();
        if (amount > availableLiquidity()) revert InsufficientLiquidity();

        sharesOf[msg.sender] -= shares;
        totalShares -= shares;

        _send(msg.sender, amount);
        emit Withdraw(msg.sender, shares, amount);
    }

    // ─── relayer fill ─────────────────────────────────────────────────────────
    /// @param id       Unique exit id from DBK FastExitRequested
    /// @param recipient L1 recipient (usually same as L2 sender)
    /// @param gross    Full L2 exit amount (pre-fee)
    function fillExit(bytes32 id, address recipient, uint256 gross)
        external
        onlyRelayer
        whenNotPaused
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (filled[id]) revert AlreadyFilled();
        if (gross == 0 || gross > maxGross) revert ExceedsMaxGross();

        uint256 day = block.timestamp / 1 days;
        uint256 used = dailyFilled[day];
        if (used + gross > dailyCap) revert ExceedsDailyCap();

        uint256 net = (gross * 90) / 100;
        uint256 onePct = gross / 100;
        uint256 refund = onePct > maxRefund ? maxRefund : onePct;
        uint256 feePart = onePct - refund;

        uint256 payout = net + refund;
        if (payout > availableLiquidity()) revert InsufficientLiquidity();

        filled[id] = true;
        dailyFilled[day] = used + gross;
        inTransit += gross;
        if (feePart > 0) fees += feePart;

        _send(recipient, net);
        if (refund > 0) _send(msg.sender, refund);

        emit FastExitFilled(id, recipient, gross, net);
    }

    /// @notice Accept recycled ETH from the 7-day L1 finalization (or manual repay).
    function repay() external payable {
        _repay(msg.value);
    }

    receive() external payable {
        _repay(msg.value);
    }

    function _repay(uint256 amount) internal {
        if (amount == 0) return;
        if (amount >= inTransit) {
            inTransit = 0;
        } else {
            inTransit -= amount;
        }
        emit Repaid(amount, inTransit);
    }

    // ─── admin ────────────────────────────────────────────────────────────────
    function setRelayer(address relayer_) external onlyOwner {
        if (relayer_ == address(0)) revert ZeroAddress();
        relayer = relayer_;
        emit RelayerUpdated(relayer_);
    }

    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedSet(paused_);
    }

    function setWithdrawLock(uint256 lock_) external onlyOwner {
        if (lock_ > 7 days) revert BadWithdrawLock();
        withdrawLock = lock_;
        emit ParamsUpdated(maxGross, dailyCap, maxRefund, minDeposit, withdrawLock);
    }

    function setDailyCap(uint256 cap_) external onlyOwner {
        dailyCap = cap_;
        emit ParamsUpdated(maxGross, dailyCap, maxRefund, minDeposit, withdrawLock);
    }

    function setMaxGross(uint256 max_) external onlyOwner {
        maxGross = max_;
        emit ParamsUpdated(maxGross, dailyCap, maxRefund, minDeposit, withdrawLock);
    }

    function setMaxRefund(uint256 max_) external onlyOwner {
        if (max_ > 0.005 ether) revert BadRefundCap();
        maxRefund = max_;
        emit ParamsUpdated(maxGross, dailyCap, maxRefund, minDeposit, withdrawLock);
    }

    function setMinDeposit(uint256 min_) external onlyOwner {
        minDeposit = min_;
        emit ParamsUpdated(maxGross, dailyCap, maxRefund, minDeposit, withdrawLock);
    }

    function sweepFees() external onlyOwner {
        uint256 amt = fees;
        if (amt == 0) return;
        fees = 0;
        _send(treasury, amt);
        emit FeesSwept(treasury, amt);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    // ─── internal ─────────────────────────────────────────────────────────────
    function _send(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}