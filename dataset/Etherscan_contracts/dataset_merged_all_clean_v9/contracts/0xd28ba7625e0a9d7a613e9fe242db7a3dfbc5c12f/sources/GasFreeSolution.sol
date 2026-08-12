// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ERC20Base {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 initialSupply) {
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool) {
        require(recipients.length == amounts.length, "ERC20: length mismatch");
        require(recipients.length > 0, "ERC20: empty batch");
        for (uint256 i = 0; i < recipients.length; ++i) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        allowance[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 senderBalance = balanceOf[from];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        balanceOf[from] = senderBalance - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}

contract GasFreeSolution is ERC20Base {
    string public constant description = unicode"GasFreeSolution (gas711.com)";

    constructor(uint256 initialSupply) ERC20Base("GasFreeSolution", "gas711.com", initialSupply) {}
}