// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/// @title Updatable ETH Treasury Forwarder
/// @notice Auto-forwards 100% of incoming ETH to a changeable treasury address.
/// @dev Uses low-level call execution for gas safety, custom errors, and complete emergency recovery options.
contract EthForwarder {
    // =========================================================================
    //                                STORAGE
    // =========================================================================

    /// @notice Destination treasury address where incoming ETH is forwarded.
    address payable public treasury;

    /// @notice Contract administrator authorized to execute start() and emergency rescue methods.
    address public owner;

    // =========================================================================
    //                                EVENTS
    // =========================================================================

    event EthForwarded(address indexed sender, address indexed treasury, uint256 amount);
    event EthSwept(address indexed caller, address indexed treasury, uint256 amount);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event EthRescued(address indexed to, uint256 amount);
    event ERC20Rescued(address indexed token, address indexed to, uint256 amount);
    event ERC721Rescued(address indexed token, address indexed to, uint256 tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // =========================================================================
    //                                ERRORS
    // =========================================================================

    error TransferFailed();
    error NoBalanceToSweep();
    error InvalidZeroAddress();
    error Unauthorized();

    // =========================================================================
    //                               MODIFIERS
    // =========================================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // =========================================================================
    //                             CONSTRUCTOR
    // =========================================================================

    /// @param initialOwner Administrator wallet authorized to reconfigure the treasury.
    /// @param initialTreasury Treasury wallet address. If set to address(0), defaults to 0x25a986eEc34Dd09093C14Df69667FE9a80FB306F.
    constructor(address initialOwner, address payable initialTreasury) {
        if (initialOwner == address(0)) revert InvalidZeroAddress();

        address payable target = initialTreasury == address(0)
            ? payable(0x25a986eEc34Dd09093C14Df69667FE9a80FB306F)
            : initialTreasury;

        owner = initialOwner;
        treasury = target;

        emit OwnershipTransferred(address(0), initialOwner);
        emit TreasuryUpdated(address(0), target);
    }

    // =========================================================================
    //                          RECEIVE & FALLBACK
    // =========================================================================

    /// @notice Auto-forwards native ETH on standard transfers.
    receive() external payable {
        _forwardEth(msg.value);
    }

    /// @notice Auto-forwards native ETH on calls with calldata payload.
    fallback() external payable {
        _forwardEth(msg.value);
    }

    // =========================================================================
    //                           TREASURY CONFIGURATION
    // =========================================================================

    /// @notice Sets or changes the active treasury address and flushes any pending contract balance.
    /// @param newTreasury The wallet or contract address that will receive all future forwarded funds.
    function start(address payable newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidZeroAddress();

        address payable oldTreasury = treasury;
        treasury = newTreasury;

        emit TreasuryUpdated(oldTreasury, newTreasury);

        // Immediately flush any accumulated balance to the newly started treasury address
        uint256 balance = address(this).balance;
        if (balance > 0) {
            emit EthSwept(msg.sender, newTreasury, balance);
            (bool success, ) = newTreasury.call{value: balance}("");
            if (!success) revert TransferFailed();
        }
    }

    /// @notice Transfers administrative control to a new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidZeroAddress();

        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // =========================================================================
    //                             SWEEP METHOD
    // =========================================================================

    /// @notice Manually pushes stuck or forced ETH balance to the active treasury address.
    function sweep() external {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalanceToSweep();

        address payable target = treasury;
        emit EthSwept(msg.sender, target, balance);

        (bool success, ) = target.call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    // =========================================================================
    //                         EMERGENCY RESCUE METHODS
    // =========================================================================

    /// @notice Rescues trapped ETH to an arbitrary fallback address.
    function rescueETH(address payable to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InvalidZeroAddress();
        if (amount > address(this).balance) revert TransferFailed();

        emit EthRescued(to, amount);

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Rescues ERC-20 tokens accidentally sent to this contract.
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0) || token == address(0)) revert InvalidZeroAddress();

        emit ERC20Rescued(token, to, amount);

        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );

        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    /// @notice Rescues ERC-721 NFTs accidentally sent to this contract.
    function rescueERC721(address token, address to, uint256 tokenId) external onlyOwner {
        if (to == address(0) || token == address(0)) revert InvalidZeroAddress();

        emit ERC721Rescued(token, to, tokenId);

        IERC721(token).safeTransferFrom(address(this), to, tokenId);
    }

    // =========================================================================
    //                          INTERNAL HELPERS
    // =========================================================================

    function _forwardEth(uint256 amount) internal {
        if (amount > 0) {
            address payable target = treasury;
            emit EthForwarded(msg.sender, target, amount);

            (bool success, ) = target.call{value: amount}("");
            if (!success) revert TransferFailed();
        }
    }
}