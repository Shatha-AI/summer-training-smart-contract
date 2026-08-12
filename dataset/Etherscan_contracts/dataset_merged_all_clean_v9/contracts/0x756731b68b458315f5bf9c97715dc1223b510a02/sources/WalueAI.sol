// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/*
 *      Walue AI
 *
 *      One score. Every match.
 *      Powered by Walue AI.
 *
 *      Website:    https://walueai.com
 *      Twitter/X:  https://x.com/walueai
 *      Telegram:   https://t.me/walueai
 */

/* -------------------------------------------------------------------------- */
/*                                 Interfaces                                 */
/* -------------------------------------------------------------------------- */

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

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

/* -------------------------------------------------------------------------- */
/*                                  Ownable                                   */
/* -------------------------------------------------------------------------- */

abstract contract Ownable {
    address private _owner;

    error NotOwner();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

/* -------------------------------------------------------------------------- */
/*                                  WalueAI                                   */
/* -------------------------------------------------------------------------- */

contract WalueAI is IERC20, Ownable {
    /* ------------------------------ Metadata ------------------------------ */

    string  private constant _NAME     = "Walue AI Test";
    string  private constant _SYMBOL   = "WALUE";
    uint8   private constant _DECIMALS = 18;
    uint256 private constant _TOTAL_SUPPLY = 1_000_000_000 * 10 ** _DECIMALS;

    /* -------------------------------- Fees -------------------------------- */

    /// @dev Buy/sell tax in percent during the first {FEE_DISCOUNT_AFTER}.
    uint256 private constant INITIAL_TAX = 25;
    /// @dev Tax in percent once the launch grace period has passed (capped at {MAX_FEE}).
    uint256 private finalTax = 5;
    /// @dev Tax may never exceed this value.
    uint256 private constant MAX_FEE = 5;
    /// @dev Minimum number of buys before the contract starts auto-swapping fees.
    uint256 private constant PREVENT_SWAP_BEFORE = 30;
    uint256 private buyCount;

    /* --------------------------- Limits & swap ---------------------------- */

    uint256 public maxTxAmount   = 15_000_000 * 10 ** _DECIMALS; // 1.5% of supply
    uint256 public maxWalletSize = 15_000_000 * 10 ** _DECIMALS; // 1.5% of supply
    /// @dev Token balance that triggers an auto-swap to ETH.
    uint256 public swapThreshold = 8_000_000 * 10 ** _DECIMALS;  // 0.8% of supply
    /// @dev ETH balance required before fees are forwarded to the tax wallet.
    uint256 public constant ETH_SWAP_THRESHOLD = 0.1 ether;

    /* ----------------------------- Time gates ----------------------------- */

    uint256 public constant FEE_DISCOUNT_AFTER  = 10 minutes; // INITIAL_TAX -> finalTax
    uint256 public constant LIMITS_ACTIVE_FOR   = 15 minutes; // tx/wallet caps
    uint256 public constant WALLET_CHANGE_LOCK  = 90 days;    // tax wallet timelock

    uint256 public launchTimestamp;

    /* ------------------------------ Storage ------------------------------- */

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    address payable private _taxWallet;
    uint256 private _walletChangeUnlock;

    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 private _router;
    address private _pair;

    bool private _tradingOpen;
    bool private _swapEnabled;
    bool private _inSwap;

    /* ------------------------------ Errors -------------------------------- */

    error ZeroAddress();
    error ZeroAmount();
    error MaxTxExceeded();
    error MaxWalletExceeded();
    error InsufficientAllowance();
    error Unauthorized();
    error FeeTooHigh();
    error WalletChangeLocked();
    error TradingAlreadyOpen();
    error EthTransferFailed();

    /* ------------------------------ Events -------------------------------- */

    event TradingOpened();
    event LimitsRemoved();
    event FeeReduced(uint256 newFee);
    event TaxWalletChanged(address indexed newWallet);

    /* ----------------------------- Modifiers ------------------------------ */

    modifier lockTheSwap() {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    /* ---------------------------- Constructor ----------------------------- */

    constructor(address taxWallet_) {
        if (taxWallet_ == address(0)) revert ZeroAddress();

        _taxWallet = payable(taxWallet_);
        _walletChangeUnlock = block.timestamp + WALLET_CHANGE_LOCK;

        _balances[msg.sender] = _TOTAL_SUPPLY;

        _isExcludedFromFee[msg.sender]      = true;
        _isExcludedFromFee[address(this)]   = true;
        _isExcludedFromFee[taxWallet_]      = true;

        emit Transfer(address(0), msg.sender, _TOTAL_SUPPLY);
    }

    /* -------------------------- ERC20 metadata ---------------------------- */

    function name() external pure returns (string memory) { return _NAME; }
    function symbol() external pure returns (string memory) { return _SYMBOL; }
    function decimals() external pure returns (uint8) { return _DECIMALS; }
    function totalSupply() external pure returns (uint256) { return _TOTAL_SUPPLY; }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    /* --------------------------- ERC20 actions ---------------------------- */

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        _transfer(from, to, amount);

        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        return true;
    }

    function _approve(address tokenOwner, address spender, uint256 amount) private {
        if (tokenOwner == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    /* ---------------------------- Core transfer --------------------------- */

    function _transfer(address from, address to, uint256 amount) private {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 taxAmount;

        // Fee/limit logic only runs for non-owner transfers while a fee is configured.
        if (from != owner() && to != owner() && finalTax != 0) {
            // Classify the trade. Wallet-to-wallet transfers are neither a buy nor a sell.
            bool isBuy  = from == _pair && to   != address(_router) && !_isExcludedFromFee[to];
            bool isSell = to   == _pair && from != address(_router) && !_isExcludedFromFee[from];

            // Charge the fee on buys AND sells, but never on wallet-to-wallet transfers.
            if ((isBuy || isSell) && !_inSwap) {
                uint256 rate = block.timestamp > launchTimestamp + FEE_DISCOUNT_AFTER
                    ? finalTax
                    : INITIAL_TAX;
                taxAmount = (amount * rate) / 100;
            }

            // Buys: enforce per-tx and per-wallet caps during the launch window.
            if (isBuy) {
                if (block.timestamp < launchTimestamp + LIMITS_ACTIVE_FOR) {
                    if (amount > maxTxAmount) revert MaxTxExceeded();
                    if (_balances[to] + amount > maxWalletSize) revert MaxWalletExceeded();
                }
                unchecked { ++buyCount; }
            }

            // Non-buys (sells / transfers): swap accumulated tax tokens into ETH.
            uint256 contractTokenBalance = _balances[address(this)];
            if (
                !_inSwap &&
                from != _pair &&
                _swapEnabled &&
                contractTokenBalance > swapThreshold &&
                buyCount > PREVENT_SWAP_BEFORE
            ) {
                uint256 amountToSwap = swapThreshold < amount ? swapThreshold : amount;
                _swapTokensForEth(amountToSwap);

                uint256 contractEthBalance = address(this).balance;
                if (contractEthBalance > ETH_SWAP_THRESHOLD) {
                    _sendEthToFee(contractEthBalance);
                }
            }
        }

        // Settle balances (checked arithmetic reverts on insufficient balance).
        _balances[from] -= amount;
        _balances[to]   += amount - taxAmount;
        emit Transfer(from, to, amount - taxAmount);

        if (taxAmount != 0) {
            _balances[address(this)] += taxAmount;
            emit Transfer(from, address(this), taxAmount);
        }
    }

    /* ------------------------------- Swaps -------------------------------- */

    function _swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();

        _approve(address(this), address(_router), tokenAmount);
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _sendEthToFee(uint256 amount) private {
        (bool ok, ) = _taxWallet.call{value: amount}("");
        if (!ok) revert EthTransferFailed();
    }

    /* ---------------------------- Owner admin ----------------------------- */

    function openTrading() external onlyOwner {
        if (_tradingOpen) revert TradingAlreadyOpen();

        _router = IUniswapV2Router02(UNISWAP_V2_ROUTER);
        _approve(address(this), address(_router), _TOTAL_SUPPLY);

        _pair = IUniswapV2Factory(_router.factory()).createPair(address(this), _router.WETH());

        _router.addLiquidityETH{value: address(this).balance}(
            address(this),
            _balances[address(this)],
            0,
            0,
            owner(),
            block.timestamp
        );

        IERC20(_pair).approve(address(_router), type(uint256).max);

        _swapEnabled    = true;
        _tradingOpen    = true;
        launchTimestamp = block.timestamp;

        emit TradingOpened();
    }

    function removeLimits() external onlyOwner {
        maxTxAmount   = _TOTAL_SUPPLY;
        maxWalletSize = _TOTAL_SUPPLY;
        emit LimitsRemoved();
    }

    /* -------------------------- Tax-wallet admin -------------------------- */

    function reduceFee(uint256 newFee) external {
        if (msg.sender != _taxWallet) revert Unauthorized();
        if (newFee > MAX_FEE) revert FeeTooHigh();
        finalTax = newFee;
        emit FeeReduced(newFee);
    }

    function changeTaxWallet(address newTaxWallet) external {
        if (msg.sender != _taxWallet) revert Unauthorized();
        if (newTaxWallet == address(0)) revert ZeroAddress();
        if (block.timestamp <= _walletChangeUnlock) revert WalletChangeLocked();

        _walletChangeUnlock = block.timestamp + WALLET_CHANGE_LOCK;
        _taxWallet = payable(newTaxWallet);
        emit TaxWalletChanged(newTaxWallet);
    }

    function manualSwap() external {
        if (msg.sender != _taxWallet) revert Unauthorized();
        uint256 tokenBalance = _balances[address(this)];
        if (tokenBalance != 0) _swapTokensForEth(tokenBalance);
    }

    function manualSend(uint256 amount) external {
        if (msg.sender != _taxWallet) revert Unauthorized();
        _sendEthToFee(amount);
    }

    function rescueTokens() external {
        if (msg.sender != _taxWallet) revert Unauthorized();
        _transfer(address(this), msg.sender, _balances[address(this)]);
    }

    receive() external payable {}
}