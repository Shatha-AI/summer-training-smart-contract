// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IERC20Referral {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract AirdropReferral {
    IERC20Referral public token;

    address public owner;
    address public tokenOwner;
    address public feeWallet;

    uint256 public claimAmount;
    uint256 public claimFee;

    bool public claimEnabled = true;

    mapping(address => bool) public claimed;
    mapping(address => address) public inviter;
    mapping(address => uint256) public directCount;
    mapping(address => uint256) public totalReward;

    uint256[5] public rewardRates = [50, 40, 30, 20, 10];

    bool private locked;

    event Claimed(address indexed user, address indexed referrer, uint256 amount);
    event RewardPaid(address indexed user, address indexed referrer, uint256 level, uint256 amount);
    event ClaimFeePaid(address indexed user, address indexed feeWallet, uint256 amount);

    event ClaimStatusChanged(bool enabled);
    event ClaimAmountChanged(uint256 amount);
    event ClaimFeeChanged(uint256 fee);
    event FeeWalletChanged(address feeWallet);
    event TokenOwnerChanged(address tokenOwner);
    event TokenChanged(address token);
    event RewardRatesChanged(uint256 level1, uint256 level2, uint256 level3, uint256 level4, uint256 level5);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ETHWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor(
        address _token,
        address _tokenOwner,
        uint256 _claimAmount,
        address _feeWallet,
        uint256 _claimFee
    ) {
        require(_token != address(0), "Invalid token");
        require(_token.code.length > 0, "Token is not a contract");
        require(_tokenOwner != address(0), "Invalid token owner");
        require(_claimAmount > 0, "Invalid claim amount");
        require(_feeWallet != address(0), "Invalid fee wallet");

        token = IERC20Referral(_token);
        owner = msg.sender;
        tokenOwner = _tokenOwner;
        claimAmount = _claimAmount;
        feeWallet = _feeWallet;
        claimFee = _claimFee;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    function claim(address referrer) external payable nonReentrant {
        require(claimEnabled, "Claim disabled");
        require(!claimed[msg.sender], "Already claimed");
        require(msg.sender != referrer, "Invalid referrer");
        require(msg.value == claimFee, "Incorrect claim fee");

        if (referrer != address(0)) {
            require(claimed[referrer], "Referrer not claimed");
            require(!_isCircularReferrer(msg.sender, referrer), "Circular referrer");
        }

        uint256 totalNeed = claimAmount + _actualReferralReward(referrer);

        require(token.allowance(tokenOwner, address(this)) >= totalNeed, "Insufficient allowance");
        require(token.balanceOf(tokenOwner) >= totalNeed, "Insufficient token balance");

        claimed[msg.sender] = true;

        if (referrer != address(0)) {
            inviter[msg.sender] = referrer;
            directCount[referrer] += 1;
        }

        if (claimFee > 0) {
            (bool feeSuccess, ) = payable(feeWallet).call{value: claimFee}("");
            require(feeSuccess, "Fee transfer failed");

            emit ClaimFeePaid(msg.sender, feeWallet, claimFee);
        }

        _safeTransferFrom(tokenOwner, msg.sender, claimAmount);

        emit Claimed(msg.sender, referrer, claimAmount);

        _payReferralRewards(msg.sender);
    }

    function _payReferralRewards(address user) internal {
        address current = inviter[user];

        for (uint256 i = 0; i < 5; i++) {
            if (current == address(0)) {
                break;
            }

            uint256 rewardAmount = claimAmount * rewardRates[i] / 100;

            if (rewardAmount > 0) {
                _safeTransferFrom(tokenOwner, current, rewardAmount);

                totalReward[current] += rewardAmount;

                emit RewardPaid(user, current, i + 1, rewardAmount);
            }

            current = inviter[current];
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) internal {
        require(address(token).code.length > 0, "Token is not a contract");

        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(
                IERC20Referral.transferFrom.selector,
                from,
                to,
                amount
            )
        );

        require(success, "Token transferFrom call failed");
        require(data.length == 0 || abi.decode(data, (bool)), "Token transferFrom failed");
    }

    function _actualReferralReward(address referrer) internal view returns (uint256) {
        uint256 totalRewardAmount;
        address current = referrer;

        for (uint256 i = 0; i < 5; i++) {
            if (current == address(0)) {
                break;
            }

            totalRewardAmount += claimAmount * rewardRates[i] / 100;
            current = inviter[current];
        }

        return totalRewardAmount;
    }

    function _maxReferralReward() internal view returns (uint256) {
        uint256 totalRewardAmount;

        for (uint256 i = 0; i < 5; i++) {
            totalRewardAmount += claimAmount * rewardRates[i] / 100;
        }

        return totalRewardAmount;
    }

    function _isCircularReferrer(address user, address referrer) internal view returns (bool) {
        address current = referrer;

        for (uint256 i = 0; i < 5; i++) {
            if (current == address(0)) {
                return false;
            }

            if (current == user) {
                return true;
            }

            current = inviter[current];
        }

        return false;
    }

    function setClaimEnabled(bool enabled) external onlyOwner {
        claimEnabled = enabled;
        emit ClaimStatusChanged(enabled);
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        require(_token.code.length > 0, "Token is not a contract");

        token = IERC20Referral(_token);

        emit TokenChanged(_token);
    }

    function setClaimAmount(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");

        claimAmount = amount;

        emit ClaimAmountChanged(amount);
    }

    function setClaimFee(uint256 fee) external onlyOwner {
        claimFee = fee;

        emit ClaimFeeChanged(fee);
    }

    function setFeeWallet(address _feeWallet) external onlyOwner {
        require(_feeWallet != address(0), "Invalid fee wallet");

        feeWallet = _feeWallet;

        emit FeeWalletChanged(_feeWallet);
    }

    function setTokenOwner(address _tokenOwner) external onlyOwner {
        require(_tokenOwner != address(0), "Invalid token owner");

        tokenOwner = _tokenOwner;

        emit TokenOwnerChanged(_tokenOwner);
    }

    function setRewardRates(
        uint256 level1,
        uint256 level2,
        uint256 level3,
        uint256 level4,
        uint256 level5
    ) external onlyOwner {
        require(level1 + level2 + level3 + level4 + level5 <= 500, "Reward too high");

        rewardRates[0] = level1;
        rewardRates[1] = level2;
        rewardRates[2] = level3;
        rewardRates[3] = level4;
        rewardRates[4] = level5;

        emit RewardRatesChanged(level1, level2, level3, level4, level5);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function getInviter(address user) external view returns (address) {
        return inviter[user];
    }

    function getAllowance() external view returns (uint256) {
        return token.allowance(tokenOwner, address(this));
    }

    function getTokenOwnerBalance() external view returns (uint256) {
        return token.balanceOf(tokenOwner);
    }

    function getActualTotalCost(address referrer) external view returns (uint256) {
        return claimAmount + _actualReferralReward(referrer);
    }

    function getMaxTotalCostPerClaim() external view returns (uint256) {
        return claimAmount + _maxReferralReward();
    }

    function withdrawETH(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(address(this).balance >= amount, "Insufficient ETH");

        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ETHWithdrawn(to, amount);
    }

    function emergencyWithdrawAllETH(address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid recipient");

        uint256 amount = address(this).balance;
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ETHWithdrawn(to, amount);
    }

    receive() external payable {}
}