// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.34;

interface ERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Tranche {
    // stETH (Lido proxy). See: https://sourcify.dev/#/lookup/0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
    ERC20 constant public STETH = ERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    address immutable public owner;
    uint256 immutable public unlockDate;
    address immutable public recipient;
    address immutable public efSafe;

    constructor(address _owner, uint256 _unlockDate, address _recipient, address _efSafe) {
        owner = _owner;
        unlockDate = _unlockDate;
        recipient = _recipient;
        efSafe = _efSafe;
    }

    // recipient can transfer the token to themselves once `unlockDate` has passed
    function claim(uint256 amount) external {
        require(msg.sender == recipient, "not-recipient");
        require(block.timestamp >= unlockDate, "unlock-date-not-reached");
        require(STETH.transfer(recipient, amount), "transfer-failed");
    }

    // owner can return the token to the EF Safe (the grantor) for recovery / mediation
    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "not-owner");
        require(STETH.transfer(efSafe, amount), "transfer-failed");
    }
}