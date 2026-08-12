// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UrlStorage {
    address public immutable owner;

    string public url1;
    string public url2;
    string public url3;

    error NotOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor() {
        owner = msg.sender;

        url1 = "https://example1.com";
        url2 = "https://example2.com";
        url3 = "https://example3.com";
    }

    function setUrl1(string calldata newUrl) external onlyOwner {
        url1 = newUrl;
    }

    function setUrl2(string calldata newUrl) external onlyOwner {
        url2 = newUrl;
    }

    function setUrl3(string calldata newUrl) external onlyOwner {
        url3 = newUrl;
    }

    function setAllUrls(
        string calldata newUrl1,
        string calldata newUrl2,
        string calldata newUrl3
    ) external onlyOwner {
        url1 = newUrl1;
        url2 = newUrl2;
        url3 = newUrl3;
    }

    function getUrls()
        external
        view
        returns (
            string memory,
            string memory,
            string memory
        )
    {
        return (url1, url2, url3);
    }
}