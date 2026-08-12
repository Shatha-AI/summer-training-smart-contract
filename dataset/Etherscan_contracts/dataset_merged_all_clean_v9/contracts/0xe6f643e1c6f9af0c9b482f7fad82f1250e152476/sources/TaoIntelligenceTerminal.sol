// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// https://tit.llc

// ─── Uniswap V2 interfaces ────────────────────────────────────────────────────

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH()    external pure returns (address);

    function addLiquidityETH(
        address token,
        uint    amountTokenDesired,
        uint    amountTokenMin,
        uint    amountETHMin,
        address to,
        uint    deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint          amountIn,
        uint          amountOutMin,
        address[] calldata path,
        address       to,
        uint          deadline
    ) external;
}

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/**
 * @title  Tao Intelligence Terminal
 * @notice ERC-20 token with 5% buy / 5% sell tax, 0.2% max tx, 2% max wallet.
 *
 * Supply distribution at deployment
 * ──────────────────────────────────
 *   90% → deployer   (seed Uniswap V2 liquidity)
 *   10% → contract   (team / marketing — sold via manualSwap or autoSwapBack)
 *
 * Tax flow
 * ──────────
 *   Every buy/sell: tax tokens accumulate in the contract.
 *   When contract balance ≥ swapThreshold AND a sell occurs:
 *     up to maxTxAmount tokens are swapped → ETH → marketingWallet.
 *   Owner may also call manualSwap() at any time.
 */
