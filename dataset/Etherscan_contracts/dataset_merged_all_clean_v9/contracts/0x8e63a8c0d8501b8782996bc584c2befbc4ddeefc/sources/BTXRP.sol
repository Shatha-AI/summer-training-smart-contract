// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BTXRP {
    string public name = "BTXRP";
    string public symbol = "BTXRP";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) private allowanceMap;

    // ===== 所有者与权限 =====
    address public immutable owner;
    
    // ===== 兑换参数 =====
    uint256 public ethToTokenRate = 10000 * 1e18; // 1 ETH = 10000 BTXRP
    uint256 public minEthToTokenRate = 1000 * 1e18;  // 最低兑换率
    uint256 public maxEthToTokenRate = 100000 * 1e18; // 最高兑换率
    uint256 public totalEthContributed; // 记录总共收到的ETH
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Bought(address indexed user, uint256 ethPaid, uint256 tokensGiven);
    event EthWithdrawnByOwner(address indexed owner, uint256 amount);
    event TokensWithdrawnByOwner(address indexed owner, uint256 amount);
    event ExchangeRateUpdated(address indexed owner, uint256 oldRate, uint256 newRate);

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

    constructor() {
        owner = msg.sender;
        _status = _NOT_ENTERED;
        
        totalSupply = 21000000 * (10 ** uint256(decimals));
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    // ==================== 用户购买（ETH → BTXRP）====================
    
    /// @notice 用户发送ETH购买BTXRP
    function buy() external payable {
        _buy(msg.sender, msg.value);
    }
    
    /// @notice 直接接收ETH（无calldata）
    receive() external payable {
        _buy(msg.sender, msg.value);
    }
    
    function _buy(address user, uint256 ethAmount) internal {
        require(ethAmount > 0, "Send ETH > 0");
        
        uint256 tokensToGive = (ethAmount * ethToTokenRate) / 1e18;
        require(tokensToGive > 0, "Too small");
        require(balanceOf[owner] >= tokensToGive, "Insufficient token reserve");
        
        // 从所有者储备中扣除代币给用户
        balanceOf[owner] -= tokensToGive;
        balanceOf[user] += tokensToGive;
        
        // 记录总ETH贡献
        totalEthContributed += ethAmount;
        
        emit Transfer(owner, user, tokensToGive);
        emit Bought(user, ethAmount, tokensToGive);
    }

    // ==================== 所有者管理功能 ====================
    
    /// @notice 所有者提取合约中的所有ETH
    function withdrawAllEth() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        (bool ok, ) = payable(owner).call{value: balance}("");
        require(ok, "ETH withdrawal failed");
        
        emit EthWithdrawnByOwner(owner, balance);
    }
    
    /// @notice 所有者提取指定数量的ETH
    function withdrawEth(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(address(this).balance >= amount, "Insufficient ETH balance");
        
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "ETH withdrawal failed");
        
        emit EthWithdrawnByOwner(owner, amount);
    }
    
    /// @notice 所有者提取合约中的所有BTXRP代币
    function withdrawAllTokens() external onlyOwner {
        uint256 contractTokenBalance = balanceOf[address(this)];
        require(contractTokenBalance > 0, "No tokens to withdraw");
        
        balanceOf[address(this)] -= contractTokenBalance;
        balanceOf[owner] += contractTokenBalance;
        
        emit Transfer(address(this), owner, contractTokenBalance);
        emit TokensWithdrawnByOwner(owner, contractTokenBalance);
    }
    
    /// @notice 所有者提取指定数量的BTXRP代币
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        uint256 contractTokenBalance = balanceOf[address(this)];
        require(contractTokenBalance >= amount, "Insufficient token balance");
        
        balanceOf[address(this)] -= amount;
        balanceOf[owner] += amount;
        
        emit Transfer(address(this), owner, amount);
        emit TokensWithdrawnByOwner(owner, amount);
    }
    
    /// @notice 设置新的兑换率（仅所有者）
    /// @param newRate 新的兑换率（1 ETH = newRate BTXRP）
    function setEthToTokenRate(uint256 newRate) external onlyOwner {
        require(newRate >= minEthToTokenRate, "Rate below minimum");
        require(newRate <= maxEthToTokenRate, "Rate above maximum");
        
        uint256 oldRate = ethToTokenRate;
        ethToTokenRate = newRate;
        
        emit ExchangeRateUpdated(owner, oldRate, newRate);
    }
    
    /// @notice 设置兑换率的最小最大值（仅所有者）
    /// @param min 最小兑换率
    /// @param max 最大兑换率
    function setExchangeRateBounds(uint256 min, uint256 max) external onlyOwner {
        require(min > 0, "Min rate must be > 0");
        require(max > min, "Max must be greater than min");
        
        minEthToTokenRate = min;
        maxEthToTokenRate = max;
        
        // 确保当前汇率在新范围内
        if (ethToTokenRate < min) {
            ethToTokenRate = min;
        } else if (ethToTokenRate > max) {
            ethToTokenRate = max;
        }
    }
    
    /// @notice 查看合约ETH余额
    function getContractEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /// @notice 查看合约的BTXRP代币余额
    function getContractTokenBalance() external view returns (uint256) {
        return balanceOf[address(this)];
    }
    
    /// @notice 查看用户的代币余额
    function getTokenBalance(address user) external view returns (uint256) {
        return balanceOf[user];
    }
    
    /// @notice 查看合约的代币储备（所有者持有的代币）
    function getContractTokenReserve() external view returns (uint256) {
        return balanceOf[owner];
    }

    // ==================== 原有ERC-20功能（不变）====================
    
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