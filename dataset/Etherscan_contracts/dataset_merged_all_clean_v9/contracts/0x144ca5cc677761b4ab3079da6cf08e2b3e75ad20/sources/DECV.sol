// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

contract DECV {
    string public name = "DECV";
    string public symbol = "DECV";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    // ===== 所有权 =====
    address public immutable owner;

    // ===== 代币分配 =====
    uint256 public constant TOTAL_SUPPLY = 21_000_000 * 1e18;
    uint256 public constant CROWDSALE_SUPPLY = 18_000_000 * 1e18; // 1800万众筹
    uint256 public constant COMMUNITY_SUPPLY = 3_000_000 * 1e18;  // 300万社区

    // ===== 众筹阶段 =====
    enum CrowdsaleStage { NONE, STAGE1, STAGE2, STAGE3, ENDED }
    CrowdsaleStage public currentStage = CrowdsaleStage.STAGE1;

    // 各阶段价格（USDT → DECV）
    uint256 public stage1Rate = 100 * 1e18;  // 1 USDT = 100 DECV
    uint256 public stage2Rate = 50 * 1e18;   // 1 USDT = 50 DECV
    uint256 public stage3Rate = 10 * 1e18;   // 1 USDT = 10 DECV

    // Uniswap 上线价格（1 DECV = 10 USDT）
    uint256 public constant UNISWAP_RATE = 10 * 1e18; // 1 DECV = 10 USDT

    // ===== USDT 配置 =====
    IERC20 public usdtToken;
    uint256 public totalUsdtRaised;
    uint256 public totalDecvSold;

    // ===== 余额 =====
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) private allowanceMap;

    // ===== 事件 =====
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BoughtWithUSDT(address indexed user, uint256 usdtPaid, uint256 decvReceived);
    event StageChanged(CrowdsaleStage oldStage, CrowdsaleStage newStage);
    event WithdrawnUSDT(address indexed owner, uint256 amount);
    event WithdrawnDECV(address indexed owner, uint256 amount);
    event RateUpdated(uint256 stage1, uint256 stage2, uint256 stage3);

    // ===== 修饰符 =====
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _usdtAddress) {
        owner = msg.sender;
        usdtToken = IERC20(_usdtAddress);

        totalSupply = TOTAL_SUPPLY;

        // 分配代币
        balanceOf[msg.sender] = COMMUNITY_SUPPLY;           // 300万给社区
        balanceOf[address(this)] = CROWDSALE_SUPPLY;         // 1800万给众筹池

        emit Transfer(address(0), msg.sender, COMMUNITY_SUPPLY);
        emit Transfer(address(0), address(this), CROWDSALE_SUPPLY);
    }

    // ==================== 购买 DECV（USDT）====================

    function buyWithUSDT(uint256 usdtAmount) external {
        require(currentStage != CrowdsaleStage.NONE && currentStage != CrowdsaleStage.ENDED, "Crowdsale not active");
        require(usdtAmount > 0, "Zero USDT");

        // 从用户转移 USDT 到合约
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");

        uint256 rate = getCurrentRate();
        uint256 decvToGive = (usdtAmount * rate) / 1e18;

        require(balanceOf[address(this)] >= decvToGive, "Not enough DECV in pool");

        // 发放 DECV
        balanceOf[address(this)] -= decvToGive;
        balanceOf[msg.sender] += decvToGive;

        totalUsdtRaised += usdtAmount;
        totalDecvSold += decvToGive;

        emit Transfer(address(this), msg.sender, decvToGive);
        emit BoughtWithUSDT(msg.sender, usdtAmount, decvToGive);
    }

    // ==================== 阶段管理 ====================

    function nextStage() external onlyOwner {
        if (currentStage == CrowdsaleStage.STAGE1) {
            currentStage = CrowdsaleStage.STAGE2;
        } else if (currentStage == CrowdsaleStage.STAGE2) {
            currentStage = CrowdsaleStage.STAGE3;
        } else if (currentStage == CrowdsaleStage.STAGE3) {
            currentStage = CrowdsaleStage.ENDED;
        }
        emit StageChanged(currentStage, currentStage);
    }

    function setStage(CrowdsaleStage stage) external onlyOwner {
        currentStage = stage;
        emit StageChanged(currentStage, stage);
    }

    function getCurrentRate() public view returns (uint256) {
        if (currentStage == CrowdsaleStage.STAGE1) return stage1Rate;
        if (currentStage == CrowdsaleStage.STAGE2) return stage2Rate;
        if (currentStage == CrowdsaleStage.STAGE3) return stage3Rate;
        return 0;
    }

    // ==================== 兑换率调整（仅开发者）====================

    function setRates(uint256 _stage1, uint256 _stage2, uint256 _stage3) external onlyOwner {
        stage1Rate = _stage1;
        stage2Rate = _stage2;
        stage3Rate = _stage3;
        emit RateUpdated(_stage1, _stage2, _stage3);
    }

    // ==================== 提现（仅开发者）====================

    // 提取 USDT
    function withdrawUSDT() external onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No USDT");
        require(usdtToken.transfer(owner, balance), "USDT withdraw failed");
        emit WithdrawnUSDT(owner, balance);
    }

    // 提取 DECV（合约中的剩余代币）
    function withdrawDECV() external onlyOwner {
        uint256 balance = balanceOf[address(this)];
        require(balance > 0, "No DECV");
        balanceOf[address(this)] -= balance;
        balanceOf[owner] += balance;
        emit Transfer(address(this), owner, balance);
        emit WithdrawnDECV(owner, balance);
    }

    // 提取指定数量的 DECV
    function withdrawDECVAmount(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        uint256 balance = balanceOf[address(this)];
        require(balance >= amount, "Insufficient DECV");
        
        balanceOf[address(this)] -= amount;
        balanceOf[owner] += amount;
        emit Transfer(address(this), owner, amount);
        emit WithdrawnDECV(owner, amount);
    }

    // ==================== 信息查看 ====================

    function getCrowdsaleInfo() external view returns (
        CrowdsaleStage stage,
        uint256 rate,
        uint256 usdtRaised,
        uint256 decvSold,
        uint256 decvRemaining
    ) {
        return (
            currentStage,
            getCurrentRate(),
            totalUsdtRaised,
            totalDecvSold,
            balanceOf[address(this)]
        );
    }

    function getContractBalances() external view returns (
        uint256 usdtBalance,
        uint256 decvBalance
    ) {
        return (
            usdtToken.balanceOf(address(this)),
            balanceOf[address(this)]
        );
    }

    // ==================== ERC-20 标准功能 ====================

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid recipient");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0), "Invalid sender");
        require(_to != address(0), "Invalid recipient");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowanceMap[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowanceMap[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "Invalid spender");
        require(_value == 0 || allowanceMap[msg.sender][_spender] == 0, "Reset to 0 first");

        allowanceMap[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowanceMap[_owner][_spender];
    }

    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool success) {
        require(_spender != address(0), "Invalid spender");
        allowanceMap[msg.sender][_spender] += _addedValue;
        emit Approval(msg.sender, _spender, allowanceMap[msg.sender][_spender]);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool success) {
        require(_spender != address(0), "Invalid spender");
        uint256 current = allowanceMap[msg.sender][_spender];
        require(current >= _subtractedValue, "Below zero");
        allowanceMap[msg.sender][_spender] = current - _subtractedValue;
        emit Approval(msg.sender, _spender, allowanceMap[msg.sender][_spender]);
        return true;
    }

    // 接收 ETH（防止误转，但不可购买）
    receive() external payable {}
}