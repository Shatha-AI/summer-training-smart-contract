// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 ██████╗ ██╗████████╗██╗███████╗███████╗███╗   ██╗
 ██╔══██╗██║╚══██╔══╝██║╚════██║██╔════╝████╗  ██║
 ██████╔╝██║   ██║   ██║    ██╔╝█████╗  ██╔██╗ ██║
 ██╔══██╗██║   ██║   ██║   ██╔╝ ██╔══╝  ██║╚██╗██║
 ██████╔╝██║   ██║   ██║   ██║  ███████╗██║ ╚████║
 ╚═════╝ ╚═╝   ╚═╝   ╚═╝   ╚═╝  ╚══════╝╚═╝  ╚═══╝
 6666 unique pixel art Bitizens — living on-chain.

 COMPILER SETTINGS (Remix):
   Compiler  : 0.8.24
   Optimizer : ON, runs 200
   viaIR     : ON (Advanced Configurations)

 CONSTRUCTOR ARG:
   "ipfs://bafybeiewewkosbmc46hxpzaaaupzcnenwazdh6bt7vwdunspgmo7mwcnp4/"
*/

// ─── Interfaces ──────────────────────────────────────────────────────────────

interface IERC165 {
    function supportsInterface(bytes4 id) external view returns (bool);
}
interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
interface IERC2981 is IERC165 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256);
}

// ─── ERC-721-C interfaces (Limit Break's on-chain validator) ─────────────────
interface ICreatorToken {
    event TransferValidatorUpdated(address oldValidator, address newValidator);
    function getTransferValidator() external view returns (address);
    function getTransferValidationFunction() external view returns (bytes4, bool);
    function setTransferValidator(address validator) external;
}
interface ITransferValidator {
    function validateTransfer(address caller, address from, address to, uint256 tokenId) external view;
}

// Limit Break's deployed transfer validator on Ethereum mainnet
address constant DEFAULT_TRANSFER_VALIDATOR = 0x0000721C310194CcfC01E523fc93C9cCcFa2A0Ac;

// ─── Ownable ─────────────────────────────────────────────────────────────────

abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _owner = msg.sender; emit OwnershipTransferred(address(0), _owner); }
    modifier onlyOwner() { require(_owner == msg.sender, "Not owner"); _; }
    function owner() public view returns (address) { return _owner; }
    function transferOwnership(address n) external onlyOwner {
        require(n != address(0)); emit OwnershipTransferred(_owner, n); _owner = n;
    }
    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(_owner, address(0)); _owner = address(0);
    }
}

// ─── ReentrancyGuard ─────────────────────────────────────────────────────────

abstract contract ReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() { require(_status == 1, "Reentrant"); _status = 2; _; _status = 1; }
}

// ─── Minimal ERC-721 with ERC-721-C hook ─────────────────────────────────────

