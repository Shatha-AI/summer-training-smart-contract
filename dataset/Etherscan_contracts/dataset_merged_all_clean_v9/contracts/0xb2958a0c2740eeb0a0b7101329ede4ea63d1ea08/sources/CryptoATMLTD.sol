// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }
}

contract CryptoATMToken {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;
    address public admin;
    address public feeCollector;
    uint256 public feeRate;
    bool public feeEnabled;
    uint256 public maxWallet;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyAdmin() { require(msg.sender == admin, "Not admin"); _; }

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 supply, address tokenAdmin, address hub, uint256 feeRate_, uint256 maxWallet_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        admin = tokenAdmin;
        feeCollector = tokenAdmin;
        feeRate = feeRate_;
        feeEnabled = true;
        maxWallet = maxWallet_;
        _mint(hub, supply * 10 ** decimals_);
    }

    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function decimals() external view returns (uint8) { return _decimals; }
    function totalSupply() external view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) external view returns (uint256) { return _balances[account]; }
    function allowance(address owner, address spender) external view returns (uint256) { return _allowances[owner][spender]; }
    function approve(address spender, uint256 amount) external returns (bool) { _approve(msg.sender, spender, amount); return true; }
    function transfer(address recipient, uint256 amount) external returns (bool) { _transfer(msg.sender, recipient, amount); return true; }
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        uint256 cur = _allowances[sender][msg.sender];
        require(cur >= amount, "Allowance");
        _approve(sender, msg.sender, cur - amount);
        _transfer(sender, recipient, amount);
        return true;
    }
    function setFeeParams(uint256 newRate, address collector) external onlyAdmin { feeRate = newRate; feeCollector = collector; }
    function setFeeEnabled(bool enabled) external onlyAdmin { feeEnabled = enabled; }
    function setLimits(uint256 newMaxWallet) external onlyAdmin { maxWallet = newMaxWallet; }
    function mint(address account, uint256 amount) external { require(msg.sender == admin, "Only admin"); _mint(account, amount); }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0) && recipient != address(0), "Zero");
        require(amount > 0, "Amount");
        uint256 feeAmount = 0;
        if (feeEnabled && feeRate > 0 && sender != admin && sender != feeCollector) {
            feeAmount = (amount * feeRate) / 10000;
            uint256 finalAmount = amount - feeAmount;
            _balances[sender] -= amount;
            if (feeAmount > 0) {
                _balances[feeCollector] += feeAmount;
                emit Transfer(sender, feeCollector, feeAmount);
            }
            _balances[recipient] += finalAmount;
            emit Transfer(sender, recipient, finalAmount);
        } else {
            _balances[sender] -= amount;
            _balances[recipient] += amount;
            emit Transfer(sender, recipient, amount);
        }
    }
    function _mint(address account, uint256 amount) internal { _totalSupply += amount; _balances[account] += amount; emit Transfer(address(0), account, amount); }
    function _approve(address owner, address spender, uint256 amount) internal { _allowances[owner][spender] = amount; emit Approval(owner, spender, amount); }
}

