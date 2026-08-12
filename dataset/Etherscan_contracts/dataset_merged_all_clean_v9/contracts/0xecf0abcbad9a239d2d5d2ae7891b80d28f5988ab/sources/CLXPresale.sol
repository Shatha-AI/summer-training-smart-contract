// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICLXT2 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CLXPresale {
    address public owner;
    ICLXT2  public clxtToken;
    uint256 public rate;        // CLXT per 1 MATIC (in wei)
    bool    public presaleActive;

    event TokensPurchased(address indexed buyer, uint256 maticSpent, uint256 clxtReceived);
    event PresaleToggled(bool active);

    modifier onlyOwner() { require(msg.sender == owner, "Presale: not owner"); _; }

    constructor(address _clxtToken, uint256 _rate) {
        owner = msg.sender;
        clxtToken = ICLXT2(_clxtToken);
        rate = _rate;
        presaleActive = true;
    }

    function buyTokens() external payable {
        require(presaleActive, "Presale: not active");
        require(msg.value > 0, "Presale: zero value");
        uint256 amount = msg.value * rate;
        require(clxtToken.balanceOf(address(this)) >= amount, "Presale: insufficient tokens");
        clxtToken.transfer(msg.sender, amount);
        emit TokensPurchased(msg.sender, msg.value, amount);
    }

    function togglePresale() external onlyOwner { presaleActive = !presaleActive; emit PresaleToggled(presaleActive); }
    function setRate(uint256 _rate) external onlyOwner { rate = _rate; }
    function withdrawMatic() external onlyOwner { payable(owner).transfer(address(this).balance); }

    function withdrawTokens(uint256 amount) external onlyOwner {
        clxtToken.transfer(owner, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0)); owner = newOwner;
    }
}