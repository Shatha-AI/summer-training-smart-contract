// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title MessagePayment
 * @notice Accepts native token and ERC20 payments for message packages.
 *         Package prices are stored in USD cents.
 *         Owner sets only:
 *         - native price per 1 cent in wei
 *         - token price per 1 cent in smallest token units
 *         The package payment amount is calculated automatically.
 */
contract MessagePayment {
    struct Package {
        uint256 messageCount;
        uint256 priceUSD; // cents
        bool active;
    }

    address public owner;
    bool private _locked;

    mapping(uint256 => Package) public packages;
    uint256 public packageCount;

    mapping(address => bool) public supportedTokens;
    address[] public tokenList;

    // Pricing per 1 USD cent
    uint256 public nativePricePerCentWei;
    mapping(address => uint256) public tokenPricePerCent;

    event MessagesPurchased(
        address indexed buyer,
        uint256 indexed packageId,
        uint256 messageCount,
        address token, // address(0) for native
        uint256 amountPaid
    );

    event PackageAdded(uint256 indexed packageId, uint256 messageCount, uint256 priceUSD);
    event PackageUpdated(uint256 indexed packageId, uint256 messageCount, uint256 priceUSD, bool active);

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    event NativePricePerCentSet(uint256 pricePerCentWei);
    event TokenPricePerCentSet(address indexed token, uint256 amountPerCent);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    constructor() {
        owner = msg.sender;

        _addPackage(50, 10);     // $0.10
        _addPackage(100, 20);    // $0.20
        _addPackage(200, 40);    // $0.40
        _addPackage(500, 100);   // $1.00
        _addPackage(1000, 200);  // $2.00
    }

    // ── Purchase: Native ───────────────────────────────

    function buyWithNative(uint256 packageId) external payable nonReentrant {
        require(packageId < packageCount, "Invalid package");

        Package storage pkg = packages[packageId];
        require(pkg.active, "Package not active");

        uint256 required = getRequiredNative(packageId);
        require(required > 0, "Native price not set");
        require(msg.value >= required, "Underpayment");

        uint256 excess = msg.value - required;
        if (excess > 0) {
            (bool refunded, ) = payable(msg.sender).call{value: excess}("");
            require(refunded, "Refund failed");
        }

        emit MessagesPurchased(msg.sender, packageId, pkg.messageCount, address(0), required);
    }

    // ── Purchase: ERC20 ────────────────────────────────

    function buyWithToken(address token, uint256 packageId) external nonReentrant {
        require(packageId < packageCount, "Invalid package");
        require(supportedTokens[token], "Token not supported");

        Package storage pkg = packages[packageId];
        require(pkg.active, "Package not active");

        uint256 required = getRequiredToken(token, packageId);
        require(required > 0, "Token price not set");

        uint256 balBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), required);
        uint256 balAfter = IERC20(token).balanceOf(address(this));
        uint256 received = balAfter - balBefore;

        require(received >= required, "Fee-on-transfer not supported");

        emit MessagesPurchased(msg.sender, packageId, pkg.messageCount, token, received);
    }

    // ── Owner: Pricing ────────────────────────────────

    /// @notice Set native coin amount for 1 USD cent, in wei
    function setNativePricePerCent(uint256 pricePerCentWei) external onlyOwner {
        require(pricePerCentWei > 0, "Invalid price");
        nativePricePerCentWei = pricePerCentWei;
        emit NativePricePerCentSet(pricePerCentWei);
    }

    /// @notice Set token amount for 1 USD cent, in smallest token units
    function setTokenPricePerCent(address token, uint256 amountPerCent) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        require(amountPerCent > 0, "Invalid price");
        tokenPricePerCent[token] = amountPerCent;
        emit TokenPricePerCentSet(token, amountPerCent);
    }

    // ── Owner: Package Management ─────────────────────

    function addPackage(uint256 messageCount, uint256 priceUSD) external onlyOwner {
        _addPackage(messageCount, priceUSD);
    }

    function updatePackage(
        uint256 packageId,
        uint256 messageCount,
        uint256 priceUSD,
        bool active
    ) external onlyOwner {
        require(packageId < packageCount, "Invalid package");
        require(messageCount > 0, "Invalid message count");
        require(priceUSD > 0, "Invalid USD price");

        packages[packageId] = Package(messageCount, priceUSD, active);
        emit PackageUpdated(packageId, messageCount, priceUSD, active);
    }

    function deactivatePackage(uint256 packageId) external onlyOwner {
        require(packageId < packageCount, "Invalid package");
        packages[packageId].active = false;
        emit PackageUpdated(
            packageId,
            packages[packageId].messageCount,
            packages[packageId].priceUSD,
            false
        );
    }

    // ── Owner: Token Management ───────────────────────

    function addToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!supportedTokens[token], "Already supported");

        supportedTokens[token] = true;
        tokenList.push(token);

        emit TokenAdded(token);
    }

    function removeToken(address token) external onlyOwner {
        require(supportedTokens[token], "Not supported");

        supportedTokens[token] = false;
        delete tokenPricePerCent[token];

        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }

        emit TokenRemoved(token);
    }

    // ── Owner: Withdraw ───────────────────────────────

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No native balance");

        (bool sent, ) = payable(owner).call{value: balance}("");
        require(sent, "Transfer failed");
    }

    function withdrawToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No token balance");
        _safeTransfer(token, owner, balance);
    }

    // ── Ownership ─────────────────────────────────────

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ── Views ─────────────────────────────────────────

    function getPackage(uint256 packageId)
        external
        view
        returns (uint256 messageCount, uint256 priceUSD, bool active)
    {
        require(packageId < packageCount, "Invalid package");
        Package storage pkg = packages[packageId];
        return (pkg.messageCount, pkg.priceUSD, pkg.active);
    }

    function getAllPackages()
        external
        view
        returns (
            uint256[] memory messageCounts,
            uint256[] memory pricesUSD,
            bool[] memory actives
        )
    {
        messageCounts = new uint256[](packageCount);
        pricesUSD = new uint256[](packageCount);
        actives = new bool[](packageCount);

        for (uint256 i = 0; i < packageCount; i++) {
            messageCounts[i] = packages[i].messageCount;
            pricesUSD[i] = packages[i].priceUSD;
            actives[i] = packages[i].active;
        }
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return tokenList;
    }

    function getRequiredNative(uint256 packageId) public view returns (uint256) {
        require(packageId < packageCount, "Invalid package");
        return packages[packageId].priceUSD * nativePricePerCentWei;
    }

    function getRequiredToken(address token, uint256 packageId) public view returns (uint256) {
        require(packageId < packageCount, "Invalid package");
        return packages[packageId].priceUSD * tokenPricePerCent[token];
    }

    function getPackagePricing(uint256 packageId)
        external
        view
        returns (
            uint256 nativePrice,
            address[] memory tokens,
            uint256[] memory prices
        )
    {
        require(packageId < packageCount, "Invalid package");

        nativePrice = getRequiredNative(packageId);
        tokens = tokenList;
        prices = new uint256[](tokenList.length);

        for (uint256 i = 0; i < tokenList.length; i++) {
            prices[i] = getRequiredToken(tokenList[i], packageId);
        }
    }

    // ── Internal ──────────────────────────────────────

    function _addPackage(uint256 messageCount, uint256 priceUSD) internal {
        require(messageCount > 0, "Invalid message count");
        require(priceUSD > 0, "Invalid USD price");

        uint256 id = packageCount;
        packages[id] = Package(messageCount, priceUSD, true);
        packageCount = id + 1;

        emit PackageAdded(id, messageCount, priceUSD);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferFrom failed");
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }
}