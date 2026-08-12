// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

// Harbor_Executor is a stateless intermediary for arbitrary external calls.
// The router approves this contract for tokens, which it pulls via transferFrom,
// approves the target, executes the call, and reverts if the full token amount
// is not consumed. This ensures atomic execution — either the target uses all
// tokens or the entire transaction reverts (triggering the router's refund path).
contract Harbor_Executor {

    bytes4 private constant APPROVE_SIG = 0x095ea7b3;        // approve(address,uint256)
    bytes4 private constant TRANSFER_FROM_SIG = 0x23b872dd;  // transferFrom(address,address,uint256)
    bytes4 private constant BALANCE_OF_SIG = 0x70a08231;    // balanceOf(address)

    function execute(
        address asset,
        uint256 amount,
        address target,
        bytes calldata payload
    ) external payable returns (bytes memory) {
        uint256 balBefore;

        if (asset != address(0) && amount > 0) {
            // Snapshot balance (in case executor already holds some of this token)
            balBefore = _balanceOf(asset);

            // Pull tokens from sender (router)
            (bool pullOk, bytes memory pullData) = asset.call(
                abi.encodeWithSelector(TRANSFER_FROM_SIG, msg.sender, address(this), amount)
            );
            require(pullOk && (pullData.length == 0 || abi.decode(pullData, (bool))),
                "Harbor_Executor: transferFrom failed");

            // Approve target to spend the tokens
            (bool appOk, bytes memory appData) = asset.call(
                abi.encodeWithSelector(APPROVE_SIG, target, amount)
            );
            require(appOk && (appData.length == 0 || abi.decode(appData, (bool))),
                "Harbor_Executor: approve failed");
        }

        // Execute the call — reverts the entire tx on failure
        (bool success, bytes memory result) = target.call{value: msg.value}(payload);
        require(success, "Harbor_Executor: call failed");

        if (asset != address(0) && amount > 0) {
            // Revoke any leftover approval
            (bool revOk,) = asset.call(abi.encodeWithSelector(APPROVE_SIG, target, 0));
            require(revOk, "Harbor_Executor: revoke failed");

            // Revert if the target did not consume all tokens.
            // The router's refund path handles the failure case.
            uint256 remaining = _balanceOf(asset) - balBefore;
            require(remaining == 0, "Harbor_Executor: tokens not fully consumed");
        }

        return result;
    }

    function _balanceOf(address asset) internal view returns (uint256) {
        (bool ok, bytes memory data) = asset.staticcall(
            abi.encodeWithSelector(BALANCE_OF_SIG, address(this))
        );
        require(ok && data.length >= 32, "Harbor_Executor: balanceOf failed");
        return abi.decode(data, (uint256));
    }
}