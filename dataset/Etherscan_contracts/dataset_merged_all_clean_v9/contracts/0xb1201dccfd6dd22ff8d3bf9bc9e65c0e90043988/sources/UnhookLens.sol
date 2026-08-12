// SPDX-License-Identifier: MIT
/*
  UNHOOK — STATE LENS  (view-only reader)

  A read-only aggregator for frontends / indexers. Given the UnhookToken hook it
  returns the live adaptive-fee state in a single call: whether the hook is
  currently "unhooked", the fee that will apply to the next swap, the anchor
  price, and how many blocks remain until it re-hooks.

  Pure reads. No state, no funds, no privileges, cannot touch the token. It exists
  so the "adaptive" behaviour is easy to display and verify off-chain.

  NOT audited, no value.
*/
pragma solidity 0.8.24;

interface IUnhook {
    function unhooked() external view returns (bool);
    function currentFeeBps() external view returns (uint256);
    function anchorPrice() external view returns (uint256);
    function lastSpikeBlock() external view returns (uint64);
    function HOOKED_FEE_BPS() external view returns (uint256);
    function UNHOOKED_FEE_BPS() external view returns (uint256);
    function MAX_FEE_BPS() external view returns (uint256);
    function TRIGGER_BPS() external view returns (uint256);
    function COOLDOWN_BLOCKS() external view returns (uint64);
    function pendingFeeToken() external view returns (uint256);
    function pendingFeeEth() external view returns (uint256);
    function treasury() external view returns (address);
    function tradingEnabled() external view returns (bool);
}

contract UnhookLens {
    struct State {
        bool    unhooked;
        bool    tradingEnabled;
        uint256 currentFeeBps;
        uint256 hookedFeeBps;
        uint256 unhookedFeeBps;
        uint256 maxFeeBps;
        uint256 triggerBps;
        uint256 anchorPrice;
        uint64  lastSpikeBlock;
        uint64  cooldownBlocks;
        uint64  blocksUntilRehook;
        uint256 pendingFeeToken;
        uint256 pendingFeeEth;
        address treasury;
        uint256 blockNumber;
    }

    /// @notice Snapshot the full adaptive-fee state of an UnhookToken hook.
    function read(address hook) external view returns (State memory s) {
        IUnhook u = IUnhook(hook);
        s.unhooked        = u.unhooked();
        s.tradingEnabled  = u.tradingEnabled();
        s.currentFeeBps   = u.currentFeeBps();
        s.hookedFeeBps    = u.HOOKED_FEE_BPS();
        s.unhookedFeeBps  = u.UNHOOKED_FEE_BPS();
        s.maxFeeBps       = u.MAX_FEE_BPS();
        s.triggerBps      = u.TRIGGER_BPS();
        s.anchorPrice     = u.anchorPrice();
        s.lastSpikeBlock  = u.lastSpikeBlock();
        s.cooldownBlocks  = u.COOLDOWN_BLOCKS();
        s.pendingFeeToken = u.pendingFeeToken();
        s.pendingFeeEth   = u.pendingFeeEth();
        s.treasury        = u.treasury();
        s.blockNumber     = block.number;

        if (s.unhooked) {
            uint256 rehookAt = uint256(s.lastSpikeBlock) + uint256(s.cooldownBlocks);
            s.blocksUntilRehook = rehookAt > block.number ? uint64(rehookAt - block.number) : 0;
        }
    }

    /// @notice Convenience: just the fee that the next swap will pay, in bps.
    function nextFeeBps(address hook) external view returns (uint256) {
        return IUnhook(hook).currentFeeBps();
    }
}