// SPDX-License-Identifier: MIT

/*
    METAL — TokenizedAssetRegistry
    The canonical registry for tokenized financial products settling on Metal:
    bank deposits, money markets, T-bills, equities, and securities.

    Website:  https://metalntwx.com/
    Twitter:  https://x.com/metalntwx
*/

pragma solidity 0.8.26;

contract TokenizedAssetRegistry {
    address public owner;

    enum AssetClass {
        BankDeposit,
        MoneyMarket,
        TBill,
        Equity,
        Security,
        Stablecoin
    }

    struct Asset {
        address token;       // ERC-20 representing the product
        AssetClass class;
        string isin;         // ISIN / external identifier
        address issuer;
        bool active;
    }

    uint256 public assetCount;
    mapping(uint256 => Asset) public assets;
    mapping(address => uint256) public assetIdByToken;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AssetListed(uint256 indexed id, address indexed token, AssetClass class, address issuer);
    event AssetStatus(uint256 indexed id, bool active);

    error NotAuthorized();
    error AlreadyListed();

    constructor(address owner_) {
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function listAsset(address token, AssetClass class, string calldata isin, address issuer)
        external
        onlyOwner
        returns (uint256 id)
    {
        if (assetIdByToken[token] != 0) revert AlreadyListed();
        id = ++assetCount;
        assets[id] = Asset({token: token, class: class, isin: isin, issuer: issuer, active: true});
        assetIdByToken[token] = id;
        emit AssetListed(id, token, class, issuer);
    }

    function setActive(uint256 id, bool active) external onlyOwner {
        assets[id].active = active;
        emit AssetStatus(id, active);
    }

    function isActive(address token) external view returns (bool) {
        uint256 id = assetIdByToken[token];
        return id != 0 && assets[id].active;
    }
}
