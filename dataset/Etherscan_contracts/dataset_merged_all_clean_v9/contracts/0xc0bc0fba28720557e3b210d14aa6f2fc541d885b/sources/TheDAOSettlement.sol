// SPDX-License-Identifier: MIT
pragma solidity 0.4.26;

interface IERC20DAO {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "subtraction overflow");
        return a - b;
    }
}


contract TheDAOSettlement {
    using SafeMath for uint256;

    IERC20DAO public daoToken;

    address public owner;
    address public pendingOwner;
    address public processingRecipient;
    bool public paused;

    uint256 public totalPending;
    uint256 public totalProcessed;
    mapping(address => uint256) public pendingDeposits;
    mapping(address => uint256) public processedDeposits;

    bool private entered;

    event DAOReceived(address indexed claimant, uint256 amount);
    event DepositCancelled(address indexed claimant, uint256 amount);
    event DepositProcessed(
        address indexed claimant,
        address indexed recipient,
        uint256 amount,
        bytes32 indexed reference
    );
    event ProcessingRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event PauseUpdated(bool paused);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ExcessTokenRecovered(address indexed token, address indexed recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "owner only");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "contract paused");
        _;
    }

    modifier nonReentrant() {
        require(!entered, "reentrant call");
        entered = true;
        _;
        entered = false;
    }

    constructor(
        address daoTokenAddress,
        address initialOwner,
        address initialProcessingRecipient
    ) public {
        require(daoTokenAddress != address(0), "invalid token");
        require(initialOwner != address(0), "invalid owner");
        require(initialProcessingRecipient != address(0), "invalid recipient");

        daoToken = IERC20DAO(daoTokenAddress);
        owner = initialOwner;
        processingRecipient = initialProcessingRecipient;
        emit OwnershipTransferred(address(0), initialOwner);
        emit ProcessingRecipientUpdated(address(0), initialProcessingRecipient);
    }


    function depositDAO(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "invalid amount");

        uint256 balanceBefore = daoToken.balanceOf(address(this));
        require(daoToken.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        uint256 balanceAfter = daoToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "invalid token balance");
        require(balanceAfter.sub(balanceBefore) == amount, "unexpected received amount");

        pendingDeposits[msg.sender] = pendingDeposits[msg.sender].add(amount);
        totalPending = totalPending.add(amount);
        emit DAOReceived(msg.sender, amount);
    }

    /// @notice Lets a claimant recover an unprocessed deposit.
    function cancelDeposit(uint256 amount) external nonReentrant {
        require(amount > 0, "invalid amount");
        require(pendingDeposits[msg.sender] >= amount, "insufficient pending deposit");

        pendingDeposits[msg.sender] = pendingDeposits[msg.sender].sub(amount);
        totalPending = totalPending.sub(amount);
        require(daoToken.transfer(msg.sender, amount), "transfer failed");
        emit DepositCancelled(msg.sender, amount);
    }


    function processDeposit(
        address claimant,
        uint256 amount,
        bytes32 reference
    ) external onlyOwner nonReentrant {
        require(claimant != address(0), "invalid claimant");
        require(amount > 0, "invalid amount");
        require(pendingDeposits[claimant] >= amount, "insufficient pending deposit");

        pendingDeposits[claimant] = pendingDeposits[claimant].sub(amount);
        processedDeposits[claimant] = processedDeposits[claimant].add(amount);
        totalPending = totalPending.sub(amount);
        totalProcessed = totalProcessed.add(amount);
        require(daoToken.transfer(processingRecipient, amount), "transfer failed");
        emit DepositProcessed(claimant, processingRecipient, amount, reference);
    }

    function setPaused(bool newPaused) external onlyOwner {
        paused = newPaused;
        emit PauseUpdated(newPaused);
    }

    function setProcessingRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "invalid recipient");
        address previousRecipient = processingRecipient;
        processingRecipient = newRecipient;
        emit ProcessingRecipientUpdated(previousRecipient, newRecipient);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "invalid owner");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "pending owner only");
        address previousOwner = owner;
        owner = msg.sender;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, msg.sender);
    }

    function recoverExcessToken(
        IERC20DAO token,
        address recipient,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(recipient != address(0), "invalid recipient");
        require(amount > 0, "invalid amount");
        if (address(token) == address(daoToken)) {
            uint256 balance = daoToken.balanceOf(address(this));
            require(balance >= totalPending, "pending deposits underfunded");
            require(amount <= balance.sub(totalPending), "amount exceeds excess");
        }
        require(token.transfer(recipient, amount), "transfer failed");
        emit ExcessTokenRecovered(address(token), recipient, amount);
    }
}