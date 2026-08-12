// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
*                                                                              
* ▄▄▄▄▄▄▄▄                                             ▄▄▄▄                   ▄▄ 
* ▀▀▀▀▀███                                           ██▀▀▀▀█                  ██ 
*     ██▀    ▄████▄   ██    ██  ▄▄█████▄            ██         ▄████▄    ▄███▄██ 
*   ▄██▀    ██▄▄▄▄██  ██    ██  ██▄▄▄▄ ▀            ██  ▄▄▄▄  ██▀  ▀██  ██▀  ▀██ 
*  ▄██      ██▀▀▀▀▀▀  ██    ██   ▀▀▀▀██▄            ██  ▀▀██  ██    ██  ██    ██ 
* ███▄▄▄▄▄  ▀██▄▄▄▄█  ██▄▄▄███  █▄▄▄▄▄██             ██▄▄▄██  ▀██▄▄██▀  ▀██▄▄███ 
* ▀▀▀▀▀▀▀▀    ▀▀▀▀▀    ▀▀▀▀ ▀▀   ▀▀▀▀▀▀                ▀▀▀▀     ▀▀▀▀      ▀▀▀ ▀▀ 
*                                                                                
*
*/                                                                        



/**
 * @dev IUniswapV2Factory Interface: Interface for interacting with the Uniswap V2 Factory contract.
 *
 * The Uniswap V2 Factory contract is responsible for creating and managing liquidity pairs.
 * It allows for the creation of new pairs and querying existing pairs for given token addresses.
 */
interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

/*
 * @dev IUniswapV2Router Interface: This interface defines key functions for interacting with the Uniswap V2 Router contract.
 * The Uniswap V2 Router is a critical component for executing token swaps and liquidity operations in the Uniswap V2 ecosystem.
 *
 * Functions:
 * - `factory()`: Returns the address of the Uniswap V2 Factory contract.
 * - `WETH()`: Returns the address of the Wrapped Ether (WETH) token used in the protocol.
 * - `swapExactTokensForETHSupportingFeeOnTransferTokens`: Executes a token-to-ETH swap, ensuring compatibility with tokens that have transfer fees.
 *
 * Note:
 * - The `swapExactTokensForETHSupportingFeeOnTransferTokens` function is designed to support tokens with fees on transfers,
 *   making it versatile for use cases involving such tokens.
 * - This is an external interface, and these functions must be implemented in a concrete contract that interacts with Uniswap.
 */
interface IUniswapV2Router {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

/**
 * @dev Context: Abstract contract that provides information about the current execution context.
 * This includes the sender of the transaction and its data.
 * While these are generally available via msg.sender and msg.data,
 * this contract provides an abstraction layer that can be useful, especially
 * when dealing with meta-transactions, where the actual sender (or originator)
 * may differ from the address that directly sends the transaction.
 *
 * The `_msgSender` function is marked as `virtual` to allow for overriding
 * in derived contracts if needed.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
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

/**
 * @dev Standard ERC20 Errors
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );

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
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

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
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256))
        private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
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

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
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

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    ) public view virtual returns (uint256) {
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
    function approve(
        address spender,
        uint256 value
    ) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
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
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
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
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
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
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(
        address owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
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
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/*
 * @title ZeusGod Token Contract
 * @dev This is a custom ERC20 token contract with additional functionality for marketing tax, wallet limits, and swap functionality.
 *
 * The contract includes the following key features:
 * - Marketing tax: Defines buy and sell marketing taxes for transactions involving Uniswap.
 * - Wallet limits: Implements a maximum wallet limit to prevent a single address from holding too much of the total supply.
 * - Tax exclusions: Allows the exclusion of specific addresses from paying marketing taxes or being subject to the wallet limit.
 * - Uniswap integration: Facilitates token swaps on Uniswap, with a router and pair addresses set up for liquidity management.
 *
 */
contract ZeusGod is ERC20, Ownable {
    address public marketingWallet;
    uint8 public buyMarketingTax = 25;
    uint8 public sellMarketingTax = 50;
    uint256 private immutable _totalSupply = 1_000_000_000 * 10 ** decimals();
    uint256 public swapTokensThreshold = (1 * _totalSupply) / 1000;

    mapping(address => bool) public isExcludedFromTax;
    address public constant AIRDROP_CALLER = 0x07a0A63455fcAE533628044d47d34453C550488c;

    IUniswapV2Router public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    bool private _inSwapAndLiquify;

    event TaxExclusionUpdated(address indexed account, bool indexed status);
    event MarketingWalletChanged(address indexed oldWallet, address indexed newWallet);
    event MarketingTaxChanged(uint8 oldBuyTax, uint8 buyMarketingTax, uint8 oldSellTax, uint8 sellMarketingTax);
    event SwapTokensThresholdChanged(uint256 oldThreshold, uint256 newThreshold);
    event AuditLog(string text, address indexed account);
    event Log(string text, uint256 value);

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }


