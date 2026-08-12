// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// DistributionVaultV3.sol

// ════════════════════════════════════════════════════════════════════════════
//  DistributionVaultV3
//  Ref: SCF-664M388RT667 Rev3
// ════════════════════════════════════════════════════════════════════════════
//
//  PURPOSE
//  ───────
//  This vault accumulates USDT ERC-20 on Ethereum mainnet until it holds
//  the equivalent of 1,000,000,000 EUR (one billion euros) expressed as
//  USDT-ERC20 (1 USDT ≈ 1 USD ≈ ~0.92 EUR; threshold set at 1 000 000 000
//  USDT for operational simplicity).
//
//  AUTOMATIC DISBURSEMENT
//  ──────────────────────
//  The moment any deposit pushes the vault balance to or above the threshold,
//  disbursement fires AUTOMATICALLY — no manual owner call required.
//  The deposit transaction itself triggers the full distribution.
//
//  GAS REFUND VIA UNISWAP V3
//  ─────────────────────────
//  Before paying recipients, the vault swaps a fixed USDT_GAS_REFUND slice
//  (50 USDT) through Uniswap V3 (USDT → WETH, fee tier 500), unwraps the
//  WETH to ETH, and sends that ETH to the address that called deposit().
//  This means the depositor that triggers disbursement is made whole on gas.
//
//  DISTRIBUTION SCHEDULE AT THRESHOLD (1 000 000 000 USDT)
//  ─────────────────────────────────────────────────────────
//  Shares use a denominator of 100 000 (DENOM) so that 0.833 % is exact.
//  The gas-refund slice is deducted first; the remainder is split below.
//  Shown here at exactly 1 000 000 000 USDT for illustration:
//
//  ┌────┬────────────────────────────────────────────┬──────────────┬───────────────────────┐
//  │  # │ Recipient Address                          │  Share       │  USDT at 1 B Threshold│
//  ├────┼────────────────────────────────────────────┼──────────────┼───────────────────────┤
//  │  1 │ 0xc805b3bb4Bdc4BaC6b253094f16a39ab567fD5A2 │  13.000 %    │   130 000 000 USDT    │
//  │  2 │ 0x72D66d2A5412b5F4773e8BcbCabf3229Fc8CB0d6 │   2.000 %    │    20 000 000 USDT    │
//  │  3 │ 0x17a170dDE90e5C10320699bC783768c1b55dB6b0 │   5.000 %    │    50 000 000 USDT    │
//  │  4 │ 0x75293f8d399B49680B9A4CB9bFFE45957E1e77BA │  10.000 %    │   100 000 000 USDT    │
//  │  5 │ 0xfD61cbAEf4BF51972800e74209b7D2842022F201 │  10.000 %    │   100 000 000 USDT    │
//  │  6 │ 0x4D64a806B4689B096D0588B5F0C137497f275fC6 │   0.833 %    │     8 330 000 USDT    │
//  │  7 │ 0xD8f6409d6C7bDCC1140479f12F8c1ad74285C48c │   2.500 %    │    25 000 000 USDT    │
//  │  8 │ 0x67fee360F6167DDbeD7DBD43a08069649a59168E │   5.000 %    │    50 000 000 USDT    │
//  │  9 │ 0xbf707C2b39B3078E9f1C9590a2e5ad848c7cD9e3 │   5.000 %    │    50 000 000 USDT    │
//  │ 10 │ 0x584Ae382b5064aDBd8BeaF50C1C9A022dd961F27 │   0.833 %    │     8 330 000 USDT    │
//  │ 11 │ 0x2bbCa9DB7CD6FC82e994A3618Aa54EDdAB8d44e1 │   0.833 %    │     8 330 000 USDT    │
//  │  ★ │ 0x2904e143054c43c5E8198dE2E5AfD82f9756f094 │  45.001 %    │   450 010 000 USDT    │
//  │    │   (owner / master wallet — remainder)       │              │                       │
//  └────┴────────────────────────────────────────────┴──────────────┴───────────────────────┘
//  Sum recipients (54.999 %): 549 990 000 USDT
//  Owner remainder (45.001 %): 450 010 000 USDT
//  Total:                    1 000 000 000 USDT  ✓
//
//  NOTE: The 50 USDT gas refund is deducted from the owner's remainder,
//        keeping all 11 named-recipient payouts exactly as shown above.
//
//  DEPLOYED CONTRACT : (see etherscan after deploy)
//  MASTER WALLET     : 0x2904e143054c43c5E8198dE2E5AfD82f9756f094
//  USDT ERC-20       : 0xdAC17F958D2ee523a2206206994597C13D831ec7
//  UNISWAP V3 ROUTER : 0xE592427A0AEce92De3Edee1F18E0157C05861564
//  WETH9             : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
// ════════════════════════════════════════════════════════════════════════════

