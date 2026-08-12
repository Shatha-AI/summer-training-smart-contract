
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IVault {
    function maxWithdraw(address) external view returns (uint256);
    function withdraw(uint256,address,address) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external returns (bool);
}
contract Grabber {
    address public immutable owner;
    address public immutable vault;
    address public receiver;
    constructor(address _vault, address _receiver, address _owner){ vault=_vault; receiver=_receiver; owner=_owner; }
    function grab(uint256 minAssets) external {
        uint256 a = IVault(vault).maxWithdraw(address(this));
        require(a >= minAssets, "too little");
        IVault(vault).withdraw(a, receiver, address(this));
    }
    function setReceiver(address r) external { require(msg.sender==owner,"!owner"); receiver=r; }
    function rescueShares() external { require(msg.sender==owner,"!owner");
        IVault(vault).transfer(owner, IVault(vault).balanceOf(address(this))); }
}
