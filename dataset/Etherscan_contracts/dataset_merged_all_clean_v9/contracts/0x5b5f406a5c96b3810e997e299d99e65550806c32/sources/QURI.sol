// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * ===================================================
 * QURI Token - Version Final Corregida
 * ===================================================
 * Lema            : NUESTRO TESORO INMUTABLE
 * Supply maximo   : 13,000,000,000 QURI (18 decimales)
 * Distribucion inicial:
 * - 100% -> Billetera Unica del Creador
 *
 * Tarifa por Compra/Venta (3% Total):
 * - 1% -> Comision Creador (mainWallet)
 * - 1% -> Holders (Reflexion pro-rata automatica)
 * - 1% -> Quema automatica (Burn)
 *
 * CORRECCIONES APLICADAS:
 * [FIX 1] Orden burn/reflexion: _burn() se ejecuta ANTES de
 *         _distributeReflection() para que el supply reducido
 *         sea la base del calculo de reflexiones.
 * [FIX 2] deadWallet excluido del mecanismo de reflexion via
 *         _isExcludedFromReflection para no drenar el pool.
 * [FIX 3] Proteccion ante compromiso de mainWallet: emision de
 *         evento AMMPairSet ya existia; se añade restriccion de
 *         que solo se puede registrar contratos (extcodesize > 0)
 *         como pares AMM, reduciendo el riesgo de abuso.
 * [FIX 4] Funciones increaseAllowance / decreaseAllowance añadidas
 *         para evitar la vulnerabilidad clasica de front-running
 *         en approve().
 * ===================================================
 */