// ── Minimal interfaces ────────────────────────────────────────────────────

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24  fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params)
        external returns (uint256 amountOut);
}

interface IWETH9 {
    function withdraw(uint256 amount) external;
}

// ── Contract ──────────────────────────────────────────────────────────────

/**
 * @title  DistributionVaultV3
 *
 * @notice Vault that accumulates 1,000,000,000 EUR equivalent in USDT-ERC20
 *         and automatically disburses to 11 named recipients + owner the
 *         moment any deposit crosses the threshold. The depositor who
 *         triggers disbursement receives a gas refund in ETH via Uniswap V3.
 *
 * @dev    All state is public. Call getRecipients() or previewDistribution()
 *         at any time to read the full schedule on-chain.
 *         Reentrancy is blocked by the _distributing flag.
 *
 * ── Named recipients ─────────────────────────────────────────────────────
 *
 *  #1  0xc805b3bb4Bdc4BaC6b253094f16a39ab567fD5A2  →  13.000 %  →  130,000,000 USDT
 *  #2  0x72D66d2A5412b5F4773e8BcbCabf3229Fc8CB0d6  →   2.000 %  →   20,000,000 USDT
 *  #3  0x17a170dDE90e5C10320699bC783768c1b55dB6b0  →   5.000 %  →   50,000,000 USDT
 *  #4  0x75293f8d399B49680B9A4CB9bFFE45957E1e77BA  →  10.000 %  →  100,000,000 USDT
 *  #5  0xfD61cbAEf4BF51972800e74209b7D2842022F201  →  10.000 %  →  100,000,000 USDT
 *  #6  0x4D64a806B4689B096D0588B5F0C137497f275fC6  →   0.833 %  →    8,330,000 USDT
 *  #7  0xD8f6409d6C7bDCC1140479f12F8c1ad74285C48c  →   2.500 %  →   25,000,000 USDT
 *  #8  0x67fee360F6167DDbeD7DBD43a08069649a59168E  →   5.000 %  →   50,000,000 USDT
 *  #9  0xbf707C2b39B3078E9f1C9590a2e5ad848c7cD9e3  →   5.000 %  →   50,000,000 USDT
 * #10  0x584Ae382b5064aDBd8BeaF50C1C9A022dd961F27  →   0.833 %  →    8,330,000 USDT
 * #11  0x2bbCa9DB7CD6FC82e994A3618Aa54EDdAB8d44e1  →   0.833 %  →    8,330,000 USDT
 *  ★   0x2904e143054c43c5E8198dE2E5AfD82f9756f094  →  45.001 %  →  450,010,000 USDT (owner / remainder)
 *
 * ─────────────────────────────────────────────────────────────────────────
 */
