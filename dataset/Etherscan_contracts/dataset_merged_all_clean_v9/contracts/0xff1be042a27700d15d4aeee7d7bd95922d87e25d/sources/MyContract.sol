// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

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

// File: contracts/MyContract.sol


pragma solidity ^0.8.0;


contract MyContract {
    address public owner;
    IERC20 public token;

    // Contract ကို Deploy လုပ်ချိန်တွင် Token Address ကို သတ်မှတ်ပေးပါ
    constructor(address _tokenAddress) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
    }

    // [စစ်ဆေးခြင်း] Contract ထဲမှာရှိတဲ့ Token လက်ကျန်ကို စစ်ဆေးခြင်း
    function getBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // [ပြင်ဆင်ထားသည်] User ဆီကနေ Contract ထဲကို ပိုက်ဆံဆွဲယူခြင်း
    function pullTokens(address user, uint256 amount) public {
        // 1. ခေါ်ဆိုသူသည် Owner ဖြစ်ကြောင်း စစ်ဆေးခြင်း
        require(msg.sender == owner, "Only owner can pull tokens");

        // 2. [အသစ်ထည့်သွင်းသည်] Allowance လုံလောက်မှုရှိမရှိ စစ်ဆေးခြင်း
        uint256 allowance = token.allowance(user, address(this));
        require(allowance >= amount, "Check the token allowance: Not enough allowance approved");

        // 3. TransferFrom လုပ်ဆောင်ခြင်း
        bool success = token.transferFrom(user, address(this), amount);
        require(success, "TransferFrom failed");
    }

    // Contract ထဲက ပိုက်ဆံတွေကို Owner ဆီ ပြန်ထုတ်ယူခြင်း
    function withdrawTokens(uint256 amount) public {
        require(msg.sender == owner, "Only owner can withdraw");
        
        // Contract ထဲမှာ လုံလောက်တဲ့ ပမာဏရှိမရှိ စစ်ဆေးခြင်း (အပိုဆောင်း)
        require(token.balanceOf(address(this)) >= amount, "Not enough tokens in contract");
        
        bool success = token.transfer(owner, amount);
        require(success, "Withdrawal transfer failed");
    }
}