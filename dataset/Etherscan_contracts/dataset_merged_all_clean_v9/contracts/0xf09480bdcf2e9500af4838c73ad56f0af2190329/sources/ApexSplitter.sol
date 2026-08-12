// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ApexSplitter
 * @notice 5-way exact-amount ERC20 payment splitter for Quorum Apex
 *         subscriptions. The subscriber pays `amountEach` to each of five
 *         recipients: the hardcoded Q_INC registry address (always
 *         recipients[0] — callers cannot omit or replace it) plus the ETH
 *         payout addresses of the four quorum-space owners the subscriber
 *         chose. Total pulled from the payer is exactly `amountEach * 5` —
 *         the client computes `amountEach = floor(totalUnits / 5)` so there
 *         is never dust.
 *
 *         Modeled on the TimedExactTokenSplitter used for QNS payments:
 *         the contract never holds funds; it only relays `transferFrom`
 *         the payer to each recipient within a single transaction, gated
 *         by a payment deadline so a stale signed/queued payment cannot
 *         execute after the client-side quote has expired.
 *
 *         Two entry points:
 *           - paySplitExactWithPermit: EIP-2612 permit for tokens that
 *             support it (USDC, wQUIL). The permit call is wrapped in a
 *             try/catch so a front-run permit (which would consume the
 *             nonce and revert the inner call) cannot brick the payment —
 *             if the allowance is already in place the transfers proceed.
 *           - paySplitExact: for tokens without EIP-2612 (e.g. SNAP).
 *             The payer must approve this contract for amountEach * 5
 *             beforehand.
 *
 * @dev SECURITY INVARIANT — payer is always msg.sender
 *      EIP-2612 permits sign (owner, spender, value, nonce, deadline) and do
 *      NOT bind a destination; destination safety must come from the spender
 *      contract. This contract therefore (a) hardcodes the permit owner to
 *      msg.sender, and (b) only ever calls transferFrom(msg.sender, ...).
 *      There is deliberately no `payer` parameter: a front-runner who replays
 *      a victim's permit signature can only execute the permit early (pure
 *      griefing, neutralized by the try/catch — the victim's own tx still
 *      completes with the victim's recipients), or call this contract as
 *      themselves and move their own funds. Do not add any function that
 *      takes an explicit payer — it would make standing allowances drainable
 *      to attacker-chosen recipients.
 *
 * @dev DEPLOYMENT NOTES
 *      - Target chain: Ethereum mainnet (chainId 1) only — the only chain
 *        where all three accepted tokens (wQUIL, SNAP, USDC) exist.
 *      - No constructor arguments, no owner, no upgradability, no held
 *        funds — a single immutable deployment is sufficient.
 *      - Compile with solc ^0.8.20 (built-in overflow checks are relied
 *        upon for `amountEach * 5`).
 *      - After deployment, place the deployed address in the mobile app at
 *        services/apex/config.ts (APEX_SPLITTER_ADDRESSES[1]) — the app
 *        refuses to initiate payments while the configured address is the
 *        zero placeholder.
 */
