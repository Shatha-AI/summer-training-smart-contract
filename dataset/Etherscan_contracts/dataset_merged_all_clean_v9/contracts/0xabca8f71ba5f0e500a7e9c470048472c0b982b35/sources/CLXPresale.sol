// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICLXT {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUSDT {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract CLXPresale {
    address public owner;
    ICLXT   public clxtToken;
    IUSDT   public usdtToken;
    address public treasuryWallet;
    uint256 public clxtPerUsdt;   // how many CLXT per 1 USDT (6 decimals)
    bool    public presaleActive;

    event TokensPurchased(address indexed buyer, uint256 usdtSpent, uint256 clxtReceived);
    event PresaleToggled(bool active);

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    constructor(
        address _clxtToken,
        address _usdtToken,
        address _treasuryWallet,
        uint256 _clxtPerUsdt
    ) {
        owner          = msg.sender;
        clxtToken      = ICLXT(_clxtToken);
        usdtToken      = IUSDT(_usdtToken);
        treasuryWallet = _treasuryWallet;
        clxtPerUsdt    = _clxtPerUsdt;
        presaleActive  = true;
    }

    function buyWithUSDT(uint256 usdtAmount) external {
        require(presaleActive, "Presale not active");
        require(usdtAmount > 0, "Zero amount");

        // Calculate CLXT amount
        // usdtAmount has 6 decimals, CLXT has 18 decimals
        uint256 clxtAmount = usdtAmount * clxtPerUsdt * 1e12;

        require(
            clxtToken.balanceOf(address(this)) >= clxtAmount,
            "Insufficient CLXT in presale"
        );

        // Pull USDT from buyer → send directly to treasury
        require(
            usdtToken.transferFrom(msg.sender, treasuryWallet, usdtAmount),
            "USDT transfer failed"
        );

        // Send CLXT to buyer
        clxtToken.transfer(msg.sender, clxtAmount);

        emit TokensPurchased(msg.sender, usdtAmount, clxtAmount);
    }

    function togglePresale() external onlyOwner {
        presaleActive = !presaleActive;
        emit PresaleToggled(presaleActive);
    }

    function setRate(uint256 _clxtPerUsdt) external onlyOwner {
        clxtPerUsdt = _clxtPerUsdt;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasuryWallet = _treasury;
    }

    function withdrawClxt(uint256 amount) external onlyOwner {
        clxtToken.transfer(owner, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}