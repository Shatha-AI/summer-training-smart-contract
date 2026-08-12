// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║        GSPD WRAPPED TETHER USD (GUSDT) — GSPD Mainnet            ║
 * ║                    Chain ID: 2025                                ║
 * ╠══════════════════════════════════════════════════════════════════╣
 * ║  Pegged 1:1 dengan USDT Ethereum (via GSPDBridgeV2)              ║
 * ║  Decimals  : 6 (sama dengan USDT Ethereum/ERC-20)                ║
 * ║  Supply    : DYNAMIC — tidak ada batas maksimum tetap. USDT      ║
 * ║              tidak punya hard cap seperti BTC (21 juta) — supply ║
 * ║              penerbitnya sendiri terus berubah (mint/redeem),    ║
 * ║              jadi supply GUSDT sepenuhnya mengikuti jumlah USDT   ║
 * ║              yang benar-benar di-lock di EthereumBridgeV2.       ║
 * ║  Mint      : onlyBridge — bridgeMint() dipanggil GSPDBridgeV2   ║
 * ║  Burn      : onlyBridge — bridgeBurn() dipanggil GSPDBridgeV2   ║
 * ║  Genesis   : mint sekali saat deploy (modal likuiditas DEX),    ║
 * ║              TIDAK dipakai untuk hitung bridgeBackedSupply       ║
 * ╠══════════════════════════════════════════════════════════════════╣
 * ║  COMPILE: Solidity 0.8.17 | EVM: london | Optimizer: 200 runs  ║
 * ╚══════════════════════════════════════════════════════════════════╝
 *
 * ── RIWAYAT ────────────────────────────────────────────────────────
 * Dibuat dari template GWETH.sol (yang sendiri diturunkan dari
 * GWBTC.sol) — arsitektur, fungsi bridge, dan mekanisme keamanan
 * TIDAK diubah. Cuma identitas, decimals, dan kebijakan supply yang
 * disesuaikan untuk merepresentasikan USDT. Sejajar dengan GWBTC dan
 * GWETH di GSPDBridgeV2, didaftarkan lewat
 * setWrappedToken(keccak256("GUSDT"), alamat_GUSDT) — tidak
 * menggantikan token apa pun, murni aset bridge baru.
 *
 * ── PERBEDAAN DARI GWBTC.sol (sengaja, sesuai permintaan) ───────────
 *   • decimals: 8 → 6 (ikut USDT Ethereum/ERC-20, bukan WBTC)
 *   • MAX_SUPPLY: DIHAPUS (sama seperti GWETH). GWBTC pakai batas
 *     21 juta karena mengikuti hard cap BTC — USDT tidak punya batas
 *     semacam itu (penerbitnya sendiri bebas mint/redeem), jadi
 *     menambahkan batas buatan di sini justru tidak merepresentasikan
 *     asetnya dengan benar. Solidity 0.8.x tetap punya checked
 *     arithmetic bawaan, jadi totalSupply/balanceOf tetap tidak bisa
 *     overflow diam-diam walau tanpa MAX_SUPPLY eksplisit.
 * Semua bagian lain (bridgeMint/bridgeBurn/ownerMint/ownerBurn,
 * keempat fungsi admin darurat, seluruh modifier, seluruh event)
 * IDENTIK logikanya dengan GWBTC.sol/GWETH.sol.
 *
 * ── CATATAN ACCOUNTING BRIDGE (diwarisi dari GWBTC.sol) ─────────────
 * bridgeMinted = counter independen yang HANYA berubah lewat
 * bridgeMint()/bridgeBurn(). Merepresentasikan porsi supply yang
 * benar-benar 1:1 dengan USDT terkunci di EthereumBridge, terlepas
 * dari ke mana pun token itu berpindah tangan. genesisSupply tetap
 * disimpan sebagai catatan historis (modal likuiditas awal), tapi
 * TIDAK dipakai dalam perhitungan bridgeMinted/bridgeBackedSupply.
 * require(bridgeMinted >= amount) di bridgeBurn() mencegah token
 * genesis "menyamar" sebagai token bridge-backed dan ditarik keluar
 * sebagai USDT asli melebihi jumlah yang benar-benar pernah masuk
 * dari sisi Ethereum.
 *
 * bridgeBackedSupply adalah storage terpisah (bukan view alias dari
 * bridgeMinted) — supaya setBridgeBackedSupply() punya makna
 * independen. Dalam alur NORMAL (bridgeMint/bridgeBurn), kedua
 * counter selalu bergerak bersamaan dan nilainya akan selalu sama.
 * Keduanya HANYA bisa berbeda kalau owner secara sengaja memanggil
 * salah satu fungsi admin di bawah.
 *
 *   • setBridgeMinted(newValue, reason)         — Opsi 1/2 (manual override)
 *   • setBridgeBackedSupply(newValue, reason)   — Opsi 1/2 (manual override)
 *   • syncBridge()                              — samakan keduanya
 *   • convertGenesisToBridge(amount, reason)    — Opsi 2 (naikkan pangkat
 *                                                  token genesis jadi
 *                                                  bridge-backed tanpa
 *                                                  mint baru)
 *
 * ⚠️  PERINGATAN — sama seperti di GWBTC/GWETH: fungsi-fungsi di atas
 * menaikkan/menurunkan bridgeMinted/bridgeBackedSupply TANPA benar-benar
 * mengunci/melepas USDT baru di EthereumBridge. Kalau dipanggil
 * sembarangan, kontrak akan mengizinkan bridgeOut() menarik USDT yang
 * TIDAK memiliki cadangan asli. Hanya panggil kalau owner SUDAH
 * memverifikasi manual bahwa jumlah yang di-set memang benar-benar
 * didukung USDT nyata di EthereumBridge.
 */

