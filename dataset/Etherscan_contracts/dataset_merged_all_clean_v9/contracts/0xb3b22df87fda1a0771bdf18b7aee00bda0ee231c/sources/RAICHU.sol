// SPDX-License-Identifier: MIT
/*

RAICHU TOKEN (BullRaichu)
Fast meme energy, clean ERC-20 rails.

If you are reading this:
Welcome to the RAICHU grid.

Token specs:
- Total Supply: 100,000,000,000 BULLRAI
- Decimals: 18
- Fixed supply minted at deployment

DISCLAIMER:
Do not send ETH directly to this contract.
This contract is an ERC-20 token, not an ETH vault.

OFFICIAL LINKS:
- X/Twitter: https://x.com/raichu_eth?s=11
- Telegram: https://t.me/raichuofficialraichu

Always verify links from official channels.
Use at your own risk.

*/
pragma solidity ^0.8.28;

contract RAICHU {
    error InsufficientAllowance();
    error InvalidAddress();
    error InsufficientBalance();
    error Unauthorized();
    error TeamWalletInvalid();
    error TeamLockAlreadyConfigured();
    error TeamAmountInvalid();
    error UnlockTimeInvalid();
    error TeamLockNotConfigured();
    error TeamLockNotExpired();
    error TeamTokensAlreadyClaimed();
    error OnlyTeamWallet();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TeamTokensLocked(address indexed teamWallet, uint256 amount, uint256 unlockTime);
    event TeamTokensClaimed(address indexed teamWallet, uint256 amount);

    string private constant _NAME = "BullRaichu";
    string private constant _SYMBOL = "BULLRAI";
    uint8 private constant _DECIMALS = 18;
    uint256 private constant _TOTAL_SUPPLY = 100_000_000_000 * 10 ** _DECIMALS;

    address public owner;
    address public teamWallet;
    uint256 public teamLockedAmount;
    uint256 public teamUnlockTime;
    bool public teamTokensClaimed;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
        _mint(msg.sender, _TOTAL_SUPPLY);
    }

    function lockTeamTokens(address _teamWallet, uint256 amount, uint256 unlockTime) external onlyOwner {
        if (_teamWallet == address(0)) revert TeamWalletInvalid();
        if (teamWallet != address(0)) revert TeamLockAlreadyConfigured();
        if (amount == 0) revert TeamAmountInvalid();
        if (unlockTime <= block.timestamp) revert UnlockTimeInvalid();

        teamWallet = _teamWallet;
        teamLockedAmount = amount;
        teamUnlockTime = unlockTime;

        _transfer(msg.sender, address(this), amount);
        emit TeamTokensLocked(_teamWallet, amount, unlockTime);
    }

    function claimTeamTokens() external returns (bool) {
        if (teamWallet == address(0)) revert TeamLockNotConfigured();
        if (msg.sender != teamWallet) revert OnlyTeamWallet();
        if (teamTokensClaimed) revert TeamTokensAlreadyClaimed();
        if (block.timestamp < teamUnlockTime) revert TeamLockNotExpired();

        teamTokensClaimed = true;
        _transfer(address(this), teamWallet, teamLockedAmount);
        emit TeamTokensClaimed(teamWallet, teamLockedAmount);
        return true;
    }

    function name() external pure returns (string memory) {
        return _NAME;
    }

    function symbol() external pure returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external pure returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() external pure returns (uint256) {
        return _TOTAL_SUPPLY;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subValue) revert InsufficientAllowance();
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subValue);
        }
        return true;
    }

    function _mint(address account, uint256 amount) private {
        if (account == address(0)) revert InvalidAddress();
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (from == address(0) || to == address(0)) revert InvalidAddress();
        uint256 senderBalance = _balances[from];
        if (senderBalance < amount) revert InsufficientBalance();

        unchecked {
            _balances[from] = senderBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) private {
        if (tokenOwner == address(0) || spender == address(0)) revert InvalidAddress();
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 amount) private {
        uint256 currentAllowance = _allowances[tokenOwner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            unchecked {
                _allowances[tokenOwner][spender] = currentAllowance - amount;
            }
            emit Approval(tokenOwner, spender, _allowances[tokenOwner][spender]);
        }
    }
}