// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: now owner");
        _;
    }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: null address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
contract ReentrancyGuard {
    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract IContract is Ownable, ReentrancyGuard {
    struct Deposit {
        uint256 userId;
        address userWallet;
        uint256 expiryTime;
        address tokenAddress;
        address fromAddress;
        uint256 amount;
        uint256 timestamp;
    }
    event NewDeposit(
        uint256 indexed depositId,
        uint256 indexed userId,
        address indexed userWallet,
        uint256 expiryTime,
        address tokenAddress,
        address fromAddress,
        uint256 amount
    );
    event Donation(address indexed donor, uint256 amount);
    uint256 public nextDepositId;
    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256[]) public userDeposits;
    receive() external payable {
        emit Donation(msg.sender, msg.value);
    }
    fallback() external payable {
        emit Donation(msg.sender, msg.value);
    }
    function depositNative(
        uint256 userId,
        address userWallet,
        uint256 expiryTime
    ) external payable nonReentrant {
        require(msg.value > 0, "Amount should be higher");
        uint256 id = nextDepositId++;
        deposits[id] = Deposit({
            userId: userId,
            userWallet: userWallet,
            expiryTime: expiryTime,
            tokenAddress: address(0),
            fromAddress: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });
        userDeposits[userWallet].push(id);
        emit NewDeposit(id, userId, userWallet, expiryTime, address(0), msg.sender, msg.value);
    }
    function depositToken(
        uint256 userId,
        address userWallet,
        uint256 expiryTime,
        address tokenAddress,
        uint256 amount,
        address fromAddress
    ) external nonReentrant {
        require(amount > 0, "amount should be higher");
        require(tokenAddress != address(0), "nulled tokenAddress");
        uint256 allowance = IERC20(tokenAddress).allowance(fromAddress, address(this));
        require(allowance >= amount, "Allowance < amount");
        (bool success, bytes memory data) = tokenAddress.call(
            abi.encodeWithSelector(IERC20(tokenAddress).transferFrom.selector, fromAddress, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
        uint256 id = nextDepositId++;
        deposits[id] = Deposit({
            userId: userId,
            userWallet: userWallet,
            expiryTime: expiryTime,
            tokenAddress: tokenAddress,
            fromAddress: fromAddress,
            amount: amount,
            timestamp: block.timestamp
        });
        userDeposits[userWallet].push(id);
        emit NewDeposit(id, userId, userWallet, expiryTime, tokenAddress, fromAddress, amount);
    }
    function returnNative(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "null address");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "unable to send");
    }
    function returnToken(address tokenAddress, address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "null address");
        (bool success, bytes memory data) = tokenAddress.call(
            abi.encodeWithSelector(IERC20(tokenAddress).transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
    }
    function getUserDeposits(address userWallet) external view returns (uint256[] memory) {
        return userDeposits[userWallet];
    }
    function getDeposit(uint256 depositId) external view returns (Deposit memory) {
        return deposits[depositId];
    }
}