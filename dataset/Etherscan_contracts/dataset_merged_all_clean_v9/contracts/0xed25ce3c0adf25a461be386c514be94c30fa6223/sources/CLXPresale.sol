// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CLXPresale {
    address public owner;
    IERC20 public clxtToken;
    IERC20 public usdt;
    address public treasury;
    uint256 public tokenPrice = 100000;
    uint256 public minPurchase = 200 * 1e6;
    uint256 public totalRaised;
    bool public saleActive = true;
    bool public claimEnabled = false;
    mapping(address => uint256) public usdtSpent;
    mapping(address => uint256) public clxtPurchased;
    mapping(address => uint256) public clxtClaimed;
    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 clxtAmount);
    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }
    constructor(address _clxt, address _usdt, address _treasury) {
        owner = msg.sender;
        clxtToken = IERC20(_clxt);
        usdt = IERC20(_usdt);
        treasury = _treasury;
    }
    function buyTokens(uint256 usdtAmount) external {
        require(saleActive, "Sale not active");
        require(usdtAmount >= minPurchase, "Below minimum");
        uint256 clxtAmount = (usdtAmount * 1e18) / tokenPrice;
        require(usdt.transferFrom(msg.sender, treasury, usdtAmount), "USDT failed");
        usdtSpent[msg.sender] += usdtAmount;
        clxtPurchased[msg.sender] += clxtAmount;
        totalRaised += usdtAmount;
        emit TokensPurchased(msg.sender, usdtAmount, clxtAmount);
    }
    function claimTokens() external {
        require(claimEnabled, "Claim not enabled");
        uint256 claimable = clxtPurchased[msg.sender] - clxtClaimed[msg.sender];
        require(claimable > 0, "Nothing to claim");
        clxtClaimed[msg.sender] += claimable;
        clxtToken.transfer(msg.sender, claimable);
    }
    function setTreasury(address _t) external onlyOwner { treasury = _t; }
    function setClaimEnabled(bool _e) external onlyOwner { claimEnabled = _e; }
    function setSaleActive(bool _a) external onlyOwner { saleActive = _a; }
    function setTokenPrice(uint256 _p) external onlyOwner { tokenPrice = _p; }
    function withdrawUSDT() external onlyOwner { usdt.transfer(owner, usdt.balanceOf(address(this))); }
    function withdrawUnsoldCLXT() external onlyOwner { clxtToken.transfer(owner, clxtToken.balanceOf(address(this))); }
    function transferOwnership(address n) external onlyOwner { require(n != address(0)); owner = n; }
}