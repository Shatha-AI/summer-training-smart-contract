// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Like {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BatchDistributor {
    event Distributed(
        address indexed sender,
        address indexed token,
        uint256 recipientCount,
        uint256 totalTokenAmount,
        uint256 totalNativeAmount
    );

    function distribute(
        address token,
        address[] calldata recipients,
        uint256[] calldata tokenAmounts,
        uint256[] calldata nativeAmounts
    ) external payable {
        uint256 len = recipients.length;
        require(len > 0, "Distributor: empty recipients");
        require(tokenAmounts.length == len, "Distributor: token length mismatch");
        require(nativeAmounts.length == len, "Distributor: native length mismatch");

        uint256 totalTokenAmount = 0;
        uint256 totalNativeAmount = 0;
        IERC20Like erc20 = IERC20Like(token);

        for (uint256 i = 0; i < len; ++i) {
            address to = recipients[i];
            require(to != address(0), "Distributor: zero recipient");

            uint256 t = tokenAmounts[i];
            if (t > 0) {
                bool ok = erc20.transferFrom(msg.sender, to, t);
                require(ok, "Distributor: token transferFrom failed");
                totalTokenAmount += t;
            }

            uint256 n = nativeAmounts[i];
            if (n > 0) {
                totalNativeAmount += n;
                (bool sent, ) = payable(to).call{value: n}("");
                require(sent, "Distributor: native transfer failed");
            }
        }

        require(msg.value == totalNativeAmount, "Distributor: msg.value mismatch");
        emit Distributed(msg.sender, token, len, totalTokenAmount, totalNativeAmount);
    }
}