// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// ════════════════════════════════════════════════════════════
/// SPEND2STAKE — EQUITY REGISTRY
/// On-chain register of consumer equity positions (RWA-style):
///  • one contract, all businesses (businessKey = business UUID as bytes32)
///  • amounts in micro-percent (1% = 1,000,000 units)
///  • every registration anchored to its payment tx hash
///  • transfer-restricted: only the platform may move positions
///    (compliance gate for future liquidation / secondary market)
/// ════════════════════════════════════════════════════════════
contract S2SEquityRegistry {
    address public platform;

    // businessKey => holder => micro-percent equity
    mapping(bytes32 => mapping(address => uint256)) public equityOf;
    // businessKey => total registered micro-percent
    mapping(bytes32 => uint256) public totalRegistered;
    // payment tx hash => already used (replay-proof registration)
    mapping(bytes32 => bool) public refUsed;

    event Registered(bytes32 indexed businessKey, address indexed holder, uint256 microPct, bytes32 indexed paymentRef);
    event Moved(bytes32 indexed businessKey, address indexed from, address indexed to, uint256 microPct);
    event PlatformChanged(address indexed newPlatform);

    modifier onlyPlatform() {
        require(msg.sender == platform, "not platform");
        _;
    }

    constructor(address _platform) {
        require(_platform != address(0), "platform=0");
        platform = _platform;
    }

    /// Register equity for a holder. paymentRef = the on-chain payment tx hash.
    function register(bytes32 businessKey, address holder, uint256 microPct, bytes32 paymentRef)
        public onlyPlatform
    {
        require(holder != address(0), "holder=0");
        require(microPct > 0, "amount=0");
        require(!refUsed[paymentRef], "ref used");
        refUsed[paymentRef] = true;

        equityOf[businessKey][holder] += microPct;
        totalRegistered[businessKey] += microPct;
        emit Registered(businessKey, holder, microPct, paymentRef);
    }

    function registerBatch(
        bytes32[] calldata keys,
        address[] calldata holders,
        uint256[] calldata amounts,
        bytes32[] calldata refs
    ) external onlyPlatform {
        require(keys.length == holders.length && keys.length == amounts.length && keys.length == refs.length, "len");
        for (uint256 i = 0; i < keys.length; i++) {
            register(keys[i], holders[i], amounts[i], refs[i]);
        }
    }

    /// Compliance-gated movement (liquidation, approved secondary transfer)
    function move(bytes32 businessKey, address from, address to, uint256 microPct)
        external onlyPlatform
    {
        require(equityOf[businessKey][from] >= microPct, "insufficient");
        equityOf[businessKey][from] -= microPct;
        if (to == address(0)) {
            totalRegistered[businessKey] -= microPct;   // burn (liquidated)
        } else {
            equityOf[businessKey][to] += microPct;
        }
        emit Moved(businessKey, from, to, microPct);
    }

    function setPlatform(address _platform) external onlyPlatform {
        require(_platform != address(0), "platform=0");
        platform = _platform;
        emit PlatformChanged(_platform);
    }
}