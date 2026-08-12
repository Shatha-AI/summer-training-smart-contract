// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * -------------------------------------------------------
 *  Donnys Phone Home — Stealth Zombie Squad
 *  Symbol  : SZS
 *  Supply  : 1 (indivisible)
 *  Chain   : Ethereum Mainnet
 *
 *  A 1-of-1 token. No liquidity. No value. Just a ping
 *  across the chain from the Squad to find their lost one.
 *
 *  If you're reading this on Etherscan... phone home. Degen Overloard and Tenga1899 are cooking.
 * -------------------------------------------------------
 */

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SteathZombieSquad is IERC20 {

    string public constant name     = "Donnys Phone Home - Stealth Zombie Squad";
    string public constant symbol   = "SZS";
    uint8  public constant decimals = 0;
    string public constant message  = "Donny. Phone home. SZS Misses You. Degen Underlord and Tenga1899 are cooking things up.";

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(address recipient) {
        _totalSupply = 1;
        _balances[recipient] = 1;
        emit Transfer(address(0), recipient, 1);
    }

    // ── ERC-20 view functions ──────────────────────────────

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    // ── ERC-20 state-changing functions ───────────────────

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(_balances[msg.sender] >= amount, "SZS: insufficient balance");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(_balances[from] >= amount, "SZS: insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "SZS: insufficient allowance");
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}