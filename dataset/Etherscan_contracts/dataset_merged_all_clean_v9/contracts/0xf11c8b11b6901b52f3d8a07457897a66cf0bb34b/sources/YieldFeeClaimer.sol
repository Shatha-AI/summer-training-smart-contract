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



interface IWETH9 is IERC20 {
    function withdraw(uint256 amount) external;
}

interface IKtv2 {
    function give() external payable;
}


contract YieldFeeClaimer {
    IPrizeVaultFeeClaimer public immutable prizeVault;
    IERC20 public immutable underlyingAsset; // read from prizeVault.asset() at construction
    IWETH9 public immutable weth;
    IKtv2 public immutable ktv;

    uint256 private _lock = 1;

    event Executed(
        uint256 claimedShares,
        uint256 redeemedAssets,
        uint256 unwrappedEth
    );

    error Reentrancy();
    error ZeroAddress();
    error TransferFailed();
    error NothingToDonate();

    constructor(
        IPrizeVaultFeeClaimer prizeVault_,
        IWETH9 weth_,
        IKtv2 ktv_
    ) {
        if (
            address(prizeVault_) == address(0) || address(weth_) == address(0) || address(ktv_) == address(0)
        ) {
            revert ZeroAddress();
        }

        address asset_ = prizeVault_.asset();
        if (asset_ == address(0)) revert ZeroAddress();

        prizeVault = prizeVault_;
        underlyingAsset = IERC20(asset_);
        weth = weth_;
        ktv = ktv_;
    }

    receive() external payable { }

    function execute() external returns (uint256 donatedEth) {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;

        uint256 claimedShares;
        uint256 redeemedAssets;
        uint256 unwrappedEth;

        // Claim all available yield fee shares
        uint256 feeShares = prizeVault.yieldFeeBalance();
        if (feeShares > 0) {
            prizeVault.claimYieldFeeShares(feeShares);
            claimedShares = feeShares;
        }

        // Redeem all vault shares for WETH
        uint256 vaultShares = prizeVault.balanceOf(address(this));
        if (vaultShares > 0) {
            redeemedAssets = prizeVault.redeem(vaultShares, address(this), address(this));
        }

        // Unwrap all WETH to ETH
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance > 0) {
            weth.withdraw(wethBalance);
            unwrappedEth = wethBalance;
        }

        // Sweep all ETH to Ktv2 via give()
        donatedEth = address(this).balance;
        if (donatedEth == 0) revert NothingToDonate();

        ktv.give{value: donatedEth}();

        emit Executed(claimedShares, redeemedAssets, unwrappedEth);

        _lock = 1;
    }

    // No swap or callback logic needed for WETH-only flow
}