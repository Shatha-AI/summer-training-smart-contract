// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
   ██████╗ ██████╗ ██╗  ██╗
  ██╔═══██╗██╔══██╗╚██╗██╔╝
  ██║   ██║██████╔╝ ╚███╔╝ 
  ██║   ██║██╔══██╗ ██╔██╗ 
  ╚██████╔╝██║  ██║██╔╝ ██╗
   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝

        ORX — Orbexa Token
*/

contract Orbexa {

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /*//////////////////////////////////////////////////////////////
                          METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public constant name = "Orbexa";
    string public constant symbol = "ORX";
    uint8 public constant decimals = 2;

    uint256 private _totalSupply = 10_000_000 * 10**2;

    /*//////////////////////////////////////////////////////////////
                            BALANCES
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) private _balanceOf;
    mapping(address => mapping(address => uint256)) private _allowance;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balanceOf[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance[owner][spender];
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "INVALID_ADDRESS");

        uint256 senderBalance = _balanceOf[msg.sender];
        require(senderBalance >= amount, "INSUFFICIENT_BALANCE");

        _balanceOf[msg.sender] = senderBalance - amount;
        _balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             APPROVE
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "INVALID_ADDRESS");

        // Mitigate ERC20 approval race condition
        require(
            amount == 0 || _allowance[msg.sender][spender] == 0,
            "RESET_ALLOWANCE_FIRST"
        );

        _allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER FROM
    //////////////////////////////////////////////////////////////*/

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(to != address(0), "INVALID_ADDRESS");

        uint256 allowed = _allowance[from][msg.sender];
        uint256 fromBalance = _balanceOf[from];

        require(fromBalance >= amount, "INSUFFICIENT_BALANCE");
        require(allowed >= amount, "INSUFFICIENT_ALLOWANCE");

        _balanceOf[from] = fromBalance - amount;
        _balanceOf[to] += amount;
        _allowance[from][msg.sender] = allowed - amount;

        emit Transfer(from, to, amount);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        ALLOWANCE HELPERS
    //////////////////////////////////////////////////////////////*/

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        require(spender != address(0), "INVALID_ADDRESS");

        _allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        require(spender != address(0), "INVALID_ADDRESS");

        uint256 currentAllowance = _allowance[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "LOW_ALLOWANCE");

        _allowance[msg.sender][spender] = currentAllowance - subtractedValue;

        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                               BURN
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 amount) external returns (bool) {
        uint256 accountBalance = _balanceOf[msg.sender];
        require(accountBalance >= amount, "INSUFFICIENT_BALANCE");

        _balanceOf[msg.sender] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
        return true;
    }
}