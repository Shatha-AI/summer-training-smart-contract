// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title SafeMath
 * @dev Wrappers over Solidity's arithmetic operations
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}

/**
 * @title Context
 * @dev Provides information about the current execution context
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/**
 * @title Ownable
 * @dev Basic ownership functionality
 */
abstract contract Ownable is Context {
    address private _owner;
    address private _pendingOwner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    
    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }
    
    function acceptOwnership() public virtual {
        require(_msgSender() == _pendingOwner, "Ownable: caller is not the pending owner");
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }
    
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

/**
 * @title ReentrancyGuard
 * @dev Protection against reentrancy attacks
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    
    constructor() {
        _status = _NOT_ENTERED;
    }
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title Pausable
 * @dev Emergency pause functionality
 */
abstract contract Pausable is Context {
    bool private _paused;
    
    event Paused(address account);
    event Unpaused(address account);
    
    constructor() {
        _paused = false;
    }
    
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @title IERC20
 * @dev Interface of the ERC20 standard
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title IERC20Metadata
 * @dev Extension of IERC20 with metadata
 */
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// ==================== Інтерфейси для хуків ====================

interface IAmpTokensSender {
    function tokensToTransfer(
        bytes4 functionSig,
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}

interface IAmpTokensRecipient {
    function tokensReceived(
        bytes4 functionSig,
        bytes32 partition,
        address operator,
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}

// ==================== Основний контракт AmpE ====================

/**
 * @title AmpE - Enhanced Amp Token
 * @dev Покращена версія Amp з виправленнями безпеки
 */
contract AmpE is Context, IERC20, IERC20Metadata, Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    
    // ==================== Константи ====================
    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;
    uint256 private _totalSupply;
    uint256 private _maxSupply;
    
    // ==================== Маппінги ====================
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // ==================== ERC1820 Інтеграція ====================
    bytes32 public constant AMP_TOKENS_RECIPIENT = keccak256("AmpTokensRecipient");
    bytes32 public constant AMP_TOKENS_SENDER = keccak256("AmpTokensSender");
    
    mapping(address => mapping(bytes32 => address)) private _implementers;
    address public registryAddress;
    
    // ==================== Додаткові функції ====================
    uint256 public swapRate;
    address public swapTokenAddress;
    address public treasuryWallet;
    uint256 public taxRate;           // в basis points (100 = 1%)
    
    // ==================== Події ====================
    event TokensReceived(address indexed from, address indexed to, uint256 value);
    event TokensSent(address indexed from, address indexed to, uint256 value);
    event SwapExecuted(address indexed from, uint256 amountIn, uint256 amountOut);
    event RegistryUpdated(address oldRegistry, address newRegistry);
    event TaxUpdated(uint256 oldTax, uint256 newTax);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event MaxSupplyUpdated(uint256 oldMax, uint256 newMax);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    
    // ==================== Конструктор ====================
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        uint256 maxSupply_,
        address swapToken_,
        uint256 swapRate_,
        address treasury_,
        uint256 taxRate_
    ) {
        require(maxSupply_ > 0, "Max supply must be > 0");
        require(initialSupply_ <= maxSupply_, "Initial supply exceeds max");
        
        _name = name_;
        _symbol = symbol_;
        _maxSupply = maxSupply_ * 10 ** _decimals;
        swapTokenAddress = swapToken_;
        swapRate = swapRate_;
        treasuryWallet = treasury_;
        taxRate = taxRate_;
        
        // Мінтимо початкову емісію
        _mint(_msgSender(), initialSupply_ * 10 ** _decimals);
        
        // Встановлюємо реєстр
        registryAddress = address(this);
    }
    
    // ==================== ERC20 Стандартні функції ====================
    
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) 
        public 
        virtual 
        override 
        whenNotPaused 
        returns (bool) 
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) 
        public 
        view 
        virtual 
        override 
        returns (uint256) 
    {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) 
        public 
        virtual 
        override 
        whenNotPaused 
        returns (bool) 
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        
        return true;
    }
    
    // ==================== ERC1820 Інтеграція ====================
    
    function setInterfaceImplementer(
        address addr,
        bytes32 interfaceHash,
        address implementer
    ) external {
        require(addr == _msgSender() || addr == address(this) || _msgSender() == owner(), 
            "Not authorized");
        _implementers[addr][interfaceHash] = implementer;
    }
    
    function getInterfaceImplementer(address addr, bytes32 interfaceHash) 
        public 
        view 
        returns (address) 
    {
        return _implementers[addr][interfaceHash];
    }
    
    function _callPreTransferHooks(
        address from,
        address to,
        uint256 value
    ) internal {
        address senderImpl = getInterfaceImplementer(from, AMP_TOKENS_SENDER);
        if (senderImpl != address(0)) {
            IAmpTokensSender(senderImpl).tokensToTransfer(
                msg.sig,
                bytes32(0),
                _msgSender(),
                from,
                to,
                value,
                "",
                ""
            );
        }
    }
    
    function _callPostTransferHooks(
        address from,
        address to,
        uint256 value
    ) internal {
        address recipientImpl = getInterfaceImplementer(to, AMP_TOKENS_RECIPIENT);
        if (recipientImpl != address(0)) {
            IAmpTokensRecipient(recipientImpl).tokensReceived(
                msg.sig,
                bytes32(0),
                _msgSender(),
                from,
                to,
                value,
                "",
                ""
            );
        }
        
        emit TokensReceived(from, to, value);
    }
    
    // ==================== Основні операції ====================
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        // Обробка податку
        uint256 transferAmount = amount;
        if (taxRate > 0 && treasuryWallet != address(0) && from != treasuryWallet && to != treasuryWallet) {
            uint256 taxAmount = (amount * taxRate) / 10000;
            transferAmount = amount - taxAmount;
            
            if (taxAmount > 0) {
                // ✅ Оновлюємо стан спочатку
                _balances[from] = _balances[from].sub(taxAmount);
                _balances[treasuryWallet] = _balances[treasuryWallet].add(taxAmount);
                emit Transfer(from, treasuryWallet, taxAmount);
            }
        }
        
        // ✅ CHECK: Перевіряємо баланс
        require(_balances[from] >= transferAmount, "ERC20: transfer amount exceeds balance");
        
        // ✅ EFFECTS: Оновлюємо стан
        _balances[from] = _balances[from].sub(transferAmount);
        _balances[to] = _balances[to].add(transferAmount);
        
        // ✅ INTERACTIONS: Викликаємо хуки ПІСЛЯ оновлення стану (захист від reentrancy)
        _callPreTransferHooks(from, to, transferAmount);
        _callPostTransferHooks(from, to, transferAmount);
        
        emit Transfer(from, to, transferAmount);
    }
    
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to the zero address");
        require(_totalSupply + amount <= _maxSupply, "Exceeds max supply");
        
        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);
        
        _callPostTransferHooks(address(0), to, amount);
        
        emit Transfer(address(0), to, amount);
        emit TokensMinted(to, amount);
    }
    
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        _mint(to, amount);
    }
    
    function burn(uint256 amount) external whenNotPaused {
        require(_balances[_msgSender()] >= amount, "ERC20: burn amount exceeds balance");
        
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        
        emit Transfer(_msgSender(), address(0), amount);
        emit TokensBurned(_msgSender(), amount);
    }
    
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // ==================== Swap функціонал ====================
    
    function swap(address from) external nonReentrant whenNotPaused {
        require(swapTokenAddress != address(0), "Swap not configured");
        require(swapRate > 0, "Swap rate not set");
        
        IERC20 swapToken = IERC20(swapTokenAddress);
        uint256 amount = swapToken.allowance(from, address(this));
        require(amount > 0, "No allowance");
        
        require(
            swapToken.transferFrom(from, address(this), amount),
            "Swap transfer failed"
        );
        
        uint256 mintAmount = amount * swapRate / 10 ** _decimals;
        require(_totalSupply + mintAmount <= _maxSupply, "Exceeds max supply");
        
        _mint(from, mintAmount);
        
        emit SwapExecuted(from, amount, mintAmount);
    }
    
    // ==================== Глобальні налаштування ====================
    
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        require(newMaxSupply > _totalSupply, "New max less than total supply");
        emit MaxSupplyUpdated(_maxSupply, newMaxSupply * 10 ** _decimals);
        _maxSupply = newMaxSupply * 10 ** _decimals;
    }
    
    function setTaxRate(uint256 newTaxRate) external onlyOwner {
        require(newTaxRate <= 1000, "Tax too high (max 10%)");
        emit TaxUpdated(taxRate, newTaxRate);
        taxRate = newTaxRate;
    }
    
    function setTreasuryWallet(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        emit TreasuryUpdated(treasuryWallet, newTreasury);
        treasuryWallet = newTreasury;
    }
    
    function setSwapRate(uint256 newSwapRate) external onlyOwner {
        swapRate = newSwapRate;
    }
    
    function setSwapToken(address newSwapToken) external onlyOwner {
        swapTokenAddress = newSwapToken;
    }
    
    function setRegistryAddress(address newRegistry) external onlyOwner {
        emit RegistryUpdated(registryAddress, newRegistry);
        registryAddress = newRegistry;
    }
    
    // ==================== Адміністративні функції ====================
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token");
        IERC20(token).transfer(owner(), amount);
    }
    
    function setMetadata(string memory newName, string memory newSymbol) external onlyOwner {
        _name = newName;
        _symbol = newSymbol;
    }
}