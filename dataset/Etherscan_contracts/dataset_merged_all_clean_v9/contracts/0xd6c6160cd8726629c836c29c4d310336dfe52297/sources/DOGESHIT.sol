// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

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
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
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
    ) external payable returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );
}

contract DOGESHIT is Context, IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private constant _name = unicode"DOGESHI";
    string private constant _symbol = unicode"SHI";
    uint8 private constant _decimals = 9;

    uint256 private constant _tTotal = 1000000000000000 * 10 ** _decimals;

    uint256 public maxTxAmount = (_tTotal * 2) / 100;

    uint256 private constant buyLimitCount = 23;
    uint256 private buyCount;

    uint256 private constant sellTax = 5;
    uint256 private tradingStartTime;
    uint256 private constant sellTaxDuration = 24 hours;

    uint256 private taxSwapThreshold = (_tTotal * 5) / 1000;

    address payable private taxWallet;

    IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;

    bool public tradingOpen;
    bool private swapEnabled;
    bool private inSwap;

    event TaxWalletUpdated(address indexed newWallet);
    event ManualSwap(uint256 tokenAmount, uint256 ethAmount);
    event TradingOpened(uint256 startTime, address pair);
    event AutoSwapFailed(uint256 tokenAmount, bytes reason);
    event ETHTransferFailed(address indexed wallet, uint256 amount);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    modifier onlyOwnerOrTaxWallet() {
        require(
            _msgSender() == owner() || _msgSender() == taxWallet,
            "Caller is not owner or tax wallet"
        );
        _;
    }

    constructor() {
        taxWallet = payable(_msgSender());
        _balances[_msgSender()] = _tTotal;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    receive() external payable {}

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) public view override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _approve(sender, _msgSender(), currentAllowance - amount);

        _transfer(sender, recipient, amount);

        return true;
    }

    function _approve(address tokenOwner, address spender, uint256 amount) private {
        require(tokenOwner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");

        _allowances[tokenOwner][spender] = amount;

        emit Approval(tokenOwner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");

        if (amount == 0) {
            emit Transfer(from, to, 0);
            return;
        }

        if (!tradingOpen) {
            require(
                from == owner() || from == address(this),
                "Trading is not open"
            );
        }

        uint256 taxAmount = 0;

        bool isBuy = from == uniswapV2Pair && to != address(uniswapV2Router);
        bool isSell = to == uniswapV2Pair && from != address(this);

        if (isBuy && buyCount < buyLimitCount) {
            require(amount <= maxTxAmount, "Exceeds max tx amount in first 23 buys");
            buyCount++;
        }

        if (
            isSell &&
            tradingStartTime > 0 &&
            block.timestamp <= tradingStartTime + sellTaxDuration
        ) {
            taxAmount = (amount * sellTax) / 100;
        }

        uint256 contractTokenBalance = _balances[address(this)];

        if (
            isSell &&
            !inSwap &&
            swapEnabled &&
            tradingOpen &&
            contractTokenBalance >= taxSwapThreshold
        ) {
            uint256 swapAmount = contractTokenBalance > taxSwapThreshold
                ? taxSwapThreshold
                : contractTokenBalance;

            bool swapSucceeded = swapTokensForETH(swapAmount);

            if (swapSucceeded) {
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToTaxWallet(contractETHBalance);
                }
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] += taxAmount;
            emit Transfer(from, address(this), taxAmount);
        }

        _balances[from] -= amount;
        _balances[to] += amount - taxAmount;

        emit Transfer(from, to, amount - taxAmount);
    }

    function openTrade() external onlyOwner {
        require(!tradingOpen, "Trading already open");

        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        _approve(address(this), address(uniswapV2Router), _tTotal);

        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2Router.factory());

        address pair = factory.getPair(address(this), uniswapV2Router.WETH());

        if (pair == address(0)) {
            pair = factory.createPair(address(this), uniswapV2Router.WETH());
        }

        uniswapV2Pair = pair;

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );

        swapEnabled = true;
        tradingOpen = true;
        tradingStartTime = block.timestamp;

        emit TradingOpened(block.timestamp, uniswapV2Pair);
    }

    function swapTokensForETH(uint256 tokenAmount) private lockTheSwap returns (bool success) {
        if (tokenAmount == 0) return true;

        address[] memory path = new address[](2);

        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        try uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        ) {
            success = true;
        } catch (bytes memory reason) {
            emit AutoSwapFailed(tokenAmount, reason);
            success = false;
        }
    }

    function sendETHToTaxWallet(uint256 amount) private returns (bool success) {
        if (amount == 0) return true;

        (success, ) = taxWallet.call{value: amount}("");

        if (!success) {
            emit ETHTransferFailed(taxWallet, amount);
        }
    }

    function manualSwap() external onlyOwnerOrTaxWallet {
        uint256 tokenBalance = balanceOf(address(this));
        uint256 swapAmount = 0;

        if (tokenBalance > 0 && swapEnabled) {
            swapAmount = tokenBalance > taxSwapThreshold
                ? taxSwapThreshold
                : tokenBalance;

            bool swapSucceeded = swapTokensForETH(swapAmount);
            require(swapSucceeded, "Token to ETH swap failed");
        }

        uint256 ethBalance = address(this).balance;

        if (ethBalance > 0) {
            bool transferSucceeded = sendETHToTaxWallet(ethBalance);
            require(transferSucceeded, "ETH transfer failed");
        }

        emit ManualSwap(swapAmount, ethBalance);
    }

    function setTaxWallet(address payable newTaxWallet) external onlyOwner {
        require(newTaxWallet != address(0), "Tax wallet cannot be zero address");

        taxWallet = newTaxWallet;

        emit TaxWalletUpdated(newTaxWallet);
    }
}