// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

contract DRKLiquidityTimelock {
    address public immutable token;
    address public immutable beneficiary;
    uint256 public immutable releaseTime;

    event Released(address indexed token, address indexed beneficiary, uint256 amount);

    constructor(address token_, address beneficiary_, uint256 releaseTime_) {
        require(token_ != address(0), "token required");
        require(beneficiary_ != address(0), "beneficiary required");
        require(releaseTime_ > block.timestamp, "release must be future");
        token = token_;
        beneficiary = beneficiary_;
        releaseTime = releaseTime_;
    }

    function releasable() public view returns (uint256) {
        if (block.timestamp < releaseTime) return 0;
        return IERC20Minimal(token).balanceOf(address(this));
    }

    function release() external {
        require(block.timestamp >= releaseTime, "locked");
        uint256 amount = IERC20Minimal(token).balanceOf(address(this));
        require(amount > 0, "nothing to release");
        require(IERC20Minimal(token).transfer(beneficiary, amount), "transfer failed");
        emit Released(token, beneficiary, amount);
    }
}
