// SPDX-License-Identifier: MIT

/*

    METAL ($METAL)
    The settlement network for tokenized financial products
    A full stack for the future of tokenized finance.

    --------------------------------------------------------------------------
    Website:  https://metalntwx.com/
    Twitter:  https://x.com/metalntwx
    --------------------------------------------------------------------------

    WHAT METAL SETTLES
    - Tokenized financial products: institutional-grade tokenized bank deposits,
      money markets, T-bills, equities, and securities.
    - Stablecoin payments: instant, cheap, cross-border payments for global
      collections, remittance, payroll, and pay-outs in any currency.
    - Inter-institutional settlement: institutional-grade compliance executes
      provably, privately, and instantly during on-chain settlement.
    - Micro-transactions: low and predictable transaction fees make
      micro-transactions efficient at any scale.
    - Agents: native support for agentic payment and authorization protocols
      for instant, intelligent, autonomous finance.
    - Embedded finance: offer the full stack of tokenized financial products and
      services directly through your product.

    WHY BUILD ON METAL FOUNDATIONS
    - Agentic: native support for x402, AP2, UCP+ACP, ERC-8004/8183, instant
      micro-transactions, subscriptions, and programmable guardrails. The era of
      agentic finance is now.
    - Institutional: primitives for stablecoins, tokenized bank deposits, money
      markets, T-bills, stocks, and securities, plus programmable on-chain
      compliance and identification with institutional-grade privacy.
    - Liquid: a global network of local payment rails covering 200 countries and
      90 currencies, in partnership with Airwallex.

*/

pragma solidity 0.8.26;

/// @dev Minimal Ownable.
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroOwner();

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroOwner();
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address old = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

/// @title Metal
/// @notice The settlement network for tokenized financial products.
contract Metal is Ownable {
    // ----------------------------------------------------------------------
    // ERC20 metadata
    // ----------------------------------------------------------------------
    string public constant name = "Metal";
    string public constant symbol = "METAL";
    uint8 public constant decimals = 18;
    uint256 public immutable totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ----------------------------------------------------------------------
    // Trading controls
    // ----------------------------------------------------------------------
    bool public tradingActive;
    bool public limitsActive = true;

    uint256 public maxTxAmount;        // max tokens per single trade
    uint256 public maxWalletAmount;    // max tokens a wallet may hold

    /// @notice The Uniswap v4 PoolManager singleton. Transfers to/from it are
    ///         treated as sells/buys for limit purposes.
    address public poolManager;

    /// @notice Addresses excluded from limits and the pre-trading transfer gate.
    mapping(address => bool) public isExempt;

    event TradingEnabled();
    event LimitsRemoved();
    event ExemptSet(address indexed account, bool exempt);
    event PoolManagerSet(address indexed poolManager);

    error TradingNotActive();
    error MaxTxExceeded();
    error MaxWalletExceeded();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor(address initialOwner, address poolManager_) Ownable(initialOwner) {
        uint256 supply = 100_000_000 * 10 ** decimals; // 100,000,000 METAL
        totalSupply = supply;

        // 2% max transaction, 2% max wallet
        maxTxAmount = (supply * 2) / 100;
        maxWalletAmount = (supply * 2) / 100;

        poolManager = poolManager_;

        // Exempt the deployer/owner and this contract so that liquidity can be
        // provisioned before trading is enabled. The PoolManager is deliberately
        // NOT exempt: buys (PoolManager -> buyer) must respect the trading gate
        // and the per-buyer max tx / max wallet limits.
        isExempt[initialOwner] = true;
        isExempt[address(this)] = true;

        balanceOf[initialOwner] = supply;
        emit Transfer(address(0), initialOwner, supply);
    }

    // ----------------------------------------------------------------------
    // ERC20
    // ----------------------------------------------------------------------
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < value) revert InsufficientBalance();

        _checkLimits(from, to, value);

        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }

    // ----------------------------------------------------------------------
    // Limits
    // ----------------------------------------------------------------------
    function _checkLimits(address from, address to, uint256 value) internal view {
        // Pre-trading: only exempt parties (owner, contract, pool infra) may move tokens.
        if (!tradingActive) {
            if (!isExempt[from] && !isExempt[to]) revert TradingNotActive();
        }

        if (!limitsActive) return;

        bool isBuy = from == poolManager;   // tokens leaving the pool to a buyer
        bool isSell = to == poolManager;    // tokens entering the pool from a seller

        if (isBuy && !isExempt[to]) {
            if (value > maxTxAmount) revert MaxTxExceeded();
            if (balanceOf[to] + value > maxWalletAmount) revert MaxWalletExceeded();
        } else if (isSell && !isExempt[from]) {
            if (value > maxTxAmount) revert MaxTxExceeded();
        } else if (!isExempt[from] && !isExempt[to]) {
            if (value > maxTxAmount) revert MaxTxExceeded();
            if (balanceOf[to] + value > maxWalletAmount) revert MaxWalletExceeded();
        }
    }

    // ----------------------------------------------------------------------
    // Owner controls
    // ----------------------------------------------------------------------
    function enableTrading() external onlyOwner {
        tradingActive = true;
        emit TradingEnabled();
    }

    function removeLimits() external onlyOwner {
        limitsActive = false;
        emit LimitsRemoved();
    }

    function setExempt(address account, bool exempt) external onlyOwner {
        isExempt[account] = exempt;
        emit ExemptSet(account, exempt);
    }

    function setPoolManager(address poolManager_) external onlyOwner {
        poolManager = poolManager_;
        emit PoolManagerSet(poolManager_);
    }

    /// @notice Adjust limits (values in whole tokens, 18 decimals applied internally is not
    ///         done here — pass raw token amounts * 10**18). Cannot be set below 1% of supply.
    function setLimits(uint256 maxTx_, uint256 maxWallet_) external onlyOwner {
        uint256 floor = totalSupply / 100; // 1% floor to prevent honeypot-style throttling
        require(maxTx_ >= floor && maxWallet_ >= floor, "limit too low");
        maxTxAmount = maxTx_;
        maxWalletAmount = maxWallet_;
    }
}
