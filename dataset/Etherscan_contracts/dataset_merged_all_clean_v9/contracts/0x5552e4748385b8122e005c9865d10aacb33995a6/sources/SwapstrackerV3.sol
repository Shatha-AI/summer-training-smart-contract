// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SwapstrackerV3 {
    uint8 public constant STATUS_UNKNOWN = 0;
    uint8 public constant STATUS_PAIR_VALID = 1;
    uint8 public constant STATUS_ZERO_ADDRESS = 2;
    uint8 public constant STATUS_NOT_CONTRACT = 3;
    uint8 public constant STATUS_PAIR_LIKE_CONTRACT = 4;
    uint8 public constant STATUS_TOKEN_EMITTER = 5;
    uint8 public constant STATUS_NON_PAIR_CONTRACT = 6;
    uint8 public constant STATUS_V3_POOL_VALID = 7;
    uint8 public constant STATUS_V3_POOL_LIKE_CONTRACT = 8;

    bytes4 private constant TOKEN0_SELECTOR = 0x0dfe1681;
    bytes4 private constant TOKEN1_SELECTOR = 0xd21220a7;
    bytes4 private constant DECIMALS_SELECTOR = 0x313ce567;
    bytes4 private constant NAME_SELECTOR = 0x06fdde03;
    bytes4 private constant SYMBOL_SELECTOR = 0x95d89b41;
    bytes4 private constant FACTORY_SELECTOR = 0xc45a0155;
    bytes4 private constant GET_RESERVES_SELECTOR = 0x0902f1ac;
    bytes4 private constant FEE_SELECTOR = 0xddca3f43;
    bytes4 private constant LIQUIDITY_SELECTOR = 0x1a686502;
    bytes4 private constant SLOT0_SELECTOR = 0x3850c7bd;
    uint256 private constant MASK_96 = (uint256(1) << 96) - 1;

    struct PairElementHot {
        uint8 status;
        uint8 pairDecimals;
        address token0;
        uint8 token0Decimals;
        address token1;
        uint8 token1Decimals;
    }

    struct PackedPairElement {
        uint256 word0;
        uint256 word1;
    }

    struct TokenIdentity {
        uint8 status;
        string name;
        string symbol;
        uint8 decimals;
    }

    struct PairReserveState {
        uint8 status;
        uint112 reserve0;
        uint112 reserve1;
        uint32 blockTimestampLast;
    }

    struct V3PoolState {
        uint8 status;
        address token0;
        address token1;
        uint24 fee;
        uint128 liquidity;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    struct PackedV3PoolState {
        uint256 word0;
        uint256 word1;
        uint256 word2;
    }

    struct V3PoolTwapState {
        uint8 status;
        int24 arithmeticMeanTick;
        uint128 harmonicMeanLiquidity;
    }

    struct PairCore {
        uint8 status;
        uint8 pairDecimals;
        address token0;
        address token1;
    }

    function getPairsElementsHotByPairs(
        address[] calldata pairAddresses
    ) external view returns (PairElementHot[] memory results) {
        uint256 length = pairAddresses.length;
        results = new PairElementHot[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildHotElement(pairAddresses[i]);
        }
    }

    function getPairsElementsPackedByPairs(
        address[] calldata pairAddresses
    ) external view returns (PackedPairElement[] memory results) {
        uint256 length = pairAddresses.length;
        results = new PackedPairElement[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildPackedElement(pairAddresses[i]);
        }
    }

    function getTokenIdentitiesByTokens(
        address[] calldata tokenAddresses
    ) external view returns (TokenIdentity[] memory results) {
        uint256 length = tokenAddresses.length;
        results = new TokenIdentity[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildTokenIdentity(tokenAddresses[i]);
        }
    }

    function getPairReservesByPairs(
        address[] calldata pairAddresses
    ) external view returns (PairReserveState[] memory results) {
        uint256 length = pairAddresses.length;
        results = new PairReserveState[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildPairReserveState(pairAddresses[i]);
        }
    }

    function getV3PoolStatesByPools(
        address[] calldata poolAddresses
    ) external view returns (V3PoolState[] memory results) {
        uint256 length = poolAddresses.length;
        results = new V3PoolState[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildV3PoolState(poolAddresses[i]);
        }
    }

    function getV3PoolStatesPackedByPools(
        address[] calldata poolAddresses
    ) external view returns (PackedV3PoolState[] memory results) {
        uint256 length = poolAddresses.length;
        results = new PackedV3PoolState[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildPackedV3PoolState(poolAddresses[i]);
        }
    }

    function getV3PoolTwapStatesByPools(
        address[] calldata poolAddresses,
        uint32 secondsAgo
    ) external view returns (V3PoolTwapState[] memory results) {
        require(secondsAgo > 0);

        uint256 length = poolAddresses.length;
        results = new V3PoolTwapState[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildV3PoolTwapState(poolAddresses[i], secondsAgo);
        }
    }

    function _buildHotElement(
        address pairAddress
    ) internal view returns (PairElementHot memory item) {
        PairCore memory core = _resolvePairCore(pairAddress);
        item.status = core.status;
        item.pairDecimals = core.pairDecimals;
        item.token0 = core.token0;
        item.token1 = core.token1;

        if (core.status != STATUS_PAIR_VALID) {
            return item;
        }

        (, item.token0Decimals) = _readUint8(core.token0, DECIMALS_SELECTOR);
        (, item.token1Decimals) = _readUint8(core.token1, DECIMALS_SELECTOR);
    }

    function _buildPackedElement(
        address pairAddress
    ) internal view returns (PackedPairElement memory item) {
        PairCore memory core = _resolvePairCore(pairAddress);
        uint8 token0Decimals = 0;
        uint8 token1Decimals = 0;

        if (core.status == STATUS_PAIR_VALID) {
            (, token0Decimals) = _readUint8(core.token0, DECIMALS_SELECTOR);
            (, token1Decimals) = _readUint8(core.token1, DECIMALS_SELECTOR);
        }

        item.word0 =
            uint256(core.status) |
            (uint256(core.pairDecimals) << 8) |
            (uint256(token0Decimals) << 16) |
            (uint256(token1Decimals) << 24) |
            (uint256(uint160(core.token0)) << 32);

        item.word1 = uint256(uint160(core.token1));
    }

    function _buildTokenIdentity(
        address tokenAddress
    ) internal view returns (TokenIdentity memory item) {
        if (tokenAddress == address(0)) {
            item.status = STATUS_ZERO_ADDRESS;
            return item;
        }

        if (tokenAddress.code.length == 0) {
            item.status = STATUS_NOT_CONTRACT;
            return item;
        }

        (bool hasName, string memory name) = _readOptionalText(
            tokenAddress,
            NAME_SELECTOR
        );
        (bool hasSymbol, string memory symbol) = _readOptionalText(
            tokenAddress,
            SYMBOL_SELECTOR
        );
        (bool hasDecimals, uint8 decimals) = _readUint8(
            tokenAddress,
            DECIMALS_SELECTOR
        );

        if (hasName || hasSymbol || hasDecimals) {
            item.status = STATUS_TOKEN_EMITTER;
            item.name = name;
            item.symbol = symbol;
            item.decimals = decimals;
            return item;
        }

        item.status = STATUS_NON_PAIR_CONTRACT;
    }

    function _buildPairReserveState(
        address pairAddress
    ) internal view returns (PairReserveState memory item) {
        PairCore memory core = _resolvePairCore(pairAddress);
        item.status = core.status;

        if (
            core.status != STATUS_PAIR_VALID &&
            core.status != STATUS_PAIR_LIKE_CONTRACT
        ) {
            return item;
        }

        (
            bool reservesSuccess,
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        ) = _readReserves(pairAddress);

        if (!reservesSuccess) {
            return item;
        }

        item.reserve0 = reserve0;
        item.reserve1 = reserve1;
        item.blockTimestampLast = blockTimestampLast;

        if (core.status != STATUS_PAIR_VALID) {
            item.status = STATUS_PAIR_LIKE_CONTRACT;
        }
    }

    function _buildV3PoolState(
        address poolAddress
    ) internal view returns (V3PoolState memory item) {
        if (poolAddress == address(0)) {
            item.status = STATUS_ZERO_ADDRESS;
            return item;
        }

        if (poolAddress.code.length == 0) {
            item.status = STATUS_NOT_CONTRACT;
            return item;
        }

        (bool token0Success, address token0) = _readAddress(
            poolAddress,
            TOKEN0_SELECTOR
        );
        (bool token1Success, address token1) = _readAddress(
            poolAddress,
            TOKEN1_SELECTOR
        );
        (bool feeSuccess, uint24 fee) = _readUint24(poolAddress, FEE_SELECTOR);
        (
            bool liquiditySuccess,
            uint128 liquidity
        ) = _readUint128(poolAddress, LIQUIDITY_SELECTOR);
        (
            bool slot0Success,
            uint160 sqrtPriceX96,
            int24 tick
        ) = _readV3Slot0(poolAddress);

        if (
            token0Success &&
            token1Success &&
            feeSuccess &&
            liquiditySuccess &&
            slot0Success
        ) {
            item.status = STATUS_V3_POOL_VALID;
            item.token0 = token0;
            item.token1 = token1;
            item.fee = fee;
            item.liquidity = liquidity;
            item.sqrtPriceX96 = sqrtPriceX96;
            item.tick = tick;
            return item;
        }

        if (_looksLikeV3PoolContract(poolAddress)) {
            item.status = STATUS_V3_POOL_LIKE_CONTRACT;
            item.token0 = token0;
            item.token1 = token1;
            item.fee = fee;
            item.liquidity = liquidity;
            item.sqrtPriceX96 = sqrtPriceX96;
            item.tick = tick;
            return item;
        }

        item.status = STATUS_NON_PAIR_CONTRACT;
    }

    function _buildPackedV3PoolState(
        address poolAddress
    ) internal view returns (PackedV3PoolState memory item) {
        V3PoolState memory state = _buildV3PoolState(poolAddress);
        uint24 tickBits = uint24(uint256(int256(state.tick)));
        uint256 liquidityLow96 = uint256(state.liquidity) & MASK_96;
        uint256 liquidityHigh32 = uint256(state.liquidity) >> 96;

        item.word0 =
            uint256(state.status) |
            (uint256(state.fee) << 8) |
            (uint256(tickBits) << 32) |
            (uint256(uint160(state.token0)) << 56);

        item.word1 =
            uint256(uint160(state.token1)) |
            (liquidityLow96 << 160);

        item.word2 =
            liquidityHigh32 |
            (uint256(state.sqrtPriceX96) << 32);
    }

    function _buildV3PoolTwapState(
        address poolAddress,
        uint32 secondsAgo
    ) internal view returns (V3PoolTwapState memory item) {
        V3PoolState memory state = _buildV3PoolState(poolAddress);
        item.status = state.status;

        if (
            state.status != STATUS_V3_POOL_VALID &&
            state.status != STATUS_V3_POOL_LIKE_CONTRACT
        ) {
            return item;
        }

        (
            bool observeSuccess,
            int24 arithmeticMeanTick,
            uint128 harmonicMeanLiquidity
        ) = _readV3Twap(poolAddress, secondsAgo);

        if (!observeSuccess) {
            return item;
        }

        item.arithmeticMeanTick = arithmeticMeanTick;
        item.harmonicMeanLiquidity = harmonicMeanLiquidity;
    }

    function _resolvePairCore(
        address pairAddress
    ) internal view returns (PairCore memory core) {
        if (pairAddress == address(0)) {
            core.status = STATUS_ZERO_ADDRESS;
            return core;
        }

        if (pairAddress.code.length == 0) {
            core.status = STATUS_NOT_CONTRACT;
            return core;
        }

        (, core.pairDecimals) = _readUint8(pairAddress, DECIMALS_SELECTOR);

        (bool token0Success, address token0) = _readAddress(
            pairAddress,
            TOKEN0_SELECTOR
        );
        if (!token0Success || token0 == address(0)) {
            core.status = _classifyAddress(pairAddress);
            return core;
        }
        core.token0 = token0;

        (bool token1Success, address token1) = _readAddress(
            pairAddress,
            TOKEN1_SELECTOR
        );
        if (!token1Success || token1 == address(0)) {
            core.status = _classifyAddress(pairAddress);
            return core;
        }

        core.token1 = token1;
        core.status = STATUS_PAIR_VALID;
    }

    function _classifyAddress(
        address candidate
    ) internal view returns (uint8 status) {
        if (_looksLikePairContract(candidate)) {
            return STATUS_PAIR_LIKE_CONTRACT;
        }

        if (_looksLikeTokenContract(candidate)) {
            return STATUS_TOKEN_EMITTER;
        }

        return STATUS_NON_PAIR_CONTRACT;
    }

    function _looksLikePairContract(
        address candidate
    ) internal view returns (bool) {
        bool reservesSuccess;
        bytes memory reservesData;

        (bool factorySuccess, address factoryAddress) = _readAddress(
            candidate,
            FACTORY_SELECTOR
        );
        if (factorySuccess && factoryAddress != address(0)) {
            return true;
        }

        (reservesSuccess, reservesData) = candidate.staticcall(
            abi.encodeWithSelector(GET_RESERVES_SELECTOR)
        );

        return reservesSuccess && reservesData.length >= 96;
    }

    function _looksLikeTokenContract(
        address candidate
    ) internal view returns (bool) {
        (bool hasName, ) = _readOptionalText(candidate, NAME_SELECTOR);
        if (hasName) {
            return true;
        }

        (bool hasSymbol, ) = _readOptionalText(candidate, SYMBOL_SELECTOR);
        if (hasSymbol) {
            return true;
        }

        (bool hasDecimals, ) = _readUint8(candidate, DECIMALS_SELECTOR);
        return hasDecimals;
    }

    function _looksLikeV3PoolContract(
        address candidate
    ) internal view returns (bool) {
        (bool feeSuccess, ) = _readUint24(candidate, FEE_SELECTOR);
        if (!feeSuccess) {
            return false;
        }

        (bool slot0Success, , ) = _readV3Slot0(candidate);
        return slot0Success;
    }

    function _readAddress(
        address target,
        bytes4 selector
    ) internal view returns (bool success, address value) {
        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSelector(selector)
        );
        if (!success || data.length < 32) {
            return (false, address(0));
        }

        value = abi.decode(data, (address));
        return (true, value);
    }

    function _readUint8(
        address target,
        bytes4 selector
    ) internal view returns (bool success, uint8 value) {
        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSelector(selector)
        );
        if (!success || data.length < 32) {
            return (false, 0);
        }

        value = abi.decode(data, (uint8));
        return (true, value);
    }

    function _readUint24(
        address target,
        bytes4 selector
    ) internal view returns (bool success, uint24 value) {
        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSelector(selector)
        );
        if (!success || data.length < 32) {
            return (false, 0);
        }

        value = abi.decode(data, (uint24));
        return (true, value);
    }

    function _readUint128(
        address target,
        bytes4 selector
    ) internal view returns (bool success, uint128 value) {
        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSelector(selector)
        );
        if (!success || data.length < 32) {
            return (false, 0);
        }

        value = abi.decode(data, (uint128));
        return (true, value);
    }

    function _readOptionalText(
        address target,
        bytes4 selector
    ) internal view returns (bool success, string memory value) {
        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSelector(selector)
        );
        if (!success || data.length == 0) {
            return (false, "");
        }

        return _decodeOptionalText(data);
    }

    function _readReserves(
        address target
    )
        internal
        view
        returns (
            bool success,
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {
        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSelector(GET_RESERVES_SELECTOR)
        );
        if (!success || data.length < 96) {
            return (false, 0, 0, 0);
        }

        (reserve0, reserve1, blockTimestampLast) = abi.decode(
            data,
            (uint112, uint112, uint32)
        );
    }

    function _readV3Slot0(
        address target
    )
        internal
        view
        returns (
            bool success,
            uint160 sqrtPriceX96,
            int24 tick
        )
    {
        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSelector(SLOT0_SELECTOR)
        );
        if (!success || data.length < 224) {
            return (false, 0, 0);
        }

        (
            sqrtPriceX96,
            tick,
            ,
            ,
            ,
            ,

        ) = abi.decode(data, (uint160, int24, uint16, uint16, uint16, uint8, bool));
    }

    function _readV3Twap(
        address target,
        uint32 secondsAgo
    )
        internal
        view
        returns (
            bool success,
            int24 arithmeticMeanTick,
            uint128 harmonicMeanLiquidity
        )
    {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        bytes memory data;
        (success, data) = target.staticcall(
            abi.encodeWithSignature("observe(uint32[])", secondsAgos)
        );
        if (!success) {
            return (false, 0, 0);
        }

        (int56[] memory tickCumulatives, uint160[] memory splCumulatives) = abi.decode(
            data,
            (int56[], uint160[])
        );
        if (tickCumulatives.length < 2 || splCumulatives.length < 2) {
            return (false, 0, 0);
        }

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        arithmeticMeanTick = int24(
            tickCumulativesDelta / int56(uint56(secondsAgo))
        );
        if (
            tickCumulativesDelta < 0 &&
            (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)
        ) {
            arithmeticMeanTick--;
        }

        uint160 splDelta = splCumulatives[1] - splCumulatives[0];
        if (splDelta == 0) {
            return (true, arithmeticMeanTick, 0);
        }

        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(
            secondsAgoX160 / (uint192(splDelta) << 32)
        );
    }

    function _decodeOptionalText(
        bytes memory data
    ) internal pure returns (bool success, string memory value) {
        if (data.length == 32) {
            value = _bytes32ToTrimmedString(bytes32(_loadWord(data, 0)));
            return (bytes(value).length > 0, value);
        }

        if (data.length < 64) {
            return (false, "");
        }

        uint256 offset = _loadWord(data, 0);
        uint256 length = _loadWord(data, 32);

        if (offset != 32 || length == 0) {
            return (false, "");
        }

        uint256 paddedLength = ((length + 31) / 32) * 32;
        if (data.length < 64 + paddedLength) {
            return (false, "");
        }

        bytes memory raw = new bytes(length);
        uint256 src;
        uint256 dst;

        assembly {
            src := add(data, 96)
            dst := add(raw, 32)
        }

        for (uint256 i = 0; i < paddedLength; i += 32) {
            assembly {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }

        return (true, string(raw));
    }

    function _loadWord(
        bytes memory data,
        uint256 offset
    ) internal pure returns (uint256 value) {
        assembly {
            value := mload(add(add(data, 32), offset))
        }
    }

    function _bytes32ToTrimmedString(
        bytes32 value
    ) internal pure returns (string memory) {
        uint256 length = 0;
        while (length < 32 && value[length] != 0) {
            length++;
        }

        bytes memory buffer = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            buffer[i] = value[i];
        }

        return string(buffer);
    }
}