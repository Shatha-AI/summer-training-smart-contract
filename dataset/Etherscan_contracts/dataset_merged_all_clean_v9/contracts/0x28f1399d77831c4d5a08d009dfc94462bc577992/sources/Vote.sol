//SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

struct Poll {
    string title;
    string[] options;
    uint256 endTime;
    address author;
}

struct PollOptionVote {
    uint256 amount;
}

contract Vote {
    Poll[] public polls;
    mapping(uint256 => mapping(address => mapping(uint256 => PollOptionVote))) public votes;
    mapping(uint256 => mapping(address => bool)) public redeemed;

    function createVote(string calldata title, string[] calldata options, uint256 endTime) external returns (uint256 pollID) {
        require(endTime > block.timestamp, "Invalid endTime");
        polls.push(Poll({
            title: title,
            options: options,
            endTime: endTime,
            author: msg.sender
        }));
        return polls.length - 1;
    }

    function vote(uint256 pollID, uint256 optionID) external payable {
        require(msg.value > 0, "No value");
        require(pollID < polls.length);
        Poll storage poll = polls[pollID];
        require(block.timestamp < poll.endTime, "Poll closed");
        require(optionID < poll.options.length, "Invalid poll option");
        
        PollOptionVote storage pollOptionVote = votes[pollID][msg.sender][optionID];
        pollOptionVote.amount += msg.value;
    }

    function withdraw_before_end(uint256 pollID, uint256 optionID, uint256 amountToWithdraw) external {
        require(amountToWithdraw > 0, "Zero withdraw");
        require(pollID < polls.length, "Invalid poll ID");
        Poll storage poll = polls[pollID];
        require(block.timestamp < poll.endTime, "Poll closed");
        require(optionID < poll.options.length, "Invalid poll option ID");

        PollOptionVote storage pollOptionVote = votes[pollID][msg.sender][optionID];
        require(pollOptionVote.amount >= amountToWithdraw);
        pollOptionVote.amount -= amountToWithdraw;

        (bool ok, ) = msg.sender.call{value: amountToWithdraw}("");
        require(ok, "ETH transfer failed");
    }

    function withdraw_after_end(uint256 pollID) external {
        require(pollID < polls.length);
        Poll storage poll = polls[pollID];
        require(block.timestamp >= poll.endTime, "Poll not closed");
        require(!redeemed[pollID][msg.sender], "Already redeemed");

        uint256 total;
        for (uint256 optionID = 0; optionID < poll.options.length; optionID++) {
            uint256 a = votes[pollID][msg.sender][optionID].amount;
            if (a != 0) {
                total += a;
            }
        }

        redeemed[pollID][msg.sender] = true;

        require(total > 0, "Nothing to withdraw");

        (bool ok, ) = msg.sender.call{value: total}("");
        require(ok, "ETH transfer failed");
    }
}