/// @title GSPD Wrapped Tether USD (GUSDT)
/// @notice Representasi USDT Ethereum di GSPD Mainnet. Mint/burn HANYA bisa
/// dipanggil oleh kontrak GSPDBridgeV2 (alamat `bridge`), dan GSPDBridgeV2
/// sendiri hanya boleh burn saldo `msg.sender` aslinya (lihat GSPDBridgeV2.bridgeOut).
/// Signature bridgeMint(address,uint256) / bridgeBurn(address,uint256) SAMA
/// PERSIS dengan GWBTC/GWETH — GSPDBridgeV2 tidak perlu diubah/redeploy sama sekali.

abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _transferOwnership(msg.sender); }
    modifier onlyOwner() { require(owner() == msg.sender, "Ownable: not owner"); _; }
    function owner() public view virtual returns (address) { return _owner; }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address old = _owner; _owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}

// GRC-20 (standar token fungible GSPD — interface-nya identik dengan ERC-20:
// transfer/transferFrom/approve/allowance/balanceOf/totalSupply + event Transfer/Approval,
// cocok dengan referensi BridgeableGRC20.sol). Implementasi minimal, tanpa
// dependency eksternal, supaya mudah diverifikasi di explorer GSPD.
contract GUSDT is Ownable {
    string public constant name = "GSPD Wrapped Tether USD";
    string public constant symbol = "GUSDT";
    uint8  public constant decimals = 6; // samakan dengan USDT Ethereum/ERC-20, 1:1 tanpa konversi

    uint256 public totalSupply;
    uint256 public immutable genesisSupply; // dicetak sekali saat deploy — catatan historis, TIDAK dipakai untuk bridgeMinted/bridgeBackedSupply
    uint256 public bridgeMinted; // porsi supply yang benar-benar 1:1 dengan USDT terkunci; naik di bridgeMint(), turun di bridgeBurn(), TIDAK terpengaruh perpindahan token antar wallet
    uint256 public bridgeBackedSupply; // storage independen (lihat catatan di header file) — normalnya selalu sama dengan bridgeMinted
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public bridge; // hanya alamat ini yang boleh mint/burn
    bool public paused;    // saat true: bridgeMint/bridgeBurn dihentikan. Transfer biasa tetap jalan.

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);
    event BridgeBackedSupplyUpdated(uint256 bridgeMinted, uint256 bridgeBackedSupply);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // ── Event untuk fungsi admin "tombol darurat" — dipisah dari BridgeMint/
    // BridgeBurn biar jelas kelihatan di explorer/log kalau ada penyesuaian
    // manual, bukan hasil bridge sungguhan lewat lock() di Ethereum.
    event BridgeMintedSet(uint256 oldValue, uint256 newValue, string reason);
    event BridgeBackedSupplySet(uint256 oldValue, uint256 newValue, string reason);
    event BridgeSynced(uint256 bridgeMinted, uint256 bridgeBackedSupply);
    event GenesisConvertedToBridge(uint256 amount, uint256 newBridgeMinted, uint256 newBridgeBackedSupply, string reason);

    modifier onlyBridge() {
        require(msg.sender == bridge, "GUSDT: caller is not bridge");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "GUSDT: bridge operations paused");
        _;
    }

    constructor(address initialBridge, address treasury, uint256 genesisAmount) {
        require(initialBridge != address(0), "GUSDT: zero bridge");
        bridge = initialBridge;
        emit BridgeUpdated(address(0), initialBridge);

        // Immutable HARUS di-assign tepat sekali, di luar percabangan if/else,
        // supaya compiler bisa memastikan itu pasti ter-assign persis sekali.
        genesisSupply = genesisAmount;

        // Genesis mint — HANYA di sini, HANYA sekali, tidak ada fungsi lain yang
        // bisa memanggil ini lagi setelah deploy. Dipakai untuk modal likuiditas
        // DEX awal. TIDAK backed oleh USDT yang terkunci di EthereumBridge, dan
        // TIDAK menambah bridgeMinted — lihat bridgeBackedSupply untuk angka
        // yang benar-benar 1:1.
        if (genesisAmount > 0) {
            require(treasury != address(0), "GUSDT: zero treasury");
            totalSupply = genesisAmount;
            balanceOf[treasury] = genesisAmount;
            emit Transfer(address(0), treasury, genesisAmount);
        }
    }

    function tokenInfo() external view returns (
        string memory tokenName, string memory tokenSymbol,
        uint8 dec, string memory peggedTo,
        uint256 chainId, string memory chainName
    ) {
        return (name, symbol, decimals,
                "USDT Ethereum 1:1 (via GSPDBridgeV2 + EthereumBridgeV2)", 2025, "GSPD Mainnet");
    }

    // ── Admin ─────────────────────────────────────────────
    /// @notice Ganti alamat bridge (mis. saat migrasi ke GSPDBridge versi baru).
    /// Dipanggil owner. Pertimbangkan multi-sig untuk owner di production.
    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "GUSDT: zero bridge");
        emit BridgeUpdated(bridge, newBridge);
        bridge = newBridge;
    }

    /// @notice Hentikan sementara bridgeMint/bridgeBurn (mis. saat ditemukan bug/serangan).
    /// Transfer antar-holder TETAP jalan — ini bukan freeze dana pengguna.
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ── Bridge-only mint/burn ─────────────────────────────
    /// @notice Dipanggil GSPDBridgeV2 setelah verifikasi Lock di EthereumBridge.
    function bridgeMint(address to, uint256 amount) external onlyBridge whenNotPaused {
        require(to != address(0), "GUSDT: mint to zero address");
        totalSupply += amount;
        bridgeMinted += amount;
        bridgeBackedSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit BridgeMint(to, amount);
        emit BridgeBackedSupplyUpdated(bridgeMinted, bridgeBackedSupply);
    }

    /// @notice Dipanggil GSPDBridgeV2. `from` HARUS berasal dari msg.sender asli
    /// di sisi GSPDBridgeV2 (user yang memanggil bridgeOut), bukan parameter bebas.
    /// require(bridgeMinted >= amount) mencegah token genesis (yang tidak backed
    /// USDT) ikut ditarik keluar sebagai USDT asli melebihi jumlah yang benar-
    /// benar pernah di-mint dari sisi bridge.
    function bridgeBurn(address from, uint256 amount) external onlyBridge whenNotPaused {
        require(balanceOf[from] >= amount, "GUSDT: burn amount exceeds balance");
        require(bridgeMinted >= amount, "GUSDT: burn exceeds bridge-minted supply");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        bridgeMinted -= amount;
        bridgeBackedSupply -= amount;
        emit Transfer(from, address(0), amount);
        emit BridgeBurn(from, amount);
        emit BridgeBackedSupplyUpdated(bridgeMinted, bridgeBackedSupply);
    }

    // ── Owner mint/burn (tanpa keterkaitan dengan bridge — genesis/admin saja) ──
    function ownerMint(address to, uint256 amount) external onlyOwner {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function ownerBurn(address from, uint256 amount) external onlyOwner {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ══════════════════════════════════════════════════════════════════
    //  ADMIN "TOMBOL DARURAT" — Opsi 1 & 2, sebagai fungsi eksplisit yang
    //  terpisah dari alur normal ownerMint/bridgeMint. Semua onlyOwner,
    //  semua mengeluarkan event sendiri untuk audit. Baca peringatan di
    //  header file sebelum memanggil salah satu di bawah.
    // ══════════════════════════════════════════════════════════════════

    /// @notice Set langsung nilai bridgeMinted. Guna: migrasi awal / audit
    ///         manual saat kamu tahu persis berapa yang seharusnya tercatat.
    function setBridgeMinted(uint256 newValue, string calldata reason) external onlyOwner {
        require(newValue <= totalSupply, "GUSDT: bridgeMinted tidak boleh melebihi totalSupply");
        uint256 old = bridgeMinted;
        bridgeMinted = newValue;
        emit BridgeMintedSet(old, newValue, reason);
    }

    /// @notice Set langsung nilai bridgeBackedSupply (storage independen —
    ///         lihat catatan di header file). Sama peringatannya dengan
    ///         setBridgeMinted().
    function setBridgeBackedSupply(uint256 newValue, string calldata reason) external onlyOwner {
        require(newValue <= totalSupply, "GUSDT: bridgeBackedSupply tidak boleh melebihi totalSupply");
        uint256 old = bridgeBackedSupply;
        bridgeBackedSupply = newValue;
        emit BridgeBackedSupplySet(old, newValue, reason);
    }

    /// @notice Samakan bridgeBackedSupply dengan bridgeMinted dalam satu
    ///         panggilan — dipakai setelah penyesuaian manual supaya kedua
    ///         counter tidak saling berbeda tanpa sengaja.
    function syncBridge() external onlyOwner {
        bridgeBackedSupply = bridgeMinted;
        emit BridgeSynced(bridgeMinted, bridgeBackedSupply);
    }

    /// @notice "Naikkan pangkat" sebagian token genesis (hasil ownerMint)
    ///         menjadi token bridge-backed, TANPA mint token baru — dipakai
    ///         kalau owner sudah memverifikasi manual ada USDT asli yang
    ///         menjadi cadangan untuk `amount` token genesis tsb.
    function convertGenesisToBridge(uint256 amount, string calldata reason) external onlyOwner {
        require(bridgeMinted + amount <= totalSupply, "GUSDT: melebihi totalSupply");
        bridgeMinted += amount;
        bridgeBackedSupply += amount;
        emit GenesisConvertedToBridge(amount, bridgeMinted, bridgeBackedSupply, reason);
    }

    // ── ERC-20 standar ────────────────────────────────────
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Mencegah race condition klasik approve() (front-running allowance lama).
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 current = allowance[msg.sender][spender];
        require(current >= subtractedValue, "GUSDT: allowance below zero");
        allowance[msg.sender][spender] = current - subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "GUSDT: insufficient allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "GUSDT: transfer to zero address");
        require(balanceOf[from] >= amount, "GUSDT: transfer amount exceeds balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}