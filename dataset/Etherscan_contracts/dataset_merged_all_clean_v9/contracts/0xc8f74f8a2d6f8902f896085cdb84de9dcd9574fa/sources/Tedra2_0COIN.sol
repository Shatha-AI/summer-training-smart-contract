// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Tedra2_0COIN {
    string public constant name = "Tedra USD 2.0";
    string public constant symbol = "USD.T";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event TokenRescued(address indexed token, uint256 amount);
    event NativeRescued(uint256 amount);

    /* ========== MODIFIER ========== */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /* ========== CONSTRUCTOR ========== */
    constructor() {
        owner = msg.sender;
        uint256 initialSupply = 100_000_000_000 * 10 ** decimals;
        totalSupply = initialSupply;
        balanceOf[owner] = initialSupply;

        emit Transfer(address(0), owner, initialSupply);
    }

    /* ========== ERC20 STANDARD ========== */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        require(to != address(0), "Zero address");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        require(to != address(0), "Zero address");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function burn(uint256 amount) external onlyOwner {
        require(balanceOf[owner] >= amount, "Burn exceeds balance");

        balanceOf[owner] -= amount;
        totalSupply -= amount;

        emit Transfer(owner, address(0), amount);
    }

    function rescueERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(owner, amount), "Token transfer failed");

        emit TokenRescued(tokenAddress, amount);
    }

    function rescueNative() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No native balance");

        (bool success, ) = owner.call{value: balance}("");
        require(success, "Native transfer failed");

        emit NativeRescued(balance);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");

        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    receive() external payable {}
}