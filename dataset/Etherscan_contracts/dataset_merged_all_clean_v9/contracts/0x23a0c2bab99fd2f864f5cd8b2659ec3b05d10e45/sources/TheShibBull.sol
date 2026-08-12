// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TheShibBull is Ownable {
    address public constant SHIB_TOKEN = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;

    uint256 public airdropAmount = 1 * 10**18;

    uint256 public constant AIRDROP_ADDRESSES = 200;

    uint256 public totalAirdroppedAddresses;

    mapping(address => uint256) public airdropCount;

    bool private _locked;

    event Airdrop(address indexed recipient, uint256 amount);
    event Deposit(address indexed sender, uint256 amount);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    event EmergencyWithdrawETH(uint256 amount);
    event AirdropAmountUpdated(uint256 oldAmount, uint256 newAmount);

    receive() external payable {
        require(msg.value == 0, "Must send 0 ETH");
        airdrop();
    }

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(IERC20(SHIB_TOKEN).transferFrom(msg.sender, address(this), amount), "Deposit failed");
        emit Deposit(msg.sender, amount);
    }

    function airdrop() public nonReentrant {
        uint256 requiredAmount = airdropAmount * AIRDROP_ADDRESSES;
        require(IERC20(SHIB_TOKEN).balanceOf(address(this)) >= requiredAmount, "Insufficient SHIB balance");

        airdropCount[msg.sender] += 1;

        uint256 successCount = 0;

        for (uint256 i = 0; i < AIRDROP_ADDRESSES; i++) {
            address randomAddress = getRandomAddress(i);
            if (randomAddress != address(0)) {
                if (IERC20(SHIB_TOKEN).transfer(randomAddress, airdropAmount)) {
                    emit Airdrop(randomAddress, airdropAmount);
                    successCount++;
                }
            }
        }

        totalAirdroppedAddresses += successCount;
    }

    function setAirdropAmount(uint256 amountInSHIB) external onlyOwner {
        require(amountInSHIB > 0, "Amount must be greater than 0");
        uint256 oldAmount = airdropAmount;
        airdropAmount = amountInSHIB * 10**18;
        emit AirdropAmountUpdated(oldAmount, airdropAmount);
    }

    function emergencyWithdraw(address token) external onlyOwner nonReentrant {
        require(token != address(0), "Invalid token address");
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(amount > 0, "No tokens to withdraw");
        require(IERC20(token).transfer(owner(), amount), "Withdraw failed");
        emit EmergencyWithdraw(token, amount);
    }

    function emergencyWithdrawETH() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        require(amount > 0, "No ETH to withdraw");
        (bool sent, ) = owner().call{value: amount}("");
        require(sent, "ETH withdraw failed");
        emit EmergencyWithdrawETH(amount);
    }

    function getRandomAddress(uint256 seed) private view returns (address) {
        uint256 rand = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            blockhash(block.number - 1),
            blockhash(block.number - 2),
            block.prevrandao,
            msg.sender,
            block.gaslimit,
            tx.gasprice,
            seed
        )));
        return address(uint160(uint256(keccak256(abi.encodePacked(rand)))));
    }
}