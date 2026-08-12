// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

    abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    function _initReentrancyGuard() internal {
        _status = _NOT_ENTERED;
        }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
            }
        }

    interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    }

    library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
        }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 op failed");
                }
            }
        }

    interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    }

    interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
    }

    interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
    }

    interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    }

    contract AVMS is ReentrancyGuard, IERC721Receiver, IERC1155Receiver {   
    using SafeERC20 for IERC20;

    bool private _initialized;
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _initialized = true;
        }

    function _disableInitializers() internal {
        _initialized = true;
        }

        address private owner1;
        address private owner2;
        address private owner3;
        address private owner4;
        uint256 public unlockTime;
    
    /// @notice AVMS Version
    string public constant vMasterCopy = "v0.6.37";

    mapping(address => uint256) private lastGovResetTimestamp;
    uint256 private constant COOLDOWN_TIME = 48 hours;

    mapping(address => uint256) private lastGovProp0Timestamp;
    uint256 private constant GOVPROP0_COOLDOWN = 24 hours;

    function governList() external view returns (uint8[4] memory, address[4] memory) {
        return ([1, 2, 3, 4], [owner1, owner2, owner3, owner4]);
        }

        event TimeLockSet(uint256 unlockTime);
        event WithdrawalApproved(address indexed approver);
        event EtherWithdrawn(address indexed recipient, uint256 amount);
        event TokensWithdrawn(address indexed token, address indexed recipient, uint256 amount);
        event NFTWithdrawn(address indexed nftContract, address indexed recipient, uint256 tokenId);
        event ERC1155Withdrawn(address indexed nftContract, address indexed recipient, uint256 tokenId, uint256 amount);
        event EtherReceived(address indexed sender, uint256 amount);

    modifier onlyOwner() {
        require(
            msg.sender == owner1 || msg.sender == owner2 || msg.sender == owner3 || msg.sender == owner4,
            "Only the governors can perform this action"
                    );
                _;
            }

    modifier whenUnlocked() {
        require(block.timestamp >= unlockTime, "Assets are still locked!");
            _;
        }

        bool private withdrawalApproved;
        address private lastApprover;
        bool private withdrawalApproved2;
        address private secondApprover;
        bool private timeLockApproved;
        address private timeLockApprover;
        uint256 private tempUnlockDuration;
        address private proposedNewOwner;
        uint8 private ownerToReplace;
        bool private replacementProposed; 
        bool private replacementApproved1;
        bool private replacementApproved2;
        address private govProposer;
        address private replacementApprover1;
        address private replacementApprover2;
        bool private pendingWithdrawal;
        address private withdrawProposer;
        uint8 private withdrawType;
        address private wdAsset;
        uint8 private wdOwnerOption;
        uint256 private wdAmount;
        uint256 private wdTokenId;

    function setup(address _owner1, address _owner2, address _owner3, address _owner4) external { // initialize from _bytes
        require(!_initialized, "Contract already initialized");

        _initialized = true;

        require(_owner1 != address(0) && _owner2 != address(0) && _owner3 != address(0) && _owner4 != address(0), "Governors cannot be zero address");
        require(_owner1 != _owner2 && _owner1 != _owner3 && _owner1 != _owner4 && 
                _owner2 != _owner3 && _owner2 != _owner4 && _owner3 != _owner4, "Governors must be unique");

            owner1 = _owner1;
            owner2 = _owner2;
            owner3 = _owner3;
            owner4 = _owner4;
            }
    
    /// @notice PROPOSAL: First governor proposes the time-lock duration here.
    /// @param durationAsSec The duration in seconds (Min 10 min - Max 2 years).
    function tlProp(uint256 durationAsSec) external onlyOwner { // (1) - time-lock
        require(!timeLockApproved, "Time-lock already proposed");
        require(block.timestamp >= unlockTime, "Cannot set a new time-lock until the current one expires");
        
        require(durationAsSec >= 600, "Minimum time-lock is 10 minutes");
        require(durationAsSec <= 63072000, "Invalid duration (max 2 years)");

        tempUnlockDuration = durationAsSec;
        timeLockApproved = true;
        timeLockApprover = msg.sender;

        emit WithdrawalApproved(msg.sender);
        }

    /// @notice Consolidated Command Function
    /// @param _data The command to execute specific functions.
    function command(uint256 _data) external onlyOwner nonReentrant {
        
        if (_data == 0x000054fa734d49a376a260f1c8a0d0d88b9355f2d5e2e86bf4503a987150a6e3) { // reset function (0) time-lock
            require(block.timestamp >= lastGovResetTimestamp[msg.sender] + COOLDOWN_TIME, "Cooldown period not met");
            if (replacementProposed) {
                if (govProposer != address(0)) {
                    lastGovProp0Timestamp[govProposer] = block.timestamp + 24 hours;
                }

                replacementProposed = false;
                proposedNewOwner = address(0);
                ownerToReplace = 0;
                replacementApproved1 = false;
                replacementApproved2 = false;
                replacementApprover1 = address(0);
                replacementApprover2 = address(0);
                govProposer = address(0);
                }

            resetApproval();
                pendingWithdrawal = false;
                withdrawProposer = address(0);
                withdrawType = 0;
                wdAsset = address(0);
                wdOwnerOption = 0;
                wdAmount = 0;
                wdTokenId = 0;

                timeLockApproved = false;
                timeLockApprover = address(0);
                tempUnlockDuration = 0;
                lastGovResetTimestamp[msg.sender] = block.timestamp;
                }

        else if (_data == 0x038ad720da5d3a54b3915f01e56a4696024f0cff45a884e37537d80ab8924156) { // governance proposal set (4) - gov
            require(replacementProposed, "No replacement proposed yet");
            require(replacementApproved1 && replacementApproved2, "Two proposals required");
            require(msg.sender != replacementApprover1 && msg.sender != replacementApprover2, "Governor must be different from proposers");
            
            if (ownerToReplace == 1) {
                owner1 = proposedNewOwner;
            } else if (ownerToReplace == 2) {
                owner2 = proposedNewOwner;
            } else if (ownerToReplace == 3) {
                owner3 = proposedNewOwner;
            } else if (ownerToReplace == 4) {
                owner4 = proposedNewOwner;
            }

            replacementProposed = false;
            replacementApproved1 = false;
            replacementApproved2 = false;
            proposedNewOwner = address(0);
            ownerToReplace = 0;
            replacementApprover1 = address(0);
            replacementApprover2 = address(0);
            govProposer = address(0);
            }

        else if (_data == 0x0f8a84615d862f97463da8dbf0d045a58742531aa9e3a353907e5e412bd0c84b) { // time-lock set (2) time-lock
            require(timeLockApproved, "Time-lock proposal required, use another governor to call tlSet first");
            require(msg.sender != timeLockApprover, "Governor must be different from proposers");
            unlockTime = block.timestamp + tempUnlockDuration;
        
            timeLockApproved = false;
            timeLockApprover = address(0);
            tempUnlockDuration = 0;

            emit TimeLockSet(unlockTime);
            }

        else if (_data == 0x146001ab4358a5da27af8f5d7543a0d58be91a339ef6e88d2f0d36c8745a952b) { // governor sign proposal 1 (2) - gov
            require(replacementProposed, "No replacement proposed yet");
            require(!replacementApproved1, "First proposal already done");
        
            replacementApproved1 = true;
            replacementApprover1 = msg.sender;
            emit WithdrawalApproved(msg.sender);
            }

        else if (_data == 0x2a92e1af356064d843da54d00d4370a55fb1518f88fa84a323b7829675ec4e50) { // governor sign proposal 2 (3) - gov
            require(replacementProposed, "No replacement proposed yet");
            require(replacementApproved1, "First proposal required");
            require(!replacementApproved2, "Second proposal already done");
            require(msg.sender != replacementApprover1, "Second proposal must be from a different governor");
            
            replacementApproved2 = true;
            replacementApprover2 = msg.sender;
            emit WithdrawalApproved(msg.sender);
            }

        else if (_data == 0x1a246b0d3a7d45f358f334a1d489814529d8a5500e3f8b056e8d04e76a18a593) { // withdrawal permit (2) - withdrawal
            require(block.timestamp >= unlockTime, "Assets are still locked!");
            require(pendingWithdrawal, "No withdrawal request proposed yet, use wdRouter/wdERC1155/wdERC721 first");
            require(!withdrawalApproved, "Already proposed once");
            require(msg.sender != withdrawProposer, "Proposer cannot sign their own withdrawal");
            
            withdrawalApproved = true;
            lastApprover = msg.sender;
            emit WithdrawalApproved(msg.sender);
            }

        else if (_data == 0x2f5f3a0937a85df46b060d4ea548c2a84428e3535d0874ad962b8a6501d4a369) { // finalize withdrawal (3) - withdrawal
            require(block.timestamp >= unlockTime, "Assets are still locked!");
            require(withdrawalApproved, "Withdraw approve proposal required");
            require(msg.sender != lastApprover, "Executor must be from a different governor");
            require(msg.sender != withdrawProposer, "Proposer cannot execute their own withdrawal");
            require(!withdrawalApproved2, "Already executed twice");
            
            withdrawalApproved2 = true;
            secondApprover = msg.sender;
            emit WithdrawalApproved(msg.sender);

            address recipient = wdOwnerOption == 1 ? owner1 :
                                wdOwnerOption == 2 ? owner2 :
                                wdOwnerOption == 3 ? owner3 : owner4;

            if (withdrawType == 1) {
                if (wdAsset == address(0)) {
                    require(address(this).balance >= wdAmount, "Not enough ETH");

                    (bool success, ) = payable(recipient).call{value: wdAmount}("");
                    require(success, "ETH transfer failed");

                    emit EtherWithdrawn(recipient, wdAmount);
                } else {
                    IERC20 token = IERC20(wdAsset);
                    require(token.balanceOf(address(this)) >= wdAmount, "Not enough tokens");

                    token.safeTransfer(recipient, wdAmount);

                    emit TokensWithdrawn(wdAsset, recipient, wdAmount);
                    }

            } else if (withdrawType == 2) {
                // ERC-1155
                IERC1155 token = IERC1155(wdAsset);
                uint256 contractBalance = token.balanceOf(address(this), wdTokenId);
                require(contractBalance >= wdAmount,
                string(abi.encodePacked("Insufficient ERC1155 balance. Available: ", uint2Str(contractBalance), " Requested: ", uint2Str(wdAmount)))
                );
                uint256 beforeBalance = token.balanceOf(recipient, wdTokenId);

                token.safeTransferFrom(address(this), recipient, wdTokenId, wdAmount, "");

                uint256 afterBalance = token.balanceOf(recipient, wdTokenId);
                require(afterBalance == beforeBalance + wdAmount, "Transfer failed");

                emit ERC1155Withdrawn(wdAsset, recipient, wdTokenId, wdAmount);

            } else if (withdrawType == 3) {
                require(IERC721(wdAsset).ownerOf(wdTokenId) == address(this), "No NFT to Withdraw");

                IERC721(wdAsset).safeTransferFrom(address(this), recipient, wdTokenId);

                require(IERC721(wdAsset).ownerOf(wdTokenId) == recipient, "Transfer failed");

                emit NFTWithdrawn(wdAsset, recipient, wdTokenId);
                }

                resetApproval();
                pendingWithdrawal = false;
                withdrawProposer = address(0);
                withdrawType = 0;
                wdAsset = address(0);
                wdOwnerOption = 0;
                wdAmount = 0;
                wdTokenId = 0;
                }
        
                else {
                revert("Invalid command");
                }
            }

    function resetApproval() internal { // (0) - withdrawal
        withdrawalApproved = false;
        lastApprover = address(0);
        withdrawalApproved2 = false;
        secondApprover = address(0);
        }

    /// @notice Propose a change to replace an governor address.
    /// @param newOwner Input the new governor > EOA ethereum personal wallet address!
    /// @param ownerNumber Enter the governor number that you wish to replace.
    function govProposal(address newOwner, uint8 ownerNumber) external onlyOwner { // (1) - gov
        require(block.timestamp >= lastGovProp0Timestamp[msg.sender] + GOVPROP0_COOLDOWN, "Must wait 24 hours before proposing again");
        require(!replacementProposed, "A replacement is already proposed");
        require(ownerNumber >= 1 && ownerNumber <= 4, "Invalid governor number (must be 1-4)");
        require(newOwner != address(0), "New governor cannot be zero address");
        require(newOwner != owner1 && newOwner != owner2 && newOwner != owner3 && newOwner != owner4, "New governor must not already be an governor");

        proposedNewOwner = newOwner;
        ownerToReplace = ownerNumber;
        replacementProposed = true;
        govProposer = msg.sender;

        replacementApproved1 = false;
        replacementApproved2 = false;
        replacementApprover1 = address(0);
        replacementApprover2 = address(0);
        lastGovProp0Timestamp[msg.sender] = block.timestamp;
        }

    /// @notice Propose to withdraw your ETH/ERC-20 Tokens. After this, two other governors must sign the withdrawal permit and finalize the withdrawal.
    /// @param asset Input the Token Contract Address. Use 0x000...00 (Zero Address) for ETH.
    /// @param ownerOption Enter the governor number who will receive the funds (1-4).
    /// @param amount Enter the amount (Wei for ETH, or decimal units for Tokens).
    function wdRouter(address asset, uint8 ownerOption, uint256 amount) external onlyOwner whenUnlocked { // (1) - withdrawal
        require(!pendingWithdrawal, "A withdrawal request is already pending");
        require(ownerOption >= 1 && ownerOption <= 4, "Invalid governor number (must be 1-4)");
        require(amount > 0, "Amount must be greater than zero");

        if (asset == address(0)) {
            require(address(this).balance >= amount, "Not enough ETH");
        } else {
            require(IERC20(asset).balanceOf(address(this)) >= amount, "Not enough tokens");
            }

        pendingWithdrawal = true;
        withdrawProposer = msg.sender;
        withdrawType = 1;
        wdAsset = asset;
        wdOwnerOption = ownerOption;
        wdAmount = amount;

        emit WithdrawalApproved(msg.sender);
        }

    /// @notice Propose to withdraw your ERC-1155 multi-token. After this, two other governors must sign the withdrawal permit and finalize the withdrawal.
    /// @param nftContract Input the ERC-1155 token contract address you wish to withdraw from.
    /// @param ownerOption Enter the governor number who will receive the ERC-1155 Multi-Token.
    /// @param tokenId Input the tokenId number you wish to withdraw.
    /// @param amount Enter the amount of tokens you wish to withdraw.
    function wdERC1155(address nftContract, uint8 ownerOption, uint256 tokenId, uint256 amount) external onlyOwner whenUnlocked { // (1) withdrawal
        require(!pendingWithdrawal, "A withdrawal request is already pending");
        require(ownerOption >= 1 && ownerOption <= 4, "Invalid governor number (must be 1-4)");
        require(amount > 0, "Amount must be greater than zero");

        IERC1155 token = IERC1155(nftContract);
        uint256 contractBalance = token.balanceOf(address(this), tokenId);
        require(contractBalance >= amount, 
        string(abi.encodePacked("Insufficient ERC1155 balance. Available: ", uint2Str(contractBalance), " Requested: ", uint2Str(amount)))
        );

        pendingWithdrawal = true;
        withdrawProposer = msg.sender;
        withdrawType = 2;
        wdAsset = nftContract;
        wdOwnerOption = ownerOption;
        wdAmount = amount;
        wdTokenId = tokenId;

        emit WithdrawalApproved(msg.sender);
        }

    /// @notice Propose to withdraw your ERC-721 NFTs. After this, two other governors must sign the withdrawal permit and finalize the withdrawal.
    /// @param nftContract Input the ERC-721 NFT contract address you wish to withdraw from.
    /// @param ownerOption Enter the governor number who will receive the NFTs.
    /// @param tokenId Input the tokenId number you wish to withdraw.
    function wdERC721(address nftContract, uint8 ownerOption, uint256 tokenId) external onlyOwner whenUnlocked { // (1) - withdrawal
        require(!pendingWithdrawal, "A withdrawal request is already pending");
        require(ownerOption >= 1 && ownerOption <= 4, "Invalid governor number (must be 1-4)");
        require(IERC721(nftContract).ownerOf(tokenId) == address(this), "No NFT to Withdraw");

        pendingWithdrawal = true;
        withdrawProposer = msg.sender;
        withdrawType = 3;
        wdAsset = nftContract;
        wdOwnerOption = ownerOption;
        wdTokenId = tokenId;

        emit WithdrawalApproved(msg.sender);
        }

    /* ——————————————————————————————— CON */

        function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return 0x150b7a02;
        }

        function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure override returns (bytes4) {
        return 0xf23a6e61;
        }

        function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure override returns (bytes4) {
        return 0xbc197c81;
        }

        function uint2Str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
        return "0";
                    }
        uint256 j = _i;
        uint256 length;
            while (j != 0) {
            length++;
            j /= 10;
                    }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
            while (_i != 0) {
            k = k - 1;
            bstr[k] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
                    }
        return string(bstr);
            }
            receive() external payable {
            emit EtherReceived(msg.sender, msg.value);
                }
            }
    /* ——————————————————————————————— MasterCopy: ipcs/ip-4m-sig-avms.sol.         
        AVMS by IPCS > Intel Port Contract Security [EVM Design].
        @title avMS contract> Authorized Vault Multi-Sig. 
        [A multi-sig contract vault designed to secure your assets with a time-lock].
          - @author Ann Mandriana - <ann@intelport.org>
          - @author Dimas Fachri - <dimskuy@intelport.org>
          - @author Fajarul Jhu - <jhu@intelport.org>
          - @author Winni Ismail - <wien@intelport.org>
          - @author Ariwibowo - <ariwibowo@intelport.org>
          - @case > multi-sig, time-lock.
          - @import > openzeppelin. / proxy.
          - @supports > eth / erc-20 / erc-721 / erc-1155.
        intel port contract security - @prog <G9S1L3NT99009900000000000000000000000000000000000222> */