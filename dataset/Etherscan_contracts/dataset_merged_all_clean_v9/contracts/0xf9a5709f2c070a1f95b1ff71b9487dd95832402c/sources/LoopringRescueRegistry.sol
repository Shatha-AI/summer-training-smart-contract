// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;



// ---------------------------------------------------------------------------
// VENDORED, VERBATIM, from Loopring's own protocol source:
//   github.com/Loopring/protocols  @ release_loopring_3.6.3
//   packages/counterfactual_nft/contracts/external/IPFS.sol
//   @author Brecht Devos - <brecht@loopring.org>   (SPDX: MIT)
//
// Reused here (with attribution) so this rescue registry's uri(id) reconstructs
// the ORIGINAL Loopring IPFS CIDv0 on-chain, exactly as the canonical
// CounterfactualNFT did. A Loopring L2 NFT's token id is the 32-byte sha2-256
// digest of its IPFS CIDv0; IPFS.encode() rebuilds "Qm..." = base58(0x1220||id).
//
// The only change from upstream is dropping the `pragma experimental
// ABIEncoderV2;` line (a no-op / default under solc 0.8.x) to avoid a compiler
// warning. The algorithm is byte-for-byte identical.
// ---------------------------------------------------------------------------

/// @title IPFS
/// @author Brecht Devos - <brecht@loopring.org>
library IPFS
{
    bytes constant ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    // Encodes the 32 byte data as an IPFS v0 CID
    function encode(uint256 data)
        internal
        pure
        returns (string memory)
    {
        // We'll be always be encoding 34 bytes
        bytes memory out = new bytes(46);

        // Copy alphabet to memory
        bytes memory alphabet = ALPHABET;

        // We have to encode 0x1220data, which is 34 bytes and doesn't fit in a single uint256.
        // Keep the first 32 bytes in the uint, but do the encoding as if 0x1220 was part of the data value.
        // 0 = (0x12200000000000000000000000000000000000000000000000000000000000000000) % 58
        out[45] = alphabet[data % 58];
        data /= 58;
        // 4 = (0x12200000000000000000000000000000000000000000000000000000000000000000 / 58) % 58
        data += 4;
        out[44] = alphabet[data % 58];
        data /= 58;
        // 40 = (0x12200000000000000000000000000000000000000000000000000000000000000000 / 58 / 58) % 58
        data += 40;
        out[43] = alphabet[data % 58];
        data /= 58;

        // Add the top bytes now there is anough space in the uint256
        // This constant is 0x12200000000000000000000000000000000000000000000000000000000000000000 / 58 / 58 / 58
        data += 2753676319555676466672318311740497214108679778017611511045364661305900823779;

        // The rest is just simple base58 encoding
        for (uint i = 3; i < 46; i++) {
            out[45 - i] = alphabet[data % 58];
            data /= 58;
        }

        return string(out);
    }
}

// ============================================================================
//  Loopring L2 Rescue Registry
// ============================================================================
//
//  A single, community-owned, provenance-anchored rescue collection for the
//  ~2.17M Loopring L2-only NFT holdings that were STRANDED when Loopring shut
//  its zkRollup DEX in June 2026 (relayer offline + trustless exodus disabled,
//  so no L2 NFT can ever be withdrawn to L1 by anyone but Loopring).
//
//  ANY collector can self-claim a faithful, provenance-anchored ERC-1155 COPY
//  of an NFT they held on L2, by proving their row in Loopring's OFFICIAL
//  published snapshot against a Merkle ROOT baked into this contract at deploy.
//
//  WHAT THIS IS / IS NOT
//    - IS:  an honest copy. Same art (uri(id) resolves the ORIGINAL IPFS CID),
//           provenance provable on-chain against Loopring's snapshot root.
//    - NOT: the original token, nor the original contract. It is a NEW contract
//           at a NEW address. See docs/PLAN.md "Fidelity ladder".
//
//  IMMUTABILITY / TRUST MODEL  (nothing to rug)
//    - The Merkle ROOT is set ONCE in the constructor and is `immutable`.
//    - There is NO owner, NO admin, NO pause, NO upgrade path, NO setter of any
//      kind. Once deployed, this contract's behaviour can never change.
//    - The only state transition anyone can cause is: prove a snapshot row and
//      mint the corresponding copy to that row's holder, exactly once.
//
//  LEAF ENCODING  (build_merkle.py MUST match this bit-for-bit)
//    leaf = keccak256(abi.encodePacked(
//              holder,            //  20 bytes  (address)
//              collection,        //  20 bytes  (address, original nft_address)
//              nftId,             //  32 bytes  (bytes32, original nft_id)
//              nftType,           //   1 byte   (uint8: erc721=0, erc1155=1)
//              amount             //  12 bytes  (uint96, snapshot nft_amount)
//           ))                    //  = 85 packed bytes, hashed with keccak256
//
//  MERKLE VERIFICATION
//    Sorted-pair hashing (OpenZeppelin MerkleProof compatible): at every level
//    parent = keccak256(min(a,b) || max(a,b)). See MerkleProof below.
//
//  TOKEN ID  (shared across all holders of the same original NFT)
//    id = uint256(keccak256(abi.encodePacked(collection, nftId)))
//    So every holder of the same original (collection, nftId) claims into the
//    SAME rescue token id, and uri(id) resolves that NFT's original CID.
//
// ============================================================================


