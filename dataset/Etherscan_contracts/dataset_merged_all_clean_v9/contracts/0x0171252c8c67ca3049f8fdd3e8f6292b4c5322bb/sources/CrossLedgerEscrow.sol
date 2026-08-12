// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICLXT {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CrossLedgerEscrow {
    address public owner;
    ICLXT   public clxtToken;

    enum State { PENDING, COMPLETED, CANCELLED }

    struct Escrow {
        address buyer;
        address seller;
        uint256 amount;
        State   state;
        uint256 createdAt;
    }

    mapping(bytes32 => Escrow) public escrows;

    event EscrowCreated(bytes32 indexed id, address buyer, address seller, uint256 amount);
    event EscrowCompleted(bytes32 indexed id);
    event EscrowCancelled(bytes32 indexed id);

    modifier onlyOwner() { require(msg.sender == owner, "Escrow: not owner"); _; }

    constructor(address _clxtToken) {
        owner = msg.sender;
        clxtToken = ICLXT(_clxtToken);
    }

    function createEscrow(bytes32 id, address seller, uint256 amount) external {
        require(escrows[id].buyer == address(0), "Escrow: already exists");
        require(amount > 0, "Escrow: zero amount");
        require(clxtToken.transferFrom(msg.sender, address(this), amount), "Escrow: transfer failed");
        escrows[id] = Escrow(msg.sender, seller, amount, State.PENDING, block.timestamp);
        emit EscrowCreated(id, msg.sender, seller, amount);
    }

    function completeEscrow(bytes32 id) external onlyOwner {
        Escrow storage e = escrows[id];
        require(e.state == State.PENDING, "Escrow: not pending");
        e.state = State.COMPLETED;
        clxtToken.transfer(e.seller, e.amount);
        emit EscrowCompleted(id);
    }

    function cancelEscrow(bytes32 id) external onlyOwner {
        Escrow storage e = escrows[id];
        require(e.state == State.PENDING, "Escrow: not pending");
        e.state = State.CANCELLED;
        clxtToken.transfer(e.buyer, e.amount);
        emit EscrowCancelled(id);
    }

    function setToken(address _clxtToken) external onlyOwner {
        clxtToken = ICLXT(_clxtToken);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0)); owner = newOwner;
    }
}