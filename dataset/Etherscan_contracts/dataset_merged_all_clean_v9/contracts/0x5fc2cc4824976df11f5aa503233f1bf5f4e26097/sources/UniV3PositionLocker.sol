// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*//////////////////////////////////////////////////////////////
                        MINIMAL INTERFACES
//////////////////////////////////////////////////////////////*/

/// @dev Minimal ERC-721 surface used by the Uniswap v3
///      NonfungiblePositionManager.
interface IERC721Like {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/// @dev Minimal Uniswap v3 NonfungiblePositionManager interface.
interface INonfungiblePositionManager is IERC721Like {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Collects tokens owed to a v3 position NFT.
    /// @dev Calling collect does not decrease active position liquidity.
    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    /// @notice Returns position information for a tokenId.
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

/*//////////////////////////////////////////////////////////////
                    UNIV3 POSITION NFT LOCKER
//////////////////////////////////////////////////////////////*/

/// @title UniV3PositionLocker
/// @notice Time-locks one Uniswap v3 liquidity-position NFT for one year.
///         The beneficiary can continue claiming fees while the NFT remains
///         locked. After maturity, the beneficiary can withdraw the NFT.
/// @dev Deploy with the v3 NonfungiblePositionManager address for the target
///      chain. Robinhood Chain mainnet (chainId 4663):
///      0x73991a25c818bf1f1128deaab1492d45638de0d3
///      The address remains constructor-configurable for portability.
contract UniV3PositionLocker {
    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Uniswap v3 NonfungiblePositionManager.
    INonfungiblePositionManager public immutable positionManager;

    /// @notice Address entitled to claim fees and withdraw the NFT.
    address public immutable beneficiary;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The locked v3 position NFT tokenId.
    uint256 public lockedTokenId;

    /// @notice Unix timestamp when the NFT becomes withdrawable.
    uint256 public unlockTime;

    /// @notice True while an NFT is held by this locker.
    bool public isLocked;

    /// @notice Fixed lock duration.
    uint256 public constant LOCK_DURATION = 365 days;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionLocked(uint256 indexed tokenId, uint256 unlockTime);
    event FeesClaimed(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1
    );
    event PositionWithdrawn(uint256 indexed tokenId, address indexed to);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotBeneficiary();
    error AlreadyLocked();
    error NothingLocked();
    error StillLocked(uint256 unlockTime);
    error WrongPositionManager();
    error InvalidPositionManager();
    error InvalidBeneficiary();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyBeneficiary() {
        if (msg.sender != beneficiary) revert NotBeneficiary();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _positionManager v3 NonfungiblePositionManager for the chain.
    /// @param _beneficiary Address allowed to lock, claim fees, and withdraw.
    constructor(address _positionManager, address _beneficiary) {
        if (_positionManager == address(0)) revert InvalidPositionManager();
        if (_beneficiary == address(0)) revert InvalidBeneficiary();

        positionManager = INonfungiblePositionManager(_positionManager);
        beneficiary = _beneficiary;
    }

    /*//////////////////////////////////////////////////////////////
                                LOCKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Pulls a beneficiary-owned v3 position NFT into the locker.
    /// @dev The beneficiary must first approve this locker for `tokenId`.
    function lock(uint256 tokenId) external onlyBeneficiary {
        if (isLocked) revert AlreadyLocked();

        positionManager.transferFrom(msg.sender, address(this), tokenId);
        _startLock(tokenId);
    }

    /// @notice Allows locking by directly calling safeTransferFrom on the v3
    ///         NonfungiblePositionManager.
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        if (msg.sender != address(positionManager)) revert WrongPositionManager();
        if (from != beneficiary) revert NotBeneficiary();
        if (isLocked) revert AlreadyLocked();

        _startLock(tokenId);
        return this.onERC721Received.selector;
    }

    function _startLock(uint256 tokenId) internal {
        lockedTokenId = tokenId;
        unlockTime = block.timestamp + LOCK_DURATION;
        isLocked = true;

        emit PositionLocked(tokenId, unlockTime);
    }

    /*//////////////////////////////////////////////////////////////
                              CLAIM FEES
    //////////////////////////////////////////////////////////////*/

    /// @notice Collects all tokens currently owed by the locked v3 position
    ///         and sends them directly to the beneficiary.
    /// @dev This does not call decreaseLiquidity, so active liquidity remains
    ///      untouched. In Uniswap v3, `collect` can also collect amounts already
    ///      owed from a decreaseLiquidity operation performed before locking.
    function claimFees()
        external
        onlyBeneficiary
        returns (uint256 amount0, uint256 amount1)
    {
        if (!isLocked) revert NothingLocked();

        uint256 tokenId = lockedTokenId;

        (amount0, amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: beneficiary,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        emit FeesClaimed(tokenId, beneficiary, amount0, amount1);
    }

    /*//////////////////////////////////////////////////////////////
                               WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the position NFT after the one-year lock expires.
    function withdraw() external onlyBeneficiary {
        if (!isLocked) revert NothingLocked();
        if (block.timestamp < unlockTime) revert StillLocked(unlockTime);

        uint256 tokenId = lockedTokenId;

        // Checks-effects-interactions.
        isLocked = false;
        lockedTokenId = 0;
        unlockTime = 0;

        positionManager.safeTransferFrom(address(this), beneficiary, tokenId);

        emit PositionWithdrawn(tokenId, beneficiary);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Seconds remaining until unlock.
    function timeRemaining() external view returns (uint256) {
        if (!isLocked || block.timestamp >= unlockTime) return 0;
        return unlockTime - block.timestamp;
    }

    /// @notice Returns the locked v3 position's key details and owed balances.
    function lockedPosition()
        external
        view
        returns (
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        if (!isLocked) revert NothingLocked();

        (
            ,
            ,
            token0,
            token1,
            fee,
            tickLower,
            tickUpper,
            liquidity,
            ,
            ,
            tokensOwed0,
            tokensOwed1
        ) = positionManager.positions(lockedTokenId);
    }
}