// ---------------------------------------------------------------------------
//  Minimal ERC-165 / ERC-1155 interfaces (vendored inline, trimmed to what we
//  use). Sourced from the EIP-1155 / EIP-165 standards.
// ---------------------------------------------------------------------------

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

interface IERC1155MetadataURI is IERC1155 {
    function uri(uint256 id) external view returns (string memory);
}

interface IERC1155Receiver is IERC165 {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}


// ---------------------------------------------------------------------------
//  MerkleProof — sorted-pair hashing, OpenZeppelin-compatible.
//  Vendored inline (single function) rather than importing OZ, to keep the
//  audited surface minimal and dependency-free.
// ---------------------------------------------------------------------------

library MerkleProof {
    /// @dev Returns true iff `leaf` can be proved to be part of the tree with
    ///      root `root`, given `proof`. Uses commutative (sorted) hashing so the
    ///      builder never has to record left/right position per node.
    function verify(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 p = proof[i];
            computed = computed <= p
                ? keccak256(abi.encodePacked(computed, p))
                : keccak256(abi.encodePacked(p, computed));
        }
        return computed == root;
    }
}


// ---------------------------------------------------------------------------
//  The registry (a self-contained minimal ERC-1155 + Merkle-gated claim).
// ---------------------------------------------------------------------------

