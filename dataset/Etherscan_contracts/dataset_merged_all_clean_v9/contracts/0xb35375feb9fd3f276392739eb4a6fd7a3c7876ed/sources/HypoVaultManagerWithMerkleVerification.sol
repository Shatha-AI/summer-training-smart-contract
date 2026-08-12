// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IHypoVault {
    function cancelDeposit(address depositor) external;

    function cancelDeposit() external;

    function cancelWithdrawal(address withdrawer) external;

    function requestWithdrawalFrom(address user, uint128 shares, bool shouldRedeposit) external;

    function fulfillDeposits(uint256 assetsToFulfill, bytes memory managerInput) external;

    function fulfillWithdrawals(
        uint256 sharesToFulfill,
        uint256 maxAssetsReceived,
        bytes memory managerInput
    ) external;

    function manage(
        address target,
        bytes calldata data,
        uint256 value
    ) external returns (bytes memory result);

    function manage(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values
    ) external returns (bytes[] memory results);

    function totalSupply() external view returns (uint256);
}

interface Authority {
    function canCall(address user, address target, bytes4 functionSig) external view returns (bool);
}

abstract contract Auth {
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;
    Authority public authority;

    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;

        emit OwnershipTransferred(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");
        _;
    }

    function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
        Authority auth = authority;
        return
            (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) ||
            user == owner;
    }

    function setAuthority(Authority newAuthority) public virtual {
        require(
            msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig),
            "UNAUTHORIZED"
        );
        authority = newAuthority;
        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function transferOwnership(address newOwner) public virtual requiresAuth {
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

interface IBalancerVault {
    function flashLoan(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external;
}

library MerkleProofLib {
    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i; i < proof.length; ++i) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == root;
    }
}

library AddressLib {
    error AddressEmptyCode(address target);

    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        if (success) {
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }

        if (returndata.length > 0) {
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }

        revert("AddressLib: staticcall failed");
    }
}