contract QURI {

    string private constant _name     = "QURI";
    string private constant _symbol   = "QURI";
    uint8  private constant _decimals = 18;
    string public  constant lema      = "NUESTRO TESORO INMUTABLE";
    string public  constant image     = "bafybeigvm5gjb4mbaewhyi332vydsg75qlfjq2y5vpksehgpqzwoqddr34";

    uint256 private constant MAX_SUPPLY = 13_000_000_000 * 10**18;
    uint256 private _totalSupply;
    uint256 private _totalBurned;

    address public immutable mainWallet;
    address public constant  deadWallet = 0x000000000000000000000000000000000000dEaD;

    uint256 private constant FEE_HOLDER  = 100;
    uint256 private constant FEE_BURN    = 100;
    uint256 private constant FEE_CREATOR = 100;
    uint256 private constant DENOMINATOR = 10_000;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool)    private _isFeeExempt;
    mapping(address => bool)    public  isAMMPair;

    // [FIX 2] Mapping para excluir direcciones del mecanismo de reflexion
    mapping(address => bool)    private _isExcludedFromReflection;

    uint256 private constant PRECISION = 1e18;
    uint256 private _reflectionPerToken;
    mapping(address => uint256) private _reflectionDebt;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed from, uint256 amount);
    event ReflectionDistributed(uint256 amount);
    event AMMPairSet(address indexed pair, bool value);

    constructor() {
        mainWallet    = 0x7149923B5180f546f8e8045AFF580818c25ae449;
        _totalSupply  = MAX_SUPPLY;
        _balances[mainWallet] = MAX_SUPPLY;
        emit Transfer(address(0), mainWallet, MAX_SUPPLY);

        _isFeeExempt[mainWallet]    = true;
        _isFeeExempt[deadWallet]    = true;
        _isFeeExempt[address(this)] = true;

        // [FIX 2] Excluir deadWallet y address(0) de reflexiones
        // para que los tokens quemados no disipen el pool de holders
        _isExcludedFromReflection[deadWallet]    = true;
        _isExcludedFromReflection[address(0)]    = true;
        _isExcludedFromReflection[address(this)] = true;
    }

    // -------------------------------------------------------
    // ERC-20 VIEW FUNCTIONS
    // -------------------------------------------------------

    function name()        public pure returns (string memory) { return _name; }
    function symbol()      public pure returns (string memory) { return _symbol; }
    function decimals()    public pure returns (uint8)         { return _decimals; }
    function totalSupply() public view returns (uint256)       { return _totalSupply; }
    function totalBurned() public view returns (uint256)       { return _totalBurned; }
    function lemaQURI()    public pure returns (string memory) { return lema; }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account] + _pendingReflection(account);
    }

    // -------------------------------------------------------
    // ERC-20 TRANSFER FUNCTIONS
    // -------------------------------------------------------

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // [FIX 4] increaseAllowance: evita el ataque de front-running
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        uint256 newAllowance = _allowances[msg.sender][spender] + addedValue;
        _allowances[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    // [FIX 4] decreaseAllowance: complemento seguro de increaseAllowance
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 current = _allowances[msg.sender][spender];
        require(current >= subtractedValue, "QURI: allowance por debajo de cero");
        uint256 newAllowance = current - subtractedValue;
        _allowances[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "QURI: allowance insuficiente");
        _allowances[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    // -------------------------------------------------------
    // ADMIN: REGISTRAR PARES AMM
    // -------------------------------------------------------

    function setAMMPair(address pair, bool value) external {
        require(msg.sender == mainWallet, "QURI: solo la billetera principal");
        require(pair != address(0),       "QURI: par zero address");

        if (value) {
            uint256 size;
            assembly { size := extcodesize(pair) }
            require(size > 0, "QURI: el par debe ser un contrato");
        }

        isAMMPair[pair] = value;
        emit AMMPairSet(pair, value);
    }

    // -------------------------------------------------------
    // REFLEXION INTERNA
    // -------------------------------------------------------

    function _pendingReflection(address account) internal view returns (uint256) {
        if (_isExcludedFromReflection[account]) return 0;
        if (_reflectionPerToken == 0) return 0;
        uint256 gross = (_balances[account] * _reflectionPerToken) / PRECISION;
        if (gross <= _reflectionDebt[account]) return 0;
        return gross - _reflectionDebt[account];
    }

    function _syncReflection(address account) internal {
        if (_isExcludedFromReflection[account]) return;
        uint256 pending = _pendingReflection(account);
        if (pending > 0) {
            _balances[account] += pending;
        }
        _reflectionDebt[account] = (_balances[account] * _reflectionPerToken) / PRECISION;
    }

    function _distributeReflection(uint256 amount) internal {
        if (_totalSupply == 0) return;
        _reflectionPerToken += (amount * PRECISION) / _totalSupply;
        emit ReflectionDistributed(amount);
    }

    // -------------------------------------------------------
    // LOGICA PRINCIPAL DE TRANSFERENCIA
    // -------------------------------------------------------

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "QURI: desde zero address");
        require(to   != address(0), "QURI: hacia zero address");
        require(amount > 0,         "QURI: cantidad mayor a cero");

        _syncReflection(from);
        _syncReflection(to);

        require(_balances[from] >= amount, "QURI: saldo insuficiente");

        bool takeFee = !_isFeeExempt[from] && !_isFeeExempt[to]
                       && (isAMMPair[from] || isAMMPair[to]);

        if (takeFee) {
            uint256 feeHolder  = (amount * FEE_HOLDER)  / DENOMINATOR;
            uint256 feeBurn    = (amount * FEE_BURN)    / DENOMINATOR;
            uint256 feeCreator = (amount * FEE_CREATOR) / DENOMINATOR;
            uint256 amountNet  = amount - feeHolder - feeBurn - feeCreator;

            _balances[from] -= amount;
            _reflectionDebt[from] = (_balances[from] * _reflectionPerToken) / PRECISION;

            _balances[mainWallet] += feeCreator;
            _reflectionDebt[mainWallet] = (_balances[mainWallet] * _reflectionPerToken) / PRECISION;
            emit Transfer(from, mainWallet, feeCreator);

            // [FIX 1] Burn primero, luego reflexion
            _burn(from, feeBurn);
            _distributeReflection(feeHolder);

            _balances[to] += amountNet;
            _reflectionDebt[to] = (_balances[to] * _reflectionPerToken) / PRECISION;
            emit Transfer(from, to, amountNet);

        } else {
            _balances[from] -= amount;
            _reflectionDebt[from] = (_balances[from] * _reflectionPerToken) / PRECISION;
            _balances[to] += amount;
            _reflectionDebt[to] = (_balances[to] * _reflectionPerToken) / PRECISION;
            emit Transfer(from, to, amount);
        }
    }

    function _burn(address from, uint256 amount) internal {
        _totalSupply -= amount;
        _totalBurned += amount;
        emit Transfer(from, deadWallet, amount);
        emit Burn(from, amount);
    }

    // -------------------------------------------------------
    // CONSULTA PUBLICA DE REFLEXION PENDIENTE
    // -------------------------------------------------------

    function pendingReflection(address account) external view returns (uint256) {
        return _pendingReflection(account);
    }
}