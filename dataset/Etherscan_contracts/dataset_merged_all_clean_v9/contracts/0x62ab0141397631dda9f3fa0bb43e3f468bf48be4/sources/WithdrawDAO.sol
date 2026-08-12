pragma solidity ^0.4.26;


contract ERC20 {

    function balanceOf(address _owner)
    public
    view
    returns(uint256);


    function transfer(address _to, uint256 _value)
    public
    returns(bool);

}



contract WithdrawDAO {


    address public daoToken;

    address public owner;



    modifier onlyOwner(){

        require(msg.sender == owner);

        _;

    }



    constructor(address _daoToken)
    public
    {

        daoToken = _daoToken;

        owner = msg.sender;

    }



    function daoBalance()
    public
    view
    returns(uint256)
    {

        ERC20 token = ERC20(daoToken);

        return token.balanceOf(address(this));

    }



    function withdrawDAO(
        address _to,
        uint256 _amount
    )
    public
    onlyOwner
    returns(bool)
    {

        ERC20 token = ERC20(daoToken);

        return token.transfer(
            _to,
            _amount
        );

    }



    function withdrawToken(
        address _token,
        address _to,
        uint256 _amount
    )
    public
    onlyOwner
    returns(bool)
    {

        ERC20 token = ERC20(_token);

        return token.transfer(
            _to,
            _amount
        );

    }



    function transferOwnership(
        address _newOwner
    )
    public
    onlyOwner
    {

        require(
            _newOwner != address(0)
        );

        owner = _newOwner;

    }



    function()
    public
    payable
    {

    }


}