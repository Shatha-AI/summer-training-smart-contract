/**

*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface InterfaceLP {
    function sync() external;
    function mint(address to) external returns (uint liquidity);
}

abstract contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint8 _tokenDecimals
    ) {
        _name = _tokenName;
        _symbol = _tokenSymbol;
        _decimals = _tokenDecimals;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IDEXFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract Ownable {
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

library Address {
    error AddressInsufficientBalance(address account);

    error AddressEmptyCode(address target);

    error FailedInnerCall();

    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResultFromTarget(target, success, returndata);
    }

    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata
    ) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

interface IWETH {
    function deposit() external payable;
}

contract Testing is ERC20Detailed, Ownable {
    bool public autoRebase = true;
    bool public rebaseStarted = false;
    uint256 public rebaseStart;
    uint256 public rebaseStep;

    uint256 public maxTxnAmount;
    uint256 public maxWallet;

    address public taxWallet;
    uint256 public taxPercentBuy;
    uint256 public taxPercentSell;

    mapping(address => bool) public isWhitelisted;

    uint8 private constant DECIMALS = 9;
    uint256 private constant INITIAL_TOKENS_SUPPLY =
        690_000_000_000_000 * 10 ** DECIMALS;
    uint256 private constant TOTAL_PARTS =
        type(uint256).max - (type(uint256).max % INITIAL_TOKENS_SUPPLY);
    uint256 private constant TERMINAL_SUPPLY = 69_000_000_000 * 10 ** DECIMALS;
    uint256 private constant REBASE_STEPS = 456;
    uint256 private constant REBASE_PERIOD = 596160;

    event Rebase(uint256 indexed time, uint256 totalSupply);
    event RemovedLimits();

    IWETH public immutable weth;

    IDEXRouter public immutable router;
    address public immutable pair;

    bool public limitsInEffect = true;
    bool public tradingIsLive = false;

    uint256 private _totalSupply;
    uint256 private _partsPerToken;
    uint256 private partsSwapThreshold = ((TOTAL_PARTS / 100000) * 25);

    mapping(address => uint256) private _partBalances;
    mapping(address => mapping(address => uint256)) private _allowedTokens;

    mapping(address => bool) private _bots;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    bool inSwap;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor()
        ERC20Detailed(
            block.chainid == 1 ? "Testing" : "TEST",
            block.chainid == 1 ? "Testing" : "TEST",
            DECIMALS
        )
    {
        address dexAddress;
        if (block.chainid == 1) {
            dexAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        } else if (block.chainid == 5) {
            dexAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        } else if (block.chainid == 97) {
            dexAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        } else if (block.chainid == 56) {
            dexAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        } else {
            revert("Chain not configured");
        }

        taxWallet = msg.sender; // update
        taxPercentBuy = 20;
        taxPercentSell = 20;

        router = IDEXRouter(dexAddress);

        _totalSupply = INITIAL_TOKENS_SUPPLY;
        _partBalances[msg.sender] = TOTAL_PARTS;
        _partsPerToken = TOTAL_PARTS / (_totalSupply);

        isWhitelisted[address(this)] = true;
        isWhitelisted[address(router)] = true;
        isWhitelisted[msg.sender] = true;

        maxTxnAmount = (_totalSupply * 2) / 100;
        maxWallet = (_totalSupply * 2) / 100;

        weth = IWETH(router.WETH());
        pair = IDEXFactory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        _allowedTokens[address(this)][address(router)] = type(uint256).max;
        _allowedTokens[address(this)][address(this)] = type(uint256).max;
        _allowedTokens[address(msg.sender)][address(router)] = type(uint256)
            .max;

        emit Transfer(
            address(0x0),
            address(msg.sender),
            balanceOf(address(this))
        );
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function allowance(
        address owner_,
        address spender
    ) external view override returns (uint256) {
        return _allowedTokens[owner_][spender];
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _partBalances[who] / (_partsPerToken);
    }

    function shouldRebase() public view returns (bool) {
        return autoRebase && rebaseStarted && _pendingSteps() > 0;
    }

    function lpSync() internal {
        InterfaceLP _pair = InterfaceLP(pair);
        _pair.sync();
    }

    function transfer(
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function removeLimits() external onlyOwner {
        require(limitsInEffect, "Limits already removed");
        limitsInEffect = false;
        emit RemovedLimits();
    }

    function whitelistWallet(
        address _address,
        bool _isWhitelisted
    ) external onlyOwner {
        isWhitelisted[_address] = _isWhitelisted;
    }

    function updateTaxWallet(address _address) external onlyOwner {
        require(_address != address(0), "Zero Address");
        taxWallet = _address;
    }

    function updateTaxPercent(
        uint256 _taxPercentBuy,
        uint256 _taxPercentSell
    ) external onlyOwner {
        require(
            _taxPercentBuy <= taxPercentBuy || _taxPercentBuy <= 20,
            "Tax too high"
        );
        require(
            _taxPercentSell <= taxPercentSell || _taxPercentSell <= 20,
            "Tax too high"
        );
        taxPercentBuy = _taxPercentBuy;
        taxPercentSell = _taxPercentSell;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        address pairAddress = pair;

        require(
            !_bots[sender] && !_bots[recipient] && !_bots[msg.sender],
            "Blacklisted"
        );

        if (
            autoRebase &&
            !inSwap &&
            !isWhitelisted[sender] &&
            !isWhitelisted[recipient]
        ) {
            require(tradingIsLive, "Trading not live");
            if (limitsInEffect) {
                if (sender == pairAddress || recipient == pairAddress) {
                    require(amount <= maxTxnAmount, "Max Tx Exceeded");
                }
                if (recipient != pairAddress) {
                    require(
                        balanceOf(recipient) + amount <= maxWallet,
                        "Max Wallet Exceeded"
                    );
                }
            }

            // swapBack on sells: processes contract balance before this sell is credited to pair
            if (recipient == pairAddress) {
                if (
                    balanceOf(address(this)) >=
                    partsSwapThreshold / (_partsPerToken)
                ) {
                    try this.swapBack() {} catch {}
                }
            }

            // Elapsed rebase catch-up: sells and wallet-to-wallet only; skip on buys
            if (sender != pairAddress && shouldRebase()) {
                rebase();
            }

            // partAmount computed after rebase so _partsPerToken is current
            uint256 partAmount = amount * _partsPerToken;

            uint256 taxPartAmount;

            if (sender == pairAddress) {
                taxPartAmount = (partAmount * taxPercentBuy) / 100;
            } else if (recipient == pairAddress) {
                taxPartAmount = (partAmount * taxPercentSell) / 100;
            }

            if (taxPartAmount > 0) {
                _partBalances[sender] -= taxPartAmount;
                _partBalances[address(this)] += taxPartAmount;
                emit Transfer(
                    sender,
                    address(this),
                    taxPartAmount / _partsPerToken
                );
                partAmount -= taxPartAmount;
            }

            _partBalances[sender] = _partBalances[sender] - (partAmount);
            _partBalances[recipient] = _partBalances[recipient] + (partAmount);

            emit Transfer(sender, recipient, partAmount / (_partsPerToken));
            return true;
        }

        // Whitelisted / inSwap path: no rebase, no tax
        uint256 untaxedPartAmount = amount * _partsPerToken;

        _partBalances[sender] -= untaxedPartAmount;
        _partBalances[recipient] += untaxedPartAmount;

        emit Transfer(sender, recipient, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (_allowedTokens[from][msg.sender] != type(uint256).max) {
            require(
                _allowedTokens[from][msg.sender] >= value,
                "Insufficient Allowance"
            );
            _allowedTokens[from][msg.sender] =
                _allowedTokens[from][msg.sender] - (value);
        }
        _transferFrom(from, to, value);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        uint256 oldValue = _allowedTokens[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedTokens[msg.sender][spender] = 0;
        } else {
            _allowedTokens[msg.sender][spender] = oldValue - (subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedTokens[msg.sender][spender]);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        _allowedTokens[msg.sender][spender] =
            _allowedTokens[msg.sender][spender] + (addedValue);
        emit Approval(msg.sender, spender, _allowedTokens[msg.sender][spender]);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) public override returns (bool) {
        _allowedTokens[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function rebase() internal returns (uint256) {
        uint256 n = _pendingSteps();
        if (n == 0) return _totalSupply;

        bool isFinal = (rebaseStep + n) >= REBASE_STEPS;
        if (isFinal) {
            n = REBASE_STEPS - rebaseStep;
        }

        uint256 newSupply = _applyRebaseSteps(_totalSupply, n);
        rebaseStep += n;

        if (isFinal) {
            // Clamp to exact terminal supply at step 456 to absorb integer rounding
            newSupply = TERMINAL_SUPPLY;
            autoRebase = false;
            if (limitsInEffect) {
                limitsInEffect = false;
                emit RemovedLimits();
            }
            if (balanceOf(address(this)) > 0) {
                try this.swapBack() {} catch {}
            }
            taxPercentBuy = 0;
            taxPercentSell = 0;
        }

        _totalSupply = newSupply;
        _partsPerToken = TOTAL_PARTS / _totalSupply;
        lpSync();

        emit Rebase(block.timestamp, _totalSupply);
        return _totalSupply;
    }

    // Returns how many rebase steps are due but not yet applied.
    function _pendingSteps() internal view returns (uint256) {
        if (!rebaseStarted || !autoRebase) return 0;
        uint256 elapsed = block.timestamp - rebaseStart;
        uint256 totalDue = (elapsed * REBASE_STEPS) / REBASE_PERIOD;
        if (totalDue > REBASE_STEPS) totalDue = REBASE_STEPS;
        return totalDue > rebaseStep ? totalDue - rebaseStep : 0;
    }

    // Computes supply * (98/100)^n using binary exponentiation with Q112 fixed-point.
    // O(log n) gas, no 456-iteration loop. Safe against overflow for n <= 456.
    function _applyRebaseSteps(
        uint256 supply,
        uint256 n
    ) internal pure returns (uint256) {
        if (n == 0) return supply;
        uint256 Q = 1 << 112;
        uint256 ratio = (98 * Q) / 100; // 0.98 in Q112
        uint256 acc = Q; // 1.0 in Q112
        while (n > 0) {
            if ((n & 1) == 1) {
                acc = (acc * ratio) / Q;
            }
            n >>= 1;
            if (n > 0) {
                ratio = (ratio * ratio) / Q;
            }
        }
        return (supply * acc) / Q;
    }

    function enableTrading() external onlyOwner {
        require(!tradingIsLive, "Trading Live Already");
        tradingIsLive = true;
    }

    function startRebaseCycles() external onlyOwner {
        require(!rebaseStarted, "already started");
        rebaseStart = block.timestamp;
        rebaseStarted = true;
    }

    function manageBots(
        address[] memory _accounts,
        bool _isBot
    ) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _bots[_accounts[i]] = _isBot;
        }
    }

    function swapBack() public swapping {
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance == 0) {
            return;
        }

        if (contractBalance > (partsSwapThreshold / (_partsPerToken)) * 20) {
            contractBalance = (partsSwapThreshold / (_partsPerToken)) * 20;
        }

        swapTokensForETH(contractBalance);
    }

    function swapTokensForETH(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(router.WETH());

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount
            path,
            address(taxWallet),
            block.timestamp
        );
    }

    function withdrawETH(address payable recipient) external {
        require(msg.sender == taxWallet, "Only taxWallet can withdraw ETH");
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        require(recipient != address(0), "Invalid recipient address");

        Address.sendValue(recipient, balance);
    }
    function rescueERC20(address _address, uint256 _amount) external {
        require(msg.sender == taxWallet, "Not authorized");
        bool ok = IERC20(_address).transfer(taxWallet, _amount);
        require(ok, "Transfer failed");
    }

    function refreshBalances(address[] memory wallets) external {
        address wallet;
        for (uint256 i = 0; i < wallets.length; i++) {
            wallet = wallets[i];
            emit Transfer(wallet, wallet, 0);
        }
    }

    receive() external payable {}
}