// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// ════════════════════════════════════════════════════════════
/// SPEND2STAKE — DISTRIBUTION SPLITTER
/// Atomic payout of a holder's entitlement:
///   one transaction → net amount to the holder,
///   success fee to the platform — both or neither.
/// Amounts are computed by the transfer-agent ledger (any fee
/// rate); the contract guarantees the fee's destination.
/// Never holds funds: both transfers pull directly from the
/// paying business to the recipients.
/// ════════════════════════════════════════════════════════════
contract S2SDistributionSplitter {
    address public immutable platform;

    event DistributionPaid(
        address indexed business,
        address indexed holder,
        address token,
        uint256 netAmount,
        uint256 feeAmount
    );

    constructor(address _platform) {
        require(_platform != address(0), "platform=0");
        platform = _platform;
    }

    /// @param token      ERC-20 (USDT / USDC / DAI)
    /// @param holder     the entitled staker's wallet
    /// @param netAmount  holder's net entitlement (base units)
    /// @param feeAmount  platform success fee (base units)
    ///                   caller must have approved >= net + fee
    function payout(address token, address holder, uint256 netAmount, uint256 feeAmount) external {
        require(holder != address(0), "holder=0");
        require(netAmount > 0, "net=0");

        _safeTransferFrom(token, msg.sender, holder, netAmount);
        if (feeAmount > 0) {
            _safeTransferFrom(token, msg.sender, platform, feeAmount);
        }
        emit DistributionPaid(msg.sender, holder, token, netAmount, feeAmount);
    }

    /// USDT-compatible transferFrom
    function _safeTransferFrom(address token, address from, address to, uint256 value) private {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
    }
}