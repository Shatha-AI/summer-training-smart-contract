// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IBEP20Metadata is IBEP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    function owner() public view returns (address) { return _owner; }
    modifier onlyOwner() { require(_owner == _msgSender(), "Ownable: caller is not the owner"); _; }
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ZeroToken is Context, IBEP20, IBEP20Metadata, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    uint256 private _totalBurned;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 public maxWalletAmount;
    uint256 public burnRate = 100;
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isExcludedFromMaxWallet;
    mapping(address => bool) public isLiquidityPair;
    event TokensBurned(address indexed from, uint256 amount);
    event ExcludedFromFees(address indexed account, bool excluded);
    event ExcludedFromMaxWallet(address indexed account, bool excluded);
    event LiquidityPairSet(address indexed pair, bool value);
    event BurnRateUpdated(uint256 oldRate, uint256 newRate);

    constructor() {
        _name = "ZeroBot";
        _symbol = "ZERO";
        _decimals = 18;
        uint256 totalTokens = 500_000_000 * 10**_decimals;
        _totalSupply = totalTokens;
        maxWalletAmount = totalTokens * 2 / 100;
        _balances[_msgSender()] = totalTokens;
        emit Transfer(address(0), _msgSender(), totalTokens);
        isExcludedFromFees[_msgSender()] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromMaxWallet[_msgSender()] = true;
        isExcludedFromMaxWallet[address(this)] = true;
    }

    function name() public view override returns (string memory) { return _name; }
    function symbol() public view override returns (string memory) { return _symbol; }
    function decimals() public view override returns (uint8) { return _decimals; }
    function totalSupply() public view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function totalBurned() public view returns (uint256) { return _totalBurned; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "BEP20: transfer amount exceeds allowance");
        unchecked { _approve(sender, _msgSender(), currentAllowance - amount); }
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "BEP20: decreased allowance below zero");
        unchecked { _approve(_msgSender(), spender, currentAllowance - subtractedValue); }
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "BEP20: transfer amount must be greater than zero");
        require(_balances[sender] >= amount, "BEP20: transfer amount exceeds balance");
        if (!isExcludedFromMaxWallet[recipient] && !isLiquidityPair[recipient]) {
            require(_balances[recipient] + amount <= maxWalletAmount, "BEP20: exceeds max wallet amount");
        }
        uint256 burnAmount = 0;
        uint256 transferAmount = amount;
        if (!isExcludedFromFees[sender] && !isExcludedFromFees[recipient] && burnRate > 0) {
            burnAmount = amount * burnRate / 10000;
            transferAmount = amount - burnAmount;
        }
        unchecked {
            _balances[sender] -= amount;
            _balances[recipient] += transferAmount;
        }
        emit Transfer(sender, recipient, transferAmount);
        if (burnAmount > 0) {
            _totalSupply -= burnAmount;
            _totalBurned += burnAmount;
            emit Transfer(sender, address(0), burnAmount);
            emit TokensBurned(sender, burnAmount);
        }
    }

    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        require(tokenOwner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function setExcludedFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
        emit ExcludedFromFees(account, excluded);
    }

    function setExcludedFromMaxWallet(address account, bool excluded) external onlyOwner {
        isExcludedFromMaxWallet[account] = excluded;
        emit ExcludedFromMaxWallet(account, excluded);
    }

    function setLiquidityPair(address pair, bool value) external onlyOwner {
        isLiquidityPair[pair] = value;
        isExcludedFromMaxWallet[pair] = value;
        emit LiquidityPairSet(pair, value);
    }

    function setBurnRate(uint256 newRate) external onlyOwner {
        require(newRate <= 500, "BEP20: burn rate cannot exceed 5%");
        emit BurnRateUpdated(burnRate, newRate);
        burnRate = newRate;
    }

    function setMaxWalletAmount(uint256 newAmount) external onlyOwner {
        require(newAmount >= 500_000_000 * 10**_decimals / 100, "BEP20: max wallet too low");
        maxWalletAmount = newAmount;
    }

    function burn(uint256 amount) external {
        require(_balances[_msgSender()] >= amount, "BEP20: burn amount exceeds balance");
        _balances[_msgSender()] -= amount;
        _totalSupply -= amount;
        _totalBurned += amount;
        emit Transfer(_msgSender(), address(0), amount);
        emit TokensBurned(_msgSender(), amount);
    }

    function recoverBNB() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function recoverTokens(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(this), "Cannot recover own tokens");
        IBEP20(tokenAddress).transfer(owner(), IBEP20(tokenAddress).balanceOf(address(this)));
    }

    receive() external payable {}
}