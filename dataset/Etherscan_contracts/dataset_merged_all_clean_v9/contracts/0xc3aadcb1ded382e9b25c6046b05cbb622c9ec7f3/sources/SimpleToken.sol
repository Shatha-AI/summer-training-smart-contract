// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract SimpleToken is IERC20Metadata {
    string private _name;
    string private _symbol;
    uint8 private constant _DECIMALS = 18;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory name_, string memory symbol_, uint256 supply_) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = supply_ * 10 ** _DECIMALS;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // ---------------- ERC20 metadata ----------------

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return _DECIMALS;
    }

    // ---------------- ERC20 core ----------------

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        require(spender != address(0), "APPROVE_ZERO");
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "INSUFFICIENT_ALLOWANCE");
            unchecked {
                _allowances[from][msg.sender] = allowed - value;
            }
            emit Approval(from, msg.sender, allowed - value);
        }
        _transfer(from, to, value);
        return true;
    }

    // ---------------- internal ----------------

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "FROM_ZERO");
        require(to != address(0), "TO_ZERO");
        require(_balances[from] >= value, "INSUFFICIENT_BALANCE");

        unchecked {
            _balances[from] -= value;
            _balances[to] += value;
        }
        emit Transfer(from, to, value);
    }
}