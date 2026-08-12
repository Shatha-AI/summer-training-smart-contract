// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
    function WETH() external pure returns (address);
}

contract SPECI {
    string public name = "SPECI";
    string public symbol = "SPECI";
    uint8 public constant decimals = 18;
    uint256 public constant TOTAL_SUPPLY = 21000000 * 1e18;
    
    // 分配方案
    uint256 public constant CROWDSALE_SUPPLY = 18000000 * 1e18; // 1800万用于众筹
    uint256 public constant COMMUNITY_SUPPLY = 3000000 * 1e18;  // 300万用于社区运营
    
    // 三轮众筹配置
    struct CrowdsalePhase {
        uint256 tokensForSale;     // 本轮出售的代币数量
        uint256 tokensSold;        // 已售出数量
        uint256 exchangeRate;      // 兑换率（1 ETH = ? SPECI）
        bool isActive;             // 是否激活
    }
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) private allowanceMap;
    
    // ===== 所有者与权限 =====
    address public immutable owner;
    
    // ===== Uniswap 配置 =====
    address public uniswapRouter;
    bool public tradingEnabled = false;
    uint256 public constant UNISWAP_PRICE_RATE = 1000 * 1e18; // 1 ETH = 1000 SPECI
    
    // ===== 众筹阶段 =====
    CrowdsalePhase[3] public phases;
    uint256 public currentPhaseIndex = 0;
    uint256 public totalEthRaised;
    uint256 public totalTokensSold;
    
    // ===== 事件 =====
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokensPurchased(address indexed buyer, uint256 ethPaid, uint256 tokensReceived, uint256 phase);
    event PhaseChanged(uint256 indexed newPhase, uint256 exchangeRate);
    event EthWithdrawnByOwner(address indexed owner, uint256 amount);
    event CommunityTokensAllocated(address indexed owner, uint256 amount);
    event LiquidityAddedToUniswap(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event TradingEnabled(bool enabled);
    event ExchangeRateUpdated(uint256 phaseIndex, uint256 oldRate, uint256 newRate);

    // ===== 轻量 ReentrancyGuard =====
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _uniswapRouter) {
        owner = msg.sender;
        _status = _NOT_ENTERED;
        uniswapRouter = _uniswapRouter;
        
        // 初始化三轮众筹
        phases[0] = CrowdsalePhase({
            tokensForSale: 6000000 * 1e18,  // 600万代币
            tokensSold: 0,
            exchangeRate: 100000 * 1e18,     // 1 ETH = 100,000 SPECI
            isActive: false
        });
        
        phases[1] = CrowdsalePhase({
            tokensForSale: 6000000 * 1e18,  // 600万代币
            tokensSold: 0,
            exchangeRate: 50000 * 1e18,      // 1 ETH = 50,000 SPECI
            isActive: false
        });
        
        phases[2] = CrowdsalePhase({
            tokensForSale: 6000000 * 1e18,  // 600万代币
            tokensSold: 0,
            exchangeRate: 10000 * 1e18,      // 1 ETH = 10,000 SPECI
            isActive: false
        });
        
        // 分配代币
        balanceOf[owner] = COMMUNITY_SUPPLY; // 300万给开发者
        balanceOf[address(this)] = CROWDSALE_SUPPLY; // 1800万留在合约用于众筹
        
        emit CommunityTokensAllocated(owner, COMMUNITY_SUPPLY);
        emit Transfer(address(0), owner, COMMUNITY_SUPPLY);
        emit Transfer(address(0), address(this), CROWDSALE_SUPPLY);
    }

    // ==================== 众筹管理（仅所有者）====================
    
    /// @notice 启动指定阶段的众筹
    function startPhase(uint256 phaseIndex) external onlyOwner {
        require(phaseIndex < 3, "Invalid phase index");
        require(!phases[phaseIndex].isActive, "Phase already active");
        
        // 结束当前阶段（如果有）
        if (currentPhaseIndex < 3 && phases[currentPhaseIndex].isActive) {
            phases[currentPhaseIndex].isActive = false;
        }
        
        currentPhaseIndex = phaseIndex;
        phases[phaseIndex].isActive = true;
        emit PhaseChanged(phaseIndex, phases[phaseIndex].exchangeRate);
    }
    
    /// @notice 结束当前阶段
    function endCurrentPhase() external onlyOwner {
        require(currentPhaseIndex < 3, "No active phase");
        phases[currentPhaseIndex].isActive = false;
    }
    
    /// @notice 调整指定阶段的兑换率（仅所有者）
    /// @param phaseIndex 阶段索引（0,1,2）
    /// @param newRate 新的兑换率（1 ETH = ? SPECI）
    function setExchangeRate(uint256 phaseIndex, uint256 newRate) external onlyOwner {
        require(phaseIndex < 3, "Invalid phase index");
        require(newRate > 0, "Rate must be > 0");
        
        uint256 oldRate = phases[phaseIndex].exchangeRate;
        phases[phaseIndex].exchangeRate = newRate;
        
        emit ExchangeRateUpdated(phaseIndex, oldRate, newRate);
    }
    
    /// @notice 检查是否可以购买
    function canBuy() public view returns (bool) {
        if (currentPhaseIndex >= 3) return false;
        CrowdsalePhase memory phase = phases[currentPhaseIndex];
        return phase.isActive && phase.tokensSold < phase.tokensForSale;
    }

    // ==================== 购买代币 ====================
    
    /// @notice 购买代币（ETH → SPECI）
    function buy() external payable {
        _buy(msg.sender, msg.value);
    }
    
    /// @notice 接收ETH并购买代币
    receive() external payable {
        _buy(msg.sender, msg.value);
    }
    
    function _buy(address buyer, uint256 ethAmount) internal {
        require(canBuy(), "Crowdsale not active or sold out");
        require(ethAmount > 0, "Send ETH > 0");
        
        CrowdsalePhase storage phase = phases[currentPhaseIndex];
        uint256 tokensToGive = (ethAmount * phase.exchangeRate) / 1e18;
        require(tokensToGive > 0, "Too small");
        
        uint256 remaining = phase.tokensForSale - phase.tokensSold;
        require(remaining >= tokensToGive, "Exceeds phase limit");
        
        phase.tokensSold += tokensToGive;
        totalTokensSold += tokensToGive;
        totalEthRaised += ethAmount;
        
        // 从合约储备转移代币给买家
        balanceOf[address(this)] -= tokensToGive;
        balanceOf[buyer] += tokensToGive;
        
        emit Transfer(address(this), buyer, tokensToGive);
        emit TokensPurchased(buyer, ethAmount, tokensToGive, currentPhaseIndex);
    }

    // ==================== Uniswap 上线功能 ====================
    
    /// @notice 添加流动性到 Uniswap（设置初始价格 1 ETH = 1000 SPECI）
    /// @param tokenAmount 要添加的代币数量
    /// @param ethAmount 要添加的 ETH 数量
    function addLiquidityToUniswap(uint256 tokenAmount, uint256 ethAmount) external onlyOwner nonReentrant {
        require(tokenAmount > 0, "Token amount must be > 0");
        require(ethAmount > 0, "ETH amount must be > 0");
        require(balanceOf[owner] >= tokenAmount, "Insufficient token balance");
        require(address(this).balance >= ethAmount, "Insufficient ETH in contract");
        
        // 将代币从所有者转移到合约
        balanceOf[owner] -= tokenAmount;
        balanceOf[address(this)] += tokenAmount;
        emit Transfer(owner, address(this), tokenAmount);
        
        // 授权 Uniswap 路由器使用代币
        allowanceMap[address(this)][uniswapRouter] = tokenAmount;
        
        // 添加流动性到 Uniswap
        uint256 deadline = block.timestamp + 30 minutes;
        
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = 
            IUniswapV2Router02(uniswapRouter).addLiquidityETH{value: ethAmount}(
                address(this),
                tokenAmount,
                tokenAmount * 95 / 100, // 允许 5% 的滑点
                ethAmount * 95 / 100,   // 允许 5% 的滑点
                owner,                  // LP 代币发送给所有者
                deadline
            );
        
        emit LiquidityAddedToUniswap(amountToken, amountETH, liquidity);
    }
    
    /// @notice 启用/禁用交易（可选，用于控制是否允许 Uniswap 交易）
    function setTradingEnabled(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        emit TradingEnabled(_enabled);
    }
    
    /// @notice 查看 Uniswap 初始价格对应的代币/ETH 比例
    function getUniswapInitialPrice() external pure returns (uint256 tokenPerEth) {
        return UNISWAP_PRICE_RATE / 1e18; // 返回 1000
    }
    
    /// @notice 计算给定 ETH 数量在 Uniswap 上能买到多少代币（基于初始价格）
    function calculateUniswapTokensForEth(uint256 ethAmount) external pure returns (uint256 tokenAmount) {
        return (ethAmount * UNISWAP_PRICE_RATE) / 1e18;
    }

    // ==================== 所有者提现 ====================
    
    /// @notice 所有者提取所有ETH
    function withdrawAllEth() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        (bool ok, ) = payable(owner).call{value: balance}("");
        require(ok, "ETH withdrawal failed");
        
        emit EthWithdrawnByOwner(owner, balance);
    }
    
    /// @notice 所有者提取指定数量ETH
    function withdrawEth(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(address(this).balance >= amount, "Insufficient ETH balance");
        
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "ETH withdrawal failed");
        
        emit EthWithdrawnByOwner(owner, amount);
    }

    // ==================== 查询函数 ====================
    
    /// @notice 查看合约ETH余额
    function getContractEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /// @notice 查看合约代币余额（众筹剩余）
    function getCrowdsaleTokenBalance() external view returns (uint256) {
        return balanceOf[address(this)];
    }
    
    /// @notice 查看所有者代币余额
    function getOwnerTokenBalance() external view returns (uint256) {
        return balanceOf[owner];
    }
    
    /// @notice 查看总众筹进度
    function getCrowdsaleProgress() external view returns (
        uint256 totalSold,
        uint256 totalRemaining,
        uint256 percentSold
    ) {
        totalSold = totalTokensSold;
        totalRemaining = CROWDSALE_SUPPLY - totalSold;
        percentSold = (totalSold * 100) / CROWDSALE_SUPPLY;
    }
    
    /// @notice 查看当前阶段信息
    function getCurrentPhaseInfo() external view returns (
        uint256 phaseIndex,
        uint256 tokensForSale,
        uint256 tokensSold,
        uint256 tokensRemaining,
        uint256 exchangeRate,
        bool isActive
    ) {
        if (currentPhaseIndex >= 3) {
            return (3, 0, 0, 0, 0, false); // 所有阶段结束
        }
        
        CrowdsalePhase memory phase = phases[currentPhaseIndex];
        return (
            currentPhaseIndex,
            phase.tokensForSale,
            phase.tokensSold,
            phase.tokensForSale - phase.tokensSold,
            phase.exchangeRate,
            phase.isActive
        );
    }

    // ==================== 原有ERC-20功能 ====================
    
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid recipient address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0), "Invalid sender address");
        require(_to != address(0), "Invalid recipient address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowanceMap[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowanceMap[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "Invalid spender address");
        require(_value == 0 || allowanceMap[msg.sender][_spender] == 0, "Reset allowance to 0 first");
        
        allowanceMap[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowanceMap[_owner][_spender];
    }
    
    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool success) {
        require(_spender != address(0), "Invalid spender address");
        allowanceMap[msg.sender][_spender] += _addedValue;
        emit Approval(msg.sender, _spender, allowanceMap[msg.sender][_spender]);
        return true;
    }
    
    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool success) {
        require(_spender != address(0), "Invalid spender address");
        uint256 currentAllowance = allowanceMap[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "Decreased allowance below zero");
        allowanceMap[msg.sender][_spender] = currentAllowance - _subtractedValue;
        emit Approval(msg.sender, _spender, allowanceMap[msg.sender][_spender]);
        return true;
    }
}