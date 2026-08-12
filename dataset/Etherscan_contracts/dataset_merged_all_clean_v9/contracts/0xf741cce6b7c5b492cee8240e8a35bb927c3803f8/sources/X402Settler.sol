// SPDX-License-Identifier: MIT
/*
CLOAK — X402 SETTLER

The "PAYMENTS: VERIFIED" layer. Bridges an HTTP-402 payment requirement to a
private on-chain settlement. A resource server registers a PaymentRequirement;
the CloakPool reports a settlement (by nullifier, bound to the requirement hash)
once a valid shielded payment lands. The facilitator reads isSettled() to grant
access — learning only that a valid payment for that resource happened.

Scaffold status: settlement bookkeeping is real; the facilitator attestation is
an EIP-712 stub the resource server would check off-chain.
*/
pragma solidity 0.8.24;

contract X402Settler {

    struct PaymentRequirement {
        bytes32 resourceId;    // the gated resource / API route
        address asset;         // payment asset (e.g. USDC)
        uint256 amount;        // required amount
        bytes32 payToMeta;     // recipient stealth meta-address hash
        uint64  expiry;
        bytes32 nonce;
    }

    address public owner;
    address public pool;       // CloakPool, the only settlement reporter
    address public facilitator;

    mapping(bytes32 => PaymentRequirement) public requirements; // hash => req
    mapping(bytes32 => bool) public settled;                     // requirementHash => settled
    mapping(bytes32 => bytes32) public settlementNullifier;      // requirementHash => nullifier

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant GRANT_TYPEHASH =
        keccak256("AccessGrant(bytes32 requirementHash,address agent,uint64 issuedAt)");

    event RequirementRegistered(bytes32 indexed requirementHash, bytes32 indexed resourceId, uint256 amount);
    event Settled(bytes32 indexed requirementHash, bytes32 nullifier);
    event PoolSet(address indexed pool);
    event FacilitatorSet(address indexed facilitator);

    error NotOwner(); error NotPool(); error Expired(); error AlreadySettled(); error Unknown();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier onlyPool()  { if (msg.sender != pool)  revert NotPool();  _; }

    constructor(address _facilitator) {
        owner = msg.sender;
        facilitator = _facilitator;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("CloakX402"), keccak256("1"), block.chainid, address(this)
        ));
    }

    function setPool(address p) external onlyOwner { pool = p; emit PoolSet(p); }
    function setFacilitator(address f) external onlyOwner { facilitator = f; emit FacilitatorSet(f); }
    function transferOwnership(address n) external onlyOwner { require(n != address(0), "zero owner"); owner = n; }

    /// @notice A resource server registers what it charges for a resource.
    function registerRequirement(PaymentRequirement calldata r) external returns (bytes32 requirementHash) {
        requirementHash = keccak256(abi.encode(
            r.resourceId, r.asset, r.amount, r.payToMeta, r.expiry, r.nonce
        ));
        requirements[requirementHash] = r;
        emit RequirementRegistered(requirementHash, r.resourceId, r.amount);
    }

    /// @notice Reported by the CloakPool when a shielded payment bound to this
    ///         requirement settles. Idempotent per requirement.
    function recordSettlement(bytes32 requirementHash, bytes32 nullifier) external onlyPool {
        if (settled[requirementHash]) revert AlreadySettled();
        PaymentRequirement storage r = requirements[requirementHash];
        if (r.expiry != 0 && block.timestamp > r.expiry) revert Expired();
        settled[requirementHash] = true;
        settlementNullifier[requirementHash] = nullifier;
        emit Settled(requirementHash, nullifier);
    }

    function isSettled(bytes32 requirementHash) external view returns (bool) {
        return settled[requirementHash];
    }

    /// @notice EIP-712 digest the facilitator signs to grant resource access.
    function accessGrantDigest(bytes32 requirementHash, address agent, uint64 issuedAt)
        external view returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(GRANT_TYPEHASH, requirementHash, agent, issuedAt));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    /// @notice Verify a facilitator-signed access grant (checked by the server).
    function verifyGrant(bytes32 requirementHash, address agent, uint64 issuedAt, uint8 v, bytes32 r_, bytes32 s)
        external view returns (bool)
    {
        if (!settled[requirementHash]) return false;
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR,
            keccak256(abi.encode(GRANT_TYPEHASH, requirementHash, agent, issuedAt))));
        return ecrecover(digest, v, r_, s) == facilitator;
    }
}