// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract ETHReceiveWallet {
    address public owner;
    uint256 private locked;

    mapping(address => uint256) public userETHDeposits;

    event DepositETH(address indexed user, uint256 amount);
    event WithdrawETH(address indexed operator, address indexed to, uint256 amount);
    event WithdrawToken(address indexed operator, address indexed token, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(locked == 0, "Reentrant call");
        locked = 1;
        _;
        locked = 0;
    }

    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner");

        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*
        用户存 ETH

        amount 单位是 wei
        例如：
        0.01 ETH = 10000000000000000 wei

        调用时：
        Deposit(10000000000000000)

        同时钱包交易里面的 value 也必须是 0.01 ETH
    */
    function Deposit(uint256 amount) external payable nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(msg.value == amount, "ETH amount mismatch");

        userETHDeposits[msg.sender] += msg.value;

        emit DepositETH(msg.sender, msg.value);
    }

    /*
        用户也可以直接给合约地址转 ETH
    */
    receive() external payable {
        require(msg.value > 0, "Amount must be > 0");

        userETHDeposits[msg.sender] += msg.value;

        emit DepositETH(msg.sender, msg.value);
    }

    /*
        用户带 calldata 转 ETH 时，也能收款
    */
    fallback() external payable {
        if (msg.value > 0) {
            userETHDeposits[msg.sender] += msg.value;
            emit DepositETH(msg.sender, msg.value);
        }
    }

    /*
        owner 提走指定数量 ETH
    */
    function withdrawETH(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid to");
        require(amount > 0, "Amount must be > 0");
        require(address(this).balance >= amount, "Insufficient ETH balance");

        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit WithdrawETH(msg.sender, to, amount);
    }

    /*
        owner 提走全部 ETH
    */
    function withdrawAllETH(address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid to");

        uint256 amount = address(this).balance;
        require(amount > 0, "No ETH balance");

        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit WithdrawETH(msg.sender, to, amount);
    }

    /*
        owner 提走指定 ERC20 代币
        例如 USDT、USDC 等
    */
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid to");
        require(amount > 0, "Amount must be > 0");

        _safeTransfer(token, to, amount);

        emit WithdrawToken(msg.sender, token, to, amount);
    }

    /*
        owner 提走某个 ERC20 代币的全部余额
    */
    function withdrawAllToken(address token, address to) external onlyOwner nonReentrant {
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid to");

        uint256 amount = IERC20(token).balanceOf(address(this));
        require(amount > 0, "No token balance");

        _safeTransfer(token, to, amount);

        emit WithdrawToken(msg.sender, token, to, amount);
    }

    /*
        查询合约 ETH 余额
    */
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /*
        查询某个用户累计存入的 ETH
    */
    function getUserETHDeposit(address user) external view returns (uint256) {
        return userETHDeposits[user];
    }

    /*
        查询合约里的某个 ERC20 代币余额
    */
    function getTokenBalance(address token) external view returns (uint256) {
        require(token != address(0), "Invalid token");

        return IERC20(token).balanceOf(address(this));
    }

    /*
        转移 owner 权限
    */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /*
        兼容 USDT 这类不标准 ERC20
    */
    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );

        require(success, "Token transfer failed");

        if (data.length > 0) {
            require(abi.decode(data, (bool)), "Token transfer returned false");
        }
    }
}