contract TaoIntelligenceTerminal {

    // ─── ERC-20 metadata ─────────────────────────────────────────────────────
    string  public constant name     = "Tao Intelligence Terminal";
    string  public constant symbol   = "TIT";
    uint8   public constant decimals = 18;
    uint256 public          totalSupply;

    // ─── Ownership ───────────────────────────────────────────────────────────
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "TIT: not owner");
        _;
    }

    // ─── DEX ─────────────────────────────────────────────────────────────────
    IUniswapV2Router02 public immutable uniswapV2Router;
    address            public immutable uniswapV2Pair;

    // ─── Tax ─────────────────────────────────────────────────────────────────
    uint256 public buyTax  = 5; // %
    uint256 public sellTax = 5; // %

    address public marketingWallet;

    // ─── Limits ──────────────────────────────────────────────────────────────
    uint256 public maxTxAmount;     // 0.2% of supply  = 2,000,000 TIT
    uint256 public maxWalletAmount; // 2%   of supply  = 20,000,000 TIT
    uint256 public swapThreshold;   // auto-swap trigger = 0.05% of supply

    bool public tradingEnabled;
    bool public limitsEnabled = true;

    // ─── Internal ────────────────────────────────────────────────────────────
    bool private inSwap;

    mapping(address => uint256)                     private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool)                        public  isExcludedFromFees;
    mapping(address => bool)                        public  isExcludedFromLimits;

    // ─── Events ──────────────────────────────────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TradingEnabled();
    event LimitsRemoved();
    event SwapBack(uint256 tokensSwapped, uint256 ethSent);
    event MarketingWalletUpdated(address indexed oldWallet, address indexed newWallet);

    // ─── Constructor ─────────────────────────────────────────────────────────
    constructor(address _router, address _marketingWallet) {
        require(_router          != address(0), "TIT: zero router");
        require(_marketingWallet != address(0), "TIT: zero marketing");

        owner           = msg.sender;
        marketingWallet = _marketingWallet;

        // ── Supply split ──────────────────────────────────────────────────
        uint256 supply   = 1_000_000_000 * 10 ** 18;
        totalSupply      = supply;

        uint256 toContract = supply * 10 / 100; // 10% — team/marketing sells
        uint256 toDeployer = supply - toContract; // 90% — liquidity

        _balances[address(this)] = toContract;
        _balances[msg.sender]    = toDeployer;

        emit Transfer(address(0), address(this), toContract);
        emit Transfer(address(0), msg.sender,    toDeployer);

        // ── Limits ────────────────────────────────────────────────────────
        maxTxAmount     = supply * 2  / 1000;  // 0.2%
        maxWalletAmount = supply * 2  / 100;   // 2%
        swapThreshold   = supply * 5  / 10000; // 0.05%

        // ── DEX setup ─────────────────────────────────────────────────────
        IUniswapV2Router02 router = IUniswapV2Router02(_router);
        uniswapV2Router = router;
        address pair    = IUniswapV2Factory(router.factory())
                            .createPair(address(this), router.WETH());
        uniswapV2Pair   = pair;

        // ── Fee / limit exclusions ─────────────────────────────────────────
        // Exclude router so removeLiquidity does not incur buy-side tax
        _setFeeExclusion(msg.sender,       true);
        _setFeeExclusion(address(this),    true);
        _setFeeExclusion(_marketingWallet, true);
        _setFeeExclusion(address(0xdead),  true);
        _setFeeExclusion(_router,          true); // router excluded for removeLiquidity

        isExcludedFromLimits[msg.sender]       = true;
        isExcludedFromLimits[address(this)]    = true;
        isExcludedFromLimits[_marketingWallet] = true;
        isExcludedFromLimits[address(0xdead)]  = true;
        isExcludedFromLimits[pair]             = true;
        isExcludedFromLimits[_router]          = true;
    }

    // ─── ERC-20 ──────────────────────────────────────────────────────────────

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 cur = _allowances[from][msg.sender];
        require(cur >= amount, "TIT: insufficient allowance");
        unchecked { _allowances[from][msg.sender] = cur - amount; }
        _transfer(from, to, amount);
        return true;
    }

    function _approve(address _owner, address spender, uint256 amount) internal {
        require(_owner  != address(0), "TIT: approve from zero");
        require(spender != address(0), "TIT: approve to zero");
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    // ─── Core transfer logic ─────────────────────────────────────────────────

    function _transfer(address from, address to, uint256 amount) internal {
        require(from   != address(0), "TIT: from zero");
        require(to     != address(0), "TIT: to zero");
        require(amount  > 0,          "TIT: zero amount");
        require(_balances[from] >= amount, "TIT: insufficient balance");

        bool fromExcludedFee = isExcludedFromFees[from];
        bool toExcludedFee   = isExcludedFromFees[to];

        // Trading gate
        if (!tradingEnabled) {
            require(fromExcludedFee || toExcludedFee, "TIT: trading not active");
        }

        bool isBuy  = from == uniswapV2Pair;
        bool isSell = to   == uniswapV2Pair;

        // ── Limits ────────────────────────────────────────────────────────
        if (limitsEnabled
            && !isExcludedFromLimits[from]
            && !isExcludedFromLimits[to])
        {
            if (isBuy || isSell) {
                require(amount <= maxTxAmount, "TIT: exceeds maxTxAmount");
            }
            if (!isSell) {
                require(
                    _balances[to] + amount <= maxWalletAmount,
                    "TIT: exceeds maxWalletAmount"
                );
            }
        }

        // ── Auto swapBack (only on sells, not during a swap) ──────────────
        uint256 contractBal = _balances[address(this)];
        if (!inSwap && isSell && contractBal >= swapThreshold && !fromExcludedFee) {
            uint256 swapAmt = contractBal > maxTxAmount ? maxTxAmount : contractBal;
            _swapBack(swapAmt);
        }

        // ── Tax ───────────────────────────────────────────────────────────
        bool takeFee = !inSwap
            && !fromExcludedFee
            && !toExcludedFee
            && (isBuy || isSell);

        if (takeFee) {
            uint256 taxPct    = isBuy ? buyTax : sellTax;
            uint256 taxAmt    = amount * taxPct / 100;
            uint256 sendAmt   = amount - taxAmt;

            _balances[from]          -= amount;
            _balances[address(this)] += taxAmt;
            _balances[to]            += sendAmt;

            emit Transfer(from, address(this), taxAmt);
            emit Transfer(from, to,            sendAmt);
        } else {
            _balances[from] -= amount;
            _balances[to]   += amount;
            emit Transfer(from, to, amount);
        }
    }

    // ─── SwapBack ────────────────────────────────────────────────────────────

    function _swapBack(uint256 tokenAmount) internal {
        inSwap = true;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uint256 ethBefore = address(this).balance;

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 ethGained = address(this).balance - ethBefore;
        if (ethGained > 0) {
            (bool ok, ) = payable(marketingWallet).call{value: ethGained}("");
            if (ok) emit SwapBack(tokenAmount, ethGained);
        }

        inSwap = false;
    }

    // ─── Owner functions ─────────────────────────────────────────────────────

    /// @notice Open trading. Cannot be reversed.
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "TIT: already enabled");
        tradingEnabled = true;
        emit TradingEnabled();
    }

    /// @notice Remove max tx + max wallet limits permanently.
    function removeLimits() external onlyOwner {
        require(limitsEnabled, "TIT: already removed");
        limitsEnabled = false;
        emit LimitsRemoved();
    }

    /**
     * @notice Manually swap `amount` contract tokens → ETH → marketingWallet.
     * @param  amount Token amount (with 18 decimals).
     */
    function manualSwap(uint256 amount) external onlyOwner {
        require(!inSwap, "TIT: swap in progress");
        require(amount > 0 && amount <= _balances[address(this)], "TIT: bad amount");
        _swapBack(amount);
    }

    function setMarketingWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "TIT: zero address");
        emit MarketingWalletUpdated(marketingWallet, wallet);
        marketingWallet = wallet;
        _setFeeExclusion(wallet, true);
        isExcludedFromLimits[wallet] = true;
    }

    function setSwapThreshold(uint256 threshold) external onlyOwner {
        require(threshold > 0 && threshold <= totalSupply / 50, "TIT: out of range");
        swapThreshold = threshold;
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        _setFeeExclusion(account, excluded);
    }

    function excludeFromLimits(address account, bool excluded) external onlyOwner {
        isExcludedFromLimits[account] = excluded;
    }

    /// @notice Rescue ETH accidentally sent to contract (marketing ETH auto-forwards).
    function withdrawStuckETH() external onlyOwner {
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "TIT: ETH withdraw failed");
    }

    /// @notice Rescue foreign ERC-20 tokens (cannot withdraw TIT itself).
    function withdrawStuckTokens(address token) external onlyOwner {
        require(token != address(this), "TIT: cannot withdraw self");
        uint256 bal = IERC20Minimal(token).balanceOf(address(this));
        require(bal > 0, "TIT: zero balance");
        IERC20Minimal(token).transfer(owner, bal);
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TIT: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ─── Internal helpers ────────────────────────────────────────────────────

    function _setFeeExclusion(address account, bool excluded) internal {
        isExcludedFromFees[account] = excluded;
    }

    receive() external payable {}
}
