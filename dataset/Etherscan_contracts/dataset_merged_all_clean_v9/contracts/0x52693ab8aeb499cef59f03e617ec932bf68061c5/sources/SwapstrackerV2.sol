// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SwapstrackerV2 {
    uint8 public constant STATUS_UNKNOWN = 0;
    uint8 public constant STATUS_PAIR_VALID = 1;
    uint8 public constant STATUS_ZERO_ADDRESS = 2;
    uint8 public constant STATUS_NOT_CONTRACT = 3;
    uint8 public constant STATUS_PAIR_LIKE_CONTRACT = 4;
    uint8 public constant STATUS_TOKEN_EMITTER = 5;
    uint8 public constant STATUS_NON_PAIR_CONTRACT = 6;

    bytes4 private constant TOKEN0_SELECTOR = 0x0dfe1681;
    bytes4 private constant TOKEN1_SELECTOR = 0xd21220a7;
    bytes4 private constant DECIMALS_SELECTOR = 0x313ce567;
    bytes4 private constant NAME_SELECTOR = 0x06fdde03;
    bytes4 private constant SYMBOL_SELECTOR = 0x95d89b41;
    bytes4 private constant FACTORY_SELECTOR = 0xc45a0155;
    bytes4 private constant GET_RESERVES_SELECTOR = 0x0902f1ac;

    struct PairElementMinimal {
        uint256 index;
        address pairAddress;
        uint8 status;
        uint8 pairDecimals;
        address token0;
        uint8 token0Decimals;
        address token1;
        uint8 token1Decimals;
    }

    struct PairElementFull {
        uint256 index;
        address pairAddress;
        uint8 status;
        uint8 pairDecimals;
        address token0;
        string token0Name;
        string token0Symbol;
        uint8 token0Decimals;
        address token1;
        string token1Name;
        string token1Symbol;
        uint8 token1Decimals;
    }

    struct PairCore {
        uint8 status;
        uint8 pairDecimals;
        address token0;
        address token1;
    }

    function getPairsElementsMinimalByPairs(
        address[] calldata pairAddresses
    ) external view returns (PairElementMinimal[] memory results) {
        uint256 length = pairAddresses.length;
        results = new PairElementMinimal[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildMinimalElement(i, pairAddresses[i]);
        }
    }

    function getPairsElementsByPairs(
        address[] calldata pairAddresses
    ) external view returns (PairElementFull[] memory results) {
        uint256 length = pairAddresses.length;
        results = new PairElementFull[](length);

        for (uint256 i = 0; i < length; i++) {
            results[i] = _buildFullElement(i, pairAddresses[i]);
        }
    }

    function _buildMinimalElement(
        uint256 index,
        address pairAddress
    ) internal view returns (PairElementMinimal memory item) {
        item.index = index;
        item.pairAddress = pairAddress;

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

    function _buildFullElement(
        uint256 index,
        address pairAddress
    ) internal view returns (PairElementFull memory item) {
        item.index = index;
        item.pairAddress = pairAddress;

        PairCore memory core = _resolvePairCore(pairAddress);
        item.status = core.status;
        item.pairDecimals = core.pairDecimals;
        item.token0 = core.token0;
        item.token1 = core.token1;

        if (core.status != STATUS_PAIR_VALID) {
            return item;
        }

        (item.token0Name, item.token0Symbol, item.token0Decimals) = _readTokenInfo(
            core.token0
        );
        (item.token1Name, item.token1Symbol, item.token1Decimals) = _readTokenInfo(
            core.token1
        );
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

    function _looksLikePairContract(address candidate) internal view returns (bool) {
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

    function _readTokenInfo(
        address token
    )
        internal
        view
        returns (string memory name_, string memory symbol_, uint8 decimals_)
    {
        if (token == address(0) || token.code.length == 0) {
            return ("", "", 0);
        }

        (, name_) = _readOptionalText(token, NAME_SELECTOR);
        (, symbol_) = _readOptionalText(token, SYMBOL_SELECTOR);
        (, decimals_) = _readUint8(token, DECIMALS_SELECTOR);
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