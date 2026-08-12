// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface Authority {
    function canCall(address user, address target, bytes4 functionSig) external view returns (bool);
}

contract SimpleAuthority is Authority {
    address public owner;

    // user => target => selector => allowed
    mapping(address => mapping(address => mapping(bytes4 => bool))) public permissions;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PermissionSet(
        address indexed user,
        address indexed target,
        bytes4 indexed selector,
        bool enabled
    );

    error NotOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _owner) {
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setPermission(
        address user,
        address target,
        bytes4 selector,
        bool enabled
    ) external onlyOwner {
        permissions[user][target][selector] = enabled;
        emit PermissionSet(user, target, selector, enabled);
    }

    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view override returns (bool) {
        return permissions[user][target][functionSig];
    }
}
