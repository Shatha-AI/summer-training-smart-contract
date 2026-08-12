// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// https://x.com/TheAutistBull
// https://x.com/VitalikButerin/status/1879597949178802602/photo/1

contract TheAutisticBull {
    // --- ERC20 metadata ---
    string public constant name = "The Autistic Bull";
    string public constant symbol = "VITALIK";
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;

    // --- ownership ---
    address public owner;

    // --- launch controls ---
    bool public tradingEnabled;
    bool public limitsInEffect = true;
    uint256 public maxTxAmount;
    uint256 public maxWalletAmount;

    // --- ledgers ---
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isExcludedFromLimits;
    mapping(address => bool) public isAMMPair;

    // --- events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TradingEnabled();
    event LimitsRemoved();
    event ExcludedFromLimits(address indexed account, bool excluded);
    event AMMPairSet(address indexed pair, bool value);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;

        uint256 supply = 1_000_000_000 * 10 ** decimals; // 1,000,000,000 VITALIK
        totalSupply = supply;

        maxTxAmount = (supply * 55) / 10_000; // 0.55%
        maxWalletAmount = (supply * 200) / 10_000; // 2%

        isExcludedFromLimits[msg.sender] = true;
        isExcludedFromLimits[address(this)] = true;
        isExcludedFromLimits[address(0)] = true;

        balanceOf[msg.sender] = supply;
        emit Transfer(address(0), msg.sender, supply);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // --- ERC20 ---
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ALLOWANCE");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ZERO_FROM");
        require(to != address(0), "ZERO_TO");
        require(balanceOf[from] >= amount, "BALANCE");

        bool fromExcluded = isExcludedFromLimits[from];
        bool toExcluded = isExcludedFromLimits[to];

        // Trading gate: nobody can trade until enabled, but excluded
        // addresses (owner/contract) can still move tokens to seed LP.
        if (!tradingEnabled) {
            require(fromExcluded || toExcluded, "TRADING_DISABLED");
        }

        if (limitsInEffect) {
            // Max tx: only on actual buys/sells (transfers touching a pair),
            // and only against the non-pair, non-excluded counterparty.
            bool isBuy = isAMMPair[from] && !toExcluded;
            bool isSell = isAMMPair[to] && !fromExcluded;
            if (isBuy || isSell) {
                require(amount <= maxTxAmount, "MAX_TX");
            }

            // Max wallet: cap the receiver, unless it is excluded or a pair.
            if (!toExcluded && !isAMMPair[to]) {
                require(balanceOf[to] + amount <= maxWalletAmount, "MAX_WALLET");
            }
        }

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    // --- owner controls ---
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "ALREADY_ENABLED");
        tradingEnabled = true;
        emit TradingEnabled();
    }

    function removeLimits() external onlyOwner {
        limitsInEffect = false;
        emit LimitsRemoved();
    }

    function setExcludedFromLimits(address account, bool excluded) external onlyOwner {
        isExcludedFromLimits[account] = excluded;
        emit ExcludedFromLimits(account, excluded);
    }

    function setAMMPair(address pair, bool value) external onlyOwner {
        isAMMPair[pair] = value;
        emit AMMPairSet(pair, value);
    }

    function setLimits(uint256 newMaxTx, uint256 newMaxWallet) external onlyOwner {
        require(newMaxTx >= (totalSupply * 5) / 10_000, "TX_TOO_LOW"); // >= 0.05%
        require(newMaxWallet >= (totalSupply * 5) / 10_000, "WALLET_TOO_LOW");
        maxTxAmount = newMaxTx;
        maxWalletAmount = newMaxWallet;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
