// SPDX-License-Identifier: MIT
/*

The wire between Bittensor and Ethereum liquidity. Uniswap v4 hooks are
programmable triggers; Bittensor subnets are decentralized intelligence engines.
Hooksensor routes stake-weighted subnet consensus on-chain, letting pools adjust
fees, manage risk and reshape curves against a global network of competing AI
models. Swap flow funds the operators who relay that consensus.

X: https://x.com/Hooksensor
*/
pragma solidity 0.8.24;

contract HooksensorToken {
    string public constant name     = "Hooksensor";
    string public constant symbol   = "SENSE";
    uint8  public constant decimals = 18;

    uint256 public constant TOTAL_SUPPLY = 100_000_000e18;
    uint256 public totalSupply;

    mapping(address => uint256)                     public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

    address public owner;
    bool    public tradingEnabled;
    bool    public limitsActive = true;
    uint256 public maxBuy    = TOTAL_SUPPLY / 100;       // 1%
    uint256 public maxWallet = (TOTAL_SUPPLY * 2) / 100; // 2%
    mapping(address => bool) public isPair;
    mapping(address => bool) public isLimitless;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed prev, address indexed next);
    event TradingEnabled();
    event PairSet(address indexed pair, bool status);
    event LimitlessSet(address indexed account, bool status);
    event LimitsLifted();

    error NotOwner(); error ZeroAddress(); error AlreadyEnabled(); error TradingNotEnabled();
    error MaxBuyExceeded(); error MaxWalletExceeded(); error InsufficientBalance();
    error InsufficientAllowance(); error PermitExpired(); error InvalidSignature();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }

    constructor() {
        owner = msg.sender;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)), keccak256("1"), block.chainid, address(this)
        ));
        totalSupply = TOTAL_SUPPLY;
        balanceOf[msg.sender] = TOTAL_SUPPLY;
        isLimitless[msg.sender] = true;
        isLimitless[address(this)] = true;
        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transfer(address to, uint256 v) external returns (bool) { _transfer(msg.sender, to, v); return true; }

    function transferFrom(address f, address to, uint256 v) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        if (a != type(uint256).max) { if (a < v) revert InsufficientAllowance(); unchecked { allowance[f][msg.sender] = a - v; } }
        _transfer(f, to, v); return true;
    }

    function approve(address s, uint256 v) external returns (bool) { allowance[msg.sender][s] = v; emit Approval(msg.sender, s, v); return true; }

    function permit(address h, address s, uint256 v, uint256 deadline, uint8 vv, bytes32 r, bytes32 ss) external {
        if (block.timestamp > deadline) revert PermitExpired();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR,
            keccak256(abi.encode(PERMIT_TYPEHASH, h, s, v, nonces[h]++, deadline))));
        address signer = ecrecover(digest, vv, r, ss);
        if (signer == address(0) || signer != h) revert InvalidSignature();
        allowance[h][s] = v; emit Approval(h, s, v);
    }

    function burn(uint256 a) external {
        if (balanceOf[msg.sender] < a) revert InsufficientBalance();
        unchecked { balanceOf[msg.sender] -= a; totalSupply -= a; }
        emit Transfer(msg.sender, address(0), a);
    }

    function enableTrading() external onlyOwner { if (tradingEnabled) revert AlreadyEnabled(); tradingEnabled = true; emit TradingEnabled(); }
    function setPair(address p, bool s) external onlyOwner { if (p == address(0)) revert ZeroAddress(); isPair[p] = s; isLimitless[p] = s; emit PairSet(p, s); }
    function setLimitless(address ac, bool s) external onlyOwner { if (ac == address(0)) revert ZeroAddress(); isLimitless[ac] = s; emit LimitlessSet(ac, s); }
    function setLimits(uint256 b, uint256 w) external onlyOwner { require(b >= TOTAL_SUPPLY / 200 && w >= TOTAL_SUPPLY / 200, "too low"); maxBuy = b; maxWallet = w; }
    function liftLimits() external onlyOwner { limitsActive = false; maxBuy = type(uint256).max; maxWallet = type(uint256).max; emit LimitsLifted(); }
    function transferOwnership(address n) external onlyOwner { if (n == address(0)) revert ZeroAddress(); emit OwnershipTransferred(owner, n); owner = n; }
    function renounceOwnership() external onlyOwner { emit OwnershipTransferred(owner, address(0)); owner = address(0); }

    function _transfer(address f, address to, uint256 v) internal {
        if (balanceOf[f] < v) revert InsufficientBalance();
        bool ef = isLimitless[f]; bool et = isLimitless[to];
        if (!tradingEnabled && !ef && !et) revert TradingNotEnabled();
        if (limitsActive && tradingEnabled) {
            if (isPair[f] && !et) { if (v > maxBuy) revert MaxBuyExceeded(); }
            if (!et && !isPair[to]) { if (balanceOf[to] + v > maxWallet) revert MaxWalletExceeded(); }
        }
        unchecked { balanceOf[f] -= v; balanceOf[to] += v; }
        emit Transfer(f, to, v);
    }
}