contract ManagerWithMerkleVerification is Auth {
    using AddressLib for address;

    mapping(address => bytes32) public manageRoot;
    bool internal performingFlashLoan;
    bytes32 internal flashLoanIntentHash = bytes32(0);
    bool public isPaused;

    error ManagerWithMerkleVerification__InvalidManageProofLength();
    error ManagerWithMerkleVerification__InvalidTargetDataLength();
    error ManagerWithMerkleVerification__InvalidValuesLength();
    error ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength();
    error ManagerWithMerkleVerification__FlashLoanNotExecuted();
    error ManagerWithMerkleVerification__FlashLoanNotInProgress();
    error ManagerWithMerkleVerification__BadFlashLoanIntentHash();
    error ManagerWithMerkleVerification__FailedToVerifyManageProof(
        address target,
        bytes targetData,
        uint256 value
    );
    error ManagerWithMerkleVerification__Paused();
    error ManagerWithMerkleVerification__OnlyCallableByBoringVault();
    error ManagerWithMerkleVerification__OnlyCallableByBalancerVault();
    error ManagerWithMerkleVerification__TotalSupplyMustRemainConstantDuringManagement();

    event ManageRootUpdated(address indexed strategist, bytes32 oldRoot, bytes32 newRoot);
    event BoringVaultManaged(uint256 callsMade);
    event Paused();
    event Unpaused();

    IHypoVault public immutable vault;
    IBalancerVault public immutable balancerVault;

    constructor(
        address _owner,
        address _vault,
        address _balancerVault
    ) Auth(_owner, Authority(address(0))) {
        vault = IHypoVault(_vault);
        balancerVault = IBalancerVault(_balancerVault);
    }

    function setManageRoot(address strategist, bytes32 _manageRoot) external requiresAuth {
        bytes32 oldRoot = manageRoot[strategist];
        manageRoot[strategist] = _manageRoot;
        emit ManageRootUpdated(strategist, oldRoot, _manageRoot);
    }

    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

    function manageVaultWithMerkleVerification(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        address[] calldata targets,
        bytes[] calldata targetData,
        uint256[] calldata values
    ) external requiresAuth {
        if (isPaused) revert ManagerWithMerkleVerification__Paused();

        uint256 targetsLength = targets.length;
        if (targetsLength != manageProofs.length)
            revert ManagerWithMerkleVerification__InvalidManageProofLength();
        if (targetsLength != targetData.length)
            revert ManagerWithMerkleVerification__InvalidTargetDataLength();
        if (targetsLength != values.length)
            revert ManagerWithMerkleVerification__InvalidValuesLength();
        if (targetsLength != decodersAndSanitizers.length) {
            revert ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength();
        }

        bytes32 strategistManageRoot = manageRoot[msg.sender];
        uint256 totalSupply = vault.totalSupply();

        for (uint256 i; i < targetsLength; ++i) {
            _verifyCallData(
                strategistManageRoot,
                manageProofs[i],
                decodersAndSanitizers[i],
                targets[i],
                values[i],
                targetData[i]
            );
            vault.manage(targets[i], targetData[i], values[i]);
        }

        if (totalSupply != vault.totalSupply()) {
            revert ManagerWithMerkleVerification__TotalSupplyMustRemainConstantDuringManagement();
        }

        emit BoringVaultManaged(targetsLength);
    }

    function flashLoan(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external {
        if (msg.sender != address(vault))
            revert ManagerWithMerkleVerification__OnlyCallableByBoringVault();

        flashLoanIntentHash = keccak256(userData);
        performingFlashLoan = true;
        balancerVault.flashLoan(recipient, tokens, amounts, userData);
        performingFlashLoan = false;

        if (flashLoanIntentHash != bytes32(0))
            revert ManagerWithMerkleVerification__FlashLoanNotExecuted();
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        if (msg.sender != address(balancerVault)) {
            revert ManagerWithMerkleVerification__OnlyCallableByBalancerVault();
        }
        if (!performingFlashLoan) revert ManagerWithMerkleVerification__FlashLoanNotInProgress();

        bytes32 intentHash = keccak256(userData);
        if (intentHash != flashLoanIntentHash)
            revert ManagerWithMerkleVerification__BadFlashLoanIntentHash();
        flashLoanIntentHash = bytes32(0);

        for (uint256 i = 0; i < amounts.length; ++i) {
            _safeTransfer(tokens[i], address(vault), amounts[i]);
        }

        {
            (
                bytes32[][] memory manageProofs,
                address[] memory decodersAndSanitizers,
                address[] memory targets,
                bytes[] memory data,
                uint256[] memory values
            ) = abi.decode(userData, (bytes32[][], address[], address[], bytes[], uint256[]));

            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                manageProofs,
                decodersAndSanitizers,
                targets,
                data,
                values
            );
        }

        bytes[] memory transferData = new bytes[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            transferData[i] = abi.encodeWithSelector(
                bytes4(keccak256("transfer(address,uint256)")),
                address(balancerVault),
                amounts[i] + feeAmounts[i]
            );
        }

        vault.manage(tokens, transferData, new uint256[](amounts.length));
    }

    function _verifyCallData(
        bytes32 currentManageRoot,
        bytes32[] calldata manageProof,
        address decoderAndSanitizer,
        address target,
        uint256 value,
        bytes calldata targetData
    ) internal view {
        bytes memory packedArgumentAddresses = abi.decode(
            decoderAndSanitizer.functionStaticCall(targetData),
            (bytes)
        );

        if (
            !_verifyManageProof(
                currentManageRoot,
                manageProof,
                target,
                decoderAndSanitizer,
                value,
                bytes4(targetData),
                packedArgumentAddresses
            )
        ) {
            revert ManagerWithMerkleVerification__FailedToVerifyManageProof(
                target,
                targetData,
                value
            );
        }
    }

    function _verifyManageProof(
        bytes32 root,
        bytes32[] calldata proof,
        address target,
        address decoderAndSanitizer,
        uint256 value,
        bytes4 selector,
        bytes memory packedArgumentAddresses
    ) internal pure returns (bool) {
        bool valueNonZero = value > 0;
        bytes32 leaf = keccak256(
            abi.encodePacked(
                decoderAndSanitizer,
                target,
                valueNonZero,
                selector,
                packedArgumentAddresses
            )
        );

        return MerkleProofLib.verify(proof, root, leaf);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory returnData) = token.call(
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), to, amount)
        );

        if (!success || (returnData.length != 0 && !abi.decode(returnData, (bool)))) {
            revert("TRANSFER_FAILED");
        }
    }
}

contract HypoVaultManagerWithMerkleVerification is ManagerWithMerkleVerification {
    error HypoVaultManager__Unauthorized();

    modifier onlyStrategist() {
        if (manageRoot[msg.sender] == bytes32(0) && msg.sender != owner) {
            revert HypoVaultManager__Unauthorized();
        }
        _;
    }

    constructor(
        address _owner,
        address _hypovault,
        address _balancerVault
    ) ManagerWithMerkleVerification(_owner, _hypovault, _balancerVault) {}

    function cancelDeposit(address depositor) external onlyStrategist {
        IHypoVault(address(vault)).cancelDeposit(depositor);
    }

    function cancelWithdrawal(address withdrawer) external onlyStrategist {
        IHypoVault(address(vault)).cancelWithdrawal(withdrawer);
    }

    function requestWithdrawalFrom(
        address user,
        uint128 shares,
        bool shouldRedeposit
    ) external onlyStrategist {
        IHypoVault(address(vault)).requestWithdrawalFrom(user, shares, shouldRedeposit);
    }

    function fulfillDeposits(
        uint256 assetsToFulfill,
        bytes memory managerInput
    ) external onlyStrategist {
        IHypoVault(address(vault)).fulfillDeposits(assetsToFulfill, managerInput);
    }

    function fulfillWithdrawals(
        uint256 sharesToFulfill,
        uint256 maxAssetsReceived,
        bytes memory managerInput
    ) external onlyStrategist {
        IHypoVault(address(vault)).fulfillWithdrawals(
            sharesToFulfill,
            maxAssetsReceived,
            managerInput
        );
    }
}