abstract contract ERC721C is Ownable, IERC721Metadata {
    string private _name;
    string private _symbol;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _opApprovals;

    constructor(string memory n, string memory s) { _name = n; _symbol = s; }

    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return id == type(IERC721).interfaceId ||
               id == type(IERC721Metadata).interfaceId ||
               id == type(IERC165).interfaceId;
    }
    function name()   public view override returns (string memory) { return _name; }
    function symbol() public view override returns (string memory) { return _symbol; }

    function balanceOf(address o) public view override returns (uint256) {
        require(o != address(0)); return _balances[o];
    }
    function ownerOf(uint256 id) public view override returns (address) {
        address o = _owners[id]; require(o != address(0), "Not minted"); return o;
    }
    function getApproved(uint256 id)                         public view override returns (address) { return _tokenApprovals[id]; }
    function isApprovedForAll(address o, address op)         public view override returns (bool)    { return _opApprovals[o][op]; }

    function approve(address to, uint256 id) public override {
        address o = ownerOf(id);
        require(msg.sender == o || isApprovedForAll(o, msg.sender), "Not auth");
        _tokenApprovals[id] = to;
        emit Approval(o, to, id);
    }
    function setApprovalForAll(address op, bool v) public override {
        require(op != msg.sender);
        _opApprovals[msg.sender][op] = v;
        emit ApprovalForAll(msg.sender, op, v);
    }
    function transferFrom(address f, address t, uint256 id) public override {
        require(_isApprovedOrOwner(msg.sender, id));
        _transfer(f, t, id);
    }
    function safeTransferFrom(address f, address t, uint256 id) public override { safeTransferFrom(f, t, id, ""); }
    function safeTransferFrom(address f, address t, uint256 id, bytes memory d) public override {
        require(_isApprovedOrOwner(msg.sender, id));
        _transfer(f, t, id);
        require(_checkReceived(f, t, id, d));
    }

    function _isApprovedOrOwner(address s, uint256 id) internal view returns (bool) {
        address o = ownerOf(id);
        return s == o || getApproved(id) == s || isApprovedForAll(o, s);
    }

    // Hook overridden by Bitizen to add trading-lock + ERC-721-C validation
    function _validateBeforeTransfer(address from, address to, uint256 tokenId) internal view virtual {}

    function _transfer(address f, address t, uint256 id) internal {
        require(ownerOf(id) == f, "Wrong owner");
        require(t != address(0), "Zero address");
        _validateBeforeTransfer(f, t, id);
        delete _tokenApprovals[id];
        unchecked { _balances[f]--; _balances[t]++; }
        _owners[id] = t;
        emit Transfer(f, t, id);
    }

    function _safeMint(address to, uint256 id) internal {
        require(to != address(0));
        require(_owners[id] == address(0), "Exists");
        unchecked { _balances[to]++; }
        _owners[id] = to;
        emit Transfer(address(0), to, id);
        require(_checkReceived(address(0), to, id, ""));
    }

    function _checkReceived(address f, address t, uint256 id, bytes memory d) private returns (bool) {
        if (t.code.length == 0) return true;
        try IERC721Receiver(t).onERC721Received(msg.sender, f, id, d) returns (bytes4 r) {
            return r == IERC721Receiver.onERC721Received.selector;
        } catch { return false; }
    }
}

// ─── Bitizen ─────────────────────────────────────────────────────────────────

/**
 * @title  Bitizen
 * @notice 6666 pixel-art NFTs.
 *         • Tokens 1–3333   → free mint  (3 per wallet)
 *         • Tokens 3334–6666 → paid mint (0.0001 ETH, 10 per wallet)
 *         • ERC-721-C: royalty enforcement via Limit Break's transfer validator
 *         • ERC-2981: on-chain royalty standard (5%)
 *         • Trading locked until sold out
 */
