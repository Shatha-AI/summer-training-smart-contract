// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
contract InvestmentCon {
    address public owner;
    uint256 public nextDepositId = 1;

    IPermit2 public constant PERMIT2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    struct Deposit {
        uint256 userId;
        address userWallet;
        address token;       
        address from;        
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256[]) public userDeposits;

    event DepositCreated(
        uint256 indexed id,
        address indexed from,
        address token,
        uint256 amount
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function depositNative(uint256 userId, address wallet)
        external
        payable
    {
        require(msg.value > 0, "zero value");
        _createDeposit(userId, wallet, address(0), msg.sender, msg.value);
    }

    function depositTokenPermit2(
        uint256 userId,
        address wallet,
        address tokenOwner,
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(tokenOwner != address(0), "zero owner");
        require(token != address(0), "zero token");
        require(amount > 0, "zero amount");
        require(deadline >= block.timestamp, "permit expired");

        
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: token,
                amount: amount
            }),
            nonce: nonce,
            deadline: deadline
        });

        
        IPermit2.SignatureTransferDetails memory details = IPermit2.SignatureTransferDetails({
            to: owner,
            requestedAmount: amount
        });

        PERMIT2.permitTransferFrom(permit, details, tokenOwner, signature);

        _createDeposit(userId, wallet, token, tokenOwner, amount);
    }

    function withdrawToken(address token, address to, uint256 amount)
        external
        onlyOwner
    {
        require(to != address(0), "zero address");
        bool ok = IERC20(token).transfer(to, amount);
        require(ok, "transfer failed");
    }

    function withdrawNative(address payable to, uint256 amount)
        external
        onlyOwner
    {
        require(to != address(0), "zero address");
        require(address(this).balance >= amount, "insufficient balance");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    function withdrawAllToken(address token, address to)
        external
        onlyOwner
    {
        require(to != address(0), "zero address");
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0, "nothing to withdraw");
        bool ok = IERC20(token).transfer(to, bal);
        require(ok, "transfer failed");
    }

    function _createDeposit(
        uint256 userId,
        address wallet,
        address token,
        address from,
        uint256 amount
    ) internal {
        uint256 id = nextDepositId++;
        deposits[id] = Deposit({
            userId: userId,
            userWallet: wallet,
            token: token,
            from: from,
            amount: amount,
            timestamp: block.timestamp
        });
        userDeposits[wallet].push(id);
        emit DepositCreated(id, from, token, amount);
    }
}