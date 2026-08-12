// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Minimal interface for NonfungiblePositionManager
interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
    
    // Fetch the owner of the NFT
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title AutoFeeClaimer
 * @dev A custom permissionless smart contract to batch collect fees
 * from Uniswap V3 and PancakeSwap V3 NFT positions.
 * Fees are automatically routed to the true owner of the NFT.
 */
contract AutoFeeClaimer {

    address public constant feeReceiver = 0xe940DFc78516D0fD26e6c6ce9dD15E15D47347d6;

   
    struct ClaimInfo {
        address manager; // The address of the NonfungiblePositionManager
        uint256 tokenId; // The ID of the NFT position
    }

    // Events
    event FeesClaimed(address indexed manager, uint256 indexed tokenId, address indexed receiver, uint256 amount0, uint256 amount1);

    /**
     * @dev Batch claims fees from multiple NFT positions across different DEXes.
     * Anyone can call this function (e.g. your automated bot), but the fees 
     * will ALWAYS be sent to the actual owner of the NFT.
     * @param claims Array of ClaimInfo containing manager address and tokenId
     */
    function claimMultiple(ClaimInfo[] calldata claims) external {
        for (uint256 i = 0; i < claims.length; i++) {
            INonfungiblePositionManager manager = INonfungiblePositionManager(claims[i].manager);
            
            // Optionally verify the NFT is valid
            address nftOwner = manager.ownerOf(claims[i].tokenId);
            require(nftOwner != address(0), "Invalid NFT");

            // Fees are sent directly to the specified feeReceiver address!
            INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
                tokenId: claims[i].tokenId,
                recipient: feeReceiver,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

            // Call the position manager
            (uint256 amount0, uint256 amount1) = manager.collect(params);
            
            // Emit event for tracking
            emit FeesClaimed(claims[i].manager, claims[i].tokenId, feeReceiver, amount0, amount1);
        }
    }
}