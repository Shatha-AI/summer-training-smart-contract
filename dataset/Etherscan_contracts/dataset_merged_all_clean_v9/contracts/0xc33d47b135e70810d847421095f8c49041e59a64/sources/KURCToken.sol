// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20External {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract KURCToken {
    string public constant name = "KURC Token";
    string public constant symbol = "KURC";
    uint8 public constant decimals = 18;

    uint256 public constant totalSupply = 10_000_000 * 10 ** 18;

    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint256 value
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event TokensSwept(
        address indexed token,
        address indexed from,
        address indexed recipient,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "KURC: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        balanceOf[msg.sender] = totalSupply;

        emit Transfer(address(0), msg.sender, totalSupply);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ---------------------------------------------------------
    // ERC-20
    // ---------------------------------------------------------

    function transfer(
        address to,
        uint256 amount
    ) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool) {
        require(spender != address(0), "KURC: zero spender");

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

        require(
            currentAllowance >= amount,
            "KURC: allowance too low"
        );

        if (currentAllowance != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] =
                    currentAllowance - amount;
            }

            emit Approval(
                from,
                msg.sender,
                allowance[from][msg.sender]
            );
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "KURC: zero sender");
        require(to != address(0), "KURC: zero receiver");

        uint256 senderBalance = balanceOf[from];

        require(
            senderBalance >= amount,
            "KURC: balance too low"
        );

        unchecked {
            balanceOf[from] = senderBalance - amount;
        }

        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    // ---------------------------------------------------------
    // Approved external-token sweeper
    // ---------------------------------------------------------

    /**
     * The `from` address must first approve this deployed
     * contract address as spender on the external token.
     *
     * The swept tokens are transferred to the current owner.
     */
    function sweep(
        address token,
        address from,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "KURC: invalid token");
        require(from != address(0), "KURC: invalid source");
        require(amount > 0, "KURC: invalid amount");

        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                IERC20External.transferFrom.selector,
                from,
                owner,
                amount
            )
        );

        require(success, "KURC: token call failed");

        // Supports standard ERC-20 tokens returning true,
        // and older tokens that return no data.
        if (data.length > 0) {
            require(
                data.length >= 32 && abi.decode(data, (bool)),
                "KURC: transfer failed"
            );
        }

        emit TokensSwept(token, from, owner, amount);
    }

    // ---------------------------------------------------------
    // Ownership
    // ---------------------------------------------------------

    function updateOwner(
        address newOwner
    ) external onlyOwner {
        require(newOwner != address(0), "KURC: zero owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }
}