contract CryptoATMLTD {
    using SafeERC20 for IERC20;

    // ---------- Owner and settings ----------
    address public owner;
    uint256 public platformFee;    // 1% = 100, max 5% = 500
    uint256 public burnRate;       // 0.5% = 50, max 10% = 1000
    uint256 public minPurchase;
    uint256 public maxPurchase;
    uint256 public nativePrice;    // native token price in USD (18 decimals)
    bool public paused;
    bool public emergencyMode;

    // ---------- Token creation for public ----------
    uint256 public tokenCreationFee;       // in wei (0 = free)
    address public tokenCreationFeeWallet;
    uint256 public globalCreationDiscount;
    mapping(address => uint256) public userCreationDiscount;  // wei discount

    // ---------- Token registry ----------
    mapping(address => bool) public isSupported;
    mapping(address => uint256) public tokenPrice;
    mapping(address => mapping(address => uint256)) public userBalance;
    address[] public supportedTokens;
    uint256 public totalTokensCreated;

    // ---------- Packages per token ----------
    struct Package {
        string label;
        uint256 amount;
        uint256 priceUSD;
        bool isActive;
    }
    mapping(address => Package[]) public tokenPackages;

    // ---------- Referral system ----------
    mapping(address => address) public referrer;
    mapping(address => uint256) public referralCount;
    mapping(address => uint256) public referralEarned;
    uint256 public referralRate;      // 1% = 100
    uint256 public maxReferralBonus;

    // ---------- User discounts (on trading fees) ----------
    mapping(address => uint256) public userDiscount;  // basis points (0 = no discount)

    // ---------- Whitelist / Blacklist ----------
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;
    bool public whitelistOnly;       // if true, only whitelisted can trade

    // ---------- Auto withdrawal (owner controlled + user opt-in) ----------
    struct AutoWithdrawSettings {
        bool enabled;
        uint256 maxAmount;          // max per auto withdraw (in wei)
        uint256 cooldown;           // seconds between auto withdraws
        uint256 minBalance;         // min balance to trigger
        address destination;        // where to send
    }
    AutoWithdrawSettings public autoConfig;
    mapping(address => bool) public userAutoEnabled;
    mapping(address => uint256) public userAutoLastTime;
    mapping(address => uint256) public userAutoTotal;

    // ---------- Stats ----------
    uint256 public totalVolume;
    uint256 public totalFees;
    uint256 public totalBuys;
    uint256 public totalReferrals;

    // ---------- Events ----------
    event TokenCreated(address indexed creator, address token, string name, string symbol, uint256 price);
    event TokenBought(address indexed user, address token, uint256 amount, uint256 cost);
    event TokenSold(address indexed user, address token, uint256 amount, uint256 received);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TokenCreationFeeUpdated(uint256 newFee, address feeWallet);
    event PackageAdded(address indexed token, string label, uint256 amount, uint256 priceUSD);
    event ReferralReward(address indexed referrer, address indexed user, uint256 amount);
    event UserDiscountUpdated(address indexed user, uint256 discount);
    event WhitelistUpdated(address indexed user, bool status);
    event BlacklistUpdated(address indexed user, bool status);
    event AutoWithdrawConfigUpdated(uint256 maxAmount, uint256 cooldown, uint256 minBalance, address destination);
    event UserAutoWithdrawToggled(address indexed user, bool enabled);
    event AutoWithdrawExecuted(address indexed user, uint256 amount);

    // ---------- Modifiers ----------
    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    modifier notPaused() { require(!paused, "Paused"); _; }
    modifier notEmergency() { require(!emergencyMode, "Emergency"); _; }
    modifier notBlacklisted() { require(!isBlacklisted[msg.sender], "Blacklisted"); _; }
    modifier onlyWhitelisted() { if (whitelistOnly) require(isWhitelisted[msg.sender], "Not whitelisted"); _; }

    // ---------- Constructor ----------
    constructor(uint256 _tokenCreationFee, address _feeWallet) {
        owner = msg.sender;
        platformFee = 0;
        burnRate = 0;
        minPurchase = 0;
        maxPurchase = type(uint256).max;
        nativePrice = 1e18;
        paused = false;
        emergencyMode = false;
        tokenCreationFee = _tokenCreationFee;
        tokenCreationFeeWallet = _feeWallet;
        globalCreationDiscount = 0;
        referralRate = 0;
        maxReferralBonus = 0;
        whitelistOnly = false;
        autoConfig.enabled = false;
    }

    // ---------- Ownership ----------
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ---------- Token creation for owner (free) ----------
    function createNewToken(
        string calldata name, string calldata symbol, uint8 decimals, uint256 supply,
        uint256 price, uint256 feeRate, uint256 maxWallet
    ) external onlyOwner {
        _createToken(name, symbol, decimals, supply, price, feeRate, maxWallet, owner);
    }

    // ---------- Token creation for public (with fee) ----------
    function createTokenForUser(
        string calldata name, string calldata symbol, uint8 decimals, uint256 supply,
        uint256 price, uint256 feeRate, uint256 maxWallet
    ) external payable notPaused notBlacklisted {
        uint256 effectiveFee = tokenCreationFee;
        if (effectiveFee > 0) {
            uint256 disc = userCreationDiscount[msg.sender] + globalCreationDiscount;
            if (disc > effectiveFee) disc = effectiveFee;
            effectiveFee -= disc;
        }
        if (effectiveFee > 0) {
            require(msg.value >= effectiveFee, "Insufficient fee");
            payable(tokenCreationFeeWallet).transfer(effectiveFee);
            if (msg.value > effectiveFee) payable(msg.sender).transfer(msg.value - effectiveFee);
        } else {
            require(msg.value == 0, "Fee is zero");
        }
        _createToken(name, symbol, decimals, supply, price, feeRate, maxWallet, msg.sender);
    }

    function _createToken(string memory name, string memory symbol, uint8 decimals, uint256 supply,
        uint256 price, uint256 feeRate, uint256 maxWallet, address creator) internal {
        CryptoATMToken newToken = new CryptoATMToken(name, symbol, decimals, supply, owner, address(this), feeRate, maxWallet);
        address tokenAddr = address(newToken);
        supportedTokens.push(tokenAddr);
        isSupported[tokenAddr] = true;
        tokenPrice[tokenAddr] = price;
        totalTokensCreated++;
        emit TokenCreated(creator, tokenAddr, name, symbol, price);
    }

    // ---------- Token management ----------
    function updateTokenPrice(address token, uint256 newPrice) external onlyOwner {
        require(isSupported[token], "Not supported");
        tokenPrice[token] = newPrice;
    }

    function addPackage(address token, string calldata label, uint256 amount, uint256 priceUSD) external onlyOwner {
        require(isSupported[token], "Not supported");
        tokenPackages[token].push(Package(label, amount, priceUSD, true));
        emit PackageAdded(token, label, amount, priceUSD);
    }
    function removePackage(address token, uint256 idx) external onlyOwner {
        require(isSupported[token] && idx < tokenPackages[token].length, "Invalid");
        uint256 last = tokenPackages[token].length - 1;
        if (idx != last) tokenPackages[token][idx] = tokenPackages[token][last];
        tokenPackages[token].pop();
    }

    // ---------- Referral ----------
    function setReferrer(address _referrer) external notBlacklisted {
        require(referrer[msg.sender] == address(0), "Already set");
        require(_referrer != address(0) && _referrer != msg.sender, "Invalid");
        referrer[msg.sender] = _referrer;
    }

    function _giveReferralReward(address user, uint256 fee) internal {
        address ref = referrer[user];
        if (ref != address(0) && referralRate > 0 && fee > 0) {
            uint256 reward = (fee * referralRate) / 10000;
            if (reward > maxReferralBonus && maxReferralBonus > 0) reward = maxReferralBonus;
            if (reward > 0 && address(this).balance >= reward) {
                payable(ref).transfer(reward);
                referralEarned[ref] += reward;
                referralCount[ref]++;
                totalReferrals++;
                emit ReferralReward(ref, user, reward);
            }
        }
    }

    // ---------- User discount on trading fees ----------
    function setUserDiscount(address user, uint256 discountBP) external onlyOwner {
        userDiscount[user] = discountBP;
        emit UserDiscountUpdated(user, discountBP);
    }

    // ---------- Whitelist / Blacklist ----------
    function setWhitelist(address user, bool status) external onlyOwner {
        isWhitelisted[user] = status;
        emit WhitelistUpdated(user, status);
    }
    function setBlacklist(address user, bool status) external onlyOwner {
        isBlacklisted[user] = status;
        emit BlacklistUpdated(user, status);
    }
    function setWhitelistOnly(bool enabled) external onlyOwner { whitelistOnly = enabled; }

    // ---------- Auto withdrawal settings ----------
    function setAutoWithdrawConfig(uint256 maxAmount, uint256 cooldown, uint256 minBalance, address destination) external onlyOwner {
        autoConfig.maxAmount = maxAmount;
        autoConfig.cooldown = cooldown;
        autoConfig.minBalance = minBalance;
        autoConfig.destination = destination;
        emit AutoWithdrawConfigUpdated(maxAmount, cooldown, minBalance, destination);
    }
    function enableAutoWithdraw(bool enable) external {
        userAutoEnabled[msg.sender] = enable;
        emit UserAutoWithdrawToggled(msg.sender, enable);
    }
    function executeAutoWithdraw() external notPaused {
        require(autoConfig.enabled, "Auto off");
        require(userAutoEnabled[msg.sender], "Not enabled");
        uint256 bal = userBalance[msg.sender][address(0)];
        require(bal >= autoConfig.minBalance && bal > 0, "Low balance");
        require(block.timestamp >= userAutoLastTime[msg.sender] + autoConfig.cooldown, "Cooldown");
        uint256 amount = bal;
        if (autoConfig.maxAmount > 0 && amount > autoConfig.maxAmount) amount = autoConfig.maxAmount;
        require(amount <= address(this).balance, "Contract low");
        userBalance[msg.sender][address(0)] -= amount;
        userAutoLastTime[msg.sender] = block.timestamp;
        userAutoTotal[msg.sender] += amount;
        payable(autoConfig.destination).transfer(amount);
        emit AutoWithdrawExecuted(msg.sender, amount);
    }

    // ---------- Trading functions ----------
    function _calcBuy(address token, uint256 amount) private view returns (uint256 reqNative, uint256 fee, uint256 totalReq, uint256 sendAmount) {
        uint256 price = tokenPrice[token];
        require(price > 0, "Price");
        uint256 requiredUSD = (amount * price) / 1e18;
        reqNative = (requiredUSD * 1e18) / nativePrice;
        uint256 effectiveFee = platformFee;
        uint256 disc = userDiscount[msg.sender];
        if (disc > effectiveFee) disc = effectiveFee;
        effectiveFee -= disc;
        fee = (reqNative * effectiveFee) / 10000;
        totalReq = reqNative + fee;
        uint256 burn = (amount * burnRate) / 10000;
        sendAmount = amount - burn;
    }

    function buyToken(address token, uint256 amount) external payable notPaused notEmergency notBlacklisted onlyWhitelisted {
        require(isSupported[token], "Not supported");
        require(amount > 0, "Zero");
        if (minPurchase > 0) require(msg.value >= minPurchase, "Below min");
        if (maxPurchase < type(uint256).max) require(msg.value <= maxPurchase, "Above max");

        (uint256 reqNative, uint256 fee, uint256 totalReq, uint256 sendAmount) = _calcBuy(token, amount);
        require(msg.value >= totalReq, "Insufficient");
        if (msg.value > totalReq) payable(msg.sender).transfer(msg.value - totalReq);

        IERC20 t = IERC20(token);
        require(t.balanceOf(address(this)) >= amount, "Low liquidity");
        t.safeTransfer(msg.sender, sendAmount);
        uint256 burnAmount = amount - sendAmount;
        if (burnAmount > 0) t.safeTransfer(address(0xdead), burnAmount);

        totalVolume += reqNative;
        totalFees += fee;
        totalBuys++;
        userBalance[msg.sender][token] += sendAmount;
        emit TokenBought(msg.sender, token, amount, reqNative);
        if (fee > 0) {
            payable(owner).transfer(fee);
            _giveReferralReward(msg.sender, fee);
        }
    }

    function sellToken(address token, uint256 amount) external notPaused notEmergency notBlacklisted onlyWhitelisted {
        require(isSupported[token], "Not supported");
        require(amount > 0, "Zero");
        require(userBalance[msg.sender][token] >= amount, "Insufficient");

        uint256 price = tokenPrice[token];
        require(price > 0, "Price");
        uint256 requiredUSD = (amount * price) / 1e18;
        uint256 reqNative = (requiredUSD * 1e18) / nativePrice;
        uint256 effectiveFee = platformFee;
        uint256 disc = userDiscount[msg.sender];
        if (disc > effectiveFee) disc = effectiveFee;
        effectiveFee -= disc;
        uint256 fee = (reqNative * effectiveFee) / 10000;
        uint256 receiveAmount = reqNative - fee;
        require(address(this).balance >= receiveAmount, "Contract low");

        userBalance[msg.sender][token] -= amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        payable(msg.sender).transfer(receiveAmount);

        totalVolume += reqNative;
        totalFees += fee;
        emit TokenSold(msg.sender, token, amount, receiveAmount);
    }

    // ---------- Admin settings ----------
    function setPlatformFee(uint256 newFee) external onlyOwner { platformFee = newFee; }
    function setBurnRate(uint256 newRate) external onlyOwner { burnRate = newRate; }
    function setPurchaseLimits(uint256 newMin, uint256 newMax) external onlyOwner {
        require(newMin <= newMax || newMax == 0, "Invalid");
        minPurchase = newMin;
        maxPurchase = newMax;
    }
    function setNativePrice(uint256 newPrice) external onlyOwner { require(newPrice > 0); nativePrice = newPrice; }
    function togglePause() external onlyOwner { paused = !paused; }
    function toggleEmergency() external onlyOwner { emergencyMode = !emergencyMode; }
    function setTokenCreationFee(uint256 newFee, address newWallet) external onlyOwner {
        tokenCreationFee = newFee;
        tokenCreationFeeWallet = newWallet;
        emit TokenCreationFeeUpdated(newFee, newWallet);
    }
    function setGlobalCreationDiscount(uint256 discount) external onlyOwner { globalCreationDiscount = discount; }
    function setUserCreationDiscount(address user, uint256 discount) external onlyOwner { userCreationDiscount[user] = discount; }
    function setReferralParams(uint256 rate, uint256 maxBonus) external onlyOwner { referralRate = rate; maxReferralBonus = maxBonus; }
    function enableGlobalAutoWithdraw(bool enable) external onlyOwner { autoConfig.enabled = enable; }

    // ---------- Withdrawal for owner ----------
    function withdrawAll() external onlyOwner { payable(owner).transfer(address(this).balance); }
    function withdrawToken(address token) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).safeTransfer(owner, bal);
    }

    // ---------- View functions ----------
    function getSupportedTokens() external view returns (address[] memory) { return supportedTokens; }
    function getTokenPackages(address token) external view returns (Package[] memory) { return tokenPackages[token]; }
    function getGlobalStats() external view returns (uint256 volume, uint256 fees, uint256 buys, uint256 tokensCount, uint256 balance) {
        return (totalVolume, totalFees, totalBuys, totalTokensCreated, address(this).balance);
    }
    function getUserStats(address user) external view returns (address ref, uint256 refCount, uint256 refEarned, uint256 discountBP, bool autoEnabled) {
        return (referrer[user], referralCount[user], referralEarned[user], userDiscount[user], userAutoEnabled[user]);
    }
    function getUserBalance(address user, address token) external view returns (uint256) { return userBalance[user][token]; }
    function getTokenInfo(address token) external view returns (bool supported, uint256 price) {
        return (isSupported[token], tokenPrice[token]);
    }

    receive() external payable {}
}