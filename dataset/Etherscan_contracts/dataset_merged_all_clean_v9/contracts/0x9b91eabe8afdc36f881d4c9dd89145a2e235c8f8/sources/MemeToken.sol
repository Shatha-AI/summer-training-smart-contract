// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Not owner");
        _;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract MemeToken is Context, IERC20, Ownable {
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    // --- Tax settings ---
    uint256 public buyTax;
    uint256 public sellTax;
    uint256 public finalBuyTax;
    uint256 public finalSellTax;
    uint256 public reduceBuyTaxAt;
    uint256 public reduceSellTaxAt;
    uint256 private _buyCount;

    // --- Limits ---
    uint256 public maxTxAmount;
    uint256 public maxWalletAmount;
    uint256 public swapThreshold;
    bool public limitsEnabled = true;

    // --- Swap ---
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;
    bool public tradingOpen;
    bool private _inSwap;
    bool public swapEnabled;

    address payable public taxWallet;

    modifier lockSwap() {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = 100_000_000 * 10 ** _decimals;

        buyTax = 20;
        sellTax = 20;
        finalBuyTax = 0;
        finalSellTax = 0;
        reduceBuyTaxAt = 20;
        reduceSellTaxAt = 20;
        taxWallet = payable(_msgSender());

        maxTxAmount = _totalSupply * 2 / 100;       // 2% max tx
        maxWalletAmount = _totalSupply * 2 / 100;    // 2% max wallet
        swapThreshold = _totalSupply / 500;           // 0.2% swap threshold

        uint256 deployerTokens = _totalSupply * 5 / 100;   // 5% to deployer
        uint256 contractTokens = _totalSupply - deployerTokens; // 95% to contract

        _balances[_msgSender()] = deployerTokens;
        _balances[address(this)] = contractTokens;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), deployerTokens);
        emit Transfer(address(0), address(this), contractTokens);
    }

    // ==================== ERC-20 ====================

    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return _decimals; }
    function totalSupply() public view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: exceeds allowance");
        unchecked { _approve(sender, _msgSender(), currentAllowance - amount); }
        return true;
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0) && spender != address(0), "Zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    // ==================== Core transfer ====================

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0) && to != address(0), "Zero address");
        require(amount > 0, "Zero amount");

        uint256 taxAmount;

        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            require(tradingOpen, "Trading not open");

            // Buy
            if (from == uniswapPair) {
                if (limitsEnabled) {
                    require(amount <= maxTxAmount, "Exceeds max tx");
                    require(_balances[to] + amount <= maxWalletAmount, "Exceeds max wallet");
                }
                uint256 tax = _buyCount < reduceBuyTaxAt ? buyTax : finalBuyTax;
                taxAmount = amount * tax / 100;
                _buyCount++;
            }
            // Sell
            else if (to == uniswapPair) {
                if (limitsEnabled) {
                    require(amount <= maxTxAmount, "Exceeds max tx");
                }
                uint256 tax = _buyCount < reduceSellTaxAt ? sellTax : finalSellTax;
                taxAmount = amount * tax / 100;

                // Auto swap
                if (!_inSwap && swapEnabled) {
                    uint256 contractBalance = _balances[address(this)];
                    if (contractBalance >= swapThreshold) {
                        _swapTokensForETH(
                            contractBalance > maxTxAmount ? maxTxAmount : contractBalance
                        );
                        uint256 ethBalance = address(this).balance;
                        if (ethBalance > 0) {
                            taxWallet.transfer(ethBalance);
                        }
                    }
                }
            }
        }

        if (taxAmount > 0) {
            unchecked {
                _balances[address(this)] += taxAmount;
            }
            emit Transfer(from, address(this), taxAmount);
        }

        unchecked {
            _balances[from] -= amount;
            _balances[to] += (amount - taxAmount);
        }
        emit Transfer(from, to, amount - taxAmount);
    }

    function _swapTokensForETH(uint256 tokenAmount) private lockSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();
        _approve(address(this), address(uniswapRouter), tokenAmount);
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    // ==================== Owner functions ====================

    function openTrading() external onlyOwner {
        require(!tradingOpen, "Already open");
        uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapRouter), _totalSupply);
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory())
            .createPair(address(this), uniswapRouter.WETH());

        uint256 contractBalance = _balances[address(this)];
        uint256 clogAmount = contractBalance * 20 / 100;      // 20% stays as clog tax
        uint256 liquidityTokens = contractBalance - clogAmount; // 80% goes to LP

        uniswapRouter.addLiquidityETH{value: address(this).balance}(
            address(this),
            liquidityTokens,
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapPair).approve(address(uniswapRouter), type(uint256).max);
        swapEnabled = true;
        tradingOpen = true;
    }

    function setTaxes(
        uint256 _buyTax,
        uint256 _sellTax
    ) external onlyOwner {
        require(_buyTax <= 30 && _sellTax <= 30, "Tax too high");
        buyTax = _buyTax;
        sellTax = _sellTax;
    }

    function setFinalTaxes(
        uint256 _finalBuyTax,
        uint256 _finalSellTax
    ) external onlyOwner {
        require(_finalBuyTax <= 5 && _finalSellTax <= 5, "Final tax too high");
        finalBuyTax = _finalBuyTax;
        finalSellTax = _finalSellTax;
    }

    function setReduceAt(uint256 _reduceBuyAt, uint256 _reduceSellAt) external onlyOwner {
        reduceBuyTaxAt = _reduceBuyAt;
        reduceSellTaxAt = _reduceSellAt;
    }

    function removeLimits() external onlyOwner {
        limitsEnabled = false;
    }

    function setLimits(uint256 _maxTx, uint256 _maxWallet) external onlyOwner {
        require(_maxTx >= _totalSupply / 200, "Max tx too low");    // min 0.5%
        require(_maxWallet >= _totalSupply / 200, "Max wallet too low");
        maxTxAmount = _maxTx;
        maxWalletAmount = _maxWallet;
    }

    function setSwapThreshold(uint256 _threshold) external onlyOwner {
        swapThreshold = _threshold;
    }

    function setSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    function setTaxWallet(address payable _wallet) external onlyOwner {
        require(_wallet != address(0), "Zero address");
        _isExcludedFromFee[taxWallet] = false;
        taxWallet = _wallet;
        _isExcludedFromFee[_wallet] = true;
    }

    function excludeFromFee(address account, bool excluded) external onlyOwner {
        _isExcludedFromFee[account] = excluded;
    }

    // ==================== Team allocation ====================

    /// @notice Distribute tokens to team wallets before trading opens (transparent on-chain)
    function distributeToTeam(
        address[] calldata wallets,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(!tradingOpen, "Trading already open");
        require(wallets.length == amounts.length, "Length mismatch");
        require(wallets.length <= 10, "Max 10 wallets");
        for (uint256 i; i < wallets.length; i++) {
            require(wallets[i] != address(0), "Zero address");
            _balances[_msgSender()] -= amounts[i];
            _balances[wallets[i]] += amounts[i];
            emit Transfer(_msgSender(), wallets[i], amounts[i]);
        }
    }

    // ==================== Manual swap & rescue ====================

    function manualSwap() external {
        require(_msgSender() == taxWallet, "Not tax wallet");
        uint256 contractBalance = _balances[address(this)];
        if (contractBalance > 0) {
            _swapTokensForETH(contractBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            taxWallet.transfer(ethBalance);
        }
    }

    /// @notice Rescue stuck ETH from the contract
    function rescueETH() external {
        require(_msgSender() == taxWallet, "Not tax wallet");
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH");
        taxWallet.transfer(ethBalance);
    }

    /// @notice Rescue any ERC-20 token stuck in the contract (including this token)
    function rescueTokens(address tokenAddress) external {
        require(_msgSender() == taxWallet, "Not tax wallet");
        uint256 tokenBalance = IERC20(tokenAddress).balanceOf(address(this));
        require(tokenBalance > 0, "No tokens");
        IERC20(tokenAddress).transfer(taxWallet, tokenBalance);
    }

    receive() external payable {}
}