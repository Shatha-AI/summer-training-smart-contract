// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IERC20 {

    function approve(
        address spender,
        uint256 amount
    )
        external
        returns(bool);

    function balanceOf(
        address account
    )
        external
        view
        returns(uint256);

    function transfer(
        address recipient,
        uint256 amount
    )
        external
        returns(bool);
}


interface IPool {

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    )
        external;
}


interface IFlashLoanSimpleReceiver {

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    )
        external
        returns(bool);
}


contract FlashLoanArbitrage is IFlashLoanSimpleReceiver {

    address public owner;

    address public immutable AAVE_POOL;
    address public immutable USDC;
    address public immutable DAI;
    address public immutable UNI_ROUTER;
    address public immutable SUSHI_ROUTER;


    constructor(
        address _aave,
        address _usdc,
        address _dai,
        address _uni,
        address _sushi
    )
    {
        owner = msg.sender;

        AAVE_POOL = _aave;
        USDC = _usdc;
        DAI = _dai;
        UNI_ROUTER = _uni;
        SUSHI_ROUTER = _sushi;
    }


    modifier onlyOwner()
    {
        require(
            msg.sender == owner,
            "Owner only"
        );

        _;
    }


    function startFlashLoan(
        address asset,
        uint256 amount
    )
        external
        onlyOwner
    {
        IPool(AAVE_POOL).flashLoanSimple(
            address(this),
            asset,
            amount,
            "",
            0
        );
    }


    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address,
        bytes calldata
    )
        external
        override
        returns(bool)
    {

        require(
            msg.sender == AAVE_POOL,
            "Only AAVE"
        );


        uint256 totalDebt =
            amount + premium;


        IERC20(asset).approve(
            AAVE_POOL,
            totalDebt
        );


        return true;
    }


    function withdraw(
        address token
    )
        external
        onlyOwner
    {

        IERC20 erc =
            IERC20(token);


        uint256 amount =
            erc.balanceOf(
                address(this)
            );


        erc.transfer(
            owner,
            amount
        );
    }


    function getBalance(
        address token
    )
        external
        view
        returns(uint256)
    {

        return IERC20(token)
            .balanceOf(
                address(this)
            );

    }

}