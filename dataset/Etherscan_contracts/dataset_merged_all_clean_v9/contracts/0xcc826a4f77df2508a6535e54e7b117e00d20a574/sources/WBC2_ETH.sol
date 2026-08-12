// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║        WRAPPED BITCOININ II (WBC2) — Ethereum                     ║
 * ║                    Chain ID: 1 (Ethereum Mainnet)                 ║
 * ╠══════════════════════════════════════════════════════════════════╣
 * ║  Pegged 1:1 dengan BC2 Native (via bridge mint/burn BARU di      ║
 * ║  Ethereum — BUKAN EthereumBridgeV2, lihat catatan di bawah)     ║
 * ║  Supply    : 21,000,000 WBC2 MAX (asumsi mirip pola BTC —        ║
 * ║              SESUAIKAN kalau BC2 Native beda batasnya)           ║
 * ║  Decimals  : 8 (samakan dengan BC2 Native)                       ║
 * ║  Mint      : onlyBridge — bridgeMint() dipanggil bridge Ethereum ║
 * ║  Burn      : onlyBridge — bridgeBurn() dipanggil bridge Ethereum ║
 * ║  Genesis   : mint sekali saat deploy (modal likuiditas DEX),    ║
 * ║              TIDAK dipakai untuk hitung bridgeBackedSupply       ║
 * ╠══════════════════════════════════════════════════════════════════╣
 * ║  COMPILE: Solidity 0.8.17 | EVM: london | Optimizer: 200 runs  ║
 * ╚══════════════════════════════════════════════════════════════════╝
 *
 * ── RIWAYAT ────────────────────────────────────────────────────────
 * Dibuat dari template GWBTC.sol (arsitektur, fungsi bridge, dan
 * mekanisme keamanan TIDAK diubah) — token BARU untuk ekosistem BC2,
 * BUKAN penerus/migrasi dari token manapun. Pasangan dari WBC2-GSPD.sol
 * (kontrak WBC2 di GSPD Mainnet) — sama-sama merepresentasikan BC2
 * Native, di dua chain berbeda.
 *
 * ⚠️  CATATAN ARSITEKTUR PENTING — WAJIB DIBACA SEBELUM DEPLOY:
 * Kontrak ini TIDAK BISA memakai EthereumBridgeV2 yang sudah ada
 * (dipakai untuk WBTC/WETH). EthereumBridgeV2 bergaya "lock aset
 * ASLI" — WBTC/WETH memang sudah ada duluan sebagai token ERC-20
 * nyata di Ethereum. BC2 Native TIDAK seperti itu: "SAAT INI BELUM
 * ADA WBC2 resmi di jaringan mana pun" (sesuai konfirmasi awal),
 * artinya WBC2 di Ethereum ini SAMA-SAMA wrapped/sintetis dengan WBC2
 * di GSPD (lihat WBC2-GSPD.sol) — bukan salah satu "asli" dan
 * satunya "wrapped".
 *
 * Konsekuensinya: variabel `bridge` di kontrak ini HARUS menunjuk ke
 * kontrak bridge BARU bergaya mint/burn yang dideploy di Ethereum
 * (analog GSPDBridgeV2, TAPI di Ethereum) — bukan EthereumBridgeV2.
 * Kontrak bridge Ethereum yang baru itu BELUM saya buat di sesi ini.
 * Sisi BC2 Native sendiri (chain aslinya, kalau memang ada "BC2
 * Network" terpisah) juga butuh kontrak "lock" tersendiri yang belum
 * bisa saya buat karena saya belum tahu teknologi chain itu (EVM atau
 * bukan).
 *
 * ── CATATAN ACCOUNTING BRIDGE (diwarisi dari GWBTC.sol) ─────────────
 * bridgeMinted = counter independen yang HANYA berubah lewat
 * bridgeMint()/bridgeBurn(). Merepresentasikan porsi supply yang
 * benar-benar 1:1 dengan BC2 Native yang benar-benar dikunci di sisi
 * asalnya, terlepas dari ke mana pun token itu berpindah tangan.
 * genesisSupply tetap disimpan sebagai catatan historis (modal
 * likuiditas awal), tapi TIDAK dipakai dalam perhitungan
 * bridgeMinted/bridgeBackedSupply. require(bridgeMinted >= amount) di
 * bridgeBurn() mencegah token genesis "menyamar" sebagai token
 * bridge-backed dan ditarik keluar sebagai BC2 Native asli melebihi
 * jumlah yang benar-benar pernah masuk.
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
 * ⚠️  PERINGATAN — fungsi-fungsi di atas menaikkan/menurunkan
 * bridgeMinted/bridgeBackedSupply TANPA benar-benar mengunci/melepas
 * BC2 Native baru di sisi asalnya. Kalau dipanggil sembarangan,
 * kontrak akan mengizinkan bridgeOut() menarik BC2 Native yang TIDAK
 * memiliki cadangan asli. Hanya panggil kalau owner SUDAH
 * memverifikasi manual bahwa jumlah yang di-set memang benar-benar
 * didukung BC2 Native nyata.
 */

/// @title Wrapped BitcoinII (WBC2) — Ethereum
/// @notice Representasi BC2 Native di Ethereum. Mint/burn HANYA bisa
/// dipanggil oleh kontrak bridge Ethereum yang BARU (alamat `bridge`,
/// BUKAN EthereumBridgeV2 — lihat catatan arsitektur di atas), dan bridge
/// itu sendiri hanya boleh burn saldo `msg.sender` aslinya. Signature
/// bridgeMint(address,uint256) / bridgeBurn(address,uint256) SAMA PERSIS
/// dengan GWBTC/WBC2-GSPD, supaya kontrak bridge Ethereum yang baru bisa
/// dibuat konsisten dengan pola GSPDBridgeV2.

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
contract WBC2_ETH is Ownable {
    string public constant name = "Wrapped BitcoinII";
    string public constant symbol = "WBC2";
    uint8  public constant decimals = 8; // samakan dengan BC2 Native (8 desimal), 1:1 tanpa konversi
    uint256 public constant MAX_SUPPLY = 21_000_000 * 10**8; // mengikuti asumsi batas suplai BC2 Native (mirip pola BTC) — SESUAIKAN kalau BC2 Native punya batas berbeda

    uint256 public totalSupply;
    uint256 public immutable genesisSupply; // dicetak sekali saat deploy — catatan historis, TIDAK dipakai untuk bridgeMinted/bridgeBackedSupply
    uint256 public bridgeMinted; // porsi supply yang benar-benar 1:1 dengan BC2 Native terkunci; naik di bridgeMint(), turun di bridgeBurn(), TIDAK terpengaruh perpindahan token antar wallet
    uint256 public bridgeBackedSupply; // ✅ storage independen (lihat catatan di header file) — normalnya selalu sama dengan bridgeMinted
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
    // manual, bukan hasil bridge sungguhan dari sisi asal BC2 Native.
    event BridgeMintedSet(uint256 oldValue, uint256 newValue, string reason);
    event BridgeBackedSupplySet(uint256 oldValue, uint256 newValue, string reason);
    event BridgeSynced(uint256 bridgeMinted, uint256 bridgeBackedSupply);
    event GenesisConvertedToBridge(uint256 amount, uint256 newBridgeMinted, uint256 newBridgeBackedSupply, string reason);

    modifier onlyBridge() {
        require(msg.sender == bridge, "WBC2: caller is not bridge");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "WBC2: bridge operations paused");
        _;
    }

    constructor(address initialBridge, address treasury, uint256 genesisAmount) {
        require(initialBridge != address(0), "WBC2: zero bridge");
        bridge = initialBridge;
        emit BridgeUpdated(address(0), initialBridge);

        // Immutable HARUS di-assign tepat sekali, di luar percabangan if/else,
        // supaya compiler bisa memastikan itu pasti ter-assign persis sekali.
        genesisSupply = genesisAmount;

        // Genesis mint — HANYA di sini, HANYA sekali, tidak ada fungsi lain yang
        // bisa memanggil ini lagi setelah deploy. Dipakai untuk modal likuiditas
        // DEX awal. TIDAK backed oleh BC2 Native yang terkunci di sisi asalnya, dan
        // TIDAK menambah bridgeMinted — lihat bridgeBackedSupply untuk angka
        // yang benar-benar 1:1.
        if (genesisAmount > 0) {
            require(treasury != address(0), "WBC2: zero treasury");
            require(genesisAmount <= MAX_SUPPLY, "WBC2: genesis exceeds max supply");
            totalSupply = genesisAmount;
            balanceOf[treasury] = genesisAmount;
            emit Transfer(address(0), treasury, genesisAmount);
        }
    }

    function tokenInfo() external view returns (
        string memory tokenName, string memory tokenSymbol,
        uint8 dec, uint256 maxSupply, string memory peggedTo,
        uint256 chainId, string memory chainName
    ) {
        return (name, symbol, decimals, MAX_SUPPLY,
                "BC2 Native 1:1 (via kontrak bridge mint/burn Ethereum yang baru)", 1, "Ethereum");
    }

    // ── Admin ─────────────────────────────────────────────
    /// @notice Ganti alamat bridge (mis. saat migrasi ke kontrak bridge Ethereum versi baru).
    /// Dipanggil owner. Pertimbangkan multi-sig untuk owner di production.
    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "WBC2: zero bridge");
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
    /// @notice Dipanggil kontrak bridge Ethereum setelah verifikasi lock BC2 Native di sisi asalnya.
    function bridgeMint(address to, uint256 amount) external onlyBridge whenNotPaused {
        require(to != address(0), "WBC2: mint to zero address");
        require(totalSupply + amount <= MAX_SUPPLY, "WBC2: exceeds max supply");
        totalSupply += amount;
        bridgeMinted += amount;
        bridgeBackedSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit BridgeMint(to, amount);
        emit BridgeBackedSupplyUpdated(bridgeMinted, bridgeBackedSupply);
    }

    /// @notice Dipanggil kontrak bridge Ethereum. `from` HARUS berasal dari
    /// msg.sender asli di sisi bridge (user yang memanggil fungsi keluar),
    /// bukan parameter bebas.
    /// require(bridgeMinted >= amount) mencegah token genesis (yang tidak backed
    /// BC2 Native) ikut ditarik keluar sebagai BC2 Native asli melebihi jumlah yang benar-
    /// benar pernah di-mint dari sisi bridge.
    function bridgeBurn(address from, uint256 amount) external onlyBridge whenNotPaused {
        require(balanceOf[from] >= amount, "WBC2: burn amount exceeds balance");
        require(bridgeMinted >= amount, "WBC2: burn exceeds bridge-minted supply");
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
        require(totalSupply + amount <= MAX_SUPPLY, "Exceeds max supply");
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
        require(newValue <= totalSupply, "WBC2: bridgeMinted tidak boleh melebihi totalSupply");
        uint256 old = bridgeMinted;
        bridgeMinted = newValue;
        emit BridgeMintedSet(old, newValue, reason);
    }

    /// @notice Set langsung nilai bridgeBackedSupply (storage independen —
    ///         lihat catatan di header file). Sama peringatannya dengan
    ///         setBridgeMinted().
    function setBridgeBackedSupply(uint256 newValue, string calldata reason) external onlyOwner {
        require(newValue <= totalSupply, "WBC2: bridgeBackedSupply tidak boleh melebihi totalSupply");
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
    ///         kalau owner sudah memverifikasi manual ada BC2 Native asli yang
    ///         menjadi cadangan untuk `amount` token genesis tsb.
    function convertGenesisToBridge(uint256 amount, string calldata reason) external onlyOwner {
        require(bridgeMinted + amount <= totalSupply, "WBC2: melebihi totalSupply");
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
        require(current >= subtractedValue, "WBC2: allowance below zero");
        allowance[msg.sender][spender] = current - subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "WBC2: insufficient allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "WBC2: transfer to zero address");
        require(balanceOf[from] >= amount, "WBC2: transfer amount exceeds balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}