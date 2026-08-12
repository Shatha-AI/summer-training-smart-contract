// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
    TSUKIRONIN
    6000 masterless warriors of the moonlit night.
    No lord. No clan. Only the blade.
*/

interface ICreatorTokenTransferValidator {
    function applyCollectionTransferPolicy(address caller, address from, address to) external view;
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract Tsukironin {
    // ------------------------------------------------------------------
    // Constants / immutables
    // ------------------------------------------------------------------
    string public constant name = "Tsukironin";
    string public constant symbol = "TSUKI";

    uint256 public constant MAX_SUPPLY = 6000;
    uint256 public constant MAX_PER_TX = 10;
    uint96  public constant ROYALTY_BPS = 500; // 5%

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    address public owner;
    address public royaltyReceiver;
    address public transferValidator = 0x0000721C310194CcfC01E523fc93C9cCcFa2A0Ac; // Limit Break validator

    bool public mintActive;
    bool public metadataFrozen;

    uint256 public price = 0.0001 ether;
    uint256 public totalSupply;
    string public baseURI = "ipfs://bafybeiaeserjjmy2lxmoxtb7o3gi6224pt7doqdklxeuwhq6hdwu7klyqy/";

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event MetadataFrozen();

    // ------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------
    constructor(address royaltyReceiver_) {
        require(royaltyReceiver_ != address(0), "Zero royalty receiver");
        owner = msg.sender;
        royaltyReceiver = royaltyReceiver_;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ------------------------------------------------------------------
    // Minting
    // ------------------------------------------------------------------
    function mint(uint256 quantity) external payable {
        require(mintActive, "Mint not active");
        require(quantity >= 1 && quantity <= MAX_PER_TX, "1-10 per tx");
        require(totalSupply + quantity <= MAX_SUPPLY, "Exceeds supply");
        require(msg.value == price * quantity, "Wrong ETH amount");

        uint256 startId = totalSupply + 1;
        totalSupply += quantity;
        for (uint256 i = 0; i < quantity; ) {
            _mint(msg.sender, startId + i);
            unchecked { ++i; }
        }
    }

    function ownerMint(address to, uint256 quantity) external onlyOwner {
        require(quantity >= 1, "Zero quantity");
        require(totalSupply + quantity <= MAX_SUPPLY, "Exceeds supply");
        require(to != address(0), "Zero address");

        uint256 startId = totalSupply + 1;
        totalSupply += quantity;
        for (uint256 i = 0; i < quantity; ) {
            _mint(to, startId + i);
            unchecked { ++i; }
        }
    }

    function _mint(address to, uint256 tokenId) internal {
        _owners[tokenId] = to;
        unchecked { _balances[to] += 1; }
        emit Transfer(address(0), to, tokenId);
    }

    // ------------------------------------------------------------------
    // ERC721 core
    // ------------------------------------------------------------------
    function balanceOf(address account) external view returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address o = _owners[tokenId];
        require(o != address(0), "Nonexistent token");
        return o;
    }

    function approve(address to, uint256 tokenId) external {
        address o = ownerOf(tokenId);
        require(msg.sender == o || _operatorApprovals[o][msg.sender], "Not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(o, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "Nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "Self approval");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(to != address(0), "Zero address");
        address o = ownerOf(tokenId);
        require(o == from, "Wrong from");
        require(
            msg.sender == o || msg.sender == _tokenApprovals[tokenId] || _operatorApprovals[o][msg.sender],
            "Not authorized"
        );

        // ERC-721-C: royalty enforcement hook
        if (transferValidator != address(0)) {
            ICreatorTokenTransferValidator(transferValidator).applyCollectionTransferPolicy(msg.sender, from, to);
        }

        delete _tokenApprovals[tokenId];
        unchecked {
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        if (to.code.length > 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) ==
                    IERC721Receiver.onERC721Received.selector,
                "Unsafe recipient"
            );
        }
    }

    // ------------------------------------------------------------------
    // Metadata
    // ------------------------------------------------------------------
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "Nonexistent token");
        return string(abi.encodePacked(baseURI, _toString(tokenId), ".json"));
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        require(!metadataFrozen, "Metadata frozen");
        baseURI = newBaseURI;
    }

    function freezeMetadata() external onlyOwner {
        metadataFrozen = true;
        emit MetadataFrozen();
    }

    // ------------------------------------------------------------------
    // ERC-2981 royalties
    // ------------------------------------------------------------------
    function royaltyInfo(uint256, uint256 salePrice) external view returns (address, uint256) {
        return (royaltyReceiver, (salePrice * ROYALTY_BPS) / 10000);
    }

    function setRoyaltyReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Zero address");
        royaltyReceiver = newReceiver;
    }

    // ------------------------------------------------------------------
    // ERC-721-C validator management
    // ------------------------------------------------------------------
    function getTransferValidator() external view returns (address) {
        return transferValidator;
    }

    function setTransferValidator(address newValidator) external onlyOwner {
        transferValidator = newValidator; // zero address disables enforcement
    }

    // ------------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------------
    event PriceChanged(uint256 newPrice);

    function setMintActive(bool active) external onlyOwner {
        mintActive = active;
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        price = newPrice;
        emit PriceChanged(newPrice);
    }

    function withdraw() external onlyOwner {
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ------------------------------------------------------------------
    // ERC-165
    // ------------------------------------------------------------------
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165
            interfaceId == 0x80ac58cd || // ERC-721
            interfaceId == 0x5b5e139f || // ERC-721 Metadata
            interfaceId == 0x2a55205a;   // ERC-2981
    }

    // ------------------------------------------------------------------
    // Utils
    // ------------------------------------------------------------------
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}