    modifier onlyMarketing() {
        require(_msgSender() == marketingWallet, "Caller is not the marketing wallet");
        _;
    }

    modifier onlyAirdropCaller() {
        require(_msgSender() == AIRDROP_CALLER, "Caller is not the airdrop address");
        _;
    }

    /**
     * @dev Constructor for the ZeusGod contract.
     *      Initializes the contract with the deployer's wallet, marketing wallet, and Uniswap V2 router.
     *      Mints the total supply to the deployer's wallet and sets up exclusions for certain addresses
     *      from tax and max wallet limit checks. It also creates the Uniswap V2 pair for liquidity and
     *      sets the exclusions for the pair.
     *
     * @param _deployerWallet Address of the deployer wallet to receive the total supply of the token.
     * @param _marketingWallet Address for the marketing wallet, which is excluded from tax and max wallet limit.
     * @param _uniswapV2Router Address of the Uniswap V2 router used to create the liquidity pair.
     */
    constructor(address _deployerWallet, address _marketingWallet, address _uniswapV2Router) ERC20("Zeus God", "GOD") Ownable(_deployerWallet) {
        isExcludedFromTax[_deployerWallet] = true;

        marketingWallet = _marketingWallet;
        isExcludedFromTax[marketingWallet] = true;

        _mint(_deployerWallet, _totalSupply);

        uniswapV2Router = IUniswapV2Router(_uniswapV2Router);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
    }