contract ApexSplitter {
    /// @notice Q Inc registry address — hardcoded so every payment routed
    ///         through this contract provably includes the Q Inc share.
    ///         Callers supply only the four space-owner recipients; the
    ///         contract prepends Q_INC as recipients[0]. If Q Inc ever
    ///         rotates this address, deploy a new splitter (the contract is
    ///         immutable by design) and update the app + API config.
    address public constant Q_INC = 0x4EB75d50C70faBAaF5f5980dE7c11009318C8635;

    /// @notice Emitted once per successful subscription payment.
    /// @dev `subscriber` binds the on-chain payment to an off-chain Quorum
    ///      account: the client passes keccak256(utf8(lowercase Quorum
    ///      address)). The Quorum API verifies a claimed subscription by
    ///      matching this topic against the claiming account — no extra
    ///      wallet-ownership proof needed, and a third party who saw the tx
    ///      cannot claim it for a different account.
    event ApexPayment(
        address indexed payer,
        address indexed token,
        bytes32 indexed subscriber,
        uint256 amountEach,
        address[5] recipients
    );

    /**
     * @notice Pay `amountEach` to Q_INC plus each of four space recipients
     *         using an EIP-2612 permit for `amountEach * 5`.
     * @param token           ERC20 token to pay with (must support permit).
     * @param spaceRecipients The four non-zero space-owner payout addresses
     *                        (Q_INC is prepended by the contract).
     * @param amountEach      Token units transferred to each recipient.
     * @param paymentDeadline Unix timestamp after which the payment reverts.
     * @param permitDeadline  Deadline embedded in the signed permit.
     * @param v               Permit signature v.
     * @param r               Permit signature r.
     * @param s               Permit signature s.
     * @param subscriber      keccak256 of the subscriber's Quorum address
     *                        (binds the payment to a Quorum account).
     */
    function paySplitExactWithPermit(
        address token,
        address[4] calldata spaceRecipients,
        uint256 amountEach,
        uint256 paymentDeadline,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 subscriber
    ) external {
        require(block.timestamp <= paymentDeadline, "ApexSplitter: payment expired");
        // try/catch: if the permit was front-run (nonce consumed) but the
        // allowance is in place, the transfers below still succeed.
        try IERC20Permit(token).permit(
            msg.sender,
            address(this),
            amountEach * 5,
            permitDeadline,
            v,
            r,
            s
        ) {} catch {}
        _paySplit(token, spaceRecipients, amountEach, subscriber);
    }

    /**
     * @notice Pay `amountEach` to Q_INC plus each of four space recipients.
     *         The payer must have approved this contract for at least
     *         `amountEach * 5`. Used for tokens without EIP-2612 support
     *         (e.g. SNAP).
     * @param token           ERC20 token to pay with.
     * @param spaceRecipients The four non-zero space-owner payout addresses
     *                        (Q_INC is prepended by the contract).
     * @param amountEach      Token units transferred to each recipient.
     * @param paymentDeadline Unix timestamp after which the payment reverts.
     * @param subscriber      keccak256 of the subscriber's Quorum address.
     */
    function paySplitExact(
        address token,
        address[4] calldata spaceRecipients,
        uint256 amountEach,
        uint256 paymentDeadline,
        bytes32 subscriber
    ) external {
        require(block.timestamp <= paymentDeadline, "ApexSplitter: payment expired");
        _paySplit(token, spaceRecipients, amountEach, subscriber);
    }

    /// @dev Duplicate space recipients are intentionally allowed — a
    ///      subscriber may assign multiple (even all four) slots to one
    ///      space, and distinct spaces may also share one owner payout
    ///      wallet. The contract only guarantees the Q Inc share and the
    ///      exact 5-way amounts; slot semantics live off-chain.
    function _paySplit(
        address token,
        address[4] calldata spaceRecipients,
        uint256 amountEach,
        bytes32 subscriber
    ) private {
        require(token != address(0), "ApexSplitter: zero token");
        require(amountEach > 0, "ApexSplitter: zero amount");
        address[5] memory recipients;
        recipients[0] = Q_INC;
        for (uint256 i = 0; i < 4; i++) {
            require(spaceRecipients[i] != address(0), "ApexSplitter: zero recipient");
            recipients[i + 1] = spaceRecipients[i];
        }
        for (uint256 i = 0; i < 5; i++) {
            _safeTransferFrom(token, msg.sender, recipients[i], amountEach);
        }
        emit ApexPayment(msg.sender, token, subscriber, amountEach, recipients);
    }

    /**
     * @dev Minimal SafeERC20-style transferFrom: tolerates tokens that
     *      return nothing (non-standard ERC20s) but reverts if the token
     *      returns `false` or the call itself fails.
     */
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "ApexSplitter: transferFrom failed"
        );
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}