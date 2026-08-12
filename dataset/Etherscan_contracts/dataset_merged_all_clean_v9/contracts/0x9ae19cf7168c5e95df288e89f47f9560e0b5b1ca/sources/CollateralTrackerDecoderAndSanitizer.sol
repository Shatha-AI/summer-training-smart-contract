// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

// ============================================================
// DecoderCustomTypes
// Source: lib/boring-vault/src/interfaces/DecoderCustomTypes.sol
// ============================================================

contract DecoderCustomTypes {
    // ========================================= BALANCER =========================================
    struct JoinPoolRequest {
        address[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        address[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }

    // ========================================= UNISWAP V3 =========================================

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct PancakeSwapExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    // ========================================= MORPHO BLUE =========================================

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    // ========================================= 1INCH =========================================

    struct SwapDescription {
        address srcToken;
        address dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    // ========================================= PENDLE =========================================
    struct TokenInput {
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        address pendleSwap;
        SwapData swapData;
    }

    struct TokenOutput {
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        address pendleSwap;
        SwapData swapData;
    }

    struct ApproxParams {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain;
        uint256 maxIteration;
        uint256 eps;
    }

    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    enum SwapType {
        NONE,
        KYBERSWAP,
        ONE_INCH,
        ETH_WETH
    }

    struct LimitOrderData {
        address limitRouter;
        uint256 epsSkipMarket;
        FillOrderParams[] normalFills;
        FillOrderParams[] flashFills;
        bytes optData;
    }

    struct FillOrderParams {
        Order order;
        bytes signature;
        uint256 makingAmount;
    }

    struct Order {
        uint256 salt;
        uint256 expiry;
        uint256 nonce;
        OrderType orderType;
        address token;
        address YT;
        address maker;
        address receiver;
        uint256 makingAmount;
        uint256 lnImpliedRate;
        uint256 failSafeRate;
        bytes permit;
    }

    enum OrderType {
        SY_FOR_PT,
        PT_FOR_SY,
        SY_FOR_YT,
        YT_FOR_SY
    }

    // ========================================= EIGEN LAYER =========================================

    struct QueuedWithdrawalParams {
        address[] strategies;
        uint256[] shares;
        address withdrawer;
    }

    struct Withdrawal {
        address staker;
        address delegatedTo;
        address withdrawer;
        uint256 nonce;
        uint32 startBlock;
        address[] strategies;
        uint256[] shares;
    }

    struct SignatureWithExpiry {
        bytes signature;
        uint256 expiry;
    }

    struct EarnerTreeMerkleLeaf {
        address earner;
        bytes32 earnerTokenRoot;
    }

    struct TokenTreeMerkleLeaf {
        address token;
        uint256 cumulativeEarnings;
    }

    struct RewardsMerkleClaim {
        uint32 rootIndex;
        uint32 earnerIndex;
        bytes earnerTreeProof;
        EarnerTreeMerkleLeaf earnerLeaf;
        uint32[] tokenIndices;
        bytes[] tokenTreeProofs;
        TokenTreeMerkleLeaf[] tokenLeaves;
    }

    // ========================================= CCIP =========================================

    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }

    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct EVMExtraArgsV1 {
        uint256 gasLimit;
    }

    // ========================================= OFT =========================================

    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    // ========================================= L1StandardBridge =========================================

    struct WithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    struct OutputRootProof {
        bytes32 version;
        bytes32 stateRoot;
        bytes32 messagePasserStorageRoot;
        bytes32 latestBlockhash;
    }

    // ========================================= Mantle L1StandardBridge =========================================

    struct MantleWithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 mntValue;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    // ========================================= Linea Bridge =========================================

    struct ClaimMessageWithProofParams {
        bytes32[] proof;
        uint256 messageNumber;
        uint32 leafIndex;
        address from;
        address to;
        uint256 fee;
        uint256 value;
        address payable feeRecipient;
        bytes32 merkleRoot;
        bytes data;
    }

    // ========================================= Scroll Bridge =========================================

    struct L2MessageProof {
        uint256 batchIndex;
        bytes merkleProof;
    }

    // ========================================= Camelot V3 =========================================

    struct CamelotMintParams {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    // ========================================= Velodrome V3 =========================================

    struct VelodromeMintParams {
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        uint160 sqrtPriceX96;
    }

    // ========================================= Karak =========================================

    struct QueuedWithdrawal {
        address staker;
        address delegatedTo;
        uint256 nonce;
        uint256 start;
        WithdrawRequest request;
    }

    struct WithdrawRequest {
        address[] vaults;
        uint256[] shares;
        address withdrawer;
    }

    // ========================================= Term Finance ==================================

    struct TermAuctionOfferSubmission {
        bytes32 id;
        address offeror;
        bytes32 offerPriceHash;
        uint256 amount;
        address purchaseToken;
    }

    // ========================================= Aera =========================================

    struct AssetValue {
        address asset;
        uint256 amount;
    }
}

// ============================================================
// BaseDecoderAndSanitizer
// Source: lib/boring-vault/src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol
// ============================================================

contract BaseDecoderAndSanitizer {
    error BaseDecoderAndSanitizer__FunctionSelectorNotSupported();

    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    //============================== ERC20 ===============================

    function approve(
        address spender,
        uint256
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }

    function transfer(address _to, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }

    //============================== FEES / YIELD ===============================

    function claimFees(address feeAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(feeAsset);
    }

    function claimYield(address yieldAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(yieldAsset);
    }

    function withdrawNonBoringToken(
        address token,
        uint256
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(token);
    }

    function withdrawNativeFromDrone() external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== FALLBACK ===============================

    fallback() external {
        revert BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
    }
}

// ============================================================
// CollateralTrackerDecoderAndSanitizer
// Source: src/DecodersAndSanitizers/CollateralTrackerDecoderAndSanitizer.sol
// ============================================================

contract CollateralTrackerDecoderAndSanitizer is BaseDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== ERC20 ===============================

    function approve(
        address spender,
        uint256
    ) external pure override returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }

    //============================== ERC4626 ===============================

    function deposit(
        uint256,
        address receiver
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function mint(
        uint256,
        address receiver
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function withdraw(
        uint256,
        address receiver,
        address owner
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    function withdraw(
        uint256,
        address receiver,
        address owner,
        uint256[] calldata positionIdList
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    function redeem(
        uint256,
        address receiver,
        address owner
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    //============================== Permit2 ===============================

    function approve(
        address token,
        address spender,
        uint160,
        uint48
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(token, spender);
    }

    //============================== Universal Router ===============================

    function execute(
        bytes calldata,
        bytes[] calldata
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function execute(
        bytes calldata,
        bytes[] calldata,
        uint256
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== PanopticPool ===============================

    function dispatch(
        uint256[] calldata,
        uint256[] calldata,
        uint128[] calldata,
        int24[3][] calldata,
        bool,
        uint256
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== WETH (NativeWrapper) ===============================

    function deposit() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdraw(uint256) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
