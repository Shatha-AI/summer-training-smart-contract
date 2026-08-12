pragma solidity ^0.8.20;

contract GM {

    string public currentMessage = "GM2";
    function setMessage(string memory _newMessage) external {
        currentMessage = _newMessage;
    }
}