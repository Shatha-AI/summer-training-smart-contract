// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct SponsoredCallRequest {
    address to;
    address from;
    bytes data;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    bytes signature;
}

interface ISponsoredExecutorProxy {
    function sponsoredCall(SponsoredCallRequest calldata req)
        external
        returns (bool success, bytes memory results);

    function upgradeTo(address newImplementation) external;
    function changeAdmin(address newAdmin) external;
    function getImplementation() external view returns (address);
    function getAdmin() external view returns (address);
}

interface IERC1155Module {
    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function sponsoredBatchTransfer(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    function sponsoredTransfer(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external;
}

interface IERC1180Module {
    function initiateSwap(
        address[] calldata tokensOffered,
        uint256[] calldata amountsOffered,
        address[] calldata tokensRequested
    ) external returns (bytes32 swapId);

    function executeSwap(
        bytes32 swapId,
        address[] calldata tokensReceived,
        uint256[] calldata amountsReceived
    ) external;

    function cancelSwap(bytes32 swapId) external;

    function sponsoredSwapAndTransfer(
        bytes32 swapId,
        address[] calldata tokensReceived,
        uint256[] calldata amountsReceived,
        address recipient
    ) external;

    function sponsoredConditionalSwap(
        bytes32 swapId,
        address[] calldata tokensReceived,
        uint256[] calldata amountsReceived,
        bytes calldata condition
    ) external;

    function getSwapDetails(bytes32 swapId)
        external
        view
        returns (address initiator, address[] memory tokensOffered, uint256[] memory amountsOffered);

    function getFullSwapState(bytes32 swapId)
        external
        view
        returns (
            address initiator,
            address[] memory tokensOffered,
            uint256[] memory amountsOffered,
            address[] memory tokensRequested,
            address[] memory tokensReceived,
            uint256[] memory amountsReceived,
            bool executed,
            bool cancelled,
            uint256 timestamp
        );

    function getUserSwaps(address user) external view returns (bytes32[] memory);
    function isSwapExpired(bytes32 swapId) external view returns (bool);
    function setSwapExpiration(uint256 newExpiration) external;
    function setSwapCoordinator(address newCoordinator) external;
}

interface IEIP196Module {
    function sponsoredModExp(
        bytes calldata base,
        bytes calldata exponent,
        bytes calldata modulus
    ) external returns (bytes memory result);

    function sponsoredECAdd(
        uint256 ax,
        uint256 ay,
        uint256 bx,
        uint256 by
    ) external returns (uint256 rx, uint256 ry);

    function sponsoredECMul(
        uint256 x,
        uint256 y,
        uint256 scalar
    ) external returns (uint256 rx, uint256 ry);

    function sponsoredECPairing(uint256[] calldata input)
        external
        returns (uint256 result);

    function getPrecompileAddress(string memory precompileName)
        external
        pure
        returns (uint256);
}

interface ISPECK256Module {
    function registerEncryptionKey(bytes32 encryptionKey) external;

    function verifyDataIntegrity(bytes memory data, bytes32 expectedHash)
        external
        returns (bool);

    function getDataHash(bytes memory data) external pure returns (bytes32);
}

contract MultiChainFragmentsHub {
    ISponsoredExecutorProxy public sponsoredExecutorProxy;
    IERC1155Module public erc1155Module;
    IERC1180Module public erc1180Module;
    IEIP196Module public eip196Module;
    ISPECK256Module public speck256Module;

    string[] public branches;

    event ModulesConfigured(
        address indexed proxy,
        address indexed erc1155,
        address indexed erc1180,
        address eip196,
        address speck256
    );

    constructor(
        address proxy,
        address erc1155,
        address erc1180,
        address eip196,
        address speck256
    ) {
        _setModuleAddresses(proxy, erc1155, erc1180, eip196, speck256);

        branches.push("404-solved");
        branches.push("auto118");
        branches.push("main");
        branches.push("multichain-libraries");
        branches.push("speck-256");
    }

    function setModuleAddresses(
        address proxy,
        address erc1155,
        address erc1180,
        address eip196,
        address speck256
    ) external {
        _setModuleAddresses(proxy, erc1155, erc1180, eip196, speck256);
    }

    function _setModuleAddresses(
        address proxy,
        address erc1155,
        address erc1180,
        address eip196,
        address speck256
    ) internal {
        require(proxy != address(0), "Invalid proxy address");
        require(erc1155 != address(0), "Invalid ERC1155 address");
        require(erc1180 != address(0), "Invalid ERC1180 address");
        require(eip196 != address(0), "Invalid EIP196 address");
        require(speck256 != address(0), "Invalid SPECK256 address");

        sponsoredExecutorProxy = ISponsoredExecutorProxy(proxy);
        erc1155Module = IERC1155Module(erc1155);
        erc1180Module = IERC1180Module(erc1180);
        eip196Module = IEIP196Module(eip196);
        speck256Module = ISPECK256Module(speck256);

        emit ModulesConfigured(proxy, erc1155, erc1180, eip196, speck256);
    }

    function getBranches() external view returns (string[] memory) {
        return branches;
    }

    function getBranchCount() external view returns (uint256) {
        return branches.length;
    }

    function proxySponsoredCall(SponsoredCallRequest calldata req)
        external
        returns (bool success, bytes memory results)
    {
        return sponsoredExecutorProxy.sponsoredCall(req);
    }

    function upgradeProxyImplementation(address newImplementation) external {
        sponsoredExecutorProxy.upgradeTo(newImplementation);
    }

    function changeProxyAdmin(address newAdmin) external {
        sponsoredExecutorProxy.changeAdmin(newAdmin);
    }

    function getProxyImplementation() external view returns (address) {
        return sponsoredExecutorProxy.getImplementation();
    }

    function getProxyAdmin() external view returns (address) {
        return sponsoredExecutorProxy.getAdmin();
    }

    function erc1155BalanceOf(address account, uint256 id)
        external
        view
        returns (uint256)
    {
        return erc1155Module.balanceOf(account, id);
    }

    function erc1155BalanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        return erc1155Module.balanceOfBatch(accounts, ids);
    }

    function setErc1155ApprovalForAll(address operator, bool approved) external {
        erc1155Module.setApprovalForAll(operator, approved);
    }

    function isErc1155Approved(address account, address operator)
        external
        view
        returns (bool)
    {
        return erc1155Module.isApprovedForAll(account, operator);
    }

    function transferErc1155(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external {
        erc1155Module.safeTransferFrom(from, to, id, amount, data);
    }

    function batchTransferErc1155(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        erc1155Module.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function sponsoredErc1155BatchTransfer(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        erc1155Module.sponsoredBatchTransfer(from, to, ids, amounts);
    }

    function sponsoredErc1155Transfer(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external {
        erc1155Module.sponsoredTransfer(from, to, id, amount);
    }

    function initiateErc1180Swap(
        address[] calldata tokensOffered,
        uint256[] calldata amountsOffered,
        address[] calldata tokensRequested
    ) external returns (bytes32 swapId) {
        return erc1180Module.initiateSwap(tokensOffered, amountsOffered, tokensRequested);
    }

    function executeErc1180Swap(
        bytes32 swapId,
        address[] calldata tokensReceived,
        uint256[] calldata amountsReceived
    ) external {
        erc1180Module.executeSwap(swapId, tokensReceived, amountsReceived);
    }

    function cancelErc1180Swap(bytes32 swapId) external {
        erc1180Module.cancelSwap(swapId);
    }

    function sponsoredErc1180SwapAndTransfer(
        bytes32 swapId,
        address[] calldata tokensReceived,
        uint256[] calldata amountsReceived,
        address recipient
    ) external {
        erc1180Module.sponsoredSwapAndTransfer(swapId, tokensReceived, amountsReceived, recipient);
    }

    function sponsoredErc1180ConditionalSwap(
        bytes32 swapId,
        address[] calldata tokensReceived,
        uint256[] calldata amountsReceived,
        bytes calldata condition
    ) external {
        erc1180Module.sponsoredConditionalSwap(swapId, tokensReceived, amountsReceived, condition);
    }

    function getErc1180SwapDetails(bytes32 swapId)
        external
        view
        returns (address initiator, address[] memory tokensOffered, uint256[] memory amountsOffered)
    {
        return erc1180Module.getSwapDetails(swapId);
    }

    function getErc1180SwapState(bytes32 swapId)
        external
        view
        returns (
            address initiator,
            address[] memory tokensOffered,
            uint256[] memory amountsOffered,
            address[] memory tokensRequested,
            address[] memory tokensReceived,
            uint256[] memory amountsReceived,
            bool executed,
            bool cancelled,
            uint256 timestamp
        )
    {
        return erc1180Module.getFullSwapState(swapId);
    }

    function getErc1180UserSwaps(address user) external view returns (bytes32[] memory) {
        return erc1180Module.getUserSwaps(user);
    }

    function isErc1180SwapExpired(bytes32 swapId) external view returns (bool) {
        return erc1180Module.isSwapExpired(swapId);
    }

    function setErc1180SwapExpiration(uint256 newExpiration) external {
        erc1180Module.setSwapExpiration(newExpiration);
    }

    function setErc1180SwapCoordinator(address newCoordinator) external {
        erc1180Module.setSwapCoordinator(newCoordinator);
    }

    function runEip196ModExp(
        bytes calldata base,
        bytes calldata exponent,
        bytes calldata modulus
    ) external returns (bytes memory result) {
        return eip196Module.sponsoredModExp(base, exponent, modulus);
    }

    function runEip196EcAdd(
        uint256 ax,
        uint256 ay,
        uint256 bx,
        uint256 by
    ) external returns (uint256 rx, uint256 ry) {
        return eip196Module.sponsoredECAdd(ax, ay, bx, by);
    }

    function runEip196EcMul(
        uint256 x,
        uint256 y,
        uint256 scalar
    ) external returns (uint256 rx, uint256 ry) {
        return eip196Module.sponsoredECMul(x, y, scalar);
    }

    function runEip196Pairing(uint256[] calldata input)
        external
        returns (uint256 result)
    {
        return eip196Module.sponsoredECPairing(input);
    }

    function getEip196PrecompileAddress(string calldata precompileName)
        external
        view
        returns (uint256)
    {
        return eip196Module.getPrecompileAddress(precompileName);
    }

    function registerSpeckKey(bytes32 encryptionKey) external {
        speck256Module.registerEncryptionKey(encryptionKey);
    }

    function verifySpeckIntegrity(bytes memory data, bytes32 expectedHash)
        external
        returns (bool)
    {
        return speck256Module.verifyDataIntegrity(data, expectedHash);
    }

    function getSpeckHash(bytes memory data) external view returns (bytes32) {
        return speck256Module.getDataHash(data);
    }
}