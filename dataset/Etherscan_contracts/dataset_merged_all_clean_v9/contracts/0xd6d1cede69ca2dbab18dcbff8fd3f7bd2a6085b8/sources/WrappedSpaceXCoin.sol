// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

contract WrappedSpaceXCoin {
    string public name = "Wrapped SpaceX COIN";
    string public symbol = "WSX";
    uint8 public decimals = 6;
    uint256 public totalSupply = 1000000000 * 10**6; // 1 milliard avec 6 décimales

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "Balance insuffisante");
        require(to != address(0), "Adresse invalide");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance insuffisante");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }
}