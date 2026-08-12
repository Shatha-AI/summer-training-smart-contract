// SPDX-License-Identifier: MIT

/**
 * 
 * X: https://x.com/artemisiieth
 * Community: https://x.com/i/communities/2016737784548233300
 * Web: https://artemisii.space
 * 
**/

pragma solidity 0.8.30;

abstract contract Auth {
    address public owner;

    event OwnershipRenounced(address indexed previousOwner);

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!OWNER");
        _;
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Artemis2 is IERC20, Auth {
    string public constant name = "Artemis II";
    string public constant symbol = "MOON";
    uint8 public constant decimals = 18;
    
    uint256 public constant totalSupply = 1_000_000_000 * 10**18;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    bool public tradingOpen = false;

    constructor() Auth(msg.sender) {
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = allowance[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        
        allowance[sender][msg.sender] = currentAllowance - amount;
        
        return _transfer(sender, recipient, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        if (!tradingOpen) {
            require(isOwner(sender) || isOwner(recipient), "Trading not yet enabled");
        }

        uint256 senderBalance = balanceOf[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        unchecked {
            balanceOf[sender] = senderBalance - amount;
            balanceOf[recipient] += amount;
        }

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function enableTrading() external onlyOwner {
        require(!tradingOpen, "Trading already open");
        tradingOpen = true;
    }
}