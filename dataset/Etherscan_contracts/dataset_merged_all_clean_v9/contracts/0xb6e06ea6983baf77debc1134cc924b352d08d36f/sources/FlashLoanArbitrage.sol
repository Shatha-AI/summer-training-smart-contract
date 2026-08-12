// Sources flattened with hardhat v2.29.0 https://hardhat.org

// SPDX-License-Identifier: MIT

// File contracts/FlashLoanArbitrage.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IPool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 feeCode
    ) external;
}

contract FlashLoanArbitrage {
    address public owner;
    IPool public immutable ADDRESSES_PROVIDER;

    constructor(address _addressProvider) {
        owner = msg.sender;
        ADDRESSES_PROVIDER = IPool(_addressProvider);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Vain omistaja voi kutsua");
        _;
    }

    // Aave V3 my├Ânt├ñ├ñ pikalainan ja kutsuu t├ñt├ñ funktiota
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(ADDRESSES_PROVIDER), "Luvaton kutsuttaja");

        uint256 totalAmountToAmount = amount + premium;

        // --- KAUPPA-LOGIIKKA TULEE T├äH├äN ---
        // T├ñst├ñ kohdasta suoritetaan arbitraasi p├Ârssien v├ñlill├ñ
        // ------------------------------------

        uint256 currentBalance = IERC20(asset).balanceOf(address(this));
        require(currentBalance >= totalAmountToAmount, "Ei riittavasti varoja lainan palautukseen");

        // Hyv├ñksyt├ñ├ñn Aaven takaisinperint├ñ
        IERC20(asset).approve(address(ADDRESSES_PROVIDER), totalAmountToAmount);

        return true;
    }

    // K├ñynnist├ñ├ñ pikalainan
    function requestFlashLoan(address _token, uint256 _amount) external onlyOwner {
        address receiverAddress = address(this);
        bytes memory params = "";
        uint16 feeCode = 0;

        ADDRESSES_PROVIDER.flashLoanSimple(
            receiverAddress,
            _token,
            _amount,
            params,
            feeCode
        );
    }

    // Voittojen nosto omaan lompakkoon
    function withdraw(address _token) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(owner, balance);
    }

    receive() external payable {}
}