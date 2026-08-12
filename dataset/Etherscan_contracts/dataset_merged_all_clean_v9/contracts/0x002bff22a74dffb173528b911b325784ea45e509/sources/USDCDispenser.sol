// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC20 interface (USDC conforms to this)
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/**
 * @title USDCDispenser
 * @notice A simple access-controlled "money dispenser" contract.
 *         - The deployer is the first admin.
 *         - Admins can add other admins.
 *         - Admins can add/remove whitelisted addresses.
 *         - Admins AND whitelisted addresses can request a specific amount of USDC.
 *         - Admins can withdraw all remaining USDC from the contract.
 *
 * @dev Security notes (read before deploying with real funds):
 *      - There is NO per-address limit, cooldown, or total budget check on requestFunds
 *        beyond the contract's own USDC balance. Anyone in the whitelist/admin set can
 *        drain the entire balance in a single call if you don't add further limits.
 *      - Admins are fully trusted parties in this design — an admin key compromise
 *        means total loss of funds. Consider a multisig for admin control in production.
 *      - Uses OpenZeppelin's ReentrancyGuard pattern manually (no external dependency)
 *        to keep this a single, self-contained file.
 */
contract USDCDispenser {
    IERC20 public immutable usdc;

    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isWhitelisted;

    address[] private whitelistArray;
    // tracks index+1 in whitelistArray for O(1) removal (0 = not present)
    mapping(address => uint256) private whitelistIndex;

    uint256 private locked; // simple reentrancy guard

    event AdminAdded(address indexed newAdmin, address indexed addedBy);
    event WhitelistAdded(address indexed account, address indexed addedBy);
    event WhitelistRemoved(address indexed account, address indexed removedBy);
    event FundsRequested(address indexed requester, uint256 amount);
    event WithdrawAll(address indexed admin, uint256 amount);

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not an admin");
        _;
    }

    modifier onlyAuthorized() {
        require(isAdmin[msg.sender] || isWhitelisted[msg.sender], "Not authorized");
        _;
    }

    modifier nonReentrant() {
        require(locked == 0, "Reentrant call");
        locked = 1;
        _;
        locked = 0;
    }

    constructor() {
        usdc = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));

        // Contract creator becomes the first admin
        isAdmin[msg.sender] = true;
        emit AdminAdded(msg.sender, msg.sender);
    }

    // ------------------------------------------------------------------
    // Admin management
    // ------------------------------------------------------------------

    /// @notice Add a new admin. Only callable by an existing admin.
    function addAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        require(!isAdmin[newAdmin], "Already an admin");
        isAdmin[newAdmin] = true;
        emit AdminAdded(newAdmin, msg.sender);
    }

    // ------------------------------------------------------------------
    // Whitelist management (admin only)
    // ------------------------------------------------------------------

    /// @notice Add an address to the whitelist. Only callable by an admin.
    function addWhitelist(address account) external onlyAdmin {
        require(account != address(0), "Invalid address");
        require(!isWhitelisted[account], "Already whitelisted");

        isWhitelisted[account] = true;
        whitelistArray.push(account);
        whitelistIndex[account] = whitelistArray.length; // store index+1

        emit WhitelistAdded(account, msg.sender);
    }

    /// @notice Remove an address from the whitelist. Only callable by an admin.
    function removeWhitelist(address account) external onlyAdmin {
        require(isWhitelisted[account], "Not whitelisted");

        isWhitelisted[account] = false;

        uint256 idxPlusOne = whitelistIndex[account];
        uint256 lastIndex = whitelistArray.length - 1;

        if (idxPlusOne - 1 != lastIndex) {
            address lastAddr = whitelistArray[lastIndex];
            whitelistArray[idxPlusOne - 1] = lastAddr;
            whitelistIndex[lastAddr] = idxPlusOne;
        }

        whitelistArray.pop();
        delete whitelistIndex[account];

        emit WhitelistRemoved(account, msg.sender);
    }

    /// @notice Returns the full current whitelist array.
    function getWhitelist() external view returns (address[] memory) {
        return whitelistArray;
    }

    // ------------------------------------------------------------------
    // Fund requests (admins + whitelisted addresses)
    // ------------------------------------------------------------------

    /**
     * @notice Request a specific amount of USDC to be sent to msg.sender.
     * @dev Callable by admins or whitelisted addresses. No cap is enforced beyond
     *      the contract's current USDC balance — add limits here if needed.
     * @param _amount Amount of USDC (in the token's human readable unit with 6 decimals included implicitly).
     */
    function requestFunds(uint256 _amount) external onlyAuthorized nonReentrant {
        uint256 amount = _amount * (10 ** 6);
        require(amount > 0, "Amount must be > 0");
        uint256 balance = usdc.balanceOf(address(this));
        require(balance >= amount, "Insufficient contract balance");

        bool success = usdc.transfer(msg.sender, amount);
        require(success, "USDC transfer failed");

        emit FundsRequested(msg.sender, amount);
    }

    // ------------------------------------------------------------------
    // Admin withdrawal
    // ------------------------------------------------------------------

    /// @notice Withdraw all remaining USDC in the contract to the calling admin.
    function withdrawAll() external onlyAdmin nonReentrant {
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");

        bool success = usdc.transfer(msg.sender, balance);
        require(success, "USDC transfer failed");

        emit WithdrawAll(msg.sender, balance);
    }

    // ------------------------------------------------------------------
    // View helpers
    // ------------------------------------------------------------------

    /// @notice Current USDC balance held by this contract.
    function contractBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}