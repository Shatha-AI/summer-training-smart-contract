// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC20 interface, only includes functions required by this contract.
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title   UniversalPiggyBank
 * @author  zwz
 * @notice  A piggy bank supporting native token (ETH) and any ERC20 token.
 * @dev     Follows CEI pattern with ReentrancyGuard. Compatible with Fee-on-Transfer tokens.
 */
contract UniversalPiggyBank {

    // ============================================================
    //  自定义错误（比 require + string 更省 gas）
    // ============================================================

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientNativeBalance(uint256 available, uint256 requested);
    error InsufficientERC20Balance(uint256 available, uint256 requested);
    error NativeTransferFailed();
    error ERC20TransferFailed();
    error Reentrant();

    // ============================================================
    //  防重入锁（手动实现，不引入外部依赖）
    // ============================================================

    uint256 private _lockStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        if (_lockStatus == _ENTERED) revert Reentrant();
        _lockStatus = _ENTERED;
        _;
        _lockStatus = _NOT_ENTERED;
    }

    constructor() {
        _lockStatus = _NOT_ENTERED;
    }

    // ============================================================
    //  账本
    // ============================================================

    /// @notice Maps user address to their native ETH balance (wei).
    mapping(address => uint256) public nativeBalances;

    /// @notice Maps user address => token contract address => ERC20 balance (actual received amount).
    mapping(address => mapping(address => uint256)) public erc20Balances;

    // ============================================================
    //  事件
    // ============================================================

    event NativeDeposited(address indexed user, uint256 amount);
    event NativeWithdrawn(address indexed user, uint256 amount);
    event ERC20Deposited(address indexed user, address indexed token, uint256 actualAmount);
    event ERC20Withdrawn(address indexed user, address indexed token, uint256 amount);

    // ============================================================
    //  原生代币（ETH）逻辑
    // ============================================================

    /**
     * @notice Deposit native ETH into the piggy bank.
     * @dev    Send ETH along with this call; msg.value is the deposit amount.
     */
    function depositNative() public payable {
        if (msg.value == 0) revert ZeroAmount();
        nativeBalances[msg.sender] += msg.value;
        emit NativeDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw native ETH from the piggy bank.
     * @dev    Follows CEI pattern: state updated before external call to prevent reentrancy.
     * @param  _amount Amount to withdraw in wei.
     */
    function withdrawNative(uint256 _amount) public nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        uint256 bal = nativeBalances[msg.sender];
        if (bal < _amount) revert InsufficientNativeBalance(bal, _amount);

        // 先改状态（Effects）
        nativeBalances[msg.sender] = bal - _amount;

        // 再外部调用（Interactions）
        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert NativeTransferFailed();

        emit NativeWithdrawn(msg.sender, _amount);
    }

    // ============================================================
    //  ERC20 代币逻辑
    // ============================================================

    /**
     * @notice Deposit ERC20 tokens into the piggy bank.
     * @dev    Caller must approve this contract on the token contract before calling.
     *         Records actual received amount to support Fee-on-Transfer tokens.
     * @param  _tokenAddress The ERC20 token contract address.
     * @param  _amount       Expected deposit amount (in token's smallest unit).
     */
    function depositERC20(address _tokenAddress, uint256 _amount) public nonReentrant {
        if (_tokenAddress == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        IERC20 token = IERC20(_tokenAddress);

        // 转账前快照余额，用于计算实际到账量（兼容扣税代币）
        uint256 balanceBefore = token.balanceOf(address(this));

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert ERC20TransferFailed();

        // 实际到账量 = 转账后余额 - 转账前余额
        uint256 actualAmount = token.balanceOf(address(this)) - balanceBefore;
        if (actualAmount == 0) revert ZeroAmount();

        erc20Balances[msg.sender][_tokenAddress] += actualAmount;
        emit ERC20Deposited(msg.sender, _tokenAddress, actualAmount);
    }

    /**
     * @notice Withdraw ERC20 tokens from the piggy bank.
     * @dev    Follows CEI pattern: state updated before external call.
     * @param  _tokenAddress The ERC20 token contract address.
     * @param  _amount       Amount to withdraw.
     */
    function withdrawERC20(address _tokenAddress, uint256 _amount) public nonReentrant {
        if (_tokenAddress == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        uint256 bal = erc20Balances[msg.sender][_tokenAddress];
        if (bal < _amount) revert InsufficientERC20Balance(bal, _amount);

        // 先改状态（Effects）
        erc20Balances[msg.sender][_tokenAddress] = bal - _amount;

        // 再外部调用（Interactions）
        IERC20 token = IERC20(_tokenAddress);
        bool success = token.transfer(msg.sender, _amount);
        if (!success) revert ERC20TransferFailed();

        emit ERC20Withdrawn(msg.sender, _tokenAddress, _amount);
    }

    // ============================================================
    //  查询工具
    // ============================================================

    /**
     * @notice Returns the native ETH balance of a user.
     * @param  _user The user's address.
     * @return Native ETH balance in wei.
     */
    function getNativeBalance(address _user) external view returns (uint256) {
        return nativeBalances[_user];
    }

    /**
     * @notice Returns the ERC20 token balance of a user.
     * @param  _user         The user's address.
     * @param  _tokenAddress The ERC20 token contract address.
     * @return ERC20 token balance.
     */
    function getERC20Balance(address _user, address _tokenAddress) external view returns (uint256) {
        return erc20Balances[_user][_tokenAddress];
    }

    // ============================================================
    //  Fallback / Receive
    // ============================================================

    /**
     * @notice Accepts plain ETH transfers (no calldata). Automatically credited to sender's balance.
     * @dev    Reverts on zero-value transfers to avoid emitting useless events.
     */
    receive() external payable {
        if (msg.value == 0) revert ZeroAmount();
        nativeBalances[msg.sender] += msg.value;
        emit NativeDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Handles calls with unrecognized function selectors.
     * @dev    If ETH is attached, credits it to sender's balance. Otherwise reverts.
     */
    fallback() external payable {
        if (msg.value > 0) {
            nativeBalances[msg.sender] += msg.value;
            emit NativeDeposited(msg.sender, msg.value);
        } else {
            revert ZeroAmount();
        }
    }
}