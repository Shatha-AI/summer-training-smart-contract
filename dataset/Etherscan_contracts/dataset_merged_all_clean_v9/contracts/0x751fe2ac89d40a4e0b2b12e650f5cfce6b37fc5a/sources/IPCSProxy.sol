// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

    contract IPCSProxy {
    event Upgraded(address indexed implementation);
    event AuthorityChanged(address indexed previousAuthority, address indexed newAuthority);
    event AuthorityProposed(address indexed pendingAuthority);
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant AUTHORITY_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 private constant INIT_SLOT = 0x7623a3df54f595085e6831d10243e858df34045a190875c74296181b5c4046d3;
    bytes32 private constant PENDING_AUTHORITY_SLOT = 0x52306045cc27177f6879a329daa3292f09a7af0dbdee5993a6563d421e02d5cc;

    constructor(address _logic) {
        _setAuthority(msg.sender);
        _setImplementation(_logic);

        emit Upgraded(_logic);
        emit AuthorityChanged(address(0), msg.sender);
        }

    modifier onlyAuthority() {
        require(msg.sender == getAuthority(), "Proxy: Not Authority");
        _;
        }

    function setup(bytes calldata _data) external onlyAuthority {
        require(!_getInitialized(), "Proxy: Already initialized");
        address impl = getImplementation();
        (bool success, ) = impl.delegatecall(_data);
        require(success, "Proxy: Initialization failed");

        _setInitialized(true);
        }

    function upgradeModule(address newImplementation) external onlyAuthority {
        require(newImplementation != address(0), "Proxy: Zero address not allowed");
        require(newImplementation.code.length > 0, "Proxy: Implementation must be a contract");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
        }

    function proposeAuthority(address newAuthority_) external onlyAuthority {
        require(newAuthority_ != address(0), "Proxy: Zero address not allowed");
        _setPendingAuthority(newAuthority_);
        emit AuthorityProposed(newAuthority_);
        }

    function acceptAuthority() external {
        address pending = _getPendingAuthority();
        require(msg.sender == pending, "Proxy: Not pending authority");
        address oldAuthority = getAuthority();
        _setAuthority(msg.sender);
        _setPendingAuthority(address(0));
        emit AuthorityChanged(oldAuthority, msg.sender);
        }

    function _setImplementation(address _impl) private {
        assembly { sstore(IMPLEMENTATION_SLOT, _impl) }
        }

    function getImplementation() public view returns (address impl) {
        assembly { impl := sload(IMPLEMENTATION_SLOT) }
        }

    function _setAuthority(address _adm) private {
        assembly { sstore(AUTHORITY_SLOT, _adm) }
        }
    
    function getAuthority() private view returns (address adm) {
        assembly { adm := sload(AUTHORITY_SLOT) }
        }

    function _setPendingAuthority(address _pending) private {
        assembly { sstore(PENDING_AUTHORITY_SLOT, _pending) }
        }

    function _getPendingAuthority() private view returns (address pending) {
        assembly { pending := sload(PENDING_AUTHORITY_SLOT) }
        }

    function _setInitialized(bool status) private {
        uint256 val = status ? 1 : 0;
        assembly { sstore(INIT_SLOT, val) }
        }

    function _getInitialized() private view returns (bool initialized) {
        uint256 val;
        assembly { val := sload(INIT_SLOT) }
        initialized = (val == 1);
        }

    fallback() external payable {
        require(_getInitialized(), "Proxy: Locked. Authority must initialize first.");

        address _impl = getImplementation();
        require(_impl != address(0), "Proxy: Logic not set");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
                }
            }
        }
    /* ——————————————————————————————— Proxy: 99382, ipcs.
    
         ▒██▓ ███▄    █ ▄▄▄█████▓▓█████  ██▓        ██▓███   ▒█████   ██▀███  ▄▄▄▓████▓
         ▓██▒ ██ ▀█   █ ▓  ██▒ ▓▒▓█   ▀ ▓██▒       ▓██░  ██▒▒██▒  ██▒▓██ ▒ ██▒▓  ██▒ ▓▒
         ▒██▒▓██  ▀█ ██▒▒ ▓██░ ▒░▒███   ▒██░       ▓██░ ██▓▒▒██░  ██▒▓██ ░▄█ ▒▒ ▓██░ ▒░
         ░██░▓██▒  ▐▌██▒░ ▓██▓ ░ ▒▓█  ▄ ▒██░       ▒██▄█▓▒ ▒▒██   ██░▒██▀▀█▄  ░ ▓██▓ ░ 
         ░██░▒██░   ▓██░  ▒██▒ ░ ░▒████▒░██████▒   ▒██▒ ░  ░░ ████▓▒░░██▓ ██▒   ▒██▒ ░ 
        █░▓  ░ ▒░   ▒ ▒   ▒ ░░   ░░ ▒░ ░░ ▒░▓  ░   ▒▓▒░ ░  ░░ ▒░▒░▒░ ░ ▒▓░▒▓░  ▒ ░░   
          ▒ ░░ ░░   ░ ▒░    ░     ░ ░  ░░ ░ ▒  ░   ░▒ ░       ░ ▒ ▒░   ░▒ ░ ▒░    ░    
          ▒ ░   ░   ░ ░   ░         ░     ░ ░      ░░       ░ ░ ░ ▒    ░░        ░      
          ░           ░             ░  ░    ░  ░                ░ ░                   
          ██████  ██▓ ██▓    ▓█████  ███▄    █ ▄▄▄█████▓     ▄████  ███▄    █  ██▓ ███▄    █ ▓█████ 
        ▒██    ▒ ▓██▒▓██▒    ▓█   ▀  ██ ▀█   █ ▓  ██▒ ▓▒    ██▒ ▀█▒ ██ ▀█   █ ▓██▒ ██ ▀█   █ ▓█   ▀ 
        ░ ▓██▄   ▒██▒▒██░    ▒███   ▓██  ▀█ ██▒▒ ▓██░ ▒░   ▒██░▄▄▄░▓██  ▀█ ██▒▒██▒▓██  ▀█ ██▒▒███   
          ▒   ██▒░██░▒██░    ▒▓█  ▄ ▓██▒  ▐▌██▒░ ▓██▓ ░    ░▓█  ██▓▓██▒  ▐▌██▒░██░▓██▒  ▐▌██▒▒▓█  ▄ 
        ▒██████▒▒░██░░██████▒░▒████▒▒██░   ▓██░  ▒██▒ ░    ░▒▓███▀▒▒██░   ▓██░░██░▒██░   ▓██░░▒████▒
        ▒ ▒▓▒ ▒ ░░▓  ░ ▒░▓  ░░░ ▒░ ░░ ▒░   ▒ ▒   ▒ ░░       ░▒   ▒ ░ ▒░   ▒ ▒ ░▓  ░ ▒░   ▒ ▒ ░░ ▒░ ░
        ░ ░▒  ░ ░ ▒ ░░ ░ ▒  ░ ░ ░  ░░ ░░   ░ ▒░    ░         ░   ░ ░ ░░   ░ ▒░ ▒ ░░ ░░   ░ ▒░ ░ ░  ░
        ░  ░  ░   ▒ ░  ░ ░      ░      ░   ░ ░   ░         ░ ░   ░    ░   ░ ░  ▒ ░   ░   ░ ░    ░   
              ░   ░      ░  ░   ░  ░         ░                   ░          ░  ░           ░    ░ 
        Proxy Design by IPCS > Intel Port Contract Security.
          - @author Ann Mandriana - <ann@intelport.org>
        intel port contract security - @prog <G9S1L3NT9486949888888888888888888888889487588777778> */