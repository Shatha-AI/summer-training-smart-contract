// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title WudaoAiSubscriber v2
 * @notice 無道 AI 訂閱智能合約 — 支援月繳/年繳方案，USDT 付款
 *
 * 方案定價 (USDT, 6 decimals):
 *   方案 1 Basic:     月繳 $19   年繳 $200
 *   方案 2 Pro:       月繳 $100  年繳 $1,080
 *   方案 3 Enterprise: 月繳 $599  年繳 $6,450
 *
 * 流程:
 *   1. 用戶 approve USDT 給合約（無上限或方案金額）
 *   2. 用戶呼叫 subscribe(plan, isYearly)
 *   3. 合約從用戶地址 transferFrom USDT 到合約地址
 *   4. Owner 可提領合約內的 USDT 和 ETH
 */

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract WudaoAiSubscriber {
    // ============ 常數 ============
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    string public constant VERSION = "2.0.0";

    // ============ 列舉 ============
    enum Plan { Basic, Pro, Enterprise }

    // ============ 狀態變數 ============
    address public owner;

    mapping(Plan => uint256) public monthlyPrices;
    mapping(Plan => uint256) public yearlyPrices;
    mapping(Plan => string) public planNames;

    struct Subscription {
        address subscriber;
        Plan plan;
        uint256 startTime;
        uint256 endTime;
        bool isYearly;
        bool active;
    }

    mapping(address => Subscription) public subscriptions;
    address[] public subscriberList;

    uint256 public totalRevenue;
    uint256 public constant SUBSCRIPTION_DURATION_MONTHLY = 30 days;
    uint256 public constant SUBSCRIPTION_DURATION_YEARLY  = 365 days;

    // ============ 事件 ============
    event Subscribed(address indexed user, string plan, uint256 amount, bool isYearly, uint256 endTime);
    event Renewed(address indexed user, string plan, uint256 amount, uint256 endTime);
    event Cancelled(address indexed user);
    event USDTWithdrawn(address indexed to, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ 修飾器 ============
    modifier onlyOwner() {
        require(msg.sender == owner, "Wudao: caller is not owner");
        _;
    }

    modifier notPaused() {
        require(subscriptions[msg.sender].active == false || block.timestamp > subscriptions[msg.sender].endTime,
                "Wudao: already subscribed");
        _;
    }

    // ============ 建構子 ============
    constructor() {
        owner = msg.sender;

        // 方案名稱
        planNames[Plan.Basic]      = "basic";
        planNames[Plan.Pro]        = "pro";
        planNames[Plan.Enterprise] = "enterprise";

        // 月繳價格 (USDT, 6 decimals)
        monthlyPrices[Plan.Basic]      = 19 * 1e6;    // $19
        monthlyPrices[Plan.Pro]        = 100 * 1e6;   // $100
        monthlyPrices[Plan.Enterprise] = 599 * 1e6;   // $599

        // 年繳價格 (USDT, 6 decimals)
        yearlyPrices[Plan.Basic]      = 200 * 1e6;    // $200
        yearlyPrices[Plan.Pro]        = 1080 * 1e6;   // $1,080
        yearlyPrices[Plan.Enterprise] = 6450 * 1e6;   // $6,450
    }

    // ============ 訂閱功能 ============

    /**
     * @notice 訂閱方案
     * @param _plan    方案枚舉 (0=Basic, 1=Pro, 2=Enterprise)
     * @param _isYearly true=年繳, false=月繳
     */
    function subscribe(Plan _plan, bool _isYearly) external notPaused {
        uint256 price    = _isYearly ? yearlyPrices[_plan] : monthlyPrices[_plan];
        uint256 duration = _isYearly ? SUBSCRIPTION_DURATION_YEARLY : SUBSCRIPTION_DURATION_MONTHLY;

        require(price > 0, "Wudao: invalid plan");

        // 從用戶轉移 USDT 到合約
        require(IERC20(USDT).transferFrom(msg.sender, address(this), price),
                "Wudao: USDT transfer failed");

        uint256 endTime = block.timestamp + duration;

        // 若用戶之前有過期訂閱，更新而非新增
        if (subscriptions[msg.sender].subscriber == address(0)) {
            subscriberList.push(msg.sender);
        }

        subscriptions[msg.sender] = Subscription({
            subscriber: msg.sender,
            plan:       _plan,
            startTime:  block.timestamp,
            endTime:    endTime,
            isYearly:   _isYearly,
            active:     true
        });

        totalRevenue += price;

        emit Subscribed(msg.sender, planNames[_plan], price, _isYearly, endTime);
    }

    /**
     * @notice 續訂（沿用相同方案與週期）
     */
    function renew() external {
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.active || block.timestamp <= sub.endTime + 30 days,
                "Wudao: subscription expired too long, please re-subscribe");

        uint256 price    = sub.isYearly ? yearlyPrices[sub.plan] : monthlyPrices[sub.plan];
        uint256 duration = sub.isYearly ? SUBSCRIPTION_DURATION_YEARLY : SUBSCRIPTION_DURATION_MONTHLY;

        require(IERC20(USDT).transferFrom(msg.sender, address(this), price),
                "Wudao: USDT transfer failed");

        // 從當前結束時間或現在時間延長
        uint256 baseTime = sub.endTime > block.timestamp ? sub.endTime : block.timestamp;

        sub.startTime = baseTime;
        sub.endTime   = baseTime + duration;
        sub.active    = true;
        totalRevenue += price;

        emit Renewed(msg.sender, planNames[sub.plan], price, sub.endTime);
    }

    /**
     * @notice 取消訂閱（不退費）
     */
    function cancel() external {
        require(subscriptions[msg.sender].active, "Wudao: no active subscription");
        subscriptions[msg.sender].active = false;
        emit Cancelled(msg.sender);
    }

    // ============ 查詢功能 ============

    function isActive(address _user) external view returns (bool) {
        Subscription storage sub = subscriptions[_user];
        return sub.active && block.timestamp <= sub.endTime;
    }

    function getPlan(address _user) external view returns (
        string memory planName,
        bool active,
        uint256 endTime
    ) {
        Subscription storage sub = subscriptions[_user];
        return (planNames[sub.plan], sub.active && block.timestamp <= sub.endTime, sub.endTime);
    }

    function totalSubscribers() external view returns (uint256) {
        return subscriberList.length;
    }

    function checkAllowance(address _user) external view returns (uint256) {
        return IERC20(USDT).allowance(_user, address(this));
    }

    function getUSDTBalance() external view returns (uint256) {
        return IERC20(USDT).balanceOf(address(this));
    }

    // ============ Owner 提領功能 ============

    /**
     * @notice Owner 提領合約內 USDT
     */
    function withdrawUSDT(address _to, uint256 _amount) external onlyOwner {
        uint256 balance = IERC20(USDT).balanceOf(address(this));
        uint256 amount  = _amount == 0 ? balance : _amount;
        require(amount > 0 && amount <= balance, "Wudao: invalid amount");
        require(IERC20(USDT).transferFrom(address(this), _to, amount),
                "Wudao: USDT withdraw failed");
        emit USDTWithdrawn(_to, amount);
    }

    /**
     * @notice Owner 提領合約內 ETH
     */
    function withdrawETH(address payable _to, uint256 _amount) external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 amount  = _amount == 0 ? balance : _amount;
        require(amount > 0 && amount <= balance, "Wudao: invalid amount");
        (bool sent, ) = _to.call{value: amount}("");
        require(sent, "Wudao: ETH withdraw failed");
        emit ETHWithdrawn(_to, amount);
    }

    /**
     * @notice 轉移合約所有權
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Wudao: zero address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    // ============ 接收 ETH ============
    receive() external payable {}
}