contract Bitizen is ERC721C, IERC2981, ICreatorToken, ReentrancyGuard {

    // ── Custom errors ─────────────────────────────────────────────────────────
    error ZeroQuantity();
    error ExceedsTotalSupply();
    error ExceedsFreeSupply();
    error ExceedsPaidSupply();
    error ExceedsFreeWalletLimit();
    error ExceedsPaidWalletLimit();
    error InsufficientPayment();
    error RefundFailed();
    error WithdrawFailed();
    error MintingPaused();
    error TradingLocked();
    error AlreadyUnlocked();
    error ZeroAddress();
    error NothingToWithdraw();

    // ── Constants ─────────────────────────────────────────────────────────────
    uint256 public constant TOTAL_SUPPLY        = 6_666;
    uint256 public constant FREE_SUPPLY         = 3_333;
    uint256 public constant PAID_SUPPLY         = 3_333;
    uint8   public constant MAX_FREE_PER_WALLET = 3;
    uint8   public constant MAX_PAID_PER_WALLET = 10;
    uint96  public constant ROYALTY_BPS         = 500;   // 5%
    address public constant ROYALTY_RECIPIENT   = 0x5d89bCDA3471A87A48ec2AceeF569bC21B7E7A11;

    // ── Storage — packed into one 32-byte slot ────────────────────────────────
    //    mintPrice(96) | totalMinted(16) | mintPaused(8) | tradingLocked(8)
    uint96  public mintPrice     = 0.0001 ether;
    uint16  public totalMinted;
    bool    public mintPaused    = false;
    bool    public tradingLocked = true;

    // ── ERC-721-C validator ───────────────────────────────────────────────────
    address private _transferValidator = DEFAULT_TRANSFER_VALIDATOR;

    // ── Metadata + mint tracking ──────────────────────────────────────────────
    string  private _baseTokenURI;
    mapping(address => uint8) public freeMintedBy;
    mapping(address => uint8) public paidMintedBy;

    // ── Events ────────────────────────────────────────────────────────────────
    event FreeMint(address indexed minter, uint256 qty, uint256 startId);
    event PaidMint(address indexed minter, uint256 qty, uint256 startId);
    event MintPriceUpdated(uint96 oldPrice, uint96 newPrice);
    event MintPauseToggled(bool paused);
    event TradingUnlocked();
    event BaseURIUpdated(string newURI);
    event Withdrawn(address to, uint256 amount);

    // ── Constructor ───────────────────────────────────────────────────────────
    constructor() ERC721C("Bitizen", "BIT") {
        _baseTokenURI = "ipfs://bafybeiewewkosbmc46hxpzaaaupzcnenwazdh6bt7vwdunspgmo7mwcnp4/";
        emit TransferValidatorUpdated(address(0), DEFAULT_TRANSFER_VALIDATOR);
    }

    // ── Free mint (tokens 1–3333) ─────────────────────────────────────────────
    function freeMint(uint256 qty) external nonReentrant {
        uint16 minted_ = totalMinted;
        if (mintPaused)                           revert MintingPaused();
        if (qty == 0)                             revert ZeroQuantity();
        if (minted_ + qty > TOTAL_SUPPLY)         revert ExceedsTotalSupply();

        uint256 freeSoFar = minted_ < FREE_SUPPLY ? minted_ : FREE_SUPPLY;
        if (freeSoFar + qty > FREE_SUPPLY)        revert ExceedsFreeSupply();

        uint8 used = freeMintedBy[msg.sender];
        if (used + qty > MAX_FREE_PER_WALLET)     revert ExceedsFreeWalletLimit();

        unchecked { freeMintedBy[msg.sender] = used + uint8(qty); }
        uint256 startId = minted_ + 1;
        _mintBatch(msg.sender, qty, minted_);
        emit FreeMint(msg.sender, qty, startId);
        _checkSoldOut();
    }

    // ── Paid mint (tokens 3334–6666) ──────────────────────────────────────────
    function mint(uint256 qty) external payable nonReentrant {
        uint16 minted_ = totalMinted;
        uint96 price_  = mintPrice;
        if (mintPaused)                           revert MintingPaused();
        if (qty == 0)                             revert ZeroQuantity();
        if (minted_ + qty > TOTAL_SUPPLY)         revert ExceedsTotalSupply();

        uint256 paidSoFar = minted_ > FREE_SUPPLY ? minted_ - FREE_SUPPLY : 0;
        if (paidSoFar + qty > PAID_SUPPLY)        revert ExceedsPaidSupply();

        uint8 used = paidMintedBy[msg.sender];
        if (used + qty > MAX_PAID_PER_WALLET)     revert ExceedsPaidWalletLimit();

        uint256 cost;
        unchecked { cost = uint256(price_) * qty; }
        if (msg.value < cost)                     revert InsufficientPayment();

        unchecked { paidMintedBy[msg.sender] = used + uint8(qty); }
        uint256 startId = minted_ + 1;
        _mintBatch(msg.sender, qty, minted_);

        unchecked {
            uint256 over = msg.value - cost;
            if (over > 0) {
                (bool ok,) = payable(msg.sender).call{value: over}("");
                if (!ok) revert RefundFailed();
            }
        }
        emit PaidMint(msg.sender, qty, startId);
        _checkSoldOut();
    }

    // ── Owner mint (no cap) ───────────────────────────────────────────────────
    function ownerMint(address to, uint256 qty) external onlyOwner {
        if (to == address(0))             revert ZeroAddress();
        if (qty == 0)                     revert ZeroQuantity();
        uint16 minted_ = totalMinted;
        if (minted_ + qty > TOTAL_SUPPLY) revert ExceedsTotalSupply();
        _mintBatch(to, qty, minted_);
        _checkSoldOut();
    }

    // ── Internal helpers ──────────────────────────────────────────────────────
    function _mintBatch(address to, uint256 qty, uint16 startAt) internal {
        unchecked {
            for (uint256 i = 0; i < qty; ++i) {
                _safeMint(to, startAt + i + 1);
            }
            totalMinted = startAt + uint16(qty);
        }
    }

    function _checkSoldOut() internal {
        if (tradingLocked && totalMinted == TOTAL_SUPPLY) {
            tradingLocked = false;
            emit TradingUnlocked();
        }
    }

    // ── ERC-721-C + trading lock ──────────────────────────────────────────────
    function _validateBeforeTransfer(address from, address to, uint256 tokenId)
        internal view override
    {
        // Block all transfers while trading is locked
        // Owner is always exempt (needed for ownerMint airdrops)
        if (from != address(0) && msg.sender != owner()) {
            if (tradingLocked) revert TradingLocked();
        }
        // ERC-721-C validator call (enforces royalties on supported marketplaces)
        if (_transferValidator != address(0) && _transferValidator.code.length > 0) {
            ITransferValidator(_transferValidator).validateTransfer(msg.sender, from, to, tokenId);
        }
    }

    // ── ICreatorToken (ERC-721-C) ─────────────────────────────────────────────
    function getTransferValidator() external view override returns (address) {
        return _transferValidator;
    }
    function setTransferValidator(address v) external override onlyOwner {
        emit TransferValidatorUpdated(_transferValidator, v);
        _transferValidator = v;
    }
    function getTransferValidationFunction() external pure override returns (bytes4, bool) {
        return (0xcaee23ea, true);
    }

    // ── ERC-2981 ──────────────────────────────────────────────────────────────
    function royaltyInfo(uint256, uint256 salePrice)
        external pure override returns (address, uint256)
    {
        return (ROYALTY_RECIPIENT, salePrice * ROYALTY_BPS / 10_000);
    }

    // ── supportsInterface ─────────────────────────────────────────────────────
    function supportsInterface(bytes4 id)
        public view override(ERC721C, IERC165) returns (bool)
    {
        return id == type(IERC2981).interfaceId ||
               id == type(ICreatorToken).interfaceId ||
               super.supportsInterface(id);
    }

    // ── Metadata ──────────────────────────────────────────────────────────────
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_owners(tokenId) != address(0), "Not minted");
        return string(abi.encodePacked(_baseTokenURI, _uint2str(tokenId)));
    }

    // workaround: access internal _owners via ownerOf
    function _owners(uint256 id) private view returns (address) {
        try this.ownerOf(id) returns (address o) { return o; } catch { return address(0); }
    }

    function _uint2str(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 temp = v; uint256 len;
        unchecked { while (temp != 0) { ++len; temp /= 10; } }
        bytes memory buf = new bytes(len);
        unchecked { while (v != 0) { buf[--len] = bytes1(uint8(48 + v % 10)); v /= 10; } }
        return string(buf);
    }

    // ── Owner controls ────────────────────────────────────────────────────────
    function setMintPrice(uint96 newPrice) external onlyOwner {
        uint96 old = mintPrice; mintPrice = newPrice;
        emit MintPriceUpdated(old, newPrice);
    }
    function setMintPaused(bool paused) external onlyOwner {
        mintPaused = paused; emit MintPauseToggled(paused);
    }
    function setBaseURI(string calldata newURI) external onlyOwner {
        _baseTokenURI = newURI; emit BaseURIUpdated(newURI);
    }
    function withdraw() external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToWithdraw();
        (bool ok,) = payable(owner()).call{value: bal}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(owner(), bal);
    }
    function unlockTrading() external onlyOwner {
        if (!tradingLocked) revert AlreadyUnlocked();
        tradingLocked = false; emit TradingUnlocked();
    }

    // ── View helpers ──────────────────────────────────────────────────────────
    function isSoldOut() external view returns (bool) { return totalMinted == TOTAL_SUPPLY; }
    function remainingFreeSupply() external view returns (uint256) {
        uint16 m = totalMinted;
        uint256 used = m < FREE_SUPPLY ? m : FREE_SUPPLY;
        unchecked { return FREE_SUPPLY - used; }
    }
    function remainingPaidSupply() external view returns (uint256) {
        uint16 m = totalMinted;
        uint256 used = m > FREE_SUPPLY ? m - FREE_SUPPLY : 0;
        unchecked { return PAID_SUPPLY - (used > PAID_SUPPLY ? PAID_SUPPLY : used); }
    }
    function remainingFreeForWallet(address wallet) external view returns (uint256) {
        uint8 used = freeMintedBy[wallet];
        unchecked { return used >= MAX_FREE_PER_WALLET ? 0 : MAX_FREE_PER_WALLET - used; }
    }
    function remainingPaidForWallet(address wallet) external view returns (uint256) {
        uint8 used = paidMintedBy[wallet];
        unchecked { return used >= MAX_PAID_PER_WALLET ? 0 : MAX_PAID_PER_WALLET - used; }
    }

    receive() external payable {}
}