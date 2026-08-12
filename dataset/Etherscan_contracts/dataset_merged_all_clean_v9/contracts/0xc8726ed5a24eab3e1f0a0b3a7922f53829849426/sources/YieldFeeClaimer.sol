// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPrizeVaultFeeClaimer {
    function asset() external view returns (address);

    function yieldFeeBalance() external view returns (uint256);

    function claimYieldFeeShares(uint256 shares) external;

    function balanceOf(address account) external view returns (uint256);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

interface IWETH9 is IERC20 {
    function withdraw(uint256 amount) external;
}

interface IKtv2 {
    function give() external payable;
}

contract YieldFeeClaimer {
    // sqrt(0.995) ≈ 0.99875 — multiplied against sqrtPriceX96 for ~0.5% slippage tolerance
    uint256 public constant SQRT_SLIPPAGE_NUMERATOR = 99875;
    uint256 public constant SQRT_SLIPPAGE_DENOMINATOR = 100000;

    IPrizeVaultFeeClaimer public immutable prizeVault;
    IERC20 public immutable underlyingAsset; // read from prizeVault.asset() at construction
    IUniswapV3Pool public immutable pool;
    IWETH9 public immutable weth;
    IKtv2 public immutable ktv;
    // true if underlyingAsset address < weth address (i.e. underlyingAsset is token0)
    bool public immutable zeroForOne;

    uint256 private _lock = 1;

    event Executed(
        uint256 claimedShares,
        uint256 redeemedAssets,
        uint256 swappedWethOut,
        uint256 donatedEth
    );

    error Reentrancy();
    error ZeroAddress();
    error TransferFailed();
    error NothingToDonate();
    error InvalidCallback();

    constructor(
        IPrizeVaultFeeClaimer prizeVault_,
        IUniswapV3Pool pool_,
        IWETH9 weth_,
        IKtv2 ktv_
    ) {
        if (
            address(prizeVault_) == address(0) || address(pool_) == address(0)
                || address(weth_) == address(0) || address(ktv_) == address(0)
        ) {
            revert ZeroAddress();
        }

        address asset_ = prizeVault_.asset();
        if (asset_ == address(0)) revert ZeroAddress();

        prizeVault = prizeVault_;
        underlyingAsset = IERC20(asset_);
        pool = pool_;
        weth = weth_;
        ktv = ktv_;
        zeroForOne = asset_ < address(weth_);
    }

    receive() external payable { }

    function execute() external returns (uint256 donatedEth) {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;

        uint256 claimedShares;
        uint256 redeemedAssets;
        uint256 swappedWethOut;

        uint256 feeShares = prizeVault.yieldFeeBalance();
        if (feeShares > 0) {
            prizeVault.claimYieldFeeShares(feeShares);
            claimedShares = feeShares;
        }

        uint256 vaultShares = prizeVault.balanceOf(address(this));
        if (vaultShares > 0) {
            redeemedAssets = prizeVault.redeem(vaultShares, address(this), address(this));
        }

        uint256 underlyingBalance = underlyingAsset.balanceOf(address(this));
        if (underlyingBalance > 0) {
            (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

            (int256 amount0, int256 amount1) = pool.swap(
                address(this),
                zeroForOne,
                int256(underlyingBalance),
                _sqrtPriceLimit(sqrtPriceX96),
                new bytes(0)
            );

            swappedWethOut = uint256(-(zeroForOne ? amount1 : amount0));

            uint256 wethBalance = weth.balanceOf(address(this));
            if (wethBalance > 0) {
                weth.withdraw(wethBalance);
            }
        }

        donatedEth = address(this).balance;
        if (donatedEth == 0) revert NothingToDonate();

        ktv.give{value: donatedEth}();

        emit Executed(claimedShares, redeemedAssets, swappedWethOut, donatedEth);

        _lock = 1;
    }

    /// @notice Called by the pool during swap to collect the input tokens.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (msg.sender != address(pool)) revert InvalidCallback();
        int256 amountOwed = zeroForOne ? amount0Delta : amount1Delta;
        if (amountOwed > 0) {
            if (!underlyingAsset.transfer(address(pool), uint256(amountOwed))) revert TransferFailed();
        }
    }

    /// @dev Applies ~0.5% slippage to sqrtPriceX96. Direction depends on zeroForOne.
    function _sqrtPriceLimit(uint160 sqrtPriceX96) internal view returns (uint160) {
        if (zeroForOne) {
            // price moves down — limit must be below current price
            return uint160(uint256(sqrtPriceX96) * SQRT_SLIPPAGE_NUMERATOR / SQRT_SLIPPAGE_DENOMINATOR);
        } else {
            // price moves up — limit must be above current price
            return uint160(uint256(sqrtPriceX96) * SQRT_SLIPPAGE_DENOMINATOR / SQRT_SLIPPAGE_NUMERATOR);
        }
    }
}