// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================================
//  TetherToken — AUTHENTIC port of the real Ethereum USDT
//  Mirrors 0xdAC17F958D2ee523a2206206994597C13D831ec7 at the INTERFACE +
//  BEHAVIOR level, so you can read the real USDT's quirks in modern Solidity.
//
//  The real contract was written in solc 0.4.17. This is 0.8.24, so the
//  BYTECODE can never be identical — but every quirk that an integrator could
//  observe (return values, decimals type, missing checks, forwarding) is
//  reproduced and marked  // USDT QUIRK:  below.
//
//  LEARNING ARTIFACT ONLY. Not Tether. Not real USDT. Backed by nothing. $0.
//  Deviations kept for teaching: revert strings are added (real USDT has bare
//  require()s) and Solidity 0.8 checked math replaces the old SafeMath library.
// =============================================================================

contract Ownable {
    // USDT QUIRK: `owner` is a plain public state variable (auto getter owner()).
    // The real Ownable has NO OwnershipTransferred event at all.
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: not owner");
        _;
    }

    // USDT QUIRK: transferring ownership to address(0) is SILENTLY IGNORED —
    // no revert, no event. A fat-fingered 0x0 just does nothing.
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}

contract BasicToken is Ownable {
    mapping(address => uint256) public balances;

    // Optional transfer fee. USDT *can* charge it but never has.
    uint256 public basisPointsRate;
    uint256 public maximumFee;

    uint256 internal _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);

    // USDT QUIRK: the 2017 "short address attack" guard. It requires the calldata
    // to be at least as long as the declared arguments (size + 4-byte selector).
    // OBSOLETE since solc 0.5 — the ABI decoder already reverts on truncated
    // calldata — but the real contract still carries it, so it's kept here.
    modifier onlyPayloadSize(uint256 size) {
        require(msg.data.length >= size + 4, "Tether: bad payload size");
        _;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return balances[account];
    }

    // USDT QUIRK: transfer returns NOTHING (no `bool`). This breaks the ERC-20
    // spec and is THE reason OpenZeppelin's SafeERC20 exists — `bool ok =
    // usdt.transfer(...)` reverts against real USDT because the ABI decoder
    // expects 32 bytes of return data and gets none.
    function transfer(address to, uint256 value) public virtual onlyPayloadSize(2 * 32) {
        _transfer(msg.sender, to, value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        // Extension hook for time-based rules (locks / expiry). No-op in the
        // authentic mirror; overridden by TimeLockedTetherToken at end of file.
        _beforeTransfer(from, to, value);
        // USDT QUIRK: NO `require(to != address(0))`. Sending to 0x0 silently
        // burns your tokens.
        uint256 fee = (value * basisPointsRate) / 10_000;
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        uint256 sendAmount = value - fee;

        balances[from] -= value; // reverts on insufficient balance (0.8 checked math)
        balances[to] += sendAmount;
        if (fee > 0) {
            // The fee is skimmed to the owner, not burned.
            balances[owner] += fee;
            emit Transfer(from, owner, fee);
        }
        emit Transfer(from, to, sendAmount);
    }

    /// @dev Extension point for time-based rules (locks / expiry). A no-op here so
    ///      the authentic USDT mirror behaves identically; overridden by
    ///      TimeLockedTetherToken at the bottom of this file. `view`: reads only.
    function _beforeTransfer(address from, address to, uint256 value) internal view virtual {}
}