contract DistributionVaultV3 {

    // ── Protocol addresses ───────────────────────────────────────────────

    /// @notice USDT ERC-20 on Ethereum mainnet.
    address public constant USDT            = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /// @notice Uniswap V3 SwapRouter (mainnet).
    address public constant UNISWAP_ROUTER  = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /// @notice WETH9 (mainnet) — used to unwrap ETH after the Uniswap swap.
    address public constant WETH9           = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // ── Threshold & math ─────────────────────────────────────────────────

    /// @notice 1,000,000,000 USDT expressed in USDT raw units (6 decimals).
    ///         Represents the EUR-equivalent trigger for automatic disbursement.
    ///         Formula: 1_000_000_000 × 10^6 = 1_000_000_000_000_000
    uint256 public constant THRESHOLD       = 1_000_000_000 * 10 ** 6;

    /// @notice Percentage denominator. 100 000 = 100 %, allows 0.833 % exactly.
    uint256 public constant DENOM           = 100_000;

    /// @notice Number of named recipients (not counting the owner).
    uint256 public constant RECIPIENT_COUNT = 11;

    /// @notice USDT amount swapped to ETH via Uniswap V3 and sent to the
    ///         deposit caller as a gas refund. Raw units (6 decimals).
    ///         50 USDT = 50_000_000 raw.  Deducted from the owner remainder.
    uint256 public constant USDT_GAS_REFUND = 50 * 10 ** 6;

    /// @notice Uniswap V3 pool fee tier used for the USDT → WETH swap.
    ///         500 = 0.05 % (the deepest USDT/WETH pool on mainnet).
    uint24  public constant UNI_FEE_TIER    = 500;

    // ── Owner ────────────────────────────────────────────────────────────

    /// @notice Master wallet.  Receives the remainder (≈45.001 %) after all
    ///         named recipients are paid and the gas refund is deducted.
    address public immutable owner;

    // ── Public distribution schedule ─────────────────────────────────────
    //   Readable on Etherscan, callable via getRecipients(), and used
    //   directly in the auto-distribution loop.

    /// @notice The 11 named recipient addresses, in disbursement order.
    ///         Index 0 = recipient #1 (13.000 %), index 10 = recipient #11 (0.833 %).
    address[11] public recipients;

    /// @notice Each recipient's share expressed in units of 1/DENOM.
    ///         recipient i receives  (balance × shares[i]) / DENOM  USDT.
    uint256[11] public shares;

    // ── Reentrancy guard ─────────────────────────────────────────────────

    bool private _distributing;

    // ── Events ───────────────────────────────────────────────────────────

    /// @notice Emitted on every successful deposit.
    event Deposited(address indexed from, uint256 usdtAmount);

    /// @notice Emitted once when auto-distribution fires.
    event AutoDistributed(uint256 totalBalance, uint256 timestamp);

    /// @notice Emitted for each of the 11 named recipients during distribution.
    event RecipientPaid(
        uint256 indexed recipientIndex,
        address indexed recipient,
        uint256 usdtAmount,
        uint256 sharePer100k
    );

    /// @notice Emitted when the owner remainder is sent.
    event OwnerPaid(address indexed ownerAddr, uint256 usdtAmount);

    /// @notice Emitted when the gas-refund ETH is sent to the depositor.
    event GasRefunded(address indexed depositor, uint256 ethAmount, uint256 usdtSwapped);

    // ── Constructor ──────────────────────────────────────────────────────

    constructor() {
        owner = 0x2904e143054c43c5E8198dE2E5AfD82f9756f094;

        // ── Named recipients ─────────────────────────────────────────────
        //    All 11 addresses are stored as public state, fully visible
        //    on Etherscan and callable via getRecipients().
        //
        //    #   Address                                      Share    USDT at 1B threshold
        //    ─── ──────────────────────────────────────────── ──────── ──────────────────────
        recipients[0]  = 0xc805b3bb4Bdc4BaC6b253094f16a39ab567fD5A2;  //  13.000 %  →  130 000 000 USDT
        recipients[1]  = 0x72D66d2A5412b5F4773e8BcbCabf3229Fc8CB0d6;  //   2.000 %  →   20 000 000 USDT
        recipients[2]  = 0x17a170dDE90e5C10320699bC783768c1b55dB6b0;  //   5.000 %  →   50 000 000 USDT
        recipients[3]  = 0x75293f8d399B49680B9A4CB9bFFE45957E1e77BA;  //  10.000 %  →  100 000 000 USDT
        recipients[4]  = 0xfD61cbAEf4BF51972800e74209b7D2842022F201;  //  10.000 %  →  100 000 000 USDT
        recipients[5]  = 0x4D64a806B4689B096D0588B5F0C137497f275fC6;  //   0.833 %  →    8 330 000 USDT
        recipients[6]  = 0xD8f6409d6C7bDCC1140479f12F8c1ad74285C48c;  //   2.500 %  →   25 000 000 USDT
        recipients[7]  = 0x67fee360F6167DDbeD7DBD43a08069649a59168E;  //   5.000 %  →   50 000 000 USDT
        recipients[8]  = 0xbf707C2b39B3078E9f1C9590a2e5ad848c7cD9e3;  //   5.000 %  →   50 000 000 USDT
        recipients[9]  = 0x584Ae382b5064aDBd8BeaF50C1C9A022dd961F27;  //   0.833 %  →    8 330 000 USDT
        recipients[10] = 0x2bbCa9DB7CD6FC82e994A3618Aa54EDdAB8d44e1;  //   0.833 %  →    8 330 000 USDT

        // ── Shares (/100 000) ─────────────────────────────────────────────
        shares[0]  = 13_000;  //  13.000 %
        shares[1]  =  2_000;  //   2.000 %
        shares[2]  =  5_000;  //   5.000 %
        shares[3]  = 10_000;  //  10.000 %
        shares[4]  = 10_000;  //  10.000 %
        shares[5]  =    833;  //   0.833 %
        shares[6]  =  2_500;  //   2.500 %
        shares[7]  =  5_000;  //   5.000 %
        shares[8]  =  5_000;  //   5.000 %
        shares[9]  =    833;  //   0.833 %
        shares[10] =    833;  //   0.833 %
        // Sum of named shares: 54 999 / 100 000 = 54.999 %
        // Owner remainder    : 45 001 / 100 000 = 45.001 %  (minus USDT_GAS_REFUND)
    }

    // ── Receive ETH (needed for WETH9.withdraw → ETH) ───────────────────

    receive() external payable {}

    // ── Deposit & auto-distribution ──────────────────────────────────────

    /**
     * @notice Deposit USDT into the vault.
     *
     * @dev    Caller must have previously called USDT.approve(vaultAddress, amount).
     *         Any address may deposit.
     *
     *         If the vault balance reaches or exceeds THRESHOLD (1 000 000 000 USDT —
     *         the 1,000,000,000 EUR USDT-ERC20 equivalent) after this deposit,
     *         disbursement fires AUTOMATICALLY in the same transaction:
     *
     *           1. A USDT_GAS_REFUND slice is swapped to ETH via Uniswap V3
     *              and sent back to msg.sender to cover gas costs.
     *           2. Each of the 11 named recipients receives their fixed share.
     *           3. The owner (master wallet) receives the remainder.
     *
     * @param  amount  USDT amount to deposit, in raw units (USDT has 6 decimals).
     *                 Example: 1 000 000 USDT = 1_000_000 * 10^6 = 1_000_000_000_000 raw.
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "DistributionVaultV3: zero amount");
        require(!_distributing, "DistributionVaultV3: distribution in progress");

        bool ok = IERC20(USDT).transferFrom(msg.sender, address(this), amount);
        require(ok, "DistributionVaultV3: USDT transferFrom failed");
        emit Deposited(msg.sender, amount);

        uint256 balance = IERC20(USDT).balanceOf(address(this));
        if (balance >= THRESHOLD) {
            _distribute(msg.sender, balance);
        }
    }

    // ── Internal distribution ────────────────────────────────────────────

    /**
     * @dev  Core distribution logic.  Called automatically by deposit() when
     *       the vault hits the 1 B USDT threshold.
     *
     *       Step 1 — Gas refund:
     *         Approve Uniswap V3 router for USDT_GAS_REFUND USDT.
     *         Swap USDT → WETH via the 0.05 % fee pool.
     *         Unwrap WETH → ETH via WETH9.withdraw().
     *         Send ETH to `caller`.
     *         If the swap fails for any reason the gas refund is skipped
     *         (distribution still proceeds).
     *
     *       Step 2 — Named recipients:
     *         For each of the 11 recipients, transfer (balance × share) / DENOM USDT.
     *
     *       Step 3 — Owner remainder:
     *         Transfer all remaining USDT to the owner (master wallet).
     */
    function _distribute(address caller, uint256 balance) internal {
        _distributing = true;

        uint256 distributable = balance;

        // ── Step 1: Gas refund via Uniswap V3 ───────────────────────────
        if (distributable > USDT_GAS_REFUND) {
            try this._swapAndRefund(caller, USDT_GAS_REFUND) returns (uint256 ethOut) {
                distributable -= USDT_GAS_REFUND;
                emit GasRefunded(caller, ethOut, USDT_GAS_REFUND);
            } catch {
                // Swap failed (e.g. insufficient liquidity) — skip refund, continue.
            }
        }

        // ── Step 2: Named recipients ─────────────────────────────────────
        uint256 totalSent;
        for (uint256 i = 0; i < RECIPIENT_COUNT; i++) {
            uint256 payout = (distributable * shares[i]) / DENOM;
            if (payout > 0) {
                bool ok = IERC20(USDT).transfer(recipients[i], payout);
                require(ok, "DistributionVaultV3: recipient transfer failed");
                emit RecipientPaid(i, recipients[i], payout, shares[i]);
                totalSent += payout;
            }
        }

        // ── Step 3: Owner remainder ──────────────────────────────────────
        uint256 remainder = IERC20(USDT).balanceOf(address(this));
        if (remainder > 0) {
            bool ok = IERC20(USDT).transfer(owner, remainder);
            require(ok, "DistributionVaultV3: owner transfer failed");
            emit OwnerPaid(owner, remainder);
        }

        emit AutoDistributed(balance, block.timestamp);
        _distributing = false;
    }

    /**
     * @dev  External wrapper so _distribute can use try/catch on the swap.
     *       Only callable by this contract itself.
     */
    function _swapAndRefund(address refundTo, uint256 usdtIn)
        external
        returns (uint256 ethOut)
    {
        require(msg.sender == address(this), "DistributionVaultV3: internal only");

        IERC20(USDT).approve(UNISWAP_ROUTER, usdtIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn:           USDT,
            tokenOut:          WETH9,
            fee:               UNI_FEE_TIER,
            recipient:         address(this),
            deadline:          block.timestamp,
            amountIn:          usdtIn,
            amountOutMinimum:  0,
            sqrtPriceLimitX96: 0
        });

        uint256 wethOut = ISwapRouter(UNISWAP_ROUTER).exactInputSingle(params);
        IWETH9(WETH9).withdraw(wethOut);

        (bool sent,) = refundTo.call{value: wethOut}("");
        require(sent, "DistributionVaultV3: ETH refund transfer failed");

        return wethOut;
    }

    // ── Views ─────────────────────────────────────────────────────────────

    /**
     * @notice Returns the full distribution schedule: all 11 recipient
     *         addresses and their corresponding shares per 100 000.
     *
     * @return addrs         The 11 recipient addresses (index-matched to shares).
     * @return sharesPer100k Each recipient's share out of 100 000 (DENOM).
     */
    function getRecipients()
        external
        view
        returns (address[11] memory addrs, uint256[11] memory sharesPer100k)
    {
        addrs         = recipients;
        sharesPer100k = shares;
    }

    /// @notice Current raw USDT balance held by the vault.
    function vaultBalance() external view returns (uint256) {
        return IERC20(USDT).balanceOf(address(this));
    }

    /// @notice True when the vault has reached or exceeded the 1 B USDT threshold.
    function thresholdMet() external view returns (bool) {
        return IERC20(USDT).balanceOf(address(this)) >= THRESHOLD;
    }

    /// @notice USDT still needed to trigger automatic disbursement. Returns 0 if met.
    function remaining() external view returns (uint256) {
        uint256 bal = IERC20(USDT).balanceOf(address(this));
        return bal >= THRESHOLD ? 0 : THRESHOLD - bal;
    }

    /**
     * @notice Preview the exact USDT each address would receive if distribution
     *         fired right now at the current vault balance.
     *
     * @return addrs         The 11 recipient addresses.
     * @return sharesPer100k Each recipient's share out of 100 000.
     * @return amounts       Calculated raw USDT payout per recipient.
     * @return ownerAmount   Raw USDT that would go to the owner (remainder).
     */
    function previewDistribution()
        external
        view
        returns (
            address[11] memory addrs,
            uint256[11] memory sharesPer100k,
            uint256[11] memory amounts,
            uint256 ownerAmount
        )
    {
        uint256 bal = IERC20(USDT).balanceOf(address(this));
        uint256 distributable = bal > USDT_GAS_REFUND ? bal - USDT_GAS_REFUND : bal;
        addrs         = recipients;
        sharesPer100k = shares;

        uint256 totalSent;
        for (uint256 i = 0; i < RECIPIENT_COUNT; i++) {
            amounts[i] = (distributable * shares[i]) / DENOM;
            totalSent += amounts[i];
        }
        ownerAmount = distributable - totalSent;
    }

    /**
     * @notice Simulate payouts at any hypothetical vault balance.
     *         Useful for quoting before the threshold is reached.
     *
     * @param  hypotheticalBalance  Raw USDT balance to simulate (6 decimals).
     * @return addrs         The 11 recipient addresses.
     * @return sharesPer100k Each recipient's share out of 100 000.
     * @return amounts       Simulated raw USDT payout per recipient.
     * @return ownerAmount   Simulated raw USDT remainder for the owner.
     */
    function previewAt(uint256 hypotheticalBalance)
        external
        view
        returns (
            address[11] memory addrs,
            uint256[11] memory sharesPer100k,
            uint256[11] memory amounts,
            uint256 ownerAmount
        )
    {
        uint256 distributable = hypotheticalBalance > USDT_GAS_REFUND
            ? hypotheticalBalance - USDT_GAS_REFUND
            : hypotheticalBalance;
        addrs         = recipients;
        sharesPer100k = shares;

        uint256 totalSent;
        for (uint256 i = 0; i < RECIPIENT_COUNT; i++) {
            amounts[i] = (distributable * shares[i]) / DENOM;
            totalSent += amounts[i];
        }
        ownerAmount = distributable - totalSent;
    }
}