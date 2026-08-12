// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// ============================================================
//  Fraxion Property Passport
//  ERC-1404 Compliant Property Encumbrance Token
//
//  One contract = one property.
//  One token = proof of encumbrance on that property.
//
//  Document-style fields store either:
//    - a SHA-256 hash (bytes32) of an off-chain file, so the
//      file's integrity can be verified on-chain (see
//      verifyDocumentHash() and its per-field wrappers below)
//      without storing the file itself on-chain, or
//    - an Arweave URI pointing to a permanent off-chain copy.
//
//  Transfer of the token is restricted to KYC-whitelisted
//  addresses only. The issuer can forcibly reclaim the token
//  at any time for legal or regulatory reasons.
// ============================================================

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
    function _msgData() internal view virtual returns (bytes calldata) { return msg.data; }
}

// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) { return _name; }
    function symbol() public view virtual override returns (string memory) { return _symbol; }
    function decimals() public view virtual override returns (uint8) { return 18; }
    function totalSupply() public view virtual override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view virtual override returns (uint256) { return _balances[account]; }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, allowance(_msgSender(), spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = allowance(_msgSender(), spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked { _approve(_msgSender(), spender, currentAllowance - subtractedValue); }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        unchecked { _balances[account] += amount; }
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked { _approve(owner, spender, currentAllowance - amount); }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// OpenZeppelin Contracts v4.7.0 (access/Ownable.sol)

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() { _transferOwnership(_msgSender()); }

    modifier onlyOwner() { _checkOwner(); _; }

    function owner() public view virtual returns (address) { return _owner; }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner { _transferOwnership(address(0)); }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// ERC-1404 Interface

abstract contract IERC1404 {
    function detectTransferRestriction(address from, address to, uint256 value) public virtual view returns (uint8);
    function messageForTransferRestriction(uint8 restrictionCode) public virtual view returns (string memory);
}

// ============================================================
//  FraxionPropertyPassport
// ============================================================

contract FraxionPropertyPassport is ERC20, Ownable, IERC1404 {

    // --------------------------------------------------------
    // Enums
    // --------------------------------------------------------
    enum PassportTier       { Notification, Verification }
    enum VerificationStatus { Pending, Verified, Disputed, Revoked }
    enum AlertStatus        { Clean, Flagged, UnderReview }

    // --------------------------------------------------------
    // Constructor input struct
    //
    // Bundled into a struct (rather than individual constructor
    // parameters) to avoid a "stack too deep" compile error, since
    // the property record now spans more than a dozen fields.
    // --------------------------------------------------------
    struct PropertyRecord {
        string  parcelId;                 // county assessor's parcel number (APN)
        string  jurisdictionCode;         // county/state FIPS code (string to preserve leading zeros)
        bytes32 deedToOwnership;          // SHA-256 hash of the deed-to-ownership document
        string  verificationCertificate;  // Arweave URI of the verification certificate
        bytes32 propertyInspections;      // SHA-256 hash of the property inspections document
        bytes32 permitRecords;            // SHA-256 hash of the permit records document
        bytes32 propertyRepairs;          // SHA-256 hash of the property repairs document
        string  encumbranceNotice;        // Arweave URI of the encumbrance notice
        bytes32 documentBundleHash;       // SHA-256 hash of the full document bundle/manifest
        PassportTier passportTier;        // Notification vs Verification product tier
        address encumbranceToken;         // contract address of the sibling encumbrance-rights token (address(0) if not yet deployed)
        bytes32 lienReferenceHash;        // SHA-256 hash of a lien reference doc (bytes32(0) if none at deploy)
    }

    // --------------------------------------------------------
    // KYC / Whitelist State
    // Values are Unix epoch timestamps:
    //   0  = not whitelisted
    //   1  = whitelisted, no time restriction
    //  >1  = whitelisted but locked until that timestamp
    // --------------------------------------------------------
    mapping(address => uint256) private _receiveRestriction;
    mapping(address => uint256) private _sendRestriction;

    // Addresses authorised to manage KYC data
    mapping(address => bool) private _whitelistControlAuthority;

    // --------------------------------------------------------
    // Events
    // --------------------------------------------------------
    event TokenMinted(address indexed account, uint256 amount);
    event TokenBurned(address indexed account, uint256 amount);
    event KYCDataSet(address indexed account, uint256 receiveRestriction, uint256 sendRestriction);

    event ParcelIdReset(string _parcelId);
    event JurisdictionCodeReset(string _jurisdictionCode);
    event DeedToOwnershipReset(bytes32 _deedToOwnership);
    event VerificationCertificateReset(string _verificationCertificate);
    event PropertyInspectionsReset(bytes32 _propertyInspections);
    event PermitRecordsReset(bytes32 _permitRecords);
    event PropertyRepairsReset(bytes32 _propertyRepairs);
    event EncumbranceNoticeReset(string _encumbranceNotice);
    event DocumentBundleHashReset(bytes32 _documentBundleHash);
    event PassportTierReset(PassportTier _passportTier);
    event LienReferenceHashReset(bytes32 _lienReferenceHash);
    event EncumbranceTokenReset(address _encumbranceToken);

    event VerificationStatusUpdated(VerificationStatus status, address verifiedBy, uint64 timestamp);
    event MonitoringUpdated(uint64 timestamp, bytes32 changeEventHash, AlertStatus alertStatus);
    event EncumbranceStatusChanged(bool active);

    event AllowedInvestorsReset(uint64 _allowedInvestors);
    event HoldingPeriodReset(uint64 _tradingHoldingPeriod);
    event WhitelistAuthoritySet(address user);
    event WhitelistAuthorityRemoved(address user);
    event TransferRestrictionDetected(address indexed from, address indexed to, string message, uint8 errorCode);
    event TransferFromExecuted(address indexed spender, address indexed sender, address indexed recipient, uint256 amount);
    event IssuerForceTransfer(address indexed from, address indexed to, uint256 amount);

    // --------------------------------------------------------
    // Branding
    // --------------------------------------------------------
    string public constant version            = "1.0";
    string public constant issuancePlatform   = "Fraxion Property Passport";
    string public constant issuanceProtocol   = "ERC-1404";

    // All *Hash fields on this contract (deedToOwnership, propertyInspections,
    // permitRecords, propertyRepairs, documentBundleHash, lienReferenceHash) are
    // required to be SHA-256 digests. This is documented here for off-chain tooling; use
    // verifyDocumentHash() (or its per-field wrappers below) to confirm a
    // candidate file was actually hashed with SHA-256 and matches on-chain.
    string public constant hashAlgorithm = "SHA-256";

    // --------------------------------------------------------
    // Property Identity & Document Records
    // --------------------------------------------------------
    string  public parcelId;
    string  public jurisdictionCode;

    bytes32 public deedToOwnership;
    string  public verificationCertificate;
    bytes32 public propertyInspections;
    bytes32 public permitRecords;
    bytes32 public propertyRepairs;
    string  public encumbranceNotice;

    bytes32 public documentBundleHash;

    // --------------------------------------------------------
    // Verification & Tier Metadata
    // --------------------------------------------------------
    PassportTier public passportTier;
    VerificationStatus public verificationStatus;
    address public verifiedBy;
    uint64  public verificationTimestamp;

    // --------------------------------------------------------
    // Monitoring & Alerting
    // --------------------------------------------------------
    uint64      public lastMonitoredTimestamp;
    bytes32     public lastChangeEventHash;
    AlertStatus public alertStatus;

    // --------------------------------------------------------
    // Encumbrance & Legal Status
    // --------------------------------------------------------
    bool    public encumbranceActive;

    // Address of the sibling contract/token (deployed alongside this
    // property passport) that represents the right to encumber this
    // property and to push updates via the third-party application.
    // address(0) if that sibling contract hasn't been deployed yet.
    // Placed directly next to encumbranceActive: both describe the
    // encumbrance's current legal standing, and (being a bool + an
    // address, 1 + 20 = 21 bytes) they can share a single storage slot.
    address public encumbranceToken;

    bytes32 public lienReferenceHash;

    // --------------------------------------------------------
    // Investor Cap & Holding Period
    // --------------------------------------------------------
    uint8  private constant ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED = 0;

    // This contract is designed for a single indivisible token (0 decimals, supply = 1).
    // decimals is hardcoded to 0 — no fractional units.
    uint8  private constant TOKEN_DECIMALS = 0;

    uint64 public currentTotalInvestors  = 0;
    uint64 public allowedInvestors;

    // Global hold: investor transfers blocked until this epoch time.
    // Set to 1 at deploy for immediate transferability.
    uint64 public tradingHoldingPeriod   = 1;

    // --------------------------------------------------------
    // Transfer Restriction Codes
    // --------------------------------------------------------
    uint8 private constant NO_TRANSFER_RESTRICTION_FOUND       = 0;
    uint8 private constant MAX_ALLOWED_INVESTORS_EXCEED        = 1;
    uint8 private constant TRANSFERS_DISABLED                  = 2;
    uint8 private constant TRANSFER_VALUE_CANNOT_ZERO          = 3;
    uint8 private constant SENDER_NOT_WHITELISTED_OR_BLOCKED   = 4;
    uint8 private constant RECEIVER_NOT_WHITELISTED_OR_BLOCKED = 5;
    uint8 private constant SENDER_UNDER_HOLDING_PERIOD         = 6;
    uint8 private constant RECEIVER_UNDER_HOLDING_PERIOD       = 7;

    string[] private _messageForTransferRestriction = [
        "No transfer restrictions found",
        "Max allowed token holders is in place; this transfer would exceed the limit",
        "All transfers are disabled because the global holding period has not yet expired",
        "Zero transfer amount not allowed",
        "Sender is not whitelisted or is blocked",
        "Receiver is not whitelisted or is blocked",
        "Sender is whitelisted but is under an individual KYC holding period",
        "Receiver is whitelisted but is under an individual KYC holding period"
    ];

    // --------------------------------------------------------
    // Constructor
    //
    // Deploy one instance of this contract per property.
    // A single token (supply = 1, decimals = 0) is minted to
    // the deployer on construction, representing the encumbrance.
    //
    // _passportId                 : Unique passport ID for this property.
    //                               Stored as the underlying ERC20 "name"
    //                               (see passportId() accessor below).
    // _symbol                     : Ticker,     e.g. "FPP-123MAIN"
    // _allowedInvestors           : Max addresses that can hold the token
    //                               (recommend 1 for single-holder use; 0 = unlimited)
    // _record                     : Bundled property/document fields — see
    //                               the PropertyRecord struct above
    // _tradingHoldingPeriod       : Epoch timestamp before which investor
    //                               transfers are locked (use 1 for immediate)
    //
    // Verification/monitoring fields (verificationStatus, verifiedBy,
    // verificationTimestamp, lastMonitoredTimestamp, lastChangeEventHash,
    // alertStatus) are not constructor inputs — they start at sensible
    // defaults (Pending / Clean / zero) and are populated later via their
    // dedicated setter functions as verification and monitoring actually
    // happen.
    // --------------------------------------------------------
    constructor(
        string memory _passportId,
        string memory _symbol,
        uint64  _allowedInvestors,
        PropertyRecord memory _record,
        uint64  _tradingHoldingPeriod
    ) ERC20(_passportId, _symbol) {
        address deployer = msg.sender;

        tradingHoldingPeriod = _tradingHoldingPeriod;
        allowedInvestors     = _allowedInvestors;

        // Pre-whitelist deployer (epoch 1 = no restriction)
        _receiveRestriction[deployer] = 1;
        _sendRestriction[deployer]    = 1;

        // Deployer is a whitelist authority by default
        _whitelistControlAuthority[deployer] = true;

        parcelId          = _record.parcelId;
        jurisdictionCode  = _record.jurisdictionCode;

        deedToOwnership         = _record.deedToOwnership;
        verificationCertificate = _record.verificationCertificate;
        propertyInspections     = _record.propertyInspections;
        permitRecords           = _record.permitRecords;
        propertyRepairs         = _record.propertyRepairs;
        encumbranceNotice       = _record.encumbranceNotice;

        documentBundleHash = _record.documentBundleHash;

        passportTier      = _record.passportTier;
        encumbranceToken  = _record.encumbranceToken;
        lienReferenceHash = _record.lienReferenceHash;

        // Verification/monitoring defaults — updated later via
        // updateVerificationStatus() / recordMonitoringUpdate()
        verificationStatus = VerificationStatus.Pending;
        alertStatus         = AlertStatus.Clean;

        // The encumbrance recorded by this token is active from the
        // moment the passport is issued; flip to false once discharged.
        encumbranceActive = true;

        // Mint exactly 1 token to the deployer
        _mint(deployer, 1);
        emit TokenMinted(deployer, 1);
    }

    // --------------------------------------------------------
    // Passport ID — unique identifier for this property.
    // Stored via the underlying ERC20 "name" slot rather than a
    // duplicate variable, so there is a single source of truth.
    // --------------------------------------------------------
    function passportId() external view returns (string memory) {
        return name();
    }

    // --------------------------------------------------------
    // Decimals override — always 0 (indivisible token)
    // --------------------------------------------------------
    function decimals() public view virtual override returns (uint8) {
        return TOKEN_DECIMALS;
    }

    // --------------------------------------------------------
    // Modifiers
    // --------------------------------------------------------
    modifier onlyWhitelistControlAuthority() {
        require(_whitelistControlAuthority[msg.sender] == true, "Only authorised addresses can manage KYC whitelisting");
        _;
    }

    modifier notRestricted(address from, address to, uint256 value) {
        uint8 restrictionCode = detectTransferRestriction(from, to, value);
        if (restrictionCode != NO_TRANSFER_RESTRICTION_FOUND) {
            string memory errorMessage = messageForTransferRestriction(restrictionCode);
            emit TransferRestrictionDetected(from, to, errorMessage, restrictionCode);
            revert(errorMessage);
        } else {
            _;
        }
    }

    // --------------------------------------------------------
    // Mint & Burn (owner only)
    // These are kept for administrative flexibility but normal
    // usage is a fixed supply of 1 token per property.
    // --------------------------------------------------------
    function mint(address account, uint256 amount)
        external
        onlyOwner
        returns (bool)
    {
        require(account != address(0), "Mint address cannot be zero");
        require(_receiveRestriction[account] != 0, "Address is not whitelisted");
        require(amount > 0, "Cannot mint zero tokens");

        if (
            account != Ownable.owner() &&
            ERC20.balanceOf(account) == 0 &&
            allowedInvestors != ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED &&
            (currentTotalInvestors + 1) > allowedInvestors
        ) {
            revert("Minting would exceed the maximum allowed token holders");
        }

        if (ERC20.balanceOf(account) == 0 && account != Ownable.owner()) {
            currentTotalInvestors += 1;
        }

        ERC20._mint(account, amount);
        emit TokenMinted(account, amount);
        return true;
    }

    function burn(address account, uint256 amount)
        external
        onlyOwner
        returns (bool)
    {
        require(account != address(0), "Burn address cannot be zero");
        require(amount > 0, "Cannot burn zero tokens");

        ERC20._burn(account, amount);

        if (ERC20.balanceOf(account) == 0 && account != Ownable.owner()) {
            currentTotalInvestors -= 1;
        }

        emit TokenBurned(account, amount);
        return true;
    }

    // --------------------------------------------------------
    // Property Identity & Document Management (owner only)
    // --------------------------------------------------------
    function resetParcelId(string calldata _parcelId) external onlyOwner {
        parcelId = _parcelId;
        emit ParcelIdReset(_parcelId);
    }

    function resetJurisdictionCode(string calldata _jurisdictionCode) external onlyOwner {
        jurisdictionCode = _jurisdictionCode;
        emit JurisdictionCodeReset(_jurisdictionCode);
    }

    function resetDeedToOwnership(bytes32 _deedToOwnership)
        external onlyOwner
    {
        deedToOwnership = _deedToOwnership;
        emit DeedToOwnershipReset(_deedToOwnership);
    }

    function resetVerificationCertificate(string calldata _verificationCertificate)
        external onlyOwner
    {
        verificationCertificate = _verificationCertificate;
        emit VerificationCertificateReset(_verificationCertificate);
    }

    function resetPropertyInspections(bytes32 _propertyInspections)
        external onlyOwner
    {
        propertyInspections = _propertyInspections;
        emit PropertyInspectionsReset(_propertyInspections);
    }

    function resetPermitRecords(bytes32 _permitRecords)
        external onlyOwner
    {
        permitRecords = _permitRecords;
        emit PermitRecordsReset(_permitRecords);
    }

    function resetPropertyRepairs(bytes32 _propertyRepairs)
        external onlyOwner
    {
        propertyRepairs = _propertyRepairs;
        emit PropertyRepairsReset(_propertyRepairs);
    }

    /// @notice Update the Arweave URI for the encumbrance notice document.
    function resetEncumbranceNotice(string calldata _encumbranceNotice)
        external onlyOwner
    {
        encumbranceNotice = _encumbranceNotice;
        emit EncumbranceNoticeReset(_encumbranceNotice);
    }

    function resetDocumentBundleHash(bytes32 _documentBundleHash) external onlyOwner {
        documentBundleHash = _documentBundleHash;
        emit DocumentBundleHashReset(_documentBundleHash);
    }

    function resetPassportTier(PassportTier _passportTier) external onlyOwner {
        passportTier = _passportTier;
        emit PassportTierReset(_passportTier);
    }

    function resetLienReferenceHash(bytes32 _lienReferenceHash) external onlyOwner {
        lienReferenceHash = _lienReferenceHash;
        emit LienReferenceHashReset(_lienReferenceHash);
    }

    /// @notice Set or update the sibling encumbrance-rights token/contract address.
    ///         Use this once the paired contract is deployed, if it wasn't known
    ///         yet at the time this property passport was deployed.
    function resetEncumbranceToken(address _encumbranceToken) external onlyOwner {
        encumbranceToken = _encumbranceToken;
        emit EncumbranceTokenReset(_encumbranceToken);
    }

    // --------------------------------------------------------
    // Document Hash Verification
    //
    // Every *Hash field on this contract is required to be a
    // SHA-256 digest (see hashAlgorithm above). These functions
    // let anyone confirm that a candidate file matches the
    // stored hash by recomputing SHA-256 on-chain (via Solidity's
    // built-in sha256() precompile) and comparing it. If the
    // stored value was not actually produced with SHA-256 (e.g.
    // someone submitted an MD5 hash instead), the check will
    // simply never return true.
    //
    // These are read-only (view) functions — call them off-chain
    // as an eth_call rather than a transaction, so verification
    // costs no gas.
    // --------------------------------------------------------
    function verifyDocumentHash(bytes calldata fileData, bytes32 expectedHash) public pure returns (bool) {
        return sha256(fileData) == expectedHash;
    }

    function verifyDeedToOwnership(bytes calldata fileData) external view returns (bool) {
        return verifyDocumentHash(fileData, deedToOwnership);
    }

    function verifyPropertyInspections(bytes calldata fileData) external view returns (bool) {
        return verifyDocumentHash(fileData, propertyInspections);
    }

    function verifyPermitRecords(bytes calldata fileData) external view returns (bool) {
        return verifyDocumentHash(fileData, permitRecords);
    }

    function verifyPropertyRepairs(bytes calldata fileData) external view returns (bool) {
        return verifyDocumentHash(fileData, propertyRepairs);
    }

    function verifyDocumentBundleHash(bytes calldata fileData) external view returns (bool) {
        return verifyDocumentHash(fileData, documentBundleHash);
    }

    function verifyLienReferenceHash(bytes calldata fileData) external view returns (bool) {
        return verifyDocumentHash(fileData, lienReferenceHash);
    }

    // --------------------------------------------------------
    // Verification & Monitoring Management (owner only)
    // --------------------------------------------------------

    /// @notice Record the outcome of a verification pass.
    /// @param _status     New verification status
    /// @param _verifiedBy Address of the agent/notary/institution that performed the verification
    function updateVerificationStatus(VerificationStatus _status, address _verifiedBy)
        external onlyOwner
    {
        verificationStatus     = _status;
        verifiedBy             = _verifiedBy;
        verificationTimestamp  = uint64(block.timestamp);
        emit VerificationStatusUpdated(_status, _verifiedBy, uint64(block.timestamp));
    }

    /// @notice Record the result of a monitoring check.
    /// @param _changeEventHash Hash of the off-chain change-event record, kept off-chain (bytes32(0) if unchanged)
    /// @param _alertStatus     Resulting alert status
    function recordMonitoringUpdate(bytes32 _changeEventHash, AlertStatus _alertStatus)
        external onlyOwner
    {
        lastMonitoredTimestamp = uint64(block.timestamp);
        lastChangeEventHash    = _changeEventHash;
        alertStatus            = _alertStatus;
        emit MonitoringUpdated(uint64(block.timestamp), _changeEventHash, _alertStatus);
    }

    /// @notice Allows either the owner (manual/administrative override) or the linked
    ///         encumbrance-rights token contract (automatic, when that token is retired)
    ///         to flip the encumbrance status on this property passport.
    modifier onlyOwnerOrEncumbranceToken() {
        require(
            _msgSender() == owner() ||
            (encumbranceToken != address(0) && _msgSender() == encumbranceToken),
            "Caller is not the owner or the linked encumbrance token"
        );
        _;
    }

    /// @notice Flip whether the encumbrance recorded by this token is active.
    ///         Set to false once the encumbrance has been legally discharged/released.
    ///         Callable by the owner directly, or automatically by the paired
    ///         encumbrance-rights token contract when its token is retired/satisfied.
    function setEncumbranceActive(bool _active) external onlyOwnerOrEncumbranceToken {
        encumbranceActive = _active;
        emit EncumbranceStatusChanged(_active);
    }

    // --------------------------------------------------------
    // Investor Cap & Holding Period (owner only)
    // --------------------------------------------------------
    function resetAllowedInvestors(uint64 _allowedInvestors) external onlyOwner {
        if (
            _allowedInvestors != ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED &&
            _allowedInvestors < currentTotalInvestors
        ) {
            revert("New limit cannot be less than current number of token holders");
        }
        allowedInvestors = _allowedInvestors;
        emit AllowedInvestorsReset(_allowedInvestors);
    }

    function setTradingHoldingPeriod(uint64 _tradingHoldingPeriod) external onlyOwner {
        tradingHoldingPeriod = _tradingHoldingPeriod;
        emit HoldingPeriodReset(_tradingHoldingPeriod);
    }

    // --------------------------------------------------------
    // Whitelist Authority Management (owner only)
    // --------------------------------------------------------
    function setWhitelistAuthorityStatus(address user) external onlyOwner {
        _whitelistControlAuthority[user] = true;
        emit WhitelistAuthoritySet(user);
    }

    function removeWhitelistAuthorityStatus(address user) external onlyOwner {
        delete _whitelistControlAuthority[user];
        emit WhitelistAuthorityRemoved(user);
    }

    function getWhitelistAuthorityStatus(address user) external view returns (bool) {
        return _whitelistControlAuthority[user];
    }

    // --------------------------------------------------------
    // KYC Data Management (whitelist authority)
    // --------------------------------------------------------

    /// @notice Whitelist a single address
    /// @param account           Wallet to whitelist
    /// @param receiveRestriction Epoch time after which address can receive (1 = immediately)
    /// @param sendRestriction    Epoch time after which address can send    (1 = immediately)
    function modifyKYCData(
        address account,
        uint256 receiveRestriction,
        uint256 sendRestriction
    ) external onlyWhitelistControlAuthority {
        _setupKYCDataForUser(account, receiveRestriction, sendRestriction);
    }

    /// @notice Whitelist up to 50 addresses in a single transaction
    function bulkWhitelistWallets(
        address[] calldata account,
        uint256 receiveRestriction,
        uint256 sendRestriction
    ) external onlyWhitelistControlAuthority {
        require(account.length <= 50, "Bulk whitelisting is limited to 50 addresses per call");
        for (uint i = 0; i < account.length; i++) {
            _setupKYCDataForUser(account[i], receiveRestriction, sendRestriction);
        }
    }

    function _setupKYCDataForUser(
        address account,
        uint256 receiveRestriction,
        uint256 sendRestriction
    ) internal {
        _receiveRestriction[account] = receiveRestriction;
        _sendRestriction[account]    = sendRestriction;
        emit KYCDataSet(account, receiveRestriction, sendRestriction);
    }

    function getKYCData(address user) external view returns (uint256, uint256) {
        return (_receiveRestriction[user], _sendRestriction[user]);
    }

    // --------------------------------------------------------
    // ERC-1404: Transfer Restriction Logic
    // --------------------------------------------------------
    function detectTransferRestriction(address _from, address _to, uint256 value)
        public
        view
        override
        returns (uint8)
    {
        if (block.timestamp < tradingHoldingPeriod && _from != Ownable.owner()) {
            return TRANSFERS_DISABLED;
        }
        if (value < 1) {
            return TRANSFER_VALUE_CANNOT_ZERO;
        }
        if (_sendRestriction[_from] == 0) {
            return SENDER_NOT_WHITELISTED_OR_BLOCKED;
        }
        if (_receiveRestriction[_to] == 0) {
            return RECEIVER_NOT_WHITELISTED_OR_BLOCKED;
        }
        if (_sendRestriction[_from] > block.timestamp) {
            return SENDER_UNDER_HOLDING_PERIOD;
        }
        if (_receiveRestriction[_to] > block.timestamp) {
            return RECEIVER_UNDER_HOLDING_PERIOD;
        }
        if (allowedInvestors == ANY_NUMBER_OF_TOKEN_HOLDERS_ALLOWED) {
            return NO_TRANSFER_RESTRICTION_FOUND;
        } else {
            if (ERC20.balanceOf(_to) > 0 || _to == Ownable.owner()) {
                return NO_TRANSFER_RESTRICTION_FOUND;
            } else {
                if (currentTotalInvestors < allowedInvestors) {
                    return NO_TRANSFER_RESTRICTION_FOUND;
                } else {
                    if (ERC20.balanceOf(_from) == value && _from != Ownable.owner()) {
                        return NO_TRANSFER_RESTRICTION_FOUND;
                    } else {
                        return MAX_ALLOWED_INVESTORS_EXCEED;
                    }
                }
            }
        }
    }

    function messageForTransferRestriction(uint8 restrictionCode)
        public
        view
        override
        returns (string memory)
    {
        if (restrictionCode <= (_messageForTransferRestriction.length - 1)) {
            return _messageForTransferRestriction[restrictionCode];
        } else {
            return "Error code is not defined";
        }
    }

    // --------------------------------------------------------
    // Transfer Functions
    // --------------------------------------------------------
    function transfer(address recipient, uint256 amount)
        public
        override
        notRestricted(msg.sender, recipient, amount)
        returns (bool)
    {
        _transferToken(msg.sender, recipient, amount, true);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override
        notRestricted(sender, recipient, amount)
        returns (bool)
    {
        _transferToken(sender, recipient, amount, false);
        emit TransferFromExecuted(msg.sender, sender, recipient, amount);
        return true;
    }

    /// @notice Issuer can forcibly reclaim the token from any address.
    ///         Use for legal recovery, regulatory requirement, or breach of terms.
    ///         This bypasses all KYC/whitelist restrictions by design.
    function forceTransferToken(address from, uint256 amount)
        external
        onlyOwner
        returns (bool)
    {
        _transferToken(from, Ownable.owner(), amount, true);
        emit IssuerForceTransfer(from, Ownable.owner(), amount);
        return true;
    }

    /// @dev Moves token and maintains the currentTotalInvestors counter
    function _transferToken(
        address sender,
        address recipient,
        uint256 amount,
        bool simpleTransfer
    ) internal {
        if (ERC20.balanceOf(recipient) == 0 && recipient != Ownable.owner()) {
            currentTotalInvestors += 1;
        }

        if (simpleTransfer) {
            ERC20._transfer(sender, recipient, amount);
        } else {
            ERC20.transferFrom(sender, recipient, amount);
        }

        if (ERC20.balanceOf(sender) == 0 && sender != Ownable.owner()) {
            currentTotalInvestors -= 1;
        }
    }
}