contract StandardToken is BasicToken {
    mapping(address => mapping(address => uint256)) public allowed;

    uint256 public constant MAX_UINT = type(uint256).max;

    event Approval(address indexed tokenOwner, address indexed spender, uint256 value);

    // USDT QUIRK: transferFrom returns NOTHING either.
    function transferFrom(address from, address to, uint256 value)
        public
        virtual
        onlyPayloadSize(3 * 32)
    {
        _transferFrom(msg.sender, from, to, value);
    }

    function _transferFrom(address spender, address from, address to, uint256 value) internal {
        uint256 currentAllowance = allowed[from][spender];

        // USDT QUIRK: no explicit `require(allowance >= value)`. The subtraction
        // below reverts on underflow — real USDT relied on SafeMath.sub throwing.
        //
        // USDT QUIRK: an allowance of MAX_UINT is treated as INFINITE and is
        // never decremented (permanent approval / gas save).
        if (currentAllowance != MAX_UINT) {
            allowed[from][spender] = currentAllowance - value;
        }

        _transfer(from, to, value);
    }

    // USDT QUIRK: approve returns NOTHING, and enforces the "approve race" guard:
    // you cannot change a non-zero allowance straight to another non-zero value.
    // You must approve(0) first, then approve(newValue). Meant to blunt the
    // classic ERC-20 approve front-running race.
    function approve(address spender, uint256 value) public virtual onlyPayloadSize(2 * 32) {
        _approve(msg.sender, spender, value);
    }

    function _approve(address holder, address spender, uint256 value) internal {
        require(!(value != 0 && allowed[holder][spender] != 0), "Tether: approve non-zero to non-zero");
        allowed[holder][spender] = value;
        emit Approval(holder, spender, value);
    }

    function allowance(address owner_, address spender) public view virtual returns (uint256) {
        return allowed[owner_][spender];
    }
}

contract Pausable is Ownable {
    bool public paused;

    event Pause();
    event Unpause();

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}