contract LoopringRescueRegistry is IERC1155MetadataURI {
    // --- collection-level metadata (ERC-1155 has no standard name/symbol;
    //     these public constants are surfaced for marketplaces/indexers) ---
    string public constant name = "Loopring L2 Rescue";
    string public constant symbol = "L2RESCUE";

    // --- the one and only trust anchor: the snapshot Merkle root, immutable ---
    bytes32 public immutable ROOT;

    // --- provenance record kept per rescue token id, powers uri(id) ---
    struct TokenInfo {
        address collection; // original Loopring nft_address
        bytes32 nftId;      // original Loopring nft_id (== IPFS CIDv0 sha2-256 digest)
    }

    // --- ERC-1155 core storage ---
    // slot 0
    mapping(uint256 => mapping(address => uint256)) private _balances;
    // slot 1
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // slot 2 : claim guard, keyed by keccak256(holder, collection, nftId)
    mapping(bytes32 => bool) public claimed;
    // slot 3 : id -> provenance
    mapping(uint256 => TokenInfo) public tokenInfo;

    /// @notice Emitted on every successful claim. Carries the ORIGINAL
    ///         collection + nftId so indexers/marketplaces can link the rescue
    ///         token back to the Loopring provenance it copies.
    event Claimed(
        address indexed holder,
        address indexed collection,
        bytes32 nftId,
        uint256 indexed rescueTokenId,
        uint8 nftType,
        uint96 amount
    );

    /// @param merkleRoot The published Merkle root over Loopring's official
    ///        L2-only snapshot, using the leaf encoding documented at the top of
    ///        this file. Set once, forever.
    constructor(bytes32 merkleRoot) {
        ROOT = merkleRoot;
    }

    // ---------------------------------------------------------------------
    //  Claiming
    // ---------------------------------------------------------------------

    /// @notice Claim your own rescue copy. msg.sender must be the snapshot holder.
    function claim(
        address collection,
        bytes32 nftId,
        uint8 nftType,
        uint96 amount,
        bytes32[] calldata proof
    ) external {
        _claim(msg.sender, collection, nftId, nftType, amount, proof);
    }

    /// @notice Gas-gift variant: anyone can pay gas to deliver the copy to the
    ///         ORIGINAL holder. Mints to `holder`, never to msg.sender, and the
    ///         claim guard is keyed by `holder`, so this cannot be used to
    ///         double-claim or to redirect someone else's NFT.
    function claimFor(
        address holder,
        address collection,
        bytes32 nftId,
        uint8 nftType,
        uint96 amount,
        bytes32[] calldata proof
    ) external {
        _claim(holder, collection, nftId, nftType, amount, proof);
    }

    function _claim(
        address holder,
        address collection,
        bytes32 nftId,
        uint8 nftType,
        uint96 amount,
        bytes32[] calldata proof
    ) internal {
        require(nftType <= 1, "bad nftType");        // 0 = erc721, 1 = erc1155
        require(amount > 0, "zero amount");

        // Recompute the exact snapshot leaf and verify it against the root.
        bytes32 leaf = keccak256(abi.encodePacked(holder, collection, nftId, nftType, amount));
        require(MerkleProof.verify(proof, ROOT, leaf), "bad proof");

        // One-shot per (holder, collection, nftId). Full amount minted at once.
        bytes32 key = keccak256(abi.encodePacked(holder, collection, nftId));
        require(!claimed[key], "already claimed");
        claimed[key] = true;

        // Shared rescue token id for this original NFT.
        uint256 id = uint256(keccak256(abi.encodePacked(collection, nftId)));
        if (tokenInfo[id].collection == address(0)) {
            tokenInfo[id] = TokenInfo(collection, nftId);
        }

        _mint(holder, id, amount);
        emit Claimed(holder, collection, nftId, id, nftType, amount);
    }

    // ---------------------------------------------------------------------
    //  Metadata: uri(id) resolves the ORIGINAL Loopring IPFS CID (same art)
    // ---------------------------------------------------------------------

    function uri(uint256 id) external view returns (string memory) {
        TokenInfo memory info = tokenInfo[id];
        require(info.collection != address(0), "unknown token");
        // nftId is the sha2-256 digest of the original CIDv0; rebuild "ipfs://Qm...".
        return string(abi.encodePacked("ipfs://", IPFS.encode(uint256(info.nftId))));
    }

    // ---------------------------------------------------------------------
    //  Minimal ERC-1155 implementation
    // ---------------------------------------------------------------------

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        require(account != address(0), "zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "length mismatch");
        uint256[] memory out = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            out[i] = balanceOf(accounts[i], ids[i]);
        }
        return out;
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "self approval");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external {
        require(to != address(0), "transfer to zero");
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "not authorized");

        uint256 fromBal = _balances[id][from];
        require(fromBal >= amount, "insufficient balance");
        unchecked { _balances[id][from] = fromBal - amount; }
        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        require(to != address(0), "transfer to zero");
        require(ids.length == amounts.length, "length mismatch");
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "not authorized");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBal = _balances[id][from];
            require(fromBal >= amount, "insufficient balance");
            unchecked { _balances[id][from] = fromBal - amount; }
            _balances[id][to] += amount;
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    function _mint(address to, uint256 id, uint256 amount) internal {
        require(to != address(0), "mint to zero");
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, "");
    }

    // ---------------------------------------------------------------------
    //  ERC-165
    // ---------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId;
    }

    // ---------------------------------------------------------------------
    //  ERC-1155 receiver acceptance checks (so mints/transfers to compliant
    //  contract wallets — e.g. Loopring smart wallets — don't strand tokens).
    // ---------------------------------------------------------------------

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                require(response == IERC1155Receiver.onERC1155Received.selector, "receiver rejected");
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("non-ERC1155Receiver");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                require(response == IERC1155Receiver.onERC1155BatchReceived.selector, "receiver rejected");
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("non-ERC1155Receiver");
            }
        }
    }
}