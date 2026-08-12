// SPDX-License-Identifier: MIT
// @title PM4 Morpho blue
// @author franix

pragma solidity 0.8.34;

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @title PM4 Morpho blue
contract PM4 {
    uint256 internal constant MAX_ALLOWANCE = type(uint256).max;
    uint256 private constant _IN_FLASH_SLOT = 0;
    uint256 private constant _IN_AGGREGATE_SLOT = 1;

    address public immutable MORPHO;

    address public owner;

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct MorphoFlashParams {
        address token;
        Call3Value[] calls;
    }

    error NotOwner();
    error NotMorpho();
    error NotUniV2();
    error NotInAggregate();
    error CallFailed();
    error ValueMismatch();
    error NotEnoughETH();
    error ETHTransferFailed();
    error TransferFailed();
    error ApproveFailed();
    error BlockNumberTooOld();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param morpho Morpho Blue address.
    /// @param tokens ERC20 tokens to pre-approve for Morpho pull-repay.
    constructor(address morpho, address[] memory tokens) {
        owner = msg.sender;
        MORPHO = morpho;

        for (uint256 i = 0; i < tokens.length;) {
            _safeApprove(tokens[i], MORPHO, MAX_ALLOWANCE);
            unchecked {
                ++i;
            }
        }
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    receive() external payable { }

    /// @notice loanProvider=NONE runs calls only; MORPHO flash-loans then runs calls and repays.
    /// @dev loanData encodes (token, amount) when loanProvider is MORPHO.
    function flashAndAggregate(uint32 maxBlockNumber, bool isMorpho, bytes calldata loanData, Call3Value[] calldata calls) external payable onlyOwner {
        if (block.number > maxBlockNumber) revert BlockNumberTooOld();
        if (!isMorpho) {
            _setInAggregate(true);
            _runCallsCalldata(calls, true);
            _setInAggregate(false);
            return;
        }

        (address token, uint256 amount) = abi.decode(loanData, (address, uint256));
        _setInFlash(true);
        IMorpho(MORPHO).flashLoan(token, amount, abi.encode(MorphoFlashParams({ token: token, calls: _callsToMemory(calls) })));
        _setInFlash(false);
        _safeTransfer(token, owner, _balanceOf(token, address(this)));
    }

    function approve(address token, address spender, uint256 amount) external onlyOwner {
        _safeApprove(token, spender, amount);
    }

    function sweep(address token, uint256 amount, address to) external onlyOwner {
        if (token == address(0)) _safeTransferETH(to, amount);
        else _safeTransfer(token, to, amount);
    }

    /**
     * Callbacks functions
     */

    function onMorphoFlashLoan(uint256, bytes calldata data) external {
        if (msg.sender != MORPHO || !_inFlash()) revert NotMorpho();
        MorphoFlashParams memory params = abi.decode(data, (MorphoFlashParams));
        _setInAggregate(true);
        _runCalls(params.calls, false);
        _setInAggregate(false);
    }

    /// @notice UniV2 pair flash-swap callback. `data` encodes nested Call3Value[] to run before repaying the pair.
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        if (sender != address(this) || !_inAggregate()) revert NotUniV2();
        // run calls
        Call3Value[] memory calls = abi.decode(data, (Call3Value[]));
        _runCalls(calls, false);

        // Repay the opposite token received by the flash swap to the v2 pool.
        address pair = msg.sender;
        if (amount0 > 0) _safeTransfer(IUniswapV2Pair(pair).token1(), pair, ((amount0 * 1000) / 997) + 1);
        else _safeTransfer(IUniswapV2Pair(pair).token0(), pair, ((amount1 * 1000) / 997) + 1);
    }

    /// @notice UniV3 pool swap callback; pays owed tokens directly to msg.sender (the pool).
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (!_inAggregate()) revert NotInAggregate();
        // run calls
        if (data.length > 0) {
            Call3Value[] memory calls = abi.decode(data, (Call3Value[]));
            if (calls.length > 0) _runCalls(calls, false);
        }

        // Pay the deltas to the v3 pool.
        if (amount0Delta > 0) _safeTransfer(IUniswapV3Pool(msg.sender).token0(), msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) _safeTransfer(IUniswapV3Pool(msg.sender).token1(), msg.sender, uint256(amount1Delta));
    }

    /**
     * Internal functions
     */

    // Solady SafeTransferLib ERC20 functions

    function _safeTransferETH(address to, uint256 amount) internal {
        assembly ("memory-safe") {
            if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        assembly ("memory-safe") {
            mstore(0x14, to)
            mstore(0x34, amount)
            mstore(0x00, 0xa9059cbb000000000000000000000000)
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0)
        }
    }

    function _safeApprove(address token, address to, uint256 amount) internal {
        assembly ("memory-safe") {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000)
            let success := call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
            if iszero(and(eq(mload(0x00), 1), success)) {
                if iszero(lt(or(iszero(extcodesize(token)), returndatasize()), success)) {
                    mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0)
        }
    }

    function _balanceOf(address token, address account) internal view returns (uint256 amount) {
        assembly ("memory-safe") {
            mstore(0x14, account) // Store the `account` argument.
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            amount := mul( // The arguments of `mul` are evaluated from right to left.
                mload(0x20),
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                )
            )
        }
    }

    // Calldata and memory functions

    function _runCalls(Call3Value[] memory calls, bool requireMsgValue) internal {
        uint256 valAccumulator;
        uint256 length = calls.length;

        for (uint256 i = 0; i < length;) {
            unchecked {
                valAccumulator += calls[i].value;
                ++i;
            }
        }

        if (requireMsgValue) {
            if (msg.value != valAccumulator) revert ValueMismatch();
        } else if (address(this).balance < valAccumulator) {
            revert NotEnoughETH();
        }

        for (uint256 i = 0; i < length;) {
            Call3Value memory calli = calls[i];
            (bool success,) = calli.target.call{ value: calli.value }(calli.callData);
            if (!success && !calli.allowFailure) revert CallFailed();
            unchecked {
                ++i;
            }
        }
    }

    function _runCallsCalldata(Call3Value[] calldata calls, bool requireMsgValue) internal {
        uint256 valAccumulator;
        uint256 length = calls.length;

        for (uint256 i = 0; i < length;) {
            unchecked {
                valAccumulator += calls[i].value;
                ++i;
            }
        }

        if (requireMsgValue) {
            if (msg.value != valAccumulator) revert ValueMismatch();
        } else if (address(this).balance < valAccumulator) {
            revert NotEnoughETH();
        }

        for (uint256 i = 0; i < length;) {
            Call3Value calldata calli = calls[i];
            (bool success,) = calli.target.call{ value: calli.value }(calli.callData);
            if (!success && !calli.allowFailure) revert CallFailed();
            unchecked {
                ++i;
            }
        }
    }

    function _callsToMemory(Call3Value[] calldata calls) internal pure returns (Call3Value[] memory out) {
        out = new Call3Value[](calls.length);
        for (uint256 i = 0; i < calls.length;) {
            out[i] = calls[i];
            unchecked {
                ++i;
            }
        }
    }

    // Slots functions

    function _setInFlash(bool value) internal {
        assembly ("memory-safe") {
            tstore(_IN_FLASH_SLOT, value)
        }
    }

    function _inFlash() internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(_IN_FLASH_SLOT)
        }
    }

    function _setInAggregate(bool value) internal {
        assembly ("memory-safe") {
            tstore(_IN_AGGREGATE_SLOT, value)
        }
    }

    function _inAggregate() internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(_IN_AGGREGATE_SLOT)
        }
    }
}