// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyToken {
    
    string public name;
    string public symbol;
    uint8  public constant decimals = 18;
    uint256 private constant _UNIT = 10 ** 18; 

    uint256 public totalSupply;
    uint256 public immutable cap; 
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    string public logoURI;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cap,
        uint256 _initialSupply,
        string memory _logoURI
    ) {
        require(_cap > 0, "Cap is zero");
        require(_initialSupply <= _cap, "Initial supply exceeds cap");

        name = _name;
        symbol = _symbol;
        cap = _cap * _UNIT;
        logoURI = _logoURI;

        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply * _UNIT);
        }
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        require(spender != address(0), "Approve to zero address");
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "Allowance exceeded");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "Transfer to zero address");
        uint256 bal = balanceOf[from];
        require(bal >= value, "Balance too low");
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value; 
        }
        emit Transfer(from, to, value);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount * _UNIT);
    }

    function _mint(address to, uint256 rawAmount) internal {
        require(to != address(0), "Mint to zero address");
        require(totalSupply + rawAmount <= cap, "Cap exceeded");
        totalSupply += rawAmount;
        unchecked {
            balanceOf[to] += rawAmount;
        }
        emit Transfer(address(0), to, rawAmount);
    }

    function setLogoURI(string calldata _logoURI) external onlyOwner {
        logoURI = _logoURI;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}