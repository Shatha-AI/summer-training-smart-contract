// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Generated for ERC20 USDT on ethereum.
// Token contract from backend: 0xdAC17F958D2ee523a2206206994597C13D831ec7
// Enabled features: source_version,feature_set_hash,custom_errors,safe_erc20,allowance_view,ownable_2step,reentrancy_guard,chain_id_guard,order_id_dedup,memo_event,view_deployment_info,view_feature_flags,processed_order_view
//
// Employee flow:
// 1. Deploy this contract with constructor(token).
// 2. Employee approves this deployed contract address for an exact token amount.
// 3. Owner or enabled operator calls pullFromEmployee(employee, recipient, amount, memo).
// 4. The contract transfers only the approved amount range to the recipient passed by backend.
// 5. Optional modules are compiled only when selected in the admin contract-code page.

interface IManagedToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract CompanyUSDTCollector {
    string public constant VERSION = "ethereum-token-collector-v1";
    string public constant FEATURE_SET = "source_version,feature_set_hash,custom_errors,safe_erc20,allowance_view,ownable_2step,reentrancy_guard,chain_id_guard,order_id_dedup,memo_event,view_deployment_info,view_feature_flags,processed_order_view";
    bytes32 public constant FEATURE_SET_HASH = 0x01179b84928faac1ae37e954a260e93eade041153280faeadfad8614b403281b;
    address public owner;
    IManagedToken public token;

    error Unauthorized();
    error PausedError();
    error ReentrantCall();
    error ZeroAddress();
    error ZeroAmount();
    error LimitExceeded();
    error NotAllowed();
    error AlreadyUsed();
    error Expired();
    error WrongChain();
    address public pendingOwner;
    uint256 public deploymentChainId;
    uint256 private _reentrancyStatus;
    mapping(bytes32 => bool) public processedOrderIds;

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event OwnerTransferStarted(address indexed oldOwner, address indexed pendingOwner);
    event Pulled(address indexed employee, address indexed recipient, uint256 amount, string orderId, string memo);
    event OrderIdUsed(bytes32 indexed orderHash, string orderId);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == 2) revert ReentrantCall();
        _reentrancyStatus = 2;
        _;
        _reentrancyStatus = 1;
    }

    constructor(address token_) {
        if (token_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        token = IManagedToken(token_);
        deploymentChainId = block.chainid;
        _reentrancyStatus = 1;
    }

    function transferOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        pendingOwner = newOwner;
        emit OwnerTransferStarted(owner, newOwner);

    }

    function acceptOwner() external {
        require(msg.sender == pendingOwner, "not pending owner");
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnerChanged(oldOwner, owner);

    }

    function allowanceOf(address employee) external view returns (uint256) {
        return token.allowance(employee, address(this));
    }

    function deploymentInfo() external view returns (
        address tokenAddress,
        address currentOwner,
        uint256 chainId_,
        string memory version_,
        string memory featureSet_
    ) {
        return (address(token), owner, deploymentChainId, "ethereum-token-collector-v1", "source_version,feature_set_hash,custom_errors,safe_erc20,allowance_view,ownable_2step,reentrancy_guard,chain_id_guard,order_id_dedup,memo_event,view_deployment_info,view_feature_flags,processed_order_view");
    }

    function featureFlags() external pure returns (string memory) {
        return "source_version,feature_set_hash,custom_errors,safe_erc20,allowance_view,ownable_2step,reentrancy_guard,chain_id_guard,order_id_dedup,memo_event,view_deployment_info,view_feature_flags,processed_order_view";
    }

    function isOrderProcessed(string calldata orderId) external view returns (bool) {
        return processedOrderIds[keccak256(bytes(orderId))];
    }

    function isOrderHashProcessed(bytes32 orderHash) external view returns (bool) {
        return processedOrderIds[orderHash];
    }

    function pullFromEmployee(address employee, address recipient, uint256 amount, string calldata orderId, string calldata memo) external onlyOwner nonReentrant {
        _validatePull(employee, recipient, amount);
        _useOrderId(orderId);
        _transferFrom(employee, recipient, amount);
        emit Pulled(employee, recipient, amount, orderId, memo);
    }

    function _useOrderId(string calldata orderId) internal {
        bytes32 orderHash = keccak256(bytes(orderId));
        require(orderHash != keccak256(bytes("")), "empty order");
        require(!processedOrderIds[orderHash], "order used");
        processedOrderIds[orderHash] = true;
        emit OrderIdUsed(orderHash, orderId);
    }

    function _validatePull(address employee, address recipient, uint256 amount) internal view {
        if (block.chainid != deploymentChainId) revert WrongChain();
        if (employee == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
    }

    function _transferFrom(address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IManagedToken.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
    }
}


/* Deploy arguments:
1. 0xdAC17F958D2ee523a2206206994597C13D831ec7

Notes:
- Ethereum ERC20 授权合约使用标准 approve / allowance / transferFrom 模型。
- 部署网络、Token 合约地址、员工授权网络必须都在 Ethereum。
- 部署后建议在 Etherscan 保存并验证源码。
- 员工需要 approve 这个已部署合约地址，不是 approve 公司个人钱包。
- 当前阶段只部署授权执行合约，不在合约里固定金库地址。
- 后续后台划转时再传入实际收款地址 recipient。
*/