pragma solidity ^0.5.12;

contract TestContract {
    address payable public owner;
    uint256 public balance;

    constructor() public {
        owner = msg.sender;
    }

    function deposit() public payable {
        balance += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(msg.sender == owner, "not owner");
        require(amount <= balance, "insufficient balance");
        balance -= amount;
        owner.transfer(amount);
    }
}
