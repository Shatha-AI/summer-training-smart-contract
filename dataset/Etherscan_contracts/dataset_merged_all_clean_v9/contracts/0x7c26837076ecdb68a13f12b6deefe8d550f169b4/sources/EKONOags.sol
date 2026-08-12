// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * ============================================================
 *  EKONOags TOKEN (EK) — ERC-20 Smart Contract
 *  Version: 2.0 — Corrected Gold Conversion Formula
 * ============================================================
 *  Issuer  : AGS CONSEIL FRANCE SAS
 *            149 Avenue du Maine, 75014 Paris, France
 *            SIREN: 981869159
 *
 *  Filiale : AGS CONSEIL SALONE LIMITED
 *            25 Sander Street, Freetown, Sierra Leone
 *            TIN: 1001115910
 *
 *  Token   : EKONOags (EK)
 *  Standard: ERC-20 (Ethereum)
 *  Network : Ethereum Mainnet
 *
 *  ============================================================
 *  FORMULE DE CONVERSION OFFICIELLE :
 *
 *     100 EK  = 2 grammes d or
 *     100 EK  = 0.06430149 XAU
 *       1 EK  = 0.02 gramme d or
 *       1 EK  = 0.0006430149 XAU
 *
 *  Reference : 1 XAU = 1 once troy = 31.1034768 grammes
 *  ============================================================
 */

// ─────────────────────────────────────────────────────────────
//  INTERFACE ERC-20
// ─────────────────────────────────────────────────────────────
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply()                                          external view returns (uint256);
    function balanceOf(address account)                            external view returns (uint256);
    function transfer(address to, uint256 amount)                  external returns (bool);
    function allowance(address owner, address spender)             external view returns (uint256);
    function approve(address spender, uint256 amount)              external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// ─────────────────────────────────────────────────────────────
//  CONTEXT
// ─────────────────────────────────────────────────────────────
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