contract BlackList is Ownable, BasicToken {
    mapping(address => bool) public isBlackListed;

    // USDT QUIRK: these events are NOT indexed in the real contract.
    event AddedBlackList(address user);
    event RemovedBlackList(address user);
    event DestroyedBlackFunds(address blackListedUser, uint256 balance);

    function getBlackListStatus(address maker) external view returns (bool) {
        return isBlackListed[maker];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function addBlackList(address evilUser) public onlyOwner {
        isBlackListed[evilUser] = true;
        emit AddedBlackList(evilUser);
    }

    function removeBlackList(address clearedUser) public onlyOwner {
        isBlackListed[clearedUser] = false;
        emit RemovedBlackList(clearedUser);
    }

    // USDT QUIRK: the owner can ZERO OUT a blacklisted user's balance and shrink
    // totalSupply — Tether can delete your money. This is the seize power used
    // against hacked / sanctioned addresses.
    function destroyBlackFunds(address blackListedUser) public onlyOwner {
        require(isBlackListed[blackListedUser], "Tether: not blacklisted");
        uint256 dirtyFunds = balanceOf(blackListedUser);
        balances[blackListedUser] = 0;
        _totalSupply -= dirtyFunds;
        emit DestroyedBlackFunds(blackListedUser, dirtyFunds);
    }
}

// USDT QUIRK: after deprecate(), EVERY ERC-20 call is forwarded to this new
// contract. Note the *ByLegacy functions return nothing, matching the token.
interface UpgradedStandardToken {
    function transferByLegacy(address from, address to, uint256 value) external;
    function transferFromByLegacy(address sender, address from, address to, uint256 value) external;
    function approveByLegacy(address from, address spender, uint256 value) external;
}

interface ILegacyBalance {
    function balanceOf(address account) external view returns (uint256);
}

/// @title  TetherToken — authentic behavioral mirror of Ethereum USDT
/// @notice LEARNING artifact only — not Tether, not mainnet USDT, worth $0.
contract TetherToken is Pausable, StandardToken, BlackList {
    string public name;
    string public symbol;

    // USDT QUIRK: decimals is uint256, NOT uint8. `decimals()` returns a full
    // 32-byte word. (Real USDT uses 6 decimals.)
    uint256 public decimals;

    address public upgradedAddress;
    bool public deprecated;

    constructor(uint256 initialSupply, string memory name_, string memory symbol_, uint256 decimals_) {
        _totalSupply = initialSupply;
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        balances[owner] = initialSupply;
        deprecated = false;
        // USDT QUIRK: NO Transfer(0x0, owner, supply) event is emitted at
        // construction — which is why early explorers couldn't show the first
        // holder. (A modern token would emit one here.)
    }

    // USDT QUIRK: returns nothing; only msg.sender is blacklist-checked (the
    // recipient is not); if deprecated, the entire call is forwarded.
    function transfer(address to, uint256 value) public override whenNotPaused {
        require(!isBlackListed[msg.sender], "Tether: sender blacklisted");
        if (deprecated) {
            UpgradedStandardToken(upgradedAddress).transferByLegacy(msg.sender, to, value);
        } else {
            super.transfer(to, value);
        }
    }

    // USDT QUIRK: the blacklist check here is on `from` (the token holder),
    // NOT on msg.sender (the spender).
    function transferFrom(address from, address to, uint256 value) public override whenNotPaused {
        require(!isBlackListed[from], "Tether: sender blacklisted");
        if (deprecated) {
            UpgradedStandardToken(upgradedAddress).transferFromByLegacy(msg.sender, from, to, value);
        } else {
            super.transferFrom(from, to, value);
        }
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (deprecated) {
            return ILegacyBalance(upgradedAddress).balanceOf(account);
        }
        return super.balanceOf(account);
    }

    // USDT QUIRK: approve carries onlyPayloadSize but NOT whenNotPaused — you can
    // still change allowances while the token is paused.
    function approve(address spender, uint256 value) public override onlyPayloadSize(2 * 32) {
        if (deprecated) {
            UpgradedStandardToken(upgradedAddress).approveByLegacy(msg.sender, spender, value);
        } else {
            super.approve(spender, value);
        }
    }

    function allowance(address owner_, address spender) public view override returns (uint256) {
        if (deprecated) {
            return StandardToken(upgradedAddress).allowance(owner_, spender);
        }
        return super.allowance(owner_, spender);
    }

    function totalSupply() public view override returns (uint256) {
        if (deprecated) {
            return StandardToken(upgradedAddress).totalSupply();
        }
        return super.totalSupply();
    }

    // USDT QUIRK: issue() prints new tokens straight to the owner with NO
    // on-chain reserve check — trust is entirely off-chain. Real USDT guarded
    // overflow with manual requires; Solidity 0.8 reverts on overflow natively.
    function issue(uint256 amount) public onlyOwner {
        balances[owner] += amount;
        _totalSupply += amount;
        emit Issue(amount);
    }

    // Reverts automatically if amount exceeds supply or the owner's balance.
    function redeem(uint256 amount) public onlyOwner {
        _totalSupply -= amount;
        balances[owner] -= amount;
        emit Redeem(amount);
    }

    // USDT QUIRK: the fee is HARD-CAPPED — basisPointsRate < 20 (max 0.19%) and
    // maxFee < 50 whole tokens. Tether never actually switched a fee on.
    function setParams(uint256 newBasisPoints, uint256 newMaxFee) public onlyOwner {
        require(newBasisPoints < 20, "Tether: basis points too high");
        require(newMaxFee < 50, "Tether: max fee too high");
        basisPointsRate = newBasisPoints;
        maximumFee = newMaxFee * 10 ** decimals;
        emit Params(basisPointsRate, maximumFee);
    }

    function deprecate(address upgradedAddress_) public onlyOwner {
        deprecated = true;
        upgradedAddress = upgradedAddress_;
        emit Deprecate(upgradedAddress_);
    }

    // USDT QUIRK: none of these events are indexed in the real contract.
    event Issue(uint256 amount);
    event Redeem(uint256 amount);
    event Deprecate(address newAddress);
    event Params(uint256 feeBasisPoints, uint256 maxFee);
}

/// @dev Reference upgrade target. The canonical single-file USDT ships only the
///      abstract `UpgradedStandardToken` interface — this concrete V2 that
///      receives forwarded calls after deprecate() is an educational addition.
contract TetherTokenV2 is StandardToken, UpgradedStandardToken {
    address public legacyContract;

    modifier onlyLegacy() {
        require(msg.sender == legacyContract, "TetherV2: not legacy");
        _;
    }

    function initialize(address legacyContract_, address[] calldata accounts, uint256[] calldata amounts)
        external
    {
        require(legacyContract == address(0), "TetherV2: already initialized");
        require(legacyContract_ != address(0), "TetherV2: zero legacy");
        require(accounts.length == amounts.length, "TetherV2: length mismatch");
        legacyContract = legacyContract_;

        uint256 migrated;
        for (uint256 i = 0; i < accounts.length; i++) {
            balances[accounts[i]] = amounts[i];
            migrated += amounts[i];
        }
        _totalSupply = migrated;
    }

    function transferByLegacy(address from, address to, uint256 value) external onlyLegacy {
        _transfer(from, to, value);
    }

    function transferFromByLegacy(address sender, address from, address to, uint256 value)
        external
        onlyLegacy
    {
        _transferFrom(sender, from, to, value);
    }

    function approveByLegacy(address from, address spender, uint256 value) external onlyLegacy {
        _approve(from, spender, value);
    }
}

/// @title  TimeLockedTetherToken — time mechanics layered on the USDT mirror
/// @notice EDUCATIONAL EXTENSION. Real USDT has NO concept of `block.timestamp`,
///         expiry, or vesting, so these live in a subclass instead of polluting the
///         authentic `TetherToken` above. Everything is on-chain and fully disclosed:
///         balances are never hidden or fabricated — they are only made
///         non-transferable until a stated time, or frozen after a stated time.
///
///         Adds:
///           * TIME-LOCKED BALANCES — the owner can vest a portion of an account's
///             balance until a unix timestamp; the tokens stay in the account but
///             cannot be moved until they mature.
///           * WHOLE-TOKEN EXPIRY   — the whole token stops transferring 20 days
///             after deployment (a scheduled, permanent freeze). The owner can
///             extend or disable it (0) via setExpiry.
contract TimeLockedTetherToken is TetherToken {
    struct Lock {
        uint256 amount; // tokens locked (same 6-decimals as the parent)
        uint64 unlockTime; // unix seconds; spendable once block.timestamp >= this
    }

    // Per-account vesting locks; a debited transfer is checked against the UNLOCKED
    // portion of the balance (see _beforeTransfer).
    mapping(address => Lock[]) private _locks;

    /// @notice Cap on simultaneous ACTIVE (unmatured) locks per account. Bounds the
    ///         cost of lockedBalanceOf() and transfers. Matured locks are pruned and
    ///         same-maturity locks merge, so this ceiling is rarely approached.
    uint256 public constant MAX_ACTIVE_LOCKS = 16;

    /// @notice Default token lifetime: transfers work for 20 days after deploy.
    uint64 public constant EXPIRY_PERIOD = 20 days;

    /// @notice The instant after which every transfer reverts. Set in the
    ///         constructor to (deploy time + EXPIRY_PERIOD); 0 = no expiry.
    uint64 public expiresAt;

    event Locked(address indexed account, uint256 amount, uint64 unlockTime);
    event ExpirySet(uint64 expiresAt);

    constructor(uint256 initialSupply, string memory name_, string memory symbol_, uint256 decimals_)
        TetherToken(initialSupply, name_, symbol_, decimals_)
    {
        // Tokens expire 20 days after deployment. Owner can extend/clear via setExpiry.
        expiresAt = uint64(block.timestamp) + EXPIRY_PERIOD;
        emit ExpirySet(expiresAt);
    }

    // --- Time-locked balances ------------------------------------------------

    /// @notice Owner (treasury) locks `amount` of `account`'s existing balance until
    ///         `unlockTime`. The tokens are NOT moved — they stay in the account's
    ///         balance but become non-transferable until maturity.
    /// @dev    Gas hygiene, in order: (1) prune matured locks, (2) merge into an
    ///         existing lock sharing this `unlockTime`, else (3) push a new entry,
    ///         capped at MAX_ACTIVE_LOCKS. This keeps the per-account array bounded
    ///         so lockedBalanceOf()/transfers never scan an ever-growing list.
    function lock(address account, uint256 amount, uint64 unlockTime) external onlyOwner {
        require(unlockTime > block.timestamp, "Tether: unlock in past");
        require(amount > 0, "Tether: zero lock");
        require(availableBalance(account) >= amount, "Tether: lock exceeds free balance");

        _prune(account); // (1) drop already-matured entries first

        Lock[] storage ls = _locks[account];
        for (uint256 i = 0; i < ls.length; i++) {
            if (ls[i].unlockTime == unlockTime) {
                ls[i].amount += amount; // (2) merge same-maturity locks into one slot
                emit Locked(account, amount, unlockTime);
                return;
            }
        }

        require(ls.length < MAX_ACTIVE_LOCKS, "Tether: too many active locks"); // (3)
        ls.push(Lock(amount, unlockTime));
        emit Locked(account, amount, unlockTime);
    }

    /// @notice Total still-locked (unmatured) tokens for `account`.
    /// @dev    Scans at most MAX_ACTIVE_LOCKS entries: lock() prunes matured entries
    ///         and merges same-maturity ones, and pruneMaturedLocks() can be called
    ///         anytime to shrink the array further.
    function lockedBalanceOf(address account) public view returns (uint256 locked) {
        Lock[] storage ls = _locks[account];
        for (uint256 i = 0; i < ls.length; i++) {
            if (block.timestamp < ls[i].unlockTime) {
                locked += ls[i].amount;
            }
        }
    }

    /// @notice Freely transferable balance = total balance − still-locked.
    /// @dev    Saturating subtraction: if a locked account is later zeroed by
    ///         destroyBlackFunds(), locked can exceed balance — return 0, never revert.
    function availableBalance(address account) public view returns (uint256) {
        uint256 bal = balanceOf(account);
        uint256 locked = lockedBalanceOf(account);
        return bal > locked ? bal - locked : 0;
    }

    /// @notice Read a specific lock entry (off-chain display / testing).
    function lockAt(address account, uint256 index) external view returns (Lock memory) {
        return _locks[account][index];
    }

    function lockCount(address account) external view returns (uint256) {
        return _locks[account].length;
    }

    /// @notice Permissionlessly drop an account's matured (fully unlocked) locks.
    ///         Purely gas hygiene — it can only remove entries that no longer
    ///         restrict anything, so it is safe for anyone to call.
    function pruneMaturedLocks(address account) external {
        _prune(account);
    }

    /// @dev Removes every matured lock (unlockTime <= now) via swap-and-pop. Array
    ///      order is not preserved, which is fine: lockedBalanceOf() sums entries,
    ///      it does not rank them. Bounds later scans to the active-lock count.
    function _prune(address account) internal {
        Lock[] storage ls = _locks[account];
        uint256 i = 0;
        while (i < ls.length) {
            if (ls[i].unlockTime <= block.timestamp) {
                uint256 last = ls.length - 1;
                if (i != last) {
                    ls[i] = ls[last]; // move the tail entry into the matured slot
                }
                ls.pop();
                // re-check the entry just swapped into slot i; do not advance i
            } else {
                i++;
            }
        }
    }

    // --- Whole-token expiry --------------------------------------------------

    /// @notice Schedule (or clear, with 0) the instant after which no transfer works.
    function setExpiry(uint64 expiresAt_) external onlyOwner {
        expiresAt = expiresAt_;
        emit ExpirySet(expiresAt_);
    }

    function isExpired() public view returns (bool) {
        return expiresAt != 0 && block.timestamp >= expiresAt;
    }

    // --- Enforcement (runs inside every local _transfer) ---------------------

    /// @dev Overrides the BasicToken hook. Reverts if the token has expired or if
    ///      the debited `value` would dip into `from`'s still-locked balance.
    ///      NOTE: this fires only on the local transfer path — if the token is
    ///      `deprecated` and forwarding to an upgraded contract, transfers bypass
    ///      _transfer entirely and these checks no longer apply.
    function _beforeTransfer(address from, address, /* to */ uint256 value)
        internal
        view
        override
    {
        require(!isExpired(), "Tether: token expired");
        require(availableBalance(from) >= value, "Tether: amount is time-locked");
    }
}