// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract Wallet {
    address public owner;
    address public pendingOwner;

    event Deposit(address indexed from, uint256 amount);
    event WithdrawETH(address indexed to, uint256 amount);
    event WithdrawToken(address indexed token, address indexed to, uint256 amount);
    event TokenDepositedFrom(address indexed token, address indexed from, uint256 amount);
    event TokenTransferredFrom(address indexed token, address indexed from, address indexed to, uint256 amount);
    event TokenApproved(address indexed token, address indexed spender, uint256 amount);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // Accept plain ETH transfers
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // Withdraw ETH (amount = 0 means withdraw full balance)
    function withdrawETH(uint256 amount) external onlyOwner {
        uint256 amt = amount == 0 ? address(this).balance : amount;
        require(amt <= address(this).balance, "Insufficient balance");
        (bool sent, ) = payable(owner).call{value: amt}("");
        require(sent, "ETH transfer failed");
        emit WithdrawETH(owner, amt);
    }

    // Withdraw ERC20 tokens already held by this contract, to the owner
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 amt = amount == 0 ? bal : amount;
        require(amt <= bal, "Insufficient token balance");
        _safeTransfer(token, owner, amt);
        emit WithdrawToken(token, owner, amt);
    }

    // Check how much the caller has approved this contract to pull, for a given token.
    function myAllowance(address token) external view returns (uint256) {
        return IERC20(token).allowance(msg.sender, address(this));
    }


    // Safe wrappers: some tokens (e.g. real USDT on mainnet) don't return a bool
    // from transfer/transferFrom/approve, which breaks a plain `require(token.transfer(...))`.
    // These use a low-level call and only check that: the call itself succeeded, AND
    // if it returned data, that data decodes to `true`. Tokens returning no data at all
    // are treated as successful as long as the call didn't revert.
    function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
    }

    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
    }


    // No onlyOwner check -- msg.sender can only ever move their own funds, into this contract.
    // Destination is always address(this); there is no way to redirect deposits elsewhere.
    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit TokenDepositedFrom(token, msg.sender, amount);
    }

    // Let this contract approve another address (e.g. a DEX router) to spend
    // tokens THIS CONTRACT holds. Only the owner can grant this.
    function approveToken(address token, address spender, uint256 amount) external onlyOwner {
        require(spender != address(0), "Zero address");
        require(IERC20(token).approve(spender, amount), "Approve failed");
        emit TokenApproved(token, spender, amount);
    }

    // Convenience: check this contract's token balance in both raw units and
    // adjusted for the token's decimals (returned as a scaled-by-1e18 fixed point,
    // since Solidity has no floats). Divide by 1e18 off-chain for a human value.
    function tokenBalanceScaled(address token) external view returns (uint256) {
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint8 dec = IERC20(token).decimals();
        if (dec >= 18) {
            return bal / (10 ** (dec - 18));
        }
        return bal * (10 ** (18 - dec));
    }

    // Step 1 of 2: current owner nominates a new owner.
    // Ownership does NOT change yet -- newOwner must call acceptOwnership().
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    // Step 2 of 2: nominated address confirms it controls the key and accepts ownership.
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, owner);
    }

    // Current owner can cancel a pending transfer before it's accepted.
    function cancelOwnershipTransfer() external onlyOwner {
        pendingOwner = address(0);
    }

    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
