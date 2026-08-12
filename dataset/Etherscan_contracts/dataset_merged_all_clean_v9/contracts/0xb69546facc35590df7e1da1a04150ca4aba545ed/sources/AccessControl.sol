// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File: @openzeppelin/contracts/access/IAccessControl.sol


// OpenZeppelin Contracts (last updated v5.4.0) (access/IAccessControl.sol)


/**
 * @dev External interface of AccessControl declared to support ERC-165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted to signal this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call. This account bears the admin role (for the granted role).
     * Expected in cases where the role was granted using the internal {AccessControl-_grantRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)


/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/utils/introspection/ERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/ERC165.sol)



/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
contract ERC165 is IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// File: @openzeppelin/contracts/access/AccessControl.sol


// OpenZeppelin Contracts (last updated v5.6.0) (access/AccessControl.sol)





/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` from `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// File: SettlementEngine_v2.sol


interface IToken {
    function mint(address to, uint256 amount) external;
}

contract SettlementEngine is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    IToken public token;
    
    address public masterWallet;

    mapping(string => bool) public processedUETRs;
    mapping(string => bool) public processedTRNs;
    mapping(string => bool) public processedEndToEndRefs;
    mapping(string => bool) public processedBankRefs;
    mapping(string => bool) public processedSettlementRefs;
    mapping(string => bool) public processedInstructionIds;
    mapping(string => bool) public processedAccountRefs;
    mapping(string => bool) public mergedUETRs;

    enum RefType { UETR, TRN, END_TO_END, BANK_REF, SETTLEMENT_REF, INSTRUCTION_ID, ACCOUNT_REF }

    constructor() {
        token = IToken(0x0F987993754e8262F6aD81c89eED2F125e8E2764);
        masterWallet = 0x8E948FF33282B29714943d3A2B5271f8E95A078D;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _setRoleAdmin(ORACLE_ROLE, ORACLE_ROLE);
    }

    function processUETR(string memory uetr) public onlyRole(ORACLE_ROLE) {
        require(!processedUETRs[uetr], "Already processed");
        processedUETRs[uetr] = true;
    }

    function processTRN(string memory trn) public onlyRole(ORACLE_ROLE) {
        require(!processedTRNs[trn], "Already processed");
        processedTRNs[trn] = true;
    }

    function processEndToEndRef(string memory endToEnd) public onlyRole(ORACLE_ROLE) {
        require(!processedEndToEndRefs[endToEnd], "Already processed");
        processedEndToEndRefs[endToEnd] = true;
    }

    function processBankRef(string memory bankRef) public onlyRole(ORACLE_ROLE) {
        require(!processedBankRefs[bankRef], "Already processed");
        processedBankRefs[bankRef] = true;
    }

    function processSettlementRef(string memory settlementRef) public onlyRole(ORACLE_ROLE) {
        require(!processedSettlementRefs[settlementRef], "Already processed");
        processedSettlementRefs[settlementRef] = true;
    }

    function processInstructionId(string memory instructionId) public onlyRole(ORACLE_ROLE) {
        require(!processedInstructionIds[instructionId], "Already processed");
        processedInstructionIds[instructionId] = true;
    }

    function processAccountRef(string memory accountRef) public onlyRole(ORACLE_ROLE) {
        require(!processedAccountRefs[accountRef], "Already processed");
        processedAccountRefs[accountRef] = true;
    }

    function mergeValue(string memory uetr, uint256 amount) public onlyRole(ORACLE_ROLE) {
        require(processedUETRs[uetr], "UETR not processed");
        require(!mergedUETRs[uetr], "Already merged");
        mergedUETRs[uetr] = true;
        token.mint(masterWallet, amount);
    }

    function mergeByReference(RefType refType, string memory refValue, uint256 amount) public onlyRole(ORACLE_ROLE) {
        if (refType == RefType.UETR) {
            require(processedUETRs[refValue], "UETR not processed");
            require(!mergedUETRs[refValue], "Already merged");
            mergedUETRs[refValue] = true;
        } else if (refType == RefType.TRN) {
            require(processedTRNs[refValue], "TRN not processed");
        } else if (refType == RefType.END_TO_END) {
            require(processedEndToEndRefs[refValue], "End-to-end ref not processed");
        } else if (refType == RefType.BANK_REF) {
            require(processedBankRefs[refValue], "Bank ref not processed");
        } else if (refType == RefType.SETTLEMENT_REF) {
            require(processedSettlementRefs[refValue], "Settlement ref not processed");
        } else if (refType == RefType.INSTRUCTION_ID) {
            require(processedInstructionIds[refValue], "Instruction ID not processed");
        } else if (refType == RefType.ACCOUNT_REF) {
            require(processedAccountRefs[refValue], "Account ref not processed");
        }
        token.mint(masterWallet, amount);
    }

    function setMasterWallet(address _newMasterWallet) public onlyRole(DEFAULT_ADMIN_ROLE) {
        masterWallet = _newMasterWallet;
    }

    // Optional XML parsing function for future use
    // WARNING: Gas-intensive (~150k+ gas). Use processUETR/mergeValue directly for efficiency.
    // This function parses pacs.008 XML to extract UETR, amount, and receiver wallet address, then processes the transaction.
    function processXML(bytes calldata xmlData) public onlyRole(ORACLE_ROLE) {
        // Extract UETR from <UETR> tag
        string memory uetr = _extractUETRFromXML(xmlData);
        require(bytes(uetr).length > 0, "UETR not found in XML");
        
        // Extract amount from <InstdAmt> tag (simplified parsing)
        uint256 amount = _extractAmountFromXML(xmlData);
        require(amount > 0, "Amount not found in XML");
        
        // Extract receiver wallet address from CdtrAcct/Id/Othr/Id with scheme WALLET_ADDR
        address receiverWallet = _extractWalletFromXML(xmlData);
        require(receiverWallet != address(0), "Wallet address not found in XML");
        
        // Process the transaction
        require(!processedUETRs[uetr], "Already processed");
        processedUETRs[uetr] = true;
        
        // Mint tokens to the extracted receiver wallet address
        token.mint(receiverWallet, amount);
    }

    // Helper: Extract UETR from XML (simplified parser)
    function _extractUETRFromXML(bytes calldata xmlData) internal pure returns (string memory) {
        bytes memory uetrTag = bytes("<UETR>");
        bytes memory uetrEndTag = bytes("</UETR>");
        
        for (uint i = 0; i < xmlData.length - uetrTag.length; i++) {
            bool isMatch = true;
            for (uint j = 0; j < uetrTag.length; j++) {
                if (xmlData[i + j] != uetrTag[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                uint start = i + uetrTag.length;
                uint end = start;
                for (uint k = start; k < xmlData.length - uetrEndTag.length; k++) {
                    bool endMatch = true;
                    for (uint m = 0; m < uetrEndTag.length; m++) {
                        if (xmlData[k + m] != uetrEndTag[m]) {
                            endMatch = false;
                            break;
                        }
                    }
                    if (endMatch) {
                        end = k;
                        break;
                    }
                }
                bytes memory result = new bytes(end - start);
                for (uint n = 0; n < end - start; n++) {
                    result[n] = xmlData[start + n];
                }
                return string(result);
            }
        }
        return "";
    }

    // Helper: Extract amount from XML (simplified parser)
    function _extractAmountFromXML(bytes calldata xmlData) internal pure returns (uint256) {
        // Look for <InstdAmt Ccy="EUR"> or similar pattern
        // This is a simplified implementation - production would need more robust parsing
        for (uint i = 0; i < xmlData.length - 20; i++) {
            if (xmlData[i] == '>' && xmlData[i+1] >= 0x30 && xmlData[i+1] <= 0x39) {
                // Found start of number
                uint256 amount = 0;
                uint j = i + 1;
                while (j < xmlData.length && xmlData[j] >= 0x30 && xmlData[j] <= 0x39) {
                    amount = amount * 10 + (uint256(uint8(xmlData[j])) - 48);
                    j++;
                }
                if (amount > 0) return amount;
            }
        }
        return 0;
    }

    // Helper: Extract wallet address from CdtrAcct/Id/Othr/Id with scheme WALLET_ADDR
    function _extractWalletFromXML(bytes calldata xmlData) internal pure returns (address) {
        // Simplified parser - looks for WALLET_ADDR pattern
        bytes memory walletAddrScheme = bytes("WALLET_ADDR");
        
        for (uint i = 0; i < xmlData.length - walletAddrScheme.length; i++) {
            bool schemeMatch = true;
            for (uint j = 0; j < walletAddrScheme.length; j++) {
                if (xmlData[i + j] != walletAddrScheme[j]) {
                    schemeMatch = false;
                    break;
                }
            }
            
            if (schemeMatch) {
                // Found WALLET_ADDR, now look backward for <Id> tag
                for (uint k = i - 50; k < i; k++) {
                    if (k + 3 < xmlData.length && 
                        xmlData[k] == '<' && 
                        xmlData[k + 1] == 'I' && 
                        xmlData[k + 2] == 'd' && 
                        xmlData[k + 3] == '>') {
                        // Found <Id> tag, extract address
                        uint addrStart = k + 4;
                        uint addrEnd = addrStart;
                        while (addrEnd < xmlData.length && addrEnd < addrStart + 50 && xmlData[addrEnd] != '<') {
                            addrEnd++;
                        }
                        
                        // Validate and parse address
                        if (addrEnd - addrStart >= 42 && xmlData[addrStart] == '0' && xmlData[addrStart + 1] == 'x') {
                            return _parseAddressFromBytes(xmlData, addrStart + 2, addrEnd);
                        }
                    }
                }
            }
        }
        return address(0);
    }

    // Helper: Parse hex address from bytes
    function _parseAddressFromBytes(bytes calldata data, uint start, uint end) internal pure returns (address) {
        uint160 addr = 0;
        for (uint i = start; i < end && i < start + 40; i++) {
            uint8 byteVal = 0;
            bytes1 char = data[i];
            if (char >= 0x30 && char <= 0x39) {
                byteVal = uint8(char) - 48;
            } else if (char >= 0x61 && char <= 0x66) {
                byteVal = uint8(char) - 87;
            } else if (char >= 0x41 && char <= 0x46) {
                byteVal = uint8(char) - 55;
            } else {
                return address(0);
            }
            addr = addr * 16 + byteVal;
        }
        return address(addr);
    }

    function grantOracleRole(address oracleAddress) public onlyRole(ORACLE_ROLE) {
        _grantRole(ORACLE_ROLE, oracleAddress);
    }
}