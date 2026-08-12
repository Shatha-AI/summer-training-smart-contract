// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract CLXToken is IERC20 {
    string  public constant name     = "CrossLedger Token";
    string  public constant symbol   = "CLXT";
    uint8   public constant decimals = 18;
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18;

    address public owner;
    address public escrowContract;
    bool    public tradingEnabled;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakeTimestamp;

    uint256 public constant REWARD_RATE = 10; // 10% APY
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event EscrowContractSet(address indexed escrow);
    event TradingEnabled();

    modifier onlyOwner() { require(msg.sender == owner, "CLX: not owner"); _; }

    constructor(address _treasury) {
        owner = msg.sender;
        _balances[_treasury] = TOTAL_SUPPLY;
        emit Transfer(address(0), _treasury, TOTAL_SUPPLY);
    }

    function totalSupply() external pure returns (uint256) { return TOTAL_SUPPLY; }
    function balanceOf(address account) external view returns (uint256) { return _balances[account]; }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount); return true;
    }

    function allowance(address _owner, address spender) external view returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount); return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(_allowances[from][msg.sender] >= amount, "CLX: insufficient allowance");
        _allowances[from][msg.sender] -= amount;
        _transfer(from, to, amount); return true;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "CLX: zero amount");
        require(_balances[msg.sender] >= amount, "CLX: insufficient balance");
        _claimReward(msg.sender);
        _balances[msg.sender] -= amount;
        stakedBalance[msg.sender] += amount;
        stakeTimestamp[msg.sender] = block.timestamp;
    }

    function unstake(uint256 amount) external {
        require(stakedBalance[msg.sender] >= amount, "CLX: insufficient staked");
        _claimReward(msg.sender);
        stakedBalance[msg.sender] -= amount;
        _balances[msg.sender] += amount;
    }

    function _calculateReward(address user) internal view returns (uint256) {
        if (stakedBalance[user] == 0) return 0;
        uint256 elapsed = block.timestamp - stakeTimestamp[user];
        return (stakedBalance[user] * REWARD_RATE * elapsed) / (100 * SECONDS_PER_YEAR);
    }

    function _claimReward(address user) internal {
        uint256 reward = _calculateReward(user);
        if (reward > 0) { _balances[user] += reward; stakeTimestamp[user] = block.timestamp; }
    }

    function pendingReward(address user) external view returns (uint256) {
        if (stakedBalance[user] == 0) return 0;
        return _calculateReward(user);
    }

    function setEscrowContract(address _escrow) external onlyOwner {
        require(_escrow != address(0), "CLX: zero address");
        escrowContract = _escrow; emit EscrowContractSet(_escrow);
    }

    function enableTrading() external onlyOwner { tradingEnabled = true; emit TradingEnabled(); }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "CLX: zero address"); owner = newOwner;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0) && to != address(0), "CLX: zero address");
        require(_balances[from] >= amount, "CLX: insufficient balance");
        if (from != owner && from != escrowContract) require(tradingEnabled, "CLX: trading not enabled");
        _balances[from] -= amount;
        _balances[to]   += amount;
        emit Transfer(from, to, amount);
    }
}