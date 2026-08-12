// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC721ReceiverMinimal {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

interface ICreatorTokenTransferValidator {
    function validateTransfer(address caller, address from, address to, uint256 tokenId) external view;
}

contract GlitchyBunniesEthereum {
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    bytes4 private constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    bytes4 private constant ERC2981_INTERFACE_ID = 0x2a55205a;
    bytes4 private constant ERC173_INTERFACE_ID = 0x7f5828d0;
    bytes4 private constant CREATOR_TOKEN_INTERFACE_ID = 0xad0d7f6c;
    bytes4 private constant TOKEN_ID_TRANSFER_VALIDATION_SELECTOR = 0xcaee23ea;

    address public owner;
    address public pendingOwner;
    address public bridgeMinter;
    address public royaltyReceiver;
    address public transferValidator;
    bool public autoApproveTransfersFromValidator;
    uint96 public royaltyBps;
    uint256 public totalSupply;

    string private baseTokenURI;
    string private collectionContractURI;
    string private tokenName;
    string private tokenSymbol;

    mapping(uint256 tokenId => address tokenOwner) private owners;
    mapping(address tokenOwner => uint256 count) private balances;
    mapping(uint256 tokenId => address approved) private tokenApprovals;
    mapping(address tokenOwner => mapping(address operator => bool approved)) private operatorApprovals;
    mapping(address operator => bool blocked) public blockedOperators;
    mapping(uint256 tokenId => bytes32 sourceTxHash) public migrationSourceTxHash;

    error NotOwner();
    error NotPendingOwner();
    error NotBridgeMinter();
    error ZeroAddress();
    error EmptyTokenList();
    error TooManyTokens();
    error AlreadyMinted(uint256 tokenId);
    error TokenNotMinted(uint256 tokenId);
    error NotApprovedOrOwner();
    error ApprovalToCurrentOwner();
    error InvalidRoyaltyBps();
    error InvalidSourceTxHash();
    error BlockedOperator(address operator);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BridgeMinterSet(address indexed bridgeMinter);
    event BaseURISet(string baseURI);
    event ContractURISet(string contractURI);
    event ContractURIUpdated();
    event RoyaltyInfoSet(address indexed receiver, uint96 bps);
    event TransferValidatorUpdated(address oldValidator, address newValidator);
    event AutomaticApprovalOfTransfersFromValidatorSet(bool enabled);
    event BlockedOperatorSet(address indexed operator, bool blocked);
    event MigrationMinted(address indexed to, uint256 indexed tokenId, bytes32 indexed sourceTxHash);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyBridgeMinter() {
        if (msg.sender != bridgeMinter) revert NotBridgeMinter();
        _;
    }

    constructor(
        string memory initialName,
        string memory initialSymbol,
        address initialOwner,
        address initialBridgeMinter,
        string memory initialBaseTokenURI,
        string memory initialContractURI,
        address initialRoyaltyReceiver,
        uint96 initialRoyaltyBps
    ) {
        if (initialOwner == address(0)) revert ZeroAddress();
        if (initialBridgeMinter == address(0)) revert ZeroAddress();
        if (initialRoyaltyBps > BPS_DENOMINATOR) revert InvalidRoyaltyBps();
        if (initialRoyaltyBps != 0 && initialRoyaltyReceiver == address(0)) revert ZeroAddress();

        owner = initialOwner;
        bridgeMinter = initialBridgeMinter;
        baseTokenURI = initialBaseTokenURI;
        collectionContractURI = initialContractURI;
        tokenName = initialName;
        tokenSymbol = initialSymbol;
        royaltyReceiver = initialRoyaltyReceiver;
        royaltyBps = initialRoyaltyBps;

        emit OwnershipTransferred(address(0), initialOwner);
        emit BridgeMinterSet(initialBridgeMinter);
        emit BaseURISet(initialBaseTokenURI);
        emit ContractURISet(initialContractURI);
        emit RoyaltyInfoSet(initialRoyaltyReceiver, initialRoyaltyBps);
    }

    function name() external view returns (string memory) {
        return tokenName;
    }

    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }

    function balanceOf(address account) external view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = owners[tokenId];
        if (tokenOwner == address(0)) revert TokenNotMinted(tokenId);
        return tokenOwner;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (!_exists(tokenId)) revert TokenNotMinted(tokenId);
        if (bytes(baseTokenURI).length == 0) return "";

        return string.concat(baseTokenURI, _toString(tokenId));
    }

    function contractURI() external view returns (string memory) {
        return collectionContractURI;
    }

    function getTransferValidator() external view returns (address validator) {
        return transferValidator;
    }

    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        return (TOKEN_ID_TRANSFER_VALIDATION_SELECTOR, true);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (!_exists(tokenId)) revert TokenNotMinted(tokenId);
        return tokenApprovals[tokenId];
    }

    function isApprovedForAll(address tokenOwner, address operator) external view returns (bool) {
        return _isApprovedForAll(tokenOwner, operator);
    }

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (to == tokenOwner) revert ApprovalToCurrentOwner();
        if (msg.sender != tokenOwner && !_isApprovedForAll(tokenOwner, msg.sender)) revert NotApprovedOrOwner();
        if (to != address(0)) _requireOperatorAllowed(to);

        tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (approved) _requireOperatorAllowed(operator);

        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        if (tokenOwner != from) revert NotApprovedOrOwner();
        if (to == address(0)) revert ZeroAddress();
        if (!_isApprovedOrOwner(msg.sender, tokenOwner, tokenId)) revert NotApprovedOrOwner();
        if (msg.sender != tokenOwner) _requireOperatorAllowed(msg.sender);

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function mintMigrated(address to, uint256 tokenId, bytes32 sourceTxHash) external onlyBridgeMinter {
        _mintMigrated(to, tokenId, sourceTxHash);
    }

    function batchMintMigrated(address to, uint256[] calldata tokenIds, bytes32 sourceTxHash) external onlyBridgeMinter {
        _validateBatch(tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _mintMigrated(to, tokenIds[i], sourceTxHash);
        }
    }

    function setBridgeMinter(address nextBridgeMinter) external onlyOwner {
        if (nextBridgeMinter == address(0)) revert ZeroAddress();

        bridgeMinter = nextBridgeMinter;
        emit BridgeMinterSet(nextBridgeMinter);
    }

    function setBaseURI(string calldata nextBaseURI) external onlyOwner {
        baseTokenURI = nextBaseURI;
        emit BaseURISet(nextBaseURI);
    }

    function setContractURI(string calldata nextContractURI) external onlyOwner {
        collectionContractURI = nextContractURI;
        emit ContractURISet(nextContractURI);
        emit ContractURIUpdated();
    }

    function setTransferValidator(address validator) external onlyOwner {
        address oldValidator = transferValidator;
        transferValidator = validator;
        emit TransferValidatorUpdated(oldValidator, validator);
    }

    function setAutomaticApprovalOfTransfersFromValidator(bool enabled) external onlyOwner {
        autoApproveTransfersFromValidator = enabled;
        emit AutomaticApprovalOfTransfersFromValidatorSet(enabled);
    }

    function getAutomaticApprovalOfTransfersFromValidator() external view returns (bool) {
        return autoApproveTransfersFromValidator;
    }

    function setBlockedOperator(address operator, bool blocked) external onlyOwner {
        _setBlockedOperator(operator, blocked);
    }

    function setBlockedOperators(address[] calldata operators, bool blocked) external onlyOwner {
        for (uint256 i = 0; i < operators.length; i++) {
            _setBlockedOperator(operators[i], blocked);
        }
    }

    function setRoyaltyInfo(address receiver, uint96 bps) external onlyOwner {
        if (bps > BPS_DENOMINATOR) revert InvalidRoyaltyBps();
        if (bps != 0 && receiver == address(0)) revert ZeroAddress();

        royaltyReceiver = receiver;
        royaltyBps = bps;
        emit RoyaltyInfoSet(receiver, bps);
    }

    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyReceiver;
        royaltyAmount = salePrice * royaltyBps / BPS_DENOMINATOR;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();

        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, owner);
    }

    function cancelOwnershipTransfer() external onlyOwner {
        pendingOwner = address(0);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == ERC165_INTERFACE_ID
            || interfaceId == ERC721_INTERFACE_ID
            || interfaceId == ERC721_METADATA_INTERFACE_ID
            || interfaceId == ERC2981_INTERFACE_ID
            || interfaceId == ERC173_INTERFACE_ID
            || interfaceId == CREATOR_TOKEN_INTERFACE_ID;
    }

    function _mintMigrated(address to, uint256 tokenId, bytes32 sourceTxHash) private {
        if (to == address(0)) revert ZeroAddress();
        if (sourceTxHash == bytes32(0)) revert InvalidSourceTxHash();
        if (_exists(tokenId)) revert AlreadyMinted(tokenId);

        owners[tokenId] = to;
        balances[to] += 1;
        totalSupply += 1;
        migrationSourceTxHash[tokenId] = sourceTxHash;

        emit Transfer(address(0), to, tokenId);
        emit MigrationMinted(to, tokenId, sourceTxHash);
    }

    function _transfer(address from, address to, uint256 tokenId) private {
        _validateTransfer(msg.sender, from, to, tokenId);

        address previousApproval = tokenApprovals[tokenId];
        if (previousApproval != address(0)) {
            delete tokenApprovals[tokenId];
            emit Approval(from, address(0), tokenId);
        }

        owners[tokenId] = to;
        balances[from] -= 1;
        balances[to] += 1;

        emit Transfer(from, to, tokenId);
    }

    function _validateTransfer(address caller, address from, address to, uint256 tokenId) private view {
        address validator = transferValidator;
        if (validator == address(0)) return;

        ICreatorTokenTransferValidator(validator).validateTransfer(caller, from, to, tokenId);
    }

    function _setBlockedOperator(address operator, bool blocked) private {
        if (operator == address(0)) revert ZeroAddress();

        blockedOperators[operator] = blocked;
        emit BlockedOperatorSet(operator, blocked);
    }

    function _requireOperatorAllowed(address operator) private view {
        if (blockedOperators[operator]) revert BlockedOperator(operator);
    }

    function _exists(uint256 tokenId) private view returns (bool) {
        return owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, address tokenOwner, uint256 tokenId) private view returns (bool) {
        return spender == tokenOwner || tokenApprovals[tokenId] == spender || _isApprovedForAll(tokenOwner, spender);
    }

    function _isApprovedForAll(address tokenOwner, address operator) private view returns (bool) {
        return operatorApprovals[tokenOwner][operator]
            || (
                autoApproveTransfersFromValidator
                    && transferValidator != address(0)
                    && operator == transferValidator
            );
    }

    function _validateBatch(uint256 length) private pure {
        if (length == 0) revert EmptyTokenList();
        if (length > MAX_BATCH_SIZE) revert TooManyTokens();
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length == 0) return;

        bytes4 selector = IERC721ReceiverMinimal(to).onERC721Received(msg.sender, from, tokenId, data);
        require(selector == IERC721ReceiverMinimal.onERC721Received.selector, "UNSAFE_RECIPIENT");
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}