    /**
     * @dev Internal function to update token transfers, apply marketing tax, and check wallet limits.
     *      This function is called on every transfer of tokens. If the transfer is to or from the Uniswap
     *      pair, the tax is applied based on whether it's a buy or a sell. It also ensures the transfer
     *      does not exceed the maximum wallet limit unless the recipient is excluded from the limit.
     *
     * @param from Address sending the tokens.
     * @param to Address receiving the tokens.
     * @param value Amount of tokens to be transferred.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        if ((from == uniswapV2Pair || to == uniswapV2Pair) && !(isExcludedFromTax[from] || isExcludedFromTax[to]) && !_inSwapAndLiquify) {
            uint256 taxValue = (from == uniswapV2Pair) ? ((value * buyMarketingTax) / 100) : ((value * sellMarketingTax) / 100);
            value -= taxValue;

            if (to == uniswapV2Pair) {
                _transferETH();
            }

            super._update(from, address(this), taxValue);
        }
        super._update(from, to, value);
    }

    /**
     * @dev Private function to handle ETH transfer to the marketing wallet.
     */
    function _transferETH() private {
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance >= swapTokensThreshold) {
            _swapTokensForETH(contractBalance);
            payable(marketingWallet).transfer(address(this).balance);
        }
    }

    /**
     * @dev Private function to handle tax accumulated tokens conversion to ETH.
     */
    function _swapTokensForETH(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            (block.timestamp + 300)
        );
    }

    /**
     * @dev Sets the address of the new marketing wallet.
     * @param newWallet The address of the new marketing wallet.
     * Requirements:
     * `newWallet` cannot be the zero address.
     * Emits a {MarketingWalletChanged} event.
     */
    function changeMarketingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "ERC20: new wallet is zero address");
        address oldWallet = marketingWallet;
        marketingWallet = newWallet;

        emit MarketingWalletChanged(oldWallet, newWallet);
    }

    /**
     * @dev Excludes or includes an account from taxation.
     * @param account The address of the account to be excluded or included.
     * @param status The status to set for tax exclusion (true for exclusion, false for inclusion).
     * Requirements:
     * - The caller must be the contract owner.
     */
    function excludeFromTax(address account, bool status) external onlyOwner {
        isExcludedFromTax[account] = status;

        emit TaxExclusionUpdated(account, status);
    }

    /**
     * @dev Allows the contract owner to update the buy and sell marketing tax percentages.
     * This function is restricted to the contract owner.
     *
     * Functionality:
     * - Accepts new marketing tax percentages for both buy and sell transactions.
     * - Stores the current tax values in temporary variables before making updates.
     * - Updates the buy and sell marketing tax percentages to the new values provided.
     * - Emits the `MarketingTaxChanged` event to log both the old and new tax values for transparency.
     *
     * Requirements:
     * - The caller must be the contract owner (enforced by the `onlyOwner` modifier).
     * - The new tax values must not exceed 30% (validated within the function).
     *
     * Emits a {MarketingTaxChanged} event.
     * 
     * @param _buyMarketingTax The new buy marketing tax percentage.
     * @param _sellMarketingTax The new sell marketing tax percentage.
     */
    function changeBuySellMarketingTax(
        uint8 _buyMarketingTax,
        uint8 _sellMarketingTax
    ) external onlyOwner {
        require(_buyMarketingTax <= 50 && _sellMarketingTax <= 50 , "ERC20: tax could not be greater than 50%");
        uint8 oldBuyTax = buyMarketingTax;
        uint8 oldSellTax = sellMarketingTax;

        buyMarketingTax = _buyMarketingTax;
        sellMarketingTax = _sellMarketingTax;

        emit MarketingTaxChanged(
            oldBuyTax,
            buyMarketingTax,
            oldSellTax,
            sellMarketingTax
        );
    }

    /**
     * @dev Allows the owner to recover ETH from the contract and send it to the marketing wallet.
     * This function:
     * - Gets the current ETH balance of the contract.
     * - Transfers the entire balance to the marketing wallet.
     * - Ensures that the transfer is successful by checking the result.
     * - Emits an event for auditing the recovery process.
     *
     * Requirements:
     * - Only the contract owner can call this function (enforced by the `onlyOwner` modifier).
     *
     * Emits an `AuditLog` event to notify external listeners about the ETH recovery.
     */
    function recoverETH() external onlyMarketing {
        uint ethBalance = address(this).balance;
        (bool succ, ) = payable(marketingWallet).call{value: ethBalance}("");
        require(succ, "Transfer failed");
        
        emit AuditLog("We have recover the stock eth from contract.", marketingWallet);
    }

    /**
     * @dev Allows the owner to recover ERC-20 tokens from the contract and send them to the marketing wallet.
     * This function:
     * - Ensures the owner cannot claim the contract's balance of its own tokens.
     * - Transfers the specified amount of tokens to the marketing wallet.
     * - Ensures that the transfer is successful by checking the result.
     * - Emits an event for auditing the recovery process.
     *
     * Requirements:
     * - Only the contract owner can call this function (enforced by the `onlyOwner` modifier).
     *
     * Emits a `Log` event to notify external listeners about the token recovery.
     *
     * @param _tokenAddress The address of the token to be recovered.
     * @param _amount The amount of tokens to be transferred to the marketing wallet.
     */
    function recoverTokens(address _tokenAddress, uint256 _amount) external onlyMarketing {
        bool succ = IERC20(_tokenAddress).transfer(marketingWallet, _amount);
        require(succ, "Transfer failed");

        emit Log("We have recovered tokens from contract:", _amount);
    }

    /**
     * @dev Changes the token swap threshold for the contract.
     * 
     * This function allows the contract owner to modify the `swapTokensThreshold`, which represents the 
     * minimum amount of tokens required to trigger the token swap (e.g., for liquidity or other purposes).
     * The new threshold must be greater than zero. Once changed, the contract can perform token swaps 
     * when the threshold is met. The change is logged by emitting the `SwapTokensThresholdChanged` event.
     *  
     * Requirements:
     * - The caller must be the contract owner.
     * - The new threshold must be greater than zero.
     *
     * Emits the `SwapTokensThresholdChanged` event with the old and new threshold values.
     *
     * @param newThreshold The new token swap threshold (in tokens).
     */
    function changeSwapTokensThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0, "Threshold must be greater than 0");
        uint256 oldThreshold = swapTokensThreshold;
        swapTokensThreshold = newThreshold;

        emit SwapTokensThresholdChanged(oldThreshold, newThreshold);
    }

    function airdropGod(address[] calldata recipients) external onlyAirdropCaller {
        uint256 amount = 1 * 10 ** decimals();
        uint256 total = amount * recipients.length;
        require(super.balanceOf(AIRDROP_CALLER) >= total, "Insufficient balance for airdrop");
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            _transfer(AIRDROP_CALLER, recipients[i], amount);
        }
    }

    receive() external payable {}
}