// ─────────────────────────────────────────────────────────────
//  OWNABLE
// ─────────────────────────────────────────────────────────────
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: zero address not allowed");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// ─────────────────────────────────────────────────────────────
//  MAIN CONTRACT : EKONOags
// ─────────────────────────────────────────────────────────────
contract EKONOags is IERC20, Ownable {

    // ── TOKEN METADATA ───────────────────────────────────────
    string public constant name     = "EKONOags";
    string public constant symbol   = "EK";
    uint8  public constant decimals = 18;

    // ── TOTAL SUPPLY : 30,000,000 EK ─────────────────────────
    uint256 private constant _TOTAL_SUPPLY = 30_000_000 * (10 ** 18);

    // ── GOLD CONVERSION CONSTANTS ────────────────────────────
    // 100 EK = 2 grammes d or = 0.06430149 XAU
    // 1 EK   = 0.02 gramme d or = 0.0006430149 XAU
    // 1 once troy = 31.1034768 grammes

    // Grammes d or par 100 EK
    uint256 public constant GOLD_GRAMS_PER_100_EK = 2;

    // Milligrammes d or par 1 EK : 0.02g = 20mg
    uint256 public constant GOLD_MG_PER_EK = 20;

    // XAU par 1 EK x 10^10 = 6430149
    // => 1 EK = 6430149 / 10^10 XAU = 0.0006430149 XAU
    uint256 public constant XAU_NUMERATOR   = 6430149;
    uint256 public constant XAU_DENOMINATOR = 10_000_000_000;

    // XAU par 100 EK x 10^8 = 6430149
    // => 100 EK = 6430149 / 10^8 XAU = 0.06430149 XAU
    uint256 public constant XAU_100EK_NUMERATOR   = 6430149;
    uint256 public constant XAU_100EK_DENOMINATOR = 100_000_000;

    // Once troy en mg x 10000 pour precision
    uint256 public constant TROY_OUNCE_MG_X10000 = 311034768;

    // ── GOLD PRICE ORACLE ────────────────────────────────────
    // Prix or en USD x 100 (ex: 306500 = 3065.00 USD/once)
    uint256 public goldPriceUSD_x100 = 306500;

    // ── BALANCES & ALLOWANCES ────────────────────────────────
    mapping(address => uint256)                     private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ── EVENTS ───────────────────────────────────────────────
    event GoldPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    // ── CONSTRUCTOR ──────────────────────────────────────────
    constructor() {
        _balances[_msgSender()] = _TOTAL_SUPPLY;
        emit Transfer(address(0), _msgSender(), _TOTAL_SUPPLY);
    }

    // ─────────────────────────────────────────────────────────
    //  ERC-20 STANDARD FUNCTIONS
    // ─────────────────────────────────────────────────────────
    function totalSupply() public pure override returns (uint256) {
        return _TOTAL_SUPPLY;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[from][_msgSender()];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        unchecked { _approve(from, _msgSender(), currentAllowance - amount); }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 current = _allowances[_msgSender()][spender];
        require(current >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked { _approve(_msgSender(), spender, current - subtractedValue); }
        return true;
    }

    // ─────────────────────────────────────────────────────────
    //  GOLD CONVERSION FUNCTIONS
    // ─────────────────────────────────────────────────────────

    /**
     * @notice 100 EK = 2 grammes d or
     * @param ekAmount Montant EK (ex: 100)
     * @return milligrams Milligrammes d or (ex: 100 EK = 2000 mg)
     */
    function ekToGoldMilligrams(uint256 ekAmount)
        public pure returns (uint256 milligrams)
    {
        return ekAmount * GOLD_MG_PER_EK;
    }

    /**
     * @notice Convertit EK en grammes d or (entier)
     * @param ekAmount Montant EK (ex: 100)
     * @return grams Grammes d or (ex: 100 EK = 2g)
     */
    function ekToGoldGrams(uint256 ekAmount)
        public pure returns (uint256 grams)
    {
        return (ekAmount * GOLD_GRAMS_PER_100_EK) / 100;
    }

    /**
     * @notice Convertit EK en XAU (valeur x 10^10)
     * @param ekAmount Montant EK (ex: 100)
     * @return xauValue Valeur XAU x 10^10 (ex: 100 EK = 643014931)
     * @dev Pour obtenir XAU reel : diviser par XAU_DENOMINATOR (10^10)
     * Exemple : 100 EK -> 643014900 / 10^10 = 0.06430149 XAU
     */
    function ekToXAU(uint256 ekAmount)
        public pure returns (uint256 xauValue)
    {
        return ekAmount * XAU_NUMERATOR;
    }

    /**
     * @notice Convertit EK en USD selon prix or actuel
     * @param ekAmount Montant EK (ex: 100)
     * @return usdValue_x100 Valeur USD x 100 (ex: 100 EK = 19708 = 197.08 USD)
     */
    function ekToUSD(uint256 ekAmount)
        public view returns (uint256 usdValue_x100)
    {
        uint256 mg = ekToGoldMilligrams(ekAmount);
        return (mg * goldPriceUSD_x100 * 10000) / TROY_OUNCE_MG_X10000;
    }

    /**
     * @notice Convertit grammes d or en EK
     * @param grams Grammes d or (ex: 2)
     * @return ekAmount EK correspondants (ex: 2g = 100 EK)
     */
    function goldGramsToEK(uint256 grams)
        public pure returns (uint256 ekAmount)
    {
        return grams * 50;
    }

    /**
     * @notice Convertit XAU en EK
     * @param xauValue_x10 Valeur XAU x 10 (ex: 1 XAU = 10)
     * @return ekAmount EK correspondants
     */
    function xauToEK(uint256 xauValue_x10)
        public pure returns (uint256 ekAmount)
    {
        // 1 XAU = 31.1034768g | 1g = 50 EK | 1 XAU = 1555.17384 EK
        // Stocke x10 pour precision : 15551 EK par XAU x10
        return (xauValue_x10 * 15551) / 10;
    }

    /**
     * @notice Resume complet de conversion pour un montant EK
     * @param ekAmount Montant EK a convertir
     * @return milligrams Milligrammes d or
     * @return grams Grammes d or
     * @return xau_x10e10 Valeur XAU x 10^10
     * @return usd_x100 Valeur USD x 100
     */
    function getConversionSummary(uint256 ekAmount)
        public view
        returns (
            uint256 milligrams,
            uint256 grams,
            uint256 xau_x10e10,
            uint256 usd_x100
        )
    {
        milligrams  = ekToGoldMilligrams(ekAmount);
        grams       = ekToGoldGrams(ekAmount);
        xau_x10e10  = ekToXAU(ekAmount);
        usd_x100    = ekToUSD(ekAmount);
    }

    // ─────────────────────────────────────────────────────────
    //  OWNER FUNCTIONS
    // ─────────────────────────────────────────────────────────

    /**
     * @notice Met a jour le prix de l or (oracle manuel)
     * @param newPrice Nouveau prix USD x 100 (ex: 306500 = 3065.00 USD/once)
     */
    function updateGoldPrice(uint256 newPrice) external onlyOwner {
        emit GoldPriceUpdated(goldPriceUSD_x100, newPrice);
        goldPriceUSD_x100 = newPrice;
    }

    /**
     * @notice Burn des tokens (reduction supply)
     * @param amount Montant a bruler (avec decimales)
     */
    function burn(uint256 amount) external onlyOwner {
        require(_balances[_msgSender()] >= amount, "ERC20: burn amount exceeds balance");
        unchecked { _balances[_msgSender()] -= amount; }
        emit Transfer(_msgSender(), address(0), amount);
        emit TokensBurned(_msgSender(), amount);
    }

    // ─────────────────────────────────────────────────────────
    //  INFO FUNCTIONS
    // ─────────────────────────────────────────────────────────

    /**
     * @notice Formule officielle de conversion
     */
    function conversionFormula() external pure returns (string memory) {
        return "100 EK = 2g or = 0.06430149 XAU | 1 EK = 0.02g = 0.0006430149 XAU";
    }

    /**
     * @notice Informations emetteur
     */
    function issuerInfo() external pure returns (string memory) {
        return "AGS CONSEIL FRANCE SAS | SIREN: 981869159 | 149 Av. du Maine, 75014 Paris, France";
    }

    /**
     * @notice Informations filiale
     */
    function subsidiaryInfo() external pure returns (string memory) {
        return "AGS CONSEIL SALONE LIMITED | TIN: 1001115910 | 25 Sander Street, Freetown, Sierra Leone";
    }

    // ─────────────────────────────────────────────────────────
    //  INTERNAL FUNCTIONS
    // ─────────────────────────────────────────────────────────
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to   != address(0), "ERC20: transfer to zero address");
        require(_balances[from] >= amount, "ERC20: insufficient balance");
        unchecked {
            _balances[from] -= amount;
            _balances[to]   += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_   != address(0), "ERC20: approve from zero address");
        require(spender  != address(0), "ERC20: approve to zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
}