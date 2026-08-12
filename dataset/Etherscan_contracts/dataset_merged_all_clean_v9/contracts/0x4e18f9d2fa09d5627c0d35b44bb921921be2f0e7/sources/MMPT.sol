// SPDX-License-Identifier: MIT
pragma solidity =0.8.25 >=0.4.16 >=0.6.2 >=0.8.4 ^0.8.20;

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// src/vaults/FundingVault.sol

/**
 * @title FundingVault
 * @notice Funding Reserve 池（首三轮融资 + Future Funding Reserve）子合约，负责 Funding 池的释放逻辑校验和记录
 * @dev 代币实际由 MMPT 主合约持有，本合约仅做状态追踪和校验，实际转账在主合约执行
 */
contract FundingVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error FundingVault__InsufficientBalance();
    error FundingVault__Unauthorized();
    error FundingVault__IndexOutOfRange();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS & STATE
    //////////////////////////////////////////////////////////////*/
    uint256 public constant FUNDING_ALLOCATION = 100_000_000 * 1e18; // 1亿枚（10%）

    address public immutable mmpt; // MMPT 主合约地址

    uint256 public released; // 已释放累计量

    struct Release {
        address to;
        uint256 amount;
        string  purpose;
        uint256 releasedAt;
    }
    Release[] public releases;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event FundingReleased(address indexed to, uint256 amount, string purpose);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyMMPT() {
        if (msg.sender != mmpt) revert FundingVault__Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _mmpt, address /*_custodyGovernance*/) {
        mmpt = _mmpt;
    }

    /*//////////////////////////////////////////////////////////////
                           RELEASE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice 校验并记录 Funding 释放（由 MMPT 主合约调用）
     * @param to      代币接收地址
     * @param amount  释放数量（wei）
     * @param purpose 释放说明
     */
    function release(address to, uint256 amount, string calldata purpose) external onlyMMPT {
        if (released + amount > FUNDING_ALLOCATION) revert FundingVault__InsufficientBalance();
        released += amount;
        releases.push(Release({
            to: to,
            amount: amount,
            purpose: purpose,
            releasedAt: block.timestamp
        }));
        emit FundingReleased(to, amount, purpose);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice 查询 Funding 池剩余可释放余量
    function getBalance() external view returns (uint256) {
        return FUNDING_ALLOCATION - released;
    }

    /// @notice 查询释放记录总数
    function getReleaseCount() external view returns (uint256) {
        return releases.length;
    }

    /// @notice 查询指定索引的释放记录
    function getRelease(uint256 i) external view returns (Release memory) {
        if (i >= releases.length) revert FundingVault__IndexOutOfRange();
        return releases[i];
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// src/vaults/ReserveVault.sol

/**
 * @title ReserveVault
 * @notice 储备池（Reserve）子合约，负责 Reserve 池的释放逻辑校验和记录
 * @dev 代币实际由 MMPT 主合约持有，本合约仅做状态追踪和校验，实际转账在主合约执行
 */
contract ReserveVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ReserveVault__InsufficientBalance();
    error ReserveVault__Unauthorized();
    error ReserveVault__IndexOutOfRange();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS & STATE
    //////////////////////////////////////////////////////////////*/
    uint256 public constant RESERVE_ALLOCATION = 200_000_000 * 1e18; // 2亿枚（20%）

    address public immutable mmpt; // MMPT 主合约地址

    uint256 public released; // 已释放累计量

    struct Release {
        address to;
        uint256 amount;
        string  purpose;
        uint256 releasedAt;
    }
    Release[] public releases;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event ReserveReleased(address indexed to, uint256 amount, string purpose);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyMMPT() {
        if (msg.sender != mmpt) revert ReserveVault__Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _mmpt, address /*_custodyGovernance*/) {
        mmpt = _mmpt;
    }

    /*//////////////////////////////////////////////////////////////
                           RELEASE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice 校验并记录 Reserve 释放（由 MMPT 主合约调用）
     * @param to      代币接收地址
     * @param amount  释放数量（wei）
     * @param purpose 释放说明
     */
    function release(address to, uint256 amount, string calldata purpose) external onlyMMPT {
        if (released + amount > RESERVE_ALLOCATION) revert ReserveVault__InsufficientBalance();
        released += amount;
        releases.push(Release({
            to: to,
            amount: amount,
            purpose: purpose,
            releasedAt: block.timestamp
        }));
        emit ReserveReleased(to, amount, purpose);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice 查询 Reserve 池剩余可释放余量
    function getBalance() external view returns (uint256) {
        return RESERVE_ALLOCATION - released;
    }

    /// @notice 查询释放记录总数
    function getReleaseCount() external view returns (uint256) {
        return releases.length;
    }

    /// @notice 查询指定索引的释放记录
    function getRelease(uint256 i) external view returns (Release memory) {
        if (i >= releases.length) revert ReserveVault__IndexOutOfRange();
        return releases[i];
    }
}

// src/vaults/TreasuryVault.sol

/**
 * @title TreasuryVault
 * @notice 金库（Treasury）子合约，负责 Treasury 池的释放逻辑校验和记录
 * @dev 代币实际由 MMPT 主合约持有，本合约仅做状态追踪和校验，实际转账在主合约执行
 */
contract TreasuryVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error TreasuryVault__InsufficientBalance();
    error TreasuryVault__Unauthorized();
    error TreasuryVault__IndexOutOfRange();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS & STATE
    //////////////////////////////////////////////////////////////*/
    uint256 public constant TREASURY_ALLOCATION = 400_000_000 * 1e18; // 4亿枚（40%）

    address public immutable mmpt; // MMPT 主合约地址

    uint256 public released; // 已释放累计量

    struct Release {
        address to;
        uint256 amount;
        string  purpose;
        uint256 releasedAt;
    }
    Release[] public releases;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event TreasuryReleased(address indexed to, uint256 amount, string purpose);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyMMPT() {
        if (msg.sender != mmpt) revert TreasuryVault__Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _mmpt, address /*_custodyGovernance*/) {
        mmpt = _mmpt;
    }

    /*//////////////////////////////////////////////////////////////
                           RELEASE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice 校验并记录 Treasury 释放（由 MMPT 主合约调用）
     * @param to      代币接收地址
     * @param amount  释放数量（wei）
     * @param purpose 释放说明
     */
    function release(address to, uint256 amount, string calldata purpose) external onlyMMPT {
        if (released + amount > TREASURY_ALLOCATION) revert TreasuryVault__InsufficientBalance();
        released += amount;
        releases.push(Release({
            to: to,
            amount: amount,
            purpose: purpose,
            releasedAt: block.timestamp
        }));
        emit TreasuryReleased(to, amount, purpose);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice 查询 Treasury 池剩余可释放余量
    function getBalance() external view returns (uint256) {
        return TREASURY_ALLOCATION - released;
    }

    /// @notice 查询释放记录总数
    function getReleaseCount() external view returns (uint256) {
        return releases.length;
    }

    /// @notice 查询指定索引的释放记录
    function getRelease(uint256 i) external view returns (Release memory) {
        if (i >= releases.length) revert TreasuryVault__IndexOutOfRange();
        return releases[i];
    }
}

// src/vaults/VestingVault.sol

/**
 * @title VestingVault
 * @notice 归属池（Vesting）子合约，负责线性归属计划的逻辑校验和记录
 * @dev 代币实际由 MMPT 主合约持有，本合约仅做状态追踪和校验，实际转账在主合约执行
 */
contract VestingVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error VestingVault__Unauthorized();
    error VestingVault__InsufficientBalance();
    error VestingVault__NotFound();
    error VestingVault__NotBeneficiary();
    error VestingVault__NotMatured();
    error VestingVault__InvalidParams();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS & STATE
    //////////////////////////////////////////////////////////////*/
    uint256 public constant VESTING_ALLOCATION = 200_000_000 * 1e18; // 2亿枚

    address public immutable mmpt; // MMPT 主合约地址

    uint256 public vestingReserved; // 已预锁定量（含已 claim 和待 claim）

    struct VestingSchedule {
        address beneficiary;   // 受益人
        uint256 amount;        // 归属代币总量（wei）
        uint256 startTime;     // 线性释放起点（Unix时间戳）
        uint256 duration;      // 线性释放持续时长（秒）
        uint256 claimedAmount; // 已累计提取量
        string  purpose;       // 用途说明
    }
    VestingSchedule[] public vestingSchedules;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event VestingScheduleCreated(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    );
    event VestingClaimed(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyMMPT() {
        if (msg.sender != mmpt) revert VestingVault__Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _mmpt, address /*_custodyGovernance*/) {
        mmpt = _mmpt;
    }

    /*//////////////////////////////////////////////////////////////
                        SCHEDULE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice 创建线性归属计划（由 MMPT 主合约调用，已在主合约完成权限校验）
     * @param beneficiary 受益人地址
     * @param amount      归属代币总量（wei）
     * @param startTime   线性释放起点，必须严格大于 block.timestamp（即未来时间）
     * @param duration    线性释放持续时长（秒）
     * @param purpose     用途说明
     * @return scheduleId 新计划在数组中的索引
     */
    function createSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        string calldata purpose
    ) external onlyMMPT returns (uint256 scheduleId) {
        if (beneficiary == address(0) || amount == 0 || duration == 0 || startTime <= block.timestamp)
            revert VestingVault__InvalidParams();
        if (vestingReserved + amount > VESTING_ALLOCATION)
            revert VestingVault__InsufficientBalance();

        vestingReserved += amount;

        scheduleId = vestingSchedules.length;
        vestingSchedules.push(VestingSchedule({
            beneficiary: beneficiary,
            amount: amount,
            startTime: startTime,
            duration: duration,
            claimedAmount: 0,
            purpose: purpose
        }));

        emit VestingScheduleCreated(scheduleId, beneficiary, amount, startTime, duration);
    }

    /**
     * @notice 校验受益人并计算可提取量（由 MMPT 主合约调用，主合约负责实际转账）
     * @param scheduleId 归属计划索引
     * @param caller     调用者地址（即受益人，由主合约传入）
     * @return claimable 本次可提取数量
     */
    function claim(uint256 scheduleId, address caller) external onlyMMPT returns (uint256 claimable) {
        if (scheduleId >= vestingSchedules.length) revert VestingVault__NotFound();

        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        if (schedule.beneficiary != caller) revert VestingVault__NotBeneficiary();

        claimable = _vestedAmount(schedule) - schedule.claimedAmount;
        if (claimable == 0) revert VestingVault__NotMatured();

        schedule.claimedAmount += claimable;
        emit VestingClaimed(scheduleId, caller, claimable);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice 查询 Vesting 池剩余可创建计划的额度（未预锁定量）
    function getBalance() external view returns (uint256) {
        return VESTING_ALLOCATION - vestingReserved;
    }

    /// @notice 查询所有计划已累计 claim 的总量（已离开主合约的代币）
    function getClaimedTotal() external view returns (uint256 total) {
        uint256 len = vestingSchedules.length;
        for (uint256 i = 0; i < len; ++i) {
            total += vestingSchedules[i].claimedAmount;
        }
    }

    /// @notice 查询主合约当前为 Vesting 实际托管的代币量（已预锁定但未 claim）
    function getLockedBalance() external view returns (uint256 total) {
        uint256 len = vestingSchedules.length;
        for (uint256 i = 0; i < len; ++i) {
            VestingSchedule storage s = vestingSchedules[i];
            if (s.amount > s.claimedAmount) {
                total += s.amount - s.claimedAmount;
            }
        }
    }

    /// @notice 查询归属计划总数
    function getScheduleCount() external view returns (uint256) {
        return vestingSchedules.length;
    }

    /// @notice 查询指定归属计划详情
    function getSchedule(uint256 scheduleId) external view returns (VestingSchedule memory) {
        if (scheduleId >= vestingSchedules.length) revert VestingVault__NotFound();
        return vestingSchedules[scheduleId];
    }

    /// @notice 查询指定计划当前可提取数量
    function getClaimableAmount(uint256 scheduleId) external view returns (uint256) {
        if (scheduleId >= vestingSchedules.length) revert VestingVault__NotFound();
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        uint256 vested = _vestedAmount(schedule);
        if (vested <= schedule.claimedAmount) return 0;
        return vested - schedule.claimedAmount;
    }

    /// @notice 查询指定计划当前已归属总量
    function vestedAmount(uint256 scheduleId) external view returns (uint256) {
        if (scheduleId >= vestingSchedules.length) revert VestingVault__NotFound();
        return _vestedAmount(vestingSchedules[scheduleId]);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @dev 根据当前时间计算线性已归属量
    function _vestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime) return 0;
        uint256 elapsed = block.timestamp - schedule.startTime;
        if (elapsed >= schedule.duration) return schedule.amount;
        return (schedule.amount * elapsed) / schedule.duration;
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol

// OpenZeppelin Contracts (last updated v5.5.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-721.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol

// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * Both values are immutable: they can only be set once during construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /// @inheritdoc IERC20
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner`'s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation sets the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the `transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// src/MMPT.sol

contract MMPT is ERC20 {

    error MMPT__InvalidAddress();
    error MMPT__InvalidAmount();
    error MMPT__GovernanceTransferToZero();
    error MMPT__NotAuthorizedGovernance();
    error MMPT__UseCreateVestingSchedule();
    error MMPT__VestingHasNoReleaseRecords();
    error MMPT__NoPendingGovernance();
    error MMPT__NoETHToWithdraw();
    error MMPT__ETHTransferFailed();
    error MMPT__InvalidVaultType();

    uint256 public constant MAX_SUPPLY          = 1_000_000_000 * 1e18;
    uint256 public constant INITIAL_CIRCULATION = 100_000_000  * 1e18;
    uint256 public constant TREASURY_ALLOCATION = 400_000_000  * 1e18;
    uint256 public constant VESTING_ALLOCATION  = 200_000_000  * 1e18;
    uint256 public constant RESERVE_ALLOCATION  = 200_000_000  * 1e18;
    uint256 public constant FUNDING_ALLOCATION  = 100_000_000  * 1e18;

    enum VaultType { Treasury, Vesting, Reserve, Funding }

    TreasuryVault public treasuryVault;
    VestingVault  public vestingVault;
    ReserveVault  public reserveVault;
    FundingVault  public fundingVault;

    address public assetSPV;
    address public issuanceSPV;
    address public custodyGovernance;
    address public pendingGovernance;

    event TokensMinted(address indexed to, uint256 amount, string purpose);
    event VaultReleased(VaultType indexed vault, address indexed to, uint256 amount, string purpose);
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);
    event GovernanceTransferProposed(address indexed currentGovernance, address indexed pendingGovernance);
    event GovernanceTransferCancelled(address indexed cancelledBy, address indexed cancelledPending);
    event AssetSPVUpdated(address indexed previous, address indexed next);
    event IssuanceSPVUpdated(address indexed previous, address indexed next);

    constructor(
        address _assetSPV,
        address _issuanceSPV,
        address _custodyGovernance
    ) ERC20("Mancala Mining Portfolio Token", "MMPT") {
        if (_assetSPV == address(0) || _issuanceSPV == address(0) || _custodyGovernance == address(0))
            revert MMPT__InvalidAddress();

        assetSPV          = _assetSPV;
        issuanceSPV       = _issuanceSPV;
        custodyGovernance = _custodyGovernance;

        _mint(_issuanceSPV, INITIAL_CIRCULATION);
        emit TokensMinted(_issuanceSPV, INITIAL_CIRCULATION, "Initial Circulation");

        uint256 vaultTotal = TREASURY_ALLOCATION + VESTING_ALLOCATION + RESERVE_ALLOCATION + FUNDING_ALLOCATION;
        _mint(address(this), vaultTotal);
        emit TokensMinted(address(this), vaultTotal, "Vault Reserves");

        treasuryVault = new TreasuryVault(address(this), _custodyGovernance);
        vestingVault  = new VestingVault(address(this), _custodyGovernance);
        reserveVault  = new ReserveVault(address(this), _custodyGovernance);
        fundingVault  = new FundingVault(address(this), _custodyGovernance);
    }

    function getLayerInfo() external view returns (
        address _assetSPV,
        address _issuanceSPV,
        address _custodyGovernance
    ) {
        return (assetSPV, issuanceSPV, custodyGovernance);
    }

    modifier onlyCustodyGovernance() {
        if (msg.sender != custodyGovernance) revert MMPT__NotAuthorizedGovernance();
        _;
    }

    function proposeGovernanceTransfer(address newGovernance) external onlyCustodyGovernance {
        if (newGovernance == address(0)) revert MMPT__GovernanceTransferToZero();
        pendingGovernance = newGovernance;
        emit GovernanceTransferProposed(custodyGovernance, newGovernance);
    }

    function acceptGovernance() external {
        if (msg.sender != pendingGovernance) revert MMPT__NotAuthorizedGovernance();
        emit GovernanceTransferred(custodyGovernance, pendingGovernance);
        custodyGovernance = pendingGovernance;
        pendingGovernance = address(0);
    }

    function cancelGovernanceTransfer() external onlyCustodyGovernance {
        if (pendingGovernance == address(0)) revert MMPT__NoPendingGovernance();
        emit GovernanceTransferCancelled(msg.sender, pendingGovernance);
        pendingGovernance = address(0);
    }

    function updateAssetSPV(address newAssetSPV) external onlyCustodyGovernance {
        if (newAssetSPV == address(0)) revert MMPT__InvalidAddress();
        emit AssetSPVUpdated(assetSPV, newAssetSPV);
        assetSPV = newAssetSPV;
    }

    function updateIssuanceSPV(address newIssuanceSPV) external onlyCustodyGovernance {
        if (newIssuanceSPV == address(0)) revert MMPT__InvalidAddress();
        emit IssuanceSPVUpdated(issuanceSPV, newIssuanceSPV);
        issuanceSPV = newIssuanceSPV;
    }

    function releaseFromVault(
        VaultType vault,
        address to,
        uint256 amount,
        string calldata purpose
    ) external onlyCustodyGovernance {
        if (to == address(0)) revert MMPT__InvalidAddress();
        if (amount == 0) revert MMPT__InvalidAmount();

        if (vault == VaultType.Treasury) {
            treasuryVault.release(to, amount, purpose);
        } else if (vault == VaultType.Vesting) {
            revert MMPT__UseCreateVestingSchedule();
        } else if (vault == VaultType.Funding) {
            fundingVault.release(to, amount, purpose);
        } else if (vault == VaultType.Reserve) {
            reserveVault.release(to, amount, purpose);
        } else {
            revert MMPT__InvalidVaultType();
        }

        _transfer(address(this), to, amount);
        emit VaultReleased(vault, to, amount, purpose);
    }

    function getVaultBalance(VaultType vault) external view returns (uint256) {
        if (vault == VaultType.Treasury) return treasuryVault.getBalance();
        if (vault == VaultType.Vesting)  return vestingVault.getBalance();
        if (vault == VaultType.Reserve)  return reserveVault.getBalance();
        if (vault == VaultType.Funding)  return fundingVault.getBalance();
        revert MMPT__InvalidVaultType();
    }

    function getVaultReconciliation() external view returns (
        uint256 actualBalance,
        uint256 accountedBalance
    ) {
        actualBalance    = balanceOf(address(this));
        accountedBalance = treasuryVault.getBalance()
                         + (VESTING_ALLOCATION - vestingVault.getClaimedTotal())
                         + reserveVault.getBalance()
                         + fundingVault.getBalance();
    }

    function getVaultReleaseCount() external view returns (uint256) {
        return treasuryVault.getReleaseCount() + reserveVault.getReleaseCount() + fundingVault.getReleaseCount();
    }

    function getVaultRelease(VaultType vault, uint256 index)
        external view
        returns (address to, uint256 amount, string memory purpose, uint256 releasedAt)
    {
        if (vault == VaultType.Treasury) {
            TreasuryVault.Release memory r = treasuryVault.getRelease(index);
            return (r.to, r.amount, r.purpose, r.releasedAt);
        } else if (vault == VaultType.Reserve) {
            ReserveVault.Release memory r = reserveVault.getRelease(index);
            return (r.to, r.amount, r.purpose, r.releasedAt);
        } else if (vault == VaultType.Funding) {
            FundingVault.Release memory r = fundingVault.getRelease(index);
            return (r.to, r.amount, r.purpose, r.releasedAt);
        } else {
            revert MMPT__VestingHasNoReleaseRecords();
        }
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        string calldata purpose
    ) external onlyCustodyGovernance returns (uint256 scheduleId) {
        return vestingVault.createSchedule(beneficiary, amount, startTime, duration, purpose);
    }

    function claimVesting(uint256 scheduleId) external {
        uint256 claimable = vestingVault.claim(scheduleId, msg.sender);
        _transfer(address(this), msg.sender, claimable);
    }

    function getVestingSchedule(uint256 scheduleId)
        external view
        returns (VestingVault.VestingSchedule memory)
    {
        return vestingVault.getSchedule(scheduleId);
    }

    function getVestingScheduleCount() external view returns (uint256) {
        return vestingVault.getScheduleCount();
    }

    function getClaimableAmount(uint256 scheduleId) external view returns (uint256) {
        return vestingVault.getClaimableAmount(scheduleId);
    }

    function withdrawETH() external onlyCustodyGovernance {
        uint256 bal = address(this).balance;
        if (bal == 0) revert MMPT__NoETHToWithdraw();
        (bool ok,) = custodyGovernance.call{value: bal}("");
        if (!ok) revert MMPT__ETHTransferFailed();
    }

    receive() external payable {}
}