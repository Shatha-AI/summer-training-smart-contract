// SPDX-License-Identifier: MIT

/*
    METAL — ComplianceRegistry
    Programmable on-chain compliance and identification for institutional-grade
    settlement. Provably-executed allow/deny lists with jurisdiction tagging.

    Website:  https://metalntwx.com/
    Twitter:  https://x.com/metalntwx
*/

pragma solidity 0.8.26;

contract ComplianceRegistry {
    address public owner;
    mapping(address => bool) public isVerifier;

    struct Identity {
        bool verified;       // passed KYC / institutional onboarding
        bool frozen;         // sanctioned / suspended
        uint16 jurisdiction; // ISO-3166 numeric country code
        uint64 verifiedAt;
    }

    mapping(address => Identity) public identities;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event VerifierSet(address indexed verifier, bool enabled);
    event IdentityUpdated(address indexed account, bool verified, bool frozen, uint16 jurisdiction);

    error NotAuthorized();

    constructor(address owner_) {
        owner = owner_;
        isVerifier[owner_] = true;
        emit OwnershipTransferred(address(0), owner_);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyVerifier() {
        if (!isVerifier[msg.sender]) revert NotAuthorized();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setVerifier(address verifier, bool enabled) external onlyOwner {
        isVerifier[verifier] = enabled;
        emit VerifierSet(verifier, enabled);
    }

    function setIdentity(address account, bool verified, bool frozen, uint16 jurisdiction)
        external
        onlyVerifier
    {
        identities[account] = Identity({
            verified: verified,
            frozen: frozen,
            jurisdiction: jurisdiction,
            verifiedAt: uint64(block.timestamp)
        });
        emit IdentityUpdated(account, verified, frozen, jurisdiction);
    }

    /// @notice Returns true if both parties may participate in a settlement.
    function canSettle(address a, address b) external view returns (bool) {
        Identity storage ia = identities[a];
        Identity storage ib = identities[b];
        return ia.verified && ib.verified && !ia.frozen && !ib.frozen;
    }
}
