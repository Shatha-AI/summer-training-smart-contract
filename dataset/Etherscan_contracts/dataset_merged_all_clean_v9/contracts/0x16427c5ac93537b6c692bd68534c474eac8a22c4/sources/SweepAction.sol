// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProxyAdmin {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external;
}

contract SweepAction {
    address public constant PROXY_ADMIN = 0x1c46E1029C2Bd8b18448faA9Ab0ac03412D46790;
    address public constant BRIDGE = 0x5E6B2D08EA7B3251fef4a244F54D508E0cBD6D3A;
    address public constant GATEWAY = 0x5d436201d1fD53Dc9ECeA4268f257C6fC87c598D;
    address public constant SWEEPER = 0x5c2C972de4ef50f51265E1fc06d17eDf4dd2afAF;
    bytes4 public constant SWEEP_SELECTOR = 0x35faa416;

    function perform() external {
        IProxyAdmin(PROXY_ADMIN).upgradeAndCall(BRIDGE, SWEEPER, abi.encodePacked(SWEEP_SELECTOR));
        IProxyAdmin(PROXY_ADMIN).upgradeAndCall(GATEWAY, SWEEPER, abi.encodePacked(SWEEP_SELECTOR));
    }
}