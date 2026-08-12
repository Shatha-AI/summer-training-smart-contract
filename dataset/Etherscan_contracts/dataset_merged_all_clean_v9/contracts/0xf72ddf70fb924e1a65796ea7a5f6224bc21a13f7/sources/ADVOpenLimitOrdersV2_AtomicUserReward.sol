// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// FINAL MVP SECURITY RULES v13 EMBEDDED BYTECODE USER-ONLY PRIORITY REWARD:
// - Only registered executors with enough stake can execute or expire orders.
// - Each executor withdraws only its own stake and own accumulated balance via msg.sender.
// - Creator withdraws only creatorBalance, sent only to feeWallet.
// - User funds in orders cannot be changed by owner or executors.
// - executeOrder is atomic: swap + output proof + user receive + fee split happen in one transaction.
// - If swap fails or user receives less than minOut, the whole transaction reverts and nobody is paid.
// - Fees are paid only from that order's baseExecutionFee + priorityReward, never from creatorBalance, executorBalance, stake, or other orders.
// - Only the order owner can add priorityReward after order creation via addExecutionReward.
// - cancelOrder is only for the order owner and returns amountIn + baseExecutionFee + priorityReward to the user.
// - On execution: executor gets executorShareBps from baseExecutionFee + priorityReward, creator gets the rest.
// - On expiry cleanup: cleaner gets executorShareBps only from baseExecutionFee; user gets priorityReward + the rest of baseExecutionFee back.
// - Creator payout threshold is adjustable without a max cap; triggerCreatorPayout pays only feeWallet.
// - Execution fee has no max cap: contract enforces only the minimum base fee.

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IRouterV2 {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

contract ADVOpenLimitOrdersV2_AtomicUserReward {
    enum Status { Open, Executed, Cancelled, Expired }

    struct Order {
        address user;
        address tokenIn;      // address(0) = native coin BNB/ETH
        address tokenOut;     // address(0) = native coin BNB/ETH
        address router;
        address pair;         // optional pair/pool address for UI and relay information
        uint256 amountIn;
        uint256 minOut;
        uint256 targetPrice;  // UI/relay info only; final protection is minOut + router quote + received output check
        uint256 baseExecutionFee; // native fee paid at order creation; must be >= minExecutionFee
        uint256 priorityReward;   // optional native reward added later only by order owner
        uint256 createdAt;
        uint256 expiresAt;
        Status status;
    }

    address public immutable defaultRouter;
    address public immutable wrappedNative;

    uint256 public immutable maxExecutorStake;

    address public owner;
    address public feeWallet;

    uint256 public minExecutionFee;
    uint256 public minExecutorStake;
    uint256 public maxExecutors; // 0 = unlimited
    uint256 public executorShareBps; // 7000 = 70%; creator receives the rest when order executes
    bool public createPaused;
    bool public executePaused;

    uint256 public creatorBalance;
    uint256 public creatorAutoPayoutThreshold;

    uint256 public orderCount;
    uint256 public executorCount;

    mapping(uint256 => Order) public orders;
    mapping(uint256 => address[]) private orderPaths;
    mapping(address => uint256) public executorStake;
    mapping(address => bool) public isExecutor;
    mapping(address => uint256) public executorBalance;

    uint256 private locked = 1;

    event OrderCreated(uint256 indexed id, address indexed user, address indexed tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, uint256 baseExecutionFee, uint256 expiresAt, address pair);
    event OrderExecuted(uint256 indexed id, address indexed executor, uint256 executorCredit, uint256 creatorCredit, uint256 amountOutReceived);
    event OrderCancelled(uint256 indexed id, address indexed user);
    event ExecutionRewardAdded(uint256 indexed id, address indexed user, uint256 amount, uint256 newPriorityReward, uint256 newTotalExecutionFee);
    event OrderExpired(uint256 indexed id, address indexed cleaner, uint256 cleanerCredit, uint256 userBaseFeeRefund, uint256 priorityRewardRefund);
    event ExecutorRegistered(address indexed executor, uint256 stake);
    event ExecutorStakeWithdrawn(address indexed executor, uint256 amount);
    event ExecutorFeeWithdrawn(address indexed executor, uint256 amount);
    event CreatorFeeAccrued(uint256 indexed orderId, uint256 amount, uint256 newCreatorBalance);
    event CreatorPayout(address indexed feeWallet, address indexed caller, uint256 amountToWallet);
    event CreatorPayoutSettingsChanged(uint256 threshold);
    event SettingsChanged(string indexed key, uint256 value);
    event FeeWalletChanged(address indexed oldWallet, address indexed newWallet);
    event PauseChanged(bool createPaused, bool executePaused);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() { require(msg.sender == owner, "Only owner"); _; }
    modifier nonReentrant() { require(locked == 1, "Reentrant"); locked = 2; _; locked = 1; }
    modifier onlyExecutor() { require(isExecutor[msg.sender] && executorStake[msg.sender] >= minExecutorStake, "Executor not active"); _; }

    constructor(
        address router_,
        address wrappedNative_,
        address feeWallet_,
        uint256 minExecutorStake_,
        uint256 minExecutionFee_,
        uint256 maxExecutors_,
        uint256 executorShareBps_,
        uint256 maxExecutorStake_,
        uint256 creatorAutoPayoutThreshold_
    ) {
        require(router_ != address(0), "Router zero");
        require(wrappedNative_ != address(0), "Wrapped zero");
        require(feeWallet_ != address(0), "Fee wallet zero");
        require(executorShareBps_ <= 10000, "Share above 100%");
        require(minExecutorStake_ <= maxExecutorStake_, "Stake above cap");

        owner = msg.sender;
        defaultRouter = router_;
        wrappedNative = wrappedNative_;
        feeWallet = feeWallet_;
        minExecutorStake = minExecutorStake_;
        minExecutionFee = minExecutionFee_;
        maxExecutors = maxExecutors_;
        executorShareBps = executorShareBps_;
        maxExecutorStake = maxExecutorStake_;
        creatorAutoPayoutThreshold = creatorAutoPayoutThreshold_;
    }

    receive() external payable {}

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setFeeWallet(address newFeeWallet) external onlyOwner {
        require(newFeeWallet != address(0), "Fee wallet zero");
        emit FeeWalletChanged(feeWallet, newFeeWallet);
        feeWallet = newFeeWallet;
    }

    function setFeeRules(uint256 minExecutionFee_, uint256 executorShareBps_) external onlyOwner {
        require(executorShareBps_ <= 10000, "Share above 100%");
        minExecutionFee = minExecutionFee_;
        executorShareBps = executorShareBps_;
        emit SettingsChanged("minExecutionFee", minExecutionFee_);
        emit SettingsChanged("executorShareBps", executorShareBps_);
    }

    function setExecutorRules(uint256 stake, uint256 limit) external onlyOwner {
        require(stake <= maxExecutorStake, "Stake above cap");
        minExecutorStake = stake;
        maxExecutors = limit;
        emit SettingsChanged("minExecutorStake", stake);
        emit SettingsChanged("maxExecutors", limit);
    }

    function setCreatorPayoutThreshold(uint256 threshold) external onlyOwner {
        creatorAutoPayoutThreshold = threshold;
        emit CreatorPayoutSettingsChanged(threshold);
    }

    function setPaused(bool pauseCreate, bool pauseExecute) external onlyOwner {
        createPaused = pauseCreate;
        executePaused = pauseExecute;
        emit PauseChanged(pauseCreate, pauseExecute);
    }

    function registerExecutor() external payable nonReentrant {
        require(msg.value >= minExecutorStake, "Stake too small");
        if (!isExecutor[msg.sender]) {
            require(maxExecutors == 0 || executorCount < maxExecutors, "Executor limit reached");
            isExecutor[msg.sender] = true;
            executorCount += 1;
        }
        executorStake[msg.sender] += msg.value;
        emit ExecutorRegistered(msg.sender, executorStake[msg.sender]);
    }

    function withdrawExecutorStake(uint256 amount) external nonReentrant {
        require(executorStake[msg.sender] >= amount, "Too much");
        executorStake[msg.sender] -= amount;
        if (executorStake[msg.sender] < minExecutorStake && isExecutor[msg.sender]) {
            isExecutor[msg.sender] = false;
            executorCount -= 1;
        }
        _sendNative(msg.sender, amount);
        emit ExecutorStakeWithdrawn(msg.sender, amount);
    }

    function withdrawExecutorBalance() external nonReentrant {
        uint256 amount = executorBalance[msg.sender];
        require(amount > 0, "No executor balance");
        executorBalance[msg.sender] = 0;
        _sendNative(msg.sender, amount);
        emit ExecutorFeeWithdrawn(msg.sender, amount);
    }

    function createOrder(
        address tokenIn,
        address tokenOut,
        address router,
        address pair,
        address[] calldata path,
        uint256 amountIn,
        uint256 minOut,
        uint256 targetPrice,
        uint256 executionFee,
        uint256 expiresAt
    ) external payable nonReentrant returns (uint256 id) {
        require(!createPaused, "Create paused");
        require(amountIn > 0, "Amount zero");
        require(minOut > 0, "MinOut zero");
        require(tokenIn != tokenOut, "Same token");
        require(expiresAt > block.timestamp && expiresAt <= block.timestamp + 30 days, "Bad expiry");
        require(executionFee >= minExecutionFee, "Execution fee too small");
        require(path.length >= 2, "Bad path");

        address useRouter = router == address(0) ? defaultRouter : router;
        require(useRouter != address(0), "Router zero");
        _validatePath(tokenIn, tokenOut, path);

        uint256 nativeNeeded = executionFee;
        if (tokenIn == address(0)) nativeNeeded += amountIn;
        require(msg.value >= nativeNeeded, "Native fee missing");

        if (tokenIn != address(0)) {
            _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        }

        if (msg.value > nativeNeeded) _sendNative(msg.sender, msg.value - nativeNeeded);

        id = ++orderCount;
        orders[id] = Order({
            user: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            router: useRouter,
            pair: pair,
            amountIn: amountIn,
            minOut: minOut,
            targetPrice: targetPrice,
            baseExecutionFee: executionFee,
            priorityReward: 0,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            status: Status.Open
        });
        for (uint256 i = 0; i < path.length; i++) orderPaths[id].push(path[i]);
        _emitOrderCreated(id);
    }

    function _emitOrderCreated(uint256 id) internal {
        Order storage o = orders[id];
        emit OrderCreated(id, o.user, o.tokenIn, o.tokenOut, o.amountIn, o.minOut, o.baseExecutionFee, o.expiresAt, o.pair);
    }

    function addExecutionReward(uint256 id) external payable nonReentrant {
        Order storage o = orders[id];
        require(o.status == Status.Open, "Not open");
        require(msg.sender == o.user, "Only user");
        require(block.timestamp < o.expiresAt, "Expired");
        require(msg.value > 0, "Reward zero");
        o.priorityReward += msg.value;
        emit ExecutionRewardAdded(id, msg.sender, msg.value, o.priorityReward, o.baseExecutionFee + o.priorityReward);
    }

    function totalExecutionFee(uint256 id) external view returns (uint256) {
        Order storage o = orders[id];
        return o.baseExecutionFee + o.priorityReward;
    }

    function executeOrder(uint256 id) external nonReentrant onlyExecutor {
        require(!executePaused, "Execute paused");
        Order storage o = orders[id];
        require(o.status == Status.Open, "Not open");
        require(block.timestamp < o.expiresAt, "Expired");
        require(canExecute(id), "Not executable");

        address[] memory path = orderPaths[id];
        uint256 receivedOut = _performSwapAndProveOutput(o, path);
        require(receivedOut >= o.minOut, "Output below minOut");

        o.status = Status.Executed;

        uint256 totalFee = o.baseExecutionFee + o.priorityReward;
        (uint256 executorPart, uint256 creatorPart) = _splitFee(totalFee);
        if (executorPart > 0) executorBalance[msg.sender] += executorPart;
        if (creatorPart > 0) {
            creatorBalance += creatorPart;
            emit CreatorFeeAccrued(id, creatorPart, creatorBalance);
        }
        emit OrderExecuted(id, msg.sender, executorPart, creatorPart, receivedOut);
    }

    function cancelOrder(uint256 id) external nonReentrant {
        Order storage o = orders[id];
        require(o.status == Status.Open, "Not open");
        require(msg.sender == o.user, "Only user");
        o.status = Status.Cancelled;
        _refundAmountIn(o);
        uint256 refundFee = o.baseExecutionFee + o.priorityReward;
        if (refundFee > 0) _sendNative(o.user, refundFee);
        emit OrderCancelled(id, msg.sender);
    }

    function expireOrder(uint256 id) external nonReentrant onlyExecutor {
        Order storage o = orders[id];
        require(o.status == Status.Open, "Not open");
        require(block.timestamp >= o.expiresAt, "Not expired");
        o.status = Status.Expired;
        _refundAmountIn(o);
        (uint256 cleanerPart, uint256 userBaseFeeRefund) = _splitFee(o.baseExecutionFee);
        uint256 totalUserRefund = userBaseFeeRefund + o.priorityReward;
        if (cleanerPart > 0) executorBalance[msg.sender] += cleanerPart;
        if (totalUserRefund > 0) _sendNative(o.user, totalUserRefund);
        emit OrderExpired(id, msg.sender, cleanerPart, userBaseFeeRefund, o.priorityReward);
    }

    function withdrawCreatorFees() external onlyOwner nonReentrant {
        uint256 amount = creatorBalance;
        require(amount > 0, "No creator fees");
        creatorBalance = 0;
        _sendNative(feeWallet, amount);
        emit CreatorPayout(feeWallet, msg.sender, amount);
    }

    function triggerCreatorPayout() external nonReentrant {
        require(creatorAutoPayoutThreshold > 0, "Auto payout disabled");
        uint256 amount = creatorBalance;
        require(amount >= creatorAutoPayoutThreshold, "Threshold not reached");
        creatorBalance = 0;
        _sendNative(feeWallet, amount);
        emit CreatorPayout(feeWallet, msg.sender, amount);
    }

    function canExecute(uint256 id) public view returns (bool) {
        Order storage o = orders[id];
        if (o.status != Status.Open || block.timestamp >= o.expiresAt) return false;
        address[] memory path = orderPaths[id];
        if (path.length < 2) return false;
        try IRouterV2(o.router).getAmountsOut(o.amountIn, path) returns (uint256[] memory amounts) {
            return amounts[amounts.length - 1] >= o.minOut;
        } catch {
            return false;
        }
    }

    function quoteOrder(uint256 id) external view returns (uint256 expectedOut, bool executable) {
        Order storage o = orders[id];
        address[] memory path = orderPaths[id];
        if (o.status != Status.Open || block.timestamp >= o.expiresAt || path.length < 2) return (0, false);
        try IRouterV2(o.router).getAmountsOut(o.amountIn, path) returns (uint256[] memory amounts) {
            expectedOut = amounts[amounts.length - 1];
            executable = expectedOut >= o.minOut;
        } catch {
            return (0, false);
        }
    }

    function getOrderPath(uint256 id) external view returns (address[] memory) {
        return orderPaths[id];
    }

    function _performSwapAndProveOutput(Order storage o, address[] memory path) internal returns (uint256 receivedOut) {
        if (o.tokenIn == address(0)) {
            // Native coin -> ERC20 token. Router sends output directly to user; we prove user received minOut.
            uint256 userTokenBefore = IERC20(o.tokenOut).balanceOf(o.user);
            IRouterV2(o.router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: o.amountIn}(o.minOut, path, o.user, o.expiresAt);
            uint256 userTokenAfter = IERC20(o.tokenOut).balanceOf(o.user);
            receivedOut = userTokenAfter - userTokenBefore;
        } else if (o.tokenOut == address(0)) {
            // ERC20 token -> native coin. Router sends native to this contract, then contract sends it to user.
            _approveIfNeeded(o.tokenIn, o.router, o.amountIn);
            uint256 nativeBefore = address(this).balance;
            IRouterV2(o.router).swapExactTokensForETHSupportingFeeOnTransferTokens(o.amountIn, o.minOut, path, address(this), o.expiresAt);
            uint256 nativeAfter = address(this).balance;
            receivedOut = nativeAfter - nativeBefore;
            require(receivedOut >= o.minOut, "Native out too low");
            _sendNative(o.user, receivedOut);
        } else {
            // ERC20 token -> ERC20 token. Router sends output directly to user; we prove user received minOut.
            _approveIfNeeded(o.tokenIn, o.router, o.amountIn);
            uint256 userTokenBefore = IERC20(o.tokenOut).balanceOf(o.user);
            IRouterV2(o.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(o.amountIn, o.minOut, path, o.user, o.expiresAt);
            uint256 userTokenAfter = IERC20(o.tokenOut).balanceOf(o.user);
            receivedOut = userTokenAfter - userTokenBefore;
        }
    }

    function _splitFee(uint256 fee) internal view returns (uint256 executorPart, uint256 creatorOrUserPart) {
        executorPart = (fee * executorShareBps) / 10000;
        creatorOrUserPart = fee - executorPart;
    }

    function _validatePath(address tokenIn, address tokenOut, address[] calldata path) internal view {
        if (tokenIn == address(0)) require(path[0] == wrappedNative, "Path must start WNATIVE");
        else require(path[0] == tokenIn, "Path tokenIn mismatch");
        if (tokenOut == address(0)) require(path[path.length - 1] == wrappedNative, "Path must end WNATIVE");
        else require(path[path.length - 1] == tokenOut, "Path tokenOut mismatch");
    }

    function _refundAmountIn(Order storage o) internal {
        if (o.tokenIn == address(0)) _sendNative(o.user, o.amountIn);
        else _safeTransfer(o.tokenIn, o.user, o.amountIn);
    }

    function _approveIfNeeded(address token_, address spender, uint256 amount) internal {
        if (IERC20(token_).allowance(address(this), spender) < amount) {
            _safeApprove(token_, spender, 0);
            _safeApprove(token_, spender, type(uint256).max);
        }
    }

    function _safeTransfer(address token_, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token_.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function _safeTransferFrom(address token_, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token_.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TransferFrom failed");
    }

    function _safeApprove(address token_, address spender, uint256 amount) internal {
        (bool ok, bytes memory data) = token_.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "Approve failed");
    }

    function _sendNative(address to, uint256 amount) internal {
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "Native send failed");
    }
}