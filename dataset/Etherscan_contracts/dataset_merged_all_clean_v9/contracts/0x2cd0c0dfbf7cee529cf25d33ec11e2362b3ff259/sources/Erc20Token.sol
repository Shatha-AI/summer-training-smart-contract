// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Erc20Token {
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), owner);
    }

    /* ---------------------------------------------------------- */
    /*                        ERC20 FUNCTIONS                     */
    /* ---------------------------------------------------------- */

    function transfer(address to, uint256 amount)
        external
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        external
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "Allowance exceeded");

        allowance[from][msg.sender] = currentAllowance - amount;

        emit Approval(from, msg.sender, allowance[from][msg.sender]);

        _transfer(from, to, amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        allowance[msg.sender][spender] += addedValue;

        emit Approval(
            msg.sender,
            spender,
            allowance[msg.sender][spender]
        );

        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 currentAllowance = allowance[msg.sender][spender];

        require(currentAllowance >= subtractedValue, "Below zero");

        allowance[msg.sender][spender] =
            currentAllowance -
            subtractedValue;

        emit Approval(
            msg.sender,
            spender,
            allowance[msg.sender][spender]
        );

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");

        require(balanceOf[from] >= amount, "Insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    /* ---------------------------------------------------------- */
    /*                     OWNER FUNCTIONS                        */
    /* ---------------------------------------------------------- */

    function mint(address to, uint256 amount)
        external
        onlyOwner
    {
        require(to != address(0), "Mint to zero");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount)
        external
        onlyOwner
    {
        require(balanceOf[from] >= amount, "Insufficient balance");

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
    {
        require(newOwner != address(0), "Zero address");

        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;
    }

    function renounceOwnership()
        external
        onlyOwner
    {
        emit OwnershipTransferred(owner, address(0));

        owner = address(0);
    }
}