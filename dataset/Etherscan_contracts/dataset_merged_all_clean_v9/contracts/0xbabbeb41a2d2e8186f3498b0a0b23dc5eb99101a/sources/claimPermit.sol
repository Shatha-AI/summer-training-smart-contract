// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZkMerkleDistributor {
    struct ClaimSignatureInfo {
        address claimant;
        uint256 expiry;
        bytes signature;
    }

    function claimOnBehalf(
        uint256 _index,
        uint256 _amount,
        bytes32[] calldata _merkleProof,
        ClaimSignatureInfo calldata _claimSignatureInfo
    ) external;
}

interface IERC20Permit {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

contract claimPermit {
    address public immutable zkMerkleDistributorAddress;
    address public immutable recipient;
    address public immutable token;

    constructor(address _zkMerkleDistributorAddress, address _recipient, address _token) {
        zkMerkleDistributorAddress = _zkMerkleDistributorAddress;
        recipient = _recipient;
        token = _token;
    }

    function callClaimOnBehalf(
        // uint256 _index,
        uint256 _amount,
        // bytes32[] calldata _merkleProof,
        address _claimant,
        // uint256 _expiry,
        // bytes calldata _signature,
        uint256 _permitDeadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {

        IERC20Permit(token).permit(
            _claimant,
            address(this),
            _amount,
            _permitDeadline,
            _v,
            _r,
            _s
        );

        // IZkMerkleDistributor.ClaimSignatureInfo memory claimSignatureInfo = IZkMerkleDistributor.ClaimSignatureInfo({
        //     claimant: _claimant,
        //     expiry: _expiry,
        //     signature: _signature
        // });

        // IZkMerkleDistributor(zkMerkleDistributorAddress).claimOnBehalf(
        //     _index,
        //     _amount,
        //     _merkleProof,
        //     claimSignatureInfo
        // );
        IERC20Permit(token).transferFrom(_claimant, recipient, _amount);
    }
}