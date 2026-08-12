// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.33;

// ungravel.eth, GroupWalletFactory, GroupWalletMaster, GroupWallet, ProxyWallet, TokenMaster, ProxyToken, PrePaidContract, AuctionMaster, BiddingProxy, intDeedMaster, extDeedMaster, IntDeedProxy, Intentions by pepihasenfuss.eth 2016-2026, Copyright (c) 2026

// GroupWalletMaster is based on MultiSigContracts inspired by Parity MultiSignature contract, consensys and gnosis MultiSig contracts.
//
// GroupWallet, Ungravel, Virtual Enterprises, Cooperation Markets, ChainScript is entirely based on Ethereum Name Service, "ENS", the domain name registry.
// Although, Ungravel extended ENS to 25+ different chains: EVM Names across chains creates an Ungravel Unified Name Space, UUNS.

//   ENS, ENSRegistryWithFallback, PublicResolver, Resolver, FIFS-Registrar, Registrar, AuctionRegistrar, BaseRegistrar, ReverseRegistrar, DefaultReverseResolver, ETHRegistrarController,
//   PriceOracle, SimplePriceOracle, StablePriceOracle, ENSMigrationSubdomainRegistrar, CustomRegistrar, Root, RegistrarMigration are contracts of "ENS", by Nick Johnson and team.
//
//   Copyright (c) 2018, True Names Limited / ENS Labs Limited
//
//   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//   The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// GroupWalletMaster is a multi-sig group wallet used by Ungravel Groups. It handles 15 different voting types that
// are controlled by majority vote of the group members.
// This master contract stores voting proposals/votes in a single slot, aka memory word of only 32 bytes.
// Although this seems to be a bit odd, it saves gas and assets, making Ungravel Voting the most economic group wallet possible.
//
// Group members vote on adding members, removing members from group, or simply spending common assets.
//
// Most important, group member vote on organizing Funding Auctions. The majority may vote for an auction, then,
// group shares are offered for sale and the group benefits. Each group member logs-in and uses her/his/its own Voting Menu.
//
// Group Voting is the center of group activity and the heart of groups. Although voting offers 15 different types of
// proposals to vote for, it is NOT a general purpose multi-sig, such as SAFE by gnosis/consensys. General purpose
// multi-sigs may execute any transaction per majority vote, while Ungravel Voting is tailored to the very needs of 
// Ungravel Groups and limited to 15 pre-configured types of proposals. Handling may be a bit easier, respectively.
// It does NOT require to submit signed transactions, for security reasons and risk reduction.
//
// TLTR:
// Ungravel GroupWalletMaster controls an easy-to-use, low-cost group wallet for group voting across 25+ EVM chains.

abstract contract AbstractEns {                                                                    // ENS Registry grants access to domain names and domain name properties
  event NewOwner(bytes32 indexed node, bytes32 indexed label, address ownerENS);
  event Transfer(bytes32 indexed node, address ownerENS);
  event NewResolver(bytes32 indexed node, address resolver);
  event NewTTL(bytes32 indexed node, uint64 ttl);
  event ApprovalForAll(address indexed ownerENS, address indexed operator, bool approved);

  function setSubnodeRecord(bytes32 nodeENS, bytes32 label, address ownerENS, address resolver, uint64 ttl) external virtual;
  function setOwner(bytes32 nodeENS, address ownerENS) external virtual;
  function owner(bytes32 nodeENS) external view virtual returns (address);
  function recordExists(bytes32 nodeENS) external view virtual returns (bool);
}
abstract contract AbstractGwmBaseRegistrar {                                                       // BaseRegistrar belongs to the ENS - Ethereum Naming Service
  event NameMigrated(uint256 indexed id, address indexed ownerB, uint expires);
  event NameRegistered(uint256 indexed id, address indexed ownerB, uint expires);
  event NameRenewed(uint256 indexed id, uint expires);
  bytes32 public baseNode;                                                                         // The namehash of the TLD this registrar owns (eg, .eth)
}
abstract contract AbstractNameWrap {                                                               // NameWrapper is used by the ENS on Ethereum mainnet or Sepolia, only needed on ENS3 compatible chains
  function setSubnodeRecord(bytes32 parentNode,string memory label,address owner,address resolver,uint64 ttl,uint32 fuses,uint64 expiry) external virtual returns (bytes32 node);
  function setSubnodeOwner(bytes32 node,string calldata label,address newOwner,uint32 fuses,uint64 expiry) external virtual returns (bytes32);
  function ownerOf(uint256 id) external virtual view returns (address);
  function setApprovalForAll(address operator,bool approved) external virtual;
}
abstract contract AbstractEthRegistrarController {                                                 // RegistrarController belongs to ENS, it handles the purchase and rent of domain names, s.a. "my-company.scroll" | "your-company.blast"
  event NameRegistered(string name, bytes32 indexed label, address indexed ownerRC, uint cost, uint expires);
  event NameRenewed(string name, bytes32 indexed label, uint cost, uint expires);
  address public nameWrapper;
  function rentPrice(string memory name, uint duration) view external virtual returns(uint);
  function available(string memory name) external virtual view returns(bool);
  function registerWithConfig(string memory name, address owner, uint duration, bytes32 secret, address resolver, address addr) external virtual payable;
}
abstract contract Resolver {                                                                       // ENS Resolver provides the address and properties of domain names, s.a. "your-company.base"
  mapping (bytes32 => string) public name;
}
abstract contract AbstractReverseRegistrar {                                                       // Reverse Resolver and Reverse Default Resolver give access to the domain name, if only an address is given
  Resolver public defaultResolver;
  function setName(string memory name) external virtual returns (bytes32);
  function node(address addr) external virtual pure returns (bytes32);
}
abstract contract AbstractResolver {                                                               // ENS Resolver provides the address and properties of domain names, s.a. "your-company.base", it resolves domain names to EVM addresses
  event AddrChanged(bytes32 indexed node, address a);
  event AddressChanged(bytes32 indexed node, uint coinType, bytes newAddress);
  event NameChanged(bytes32 indexed node, string name);
  event ABIChanged(bytes32 indexed node, uint256 indexed contentType);
  event PubkeyChanged(bytes32 indexed node, bytes32 x, bytes32 y);
  event TextChanged(bytes32 indexed node, string indexed indexedKey, string key);
  event ContenthashChanged(bytes32 indexed node, bytes hash);
  function setABI(bytes32 nodeC, uint256 contentType, bytes calldata data) external virtual;
  function setAddr(bytes32 nodeD, address r_addr) external virtual;
  function setName(bytes32 nodeF, string calldata _name) external virtual;
  function setText(bytes32 nodeG, string calldata key, string calldata value) external virtual;
  function supportsInterface(bytes4 interfaceId) external virtual view returns (bool);
  function addr(bytes32 node) external virtual view returns (address);
}
abstract contract AbstractGroupWalletFactory {                                                     // Group Wallet Factory, GWF, main Ungravel entry point coordinating Ungravel Groups and all activities, deploying ProxyGroupWallet, GWP, and ProxyToken, aka TokenProxy
  AbstractResolver                public  resolverContract;
  AbstractEthRegistrarController  public  controllerContract;
  AbstractGwmBaseRegistrar        public  base;
  AbstractEns                     public  ens;
  AbstractReverseRegistrar        public  reverseContract;
  AbstractNameWrap                public  ensNameWrapper;
  AbsMultiFour                    public  multifourContract;                                       // Ungravel MultiCall4 contract, provides chain names and tld
  function getProxyToken(bytes32 _domainHash) external view virtual returns (address p);
  function reserve_replicate(bytes32 _domainHash,bytes32 _commitment) external virtual payable;
  function replicate_group_l9Y(bytes32[] calldata _m, bytes calldata data32, bytes32[] calldata _mem) external virtual payable;
  function upgradeGWF(bytes32 _dHash, address _GWF) external virtual payable;
  function tld() public view virtual returns (string memory);
  function receivePayment() external virtual payable returns(bool);
  function getOwner(bytes32 _domainHash) external virtual view returns (address);
  function _register(bytes32 _dHash,uint256 _rent,string memory _name,uint256 _dur,bytes32 _secret) external virtual payable;
}
abstract contract AbstractTokenProxy {                                                             // TokenProxy gives access to the Group Shares contract, aka TokenProxy contract, that comes with each group, a proxy contract that belongs to TokenMaster
  function balanceOf(address tokenOwner) external virtual view returns (uint thebalance);
  function drainShares(bytes32 dHash, address from, address toReceiver) external virtual;
  function drainLegacyShares(bytes32 dHash, address from, address toReceiver) external virtual;
  function approve_v2d(address spender, uint tokens) external virtual;
  function tokenAllow(address tokenOwner,address spender) external virtual view returns (uint256 tokens);
  function transfer_G8l(address toReceiver, uint amount) external virtual;
  function sell_LA2(uint256 amount) external virtual;
  function buy_uae() payable external virtual;
  function upgradeTokenMaster(bytes32 dHash, address master) external payable virtual;
  function upgradeGWM(bytes32 dHash, address master) external payable virtual;
  function substring(bytes memory self, uint offset, uint len) public pure virtual returns(bytes memory);
}
abstract contract AbsEthRegV3 {                                                                    // ETHRegistrar is only needed with isENSV3() on ENS - chains, such as Ethereum mainnet or Sepolia, integrating with the original ENS installation 
  address public nameWrapper;
  function rentPrice(string memory name, uint duration) view external virtual returns(uint,uint);
}
abstract contract AbstractGroupWalletProxy {                                                       // Abstract and access to GWP, Group Wallet Proxy contract, the Voting and Multi-Sig-contract of each group, a proxy, belonging to the GroupWallet Master
  function submitFirstTransaction_gm(uint firstTRecord, uint256 dhash) external virtual payable;
  function submitLegacyTransaction(uint tNb,uint tRecord) external virtual payable;
  function getMasterCopy() external view virtual returns (address);
}
abstract contract AbstractAuctionRegistrar {                                                       // Auction Registrar is Vickrey Auction, controlled by Ungravel GroupWallets, in order to sell group shares to investors and to tame competition
  function startAuction_ge0(bytes32 _hash, uint revealP) public virtual payable;
}
abstract contract AbsInt {                                                                         // Intentions store and provide information about LOIs. LOIs are also important in order to participate in and to profit from Ungravel Global Token, aka Ungravel Global Shares, in the future.
  function saveLetterOfIntent(address target, uint nbOfShares) public virtual payable;
  function storeInvestment(uint _nbOfShares, address _gwp, uint _pricePaidEth, bytes32 _salt) public virtual payable;
}
abstract contract AbsGlobalT {
  function convertGroupSharesToEther(address _groupTokenContract, uint gShares) public virtual payable;
}
abstract contract AbsGwm {                                                                         // GroupWallet Master is the Master contract of any GroupWalletProxy contract, GWP
  function getIntention() public virtual view returns (AbsInt);
  function proxyToken() public virtual view returns (address);
}
abstract contract AbsReg {                                                                         // Auction Registrar, aka AuctionMaster
  function getGWPfromAuction(bytes32 _hash) public virtual view returns (address);
}
abstract contract AbsExtDeed {                                                                     // external Deeds are BidBuckets proxy contracts, with a extDeedMaster as a Master
  address public  owner;
  AbsReg  public  registrar;
  bytes32 public  lhash;
}
abstract contract MulToken {                                                                       // TokenProxy
  function balanceOf(address tokenOwner) external view virtual returns (uint thebalance);
  function name() external view virtual returns (string memory);
  function symbol() external view virtual returns (string memory);
  function owner() external view virtual returns (address);
  function decimals() external view virtual returns (uint8);
  function transfer(address toReceiver, uint amount) external virtual;
  function withdraw(uint256 amount) external virtual;
}
interface IMulGWP {                                                                                // Abstract and access to GWP, Group Wallet Proxy contract, the Voting and Multi-Sig-contract of each group, a proxy, belonging to the GroupWallet Master
  function getIsOwner(address _owner)      external view returns (bool);
  function getOwners()                     external view returns (address[] memory);
  function getTransactionsCount()          external view returns (uint);
  function getTransactionRecord(uint _tNb) external view returns (uint256);
  function getGWF()                        external view returns (address);
  function getAllTransactions()            external view returns (uint256[] memory transArr);
  function getMasterCopy()                                                    external view returns (address);
  function nameAuctionBidBucketLabel(bytes32 labelhash, address deedContract) external;
}
abstract contract AbsMultiFour {                                                                   // Multicall4 controls safe batching of transactions and UUNS utilities for safety and authentication
  event Deployment(address owner, address theContract);
  event DeploymentMulticall4(address theContract, bytes32 dhash);
  event Deposit(address from, uint256 value);
  function tld() public virtual view returns (string memory);
  function chainName() public virtual view returns (string memory);
  function __isGwpFromSender(address _sender) public virtual view returns (bool);
  function __isNameSpace(bytes32 _dHash) public virtual view returns (bool);
  function __isGwpOrMember(address _sender) public virtual view returns (bool);
}

// GroupWalletMaster is a group multi-sig wallet used by Ungravel Groups. It handles 15 different voting types that
// are controlled by majority vote of group members.
// This master contract stores voting proposals/votes in a single slot, aka memory word of 32 bytes.
// Although this seems to be a bit odd, it saves gas and assets, making Ungravel Voting the most economic group wallet possible.
// Group members vote on adding members, removing members from group, or simply spending common assets.
// Most important, group member vote on organizing Funding Auctions. The majority may vote for an auction, then,
// group shares are offered for sale and the group benefits. Each group member can log-in and uses her/his/its Voting Menu.
// Group Voting is the center of group activity and the heart of groups. Although voting offers 15 different types of
// proposals to vote for, it is NOT a general purpose multi-sig, such as SAFE by gnosis/consensys. General purpose
// multi-sigs may execute any transaction per majority vote, while Ungravel Voting is tailored to the very needs of 
// Ungravel Groups and limited to 15 pre-configured types of proposals. Handling may be a bit easier as well.

contract GroupWalletMaster {                                                    // GroupWalletMaster, GWM, is the Master of all GWP,  GroupWalletProxy contracts, mainly for voting and multi-sig functionality
    address private masterCopy;                                                 // ProxyGroupWallet needs this ******* DO NOT CHANGE ORDER ******

    mapping(uint256 transId => uint256 transRecord) private tArr;               // transaction records, 32 bytes to store any transaction (saves transaction fees, uses only 1 word)
    address[]                   private  owners;                                // contract owners = members of the group (2-31)

    address private GWF;                                                        // GWF - GroupWalletFactory contract, main entry point for Ungravel
    mapping(uint256 hash => bytes storageBytes) private  structures;            // saving encoded group structure for addUser() or submitted proposals, temporarily used during multi-part decisions
    
    address private intent;                                                     // Intention Contract collects and stores relevant investment activities, such as Funding Auctions and Letters of Intent, LOI
                                                                                // ******* DO NOT CHANGE ORDER ******

    // Master contract for group wallets, a low-cost x-chain group wallet with multi-sig voting, ENS member domain names, group shares and Funding Auction support.

    event GroupWalletDeployed(address sender, uint256 members, uint256 timeStamp);
    event Deposit(address from, uint256 value);
    event ColorTableSaved(bytes32 domainHash);
    event EtherScriptSaved(bytes32 domainHash,string key);

    uint256 private _guardCounter = 1;                                          // used for reentrancy checks

    uint constant     private MAX_OWNER_COUNT = 31;                             // group may have 2 ot up to 31 members
    uint constant     private WELCOMEBUDGET   = 0.0025 ether;                   // new member gets welcome ether

    uint256 constant K_ASSET          =  1;                                     // cmd type of the send asset       transaction type
    uint256 constant K_ADDOWNER       =  2;                                     // cmd type of the addOwner         transaction type
    uint256 constant K_RMVOWNER       =  3;                                     // cmd type of the removeOwner      transaction type
    uint256 constant K_MAJORITY       =  5;                                     // cmd type of the majority         transaction type
    uint256 constant K_GWASSET        =  6;                                     // cmd type of the send GW asset    transaction type
    uint256 constant K_SPLITGROUP     =  7;                                     // cmd type of the splitGroup       transaction type
    uint256 constant K_SPINOFFGROUP   =  8;                                     // cmd type of the spinoffGroup     transaction type
    uint256 constant K_MIGRATE        =  9;                                     // cmd type of the migrateGroup     transaction type
    uint256 constant K_DEPOSIT        = 10;                                     // cmd type of the deposit          transaction type
    uint256 constant K_LEGACYTOKEN    = 11;                                     // cmd type of the legacyToken      transaction type
    uint256 constant K_LETTEROFINTENT = 12;                                     // cmd type of the legacyToken      transaction type
    uint256 constant K_PROPOSAL       = 13;                                     // cmd type of the proposal         transaction type
    uint256 constant K_UPGRADECTR     = 14;                                     // cmd type of the upgrade contract transaction type
    uint256 constant K_AUCTION        = 15;                                     // cmd type of the auction          transaction type

    uint64  constant K_TIMEMASK     = 0xffffffffffff0000;
    uint256 constant k_ADDRESSMASK  = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff; // 160 bits address mask
    uint256 constant K_ADDRESS2MASK = 0xffffffffffffffffffffffff0000000000000000000000000000000000000000; // mask out 160 bits address
        
    uint256 constant K_VALUEMASK    = 0x000000000000ffffffffffff0000000000000000000000000000000000000000; // mask value, 48 bits, 6 bytes
    uint256 constant K_VALUE3MASK   = 0xffffffffffff000000000000ffffffffffffffffffffffffffffffffffffffff; // mask out value 48 bits
    uint256 constant K_VALUE2MASK   = 0x0000000000000000000000000000000000000000000000000000ffffffffffff; // value mask

    uint256 constant K_FLAGSMASK    = 0x0fffffffff000000000000000000000000000000000000000000000000000000; // mask flags only, 36 bits
    uint256 constant K_FLAGS2MASK   = 0x0000000000000000000000000000000000000000000000000000000fffffffff; // flags mask 36 bits
    uint256 constant K_FLAGS3MASK   = 0xf000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff; // mask out 36 bits flags
    uint256 constant K_FLAGS4MASK   = 0xffffffffe0ffffffffffffffffffffffffffffffffffffffffffffffffffffff; // mask 5 bits, used for legacy token
    
    uint256 constant K_ASSETMASK    = 0x0000000000ff0000000000000000000000000000000000000000000000000000; // only 8 bits
    uint256 constant K_ASSET2MASK   = 0x00000000000000000000000000000000000000000000000000000000000000ff; // only 8 bits
    uint256 constant K_ASSET3MASK   = 0xffffffffff00ffffffffffffffffffffffffffffffffffffffffffffffffffff; // only 8 bits asset mask
    uint256 constant K_EXECUTEFLAG  = 0x0000000000800000000000000000000000000000000000000000000000000000; // 1 bit
    
    uint256 constant K_TYPEMASK     = 0xf000000000000000000000000000000000000000000000000000000000000000; // command type = 4 bits
    uint256 constant K_TYPE2MASK    = 0x000000000000000000000000000000000000000000000000000000000000000f; // mask 4 bits command type

    uint256 constant K_TYPELEGACYMSK= 0xb000000000000000000000000000000000000000000000000000000000000000; // legacy token contract

    modifier nonReentrant() {
      _guardCounter += 1;
      uint256 localCounter = _guardCounter;
      _;
      require(localCounter == _guardCounter,"r");
    }
    modifier onlyByTokenProxy() {
      my_require(address(getPtoken(getHash()))==msg.sender,"P"); 
      _;
    }
    modifier onlyWhileDeploying() {
      my_require(owners.length==0,"d");
      _;
    }
    modifier onlyOwners() {
      my_require(isAddressOwner(msg.sender),"n");
      _;
    }
    modifier onlyOwnersOrGWP() {
      my_require(isAddressOwner(msg.sender) || __multi4().__isGwpFromSender(msg.sender),"t"); // group member or other GWP
      _;
    }
    modifier onlyNewOwners(address _t) {
      my_require(isAddressOwner(msg.sender)||isAddressOwner(_t),"J"); // only group owner
      _;
    }
    modifier onlyOwnersAndValue() {
      // value in wei identifies transaction id, it must be > 0
      // sending address / sender must be a valid and active member of this group,
      // transaction record of the given id must be empty.
      // Only one transaction / proposal record per slot.

      my_require(msg.value!=0 && tArr[msg.value]==0 && isAddressOwner(msg.sender),"w");
      _;
    }
    modifier ungravelNameSpaceOwners(bytes32 _dhash) {
      my_require(isAddressOwner(msg.sender) && __isNameSpace(_dhash),"n");
      _;
    }
    modifier onlyOtherGWP() {
      my_require(__multi4().__isGwpFromSender(msg.sender),"K");
      _;
    }
    modifier onlyDeployer() {
      my_require(masterCopy==address(msg.sender),"k");
      _;
    }

    function __multi4() private view returns (AbsMultiFour) {
      return AbstractGroupWalletFactory(GWF).multifourContract();
    }
    function __isNameSpace(bytes32 _dhash) private view returns (bool) {
      return ( getENS().recordExists(_dhash) && getENSOwnerExpected(_dhash)==address(this) );
    }
    function __gasPrice() private view returns (uint256 gasPrice) {
      assembly { gasPrice := gasprice() }                                       // compute cost of PrePaidContract deployment
      return gasPrice;
    }
    function __timeStamp() private view returns (uint64) {
      return uint64(block.timestamp);
    }
    function __selfbalance() private view returns (uint self) {
        assembly {
          self :=selfbalance()
        }
        return self;
    }

    // ----------------------  GWM ---------------------------------------------

    function getMasterCopy() public view returns (address) {
      return masterCopy;
    }

    function getGWF() external view returns (address) {
      return GWF;
    }
    
    function getENS() private view returns (AbstractEns) {
      return AbstractEns( AbstractGroupWalletFactory(GWF).ens() );
    }

    function getRsv() private view returns (AbstractResolver) {
      return AbstractGroupWalletFactory(GWF).resolverContract();
    }

    function getCtrl() private view returns (AbstractEthRegistrarController) {
      return AbstractGroupWalletFactory(GWF).controllerContract();
    }
    
    function getRevs() private view returns (AbstractReverseRegistrar) {
      return AbstractGroupWalletFactory(GWF).reverseContract();
    }

    function getNWrap() private view returns (AbstractNameWrap) {
      return AbstractNameWrap(getCtrl().nameWrapper());
    }

    function getIntention() public view returns (AbsInt) {
      if (intent!=address(0)) return AbsInt( intent );
      return AbsInt(AbsGwm(getMasterCopy()).getIntention());
    }

    function getTarget(uint tNb) private view returns (address) { // target address
      return address( uint160( uint256( uint256( tArr[tNb] ) & k_ADDRESSMASK ) ) );
    }

    function getTValue(uint tNb) private view returns (uint64) { // target value
      return uint64( uint256( (uint256( uint256( tArr[tNb] ) & K_VALUEMASK )>>160) & K_VALUE2MASK ) );
    }

    function getAsset(uint tNb) private view returns (uint8) { // asset number, used in various contexts
      return uint8( uint256( uint256(uint256( uint256( tArr[tNb] ) & K_ASSETMASK )>>208) & K_ASSET2MASK ) );
    }
    
    function getAssetT(uint256 t) private pure returns (uint8) { // asset type, used in various contexts
      return uint8 (uint256( (uint256( uint256( t ) & K_ASSETMASK )>>208) & K_ASSET2MASK ));
    }
    
    function getFlags(uint tNb) private view returns (uint64) { // transaction flags indicate member votes and state
      return uint64( uint256( uint256(uint256( uint256( tArr[tNb] ) & K_FLAGSMASK )>>216) & K_FLAGS2MASK ) );
    }
    
    function getFlagsT(uint256 t) private pure returns (uint64) { // transaction flags indicate member vote / state
      return uint64( (uint256( uint256( t ) & K_FLAGSMASK )>>216) & K_FLAGS2MASK );
    }

    function getType(uint tNb) private view returns (uint8) { // transaction type 0..15, id of trans type
      return uint8( uint256( uint256(uint256( uint256( tArr[tNb] ) & K_TYPEMASK )>>252) & K_TYPE2MASK ) );
    }

    function getStructure(uint256 target) external view returns (bytes memory) { // access to temp storage
      return structures[target];
    }

    function saveFlags(uint _tId, uint64 flags) private { // save user flags and member votes
      tArr[_tId] = uint256( uint256(uint256( flags )<<216) & K_FLAGSMASK ) + uint256( tArr[_tId] & K_FLAGS3MASK );
    }
    
    function saveAsset(uint _tId, uint8 asset) private { // save 8bits of asset type - used for different purposes
      tArr[_tId] = uint256( uint256(uint256( asset )<<208) & K_ASSETMASK ) + uint256( tArr[_tId] & K_ASSET3MASK );
    }
    
    function saveExecuted(uint _tId, uint64 f, uint t) private { // store transaction as "executed"
      tArr[_tId] = uint256( uint256( uint256((uint256(f)<<216) & K_FLAGSMASK) + uint256( t & K_FLAGS3MASK ) ) | K_EXECUTEFLAG );
    }
    
    function saveNotExecuted(uint _tId, uint64 f, uint t) private { // store/save current transaction, NOT yet executed
      tArr[_tId] = uint256( ((uint256(f)<<216) & K_FLAGSMASK) + uint256( t & K_FLAGS3MASK ) );
    }
    
    function getBase() private view returns (bytes32) { // baseNode(), such as hash(".eth") or hash(".stable")
      return AbstractGroupWalletFactory(GWF).base().baseNode();
    }
    
    function getPtoken(bytes32 _hash) private view returns (AbstractTokenProxy) { // retrieve tokenProxy contract address from group name hash
      return AbstractTokenProxy( AbstractGroupWalletFactory(GWF).getProxyToken( _hash ) );
    }

    function proxyToken() public view returns (address) { // get proxy token contract belonging to this group wallet proxy contract
      return address(getPtoken(getHash()));
    }
    
    function getHash() private view returns (bytes32) { // provides group domain name hash of current group
      // *** ATTENTION: This requires at least one GWP transaction, one submitted proposal to vote for ***

      return bytes32( tArr[uint256(uint160(GWF))] );

      // Hint: GWF set in newProxyGroupWallet_j5O with init of GWP and construction of member records.
      // tArr[uint256(uint160(GWF))] stores the domain name hash of the GWP, s.a. hash("group-rebels.eth").
      // tArr[uint256(uint160(GWF))] set while submitting first transaction/voting proposal.
    }
    
    function dHashFromLabelBytes32(bytes32 _name) private view returns (bytes32) { // provides domain name hash of group name
      return keccak256(abi.encodePacked( getBase(), keccak256(bytes(bytesToStr(_name, uint(_name)&0xff))) )); // dhash e.g. "group-rebels.eth"
    }
    
    function adjustMajority(uint64 _f) private view returns (uint64) { // changing current majority required for group decisions
      return (uint64(_f|uint64(MAX_OWNER_COUNT)) ^ uint64(MAX_OWNER_COUNT))+(uint64(activeOwners())>>1)+1;
    }

    // ---------------------  string utilities ---------------------------------

    function my_require(bool b, string memory str) private pure {
      require(b,str);
    }
    
    function bytesToStr(bytes32 _b, uint len) private pure returns (string memory) {
      bytes memory bArr = new bytes(len);
      uint256 i;
      
      do
       { 
        bArr[i] = _b[i];
        i++;
      } while(i<len&&i<32);
      
      return string(bArr); 
    }
    
    function bytes32ToStr(bytes32 _b) private pure returns (string memory) {
      bytes memory bArr = new bytes(32);
      uint256 i;
      
      uint off = 0;
      do { 
        if (_b[i] != 0) bArr[i] = _b[i];
        else off = i;
        i++;
      } while(i<32&&off==0);
      
      
      bytes memory rArr = new bytes(off);
      
      i=0;
      do
       { 
        if (bArr[i] != 0) rArr[i] = bArr[i];
        off--;
        i++;
      } while(i<32&&off>0);
      
      return string(rArr); 
    }
    
    function toLowerCaseBytes32(bytes32 _in) private pure returns (bytes32) {
      if ( uint256(uint256(uint256(_in) & K_TYPEMASK) >> 252) <= 5 ) return bytes32(uint256(uint256(_in) | 0x2000000000000000000000000000000000000000000000000000000000000000 ));
      return _in;
    }
    
    function mb32(bytes memory _data) private pure returns(bytes32 a) {
      // solium-disable-next-line security/no-inline-assembly
      assembly {
          a := mload(add(_data, 32))
      }
    }
    
    function labelStrFromBytes32(bytes32 _label) private pure returns (string memory) {
      return bytesToStr(_label,uint(_label)&0xff);
    }
    
    // -------------------  transactions ---------------------------------------
    
    function checkPreconditions(uint tNb, uint tRecord, uint cmd) private view { // security checks, transaction type check
      my_require(tNb>0&&tArr[tNb]==0&&isExpectedCmd(tRecord,cmd),"V"); 
    }

    function isExpectedCmd(uint tRecord,uint cmdType) private pure returns (bool) { // is transaction record holding a legacy group share/token contract ?
      return uint8( uint256( uint256(uint256( uint256( tRecord ) & K_TYPEMASK )>>252) & K_TYPE2MASK ) )==cmdType; // e.g. K_LEGACYTOKEN
    }
    
    function checkSplitPreconditions(uint tNb, uint8 execVal) private view returns (uint) { // check conditions before splitting from group
      my_require(owners.length>3,"G");
      return getOpenSplitTransactionNb(tNb-1,execVal);
    }
    
    function reverseDNameFromAddress(address a) private view returns (string memory) { // provide the domain name, derived from an address
      return getRevs().defaultResolver().name( getRevs().node(a) );                     // e.g. "some-group.stable", using ReverseRegistrar/ENS
    }
    
    // -------------------  multi-Sig wallet -----------------------------------

    function confirmTransaction_Q6d(uint _tId) external onlyOwners payable { // confirm transaction[ _tId ]
      // confirmations are payable, each vote cost a couple of wei. The transaction number/id
      // is the number of wei sent to the voting contract. Anyway, voting is a low-cost transaction.

      if (_tId!=0) my_require(msg.value!=0,"Q");

      uint256 t = tArr[_tId];
      uint64 f  = getFlagsT(t);
      uint64 o  = getOwnerMask(msg.sender);

      my_require(t!=0&&(uint256(t)&K_EXECUTEFLAG)==0&&uint64(f&o)==0&&getAssetT(t)<128,"X");
      
      f = uint64(f|o); // confirm f|o

      uint64 reqVotes = (_tId==0) ? uint64((owners.length>>1) + 1) : getTRequired(_tId); 

      if (reqVotes <= nbOfConfirmations(f)) executeMultiSigCommand(_tId,t,f);
      else saveNotExecuted(_tId, f, t);
    }

    function revokeConfirmation_NlP(uint _tId) external onlyOwners { // revoke the vote of a proposal/vote
      uint256 t = tArr[_tId];
      uint64 f  = getFlagsT(t);
      uint64 o  = getOwnerMask(msg.sender);

      my_require( o>0                            &&
                  uint64(f&o)>0                  &&
                  (uint256(t)&K_EXECUTEFLAG)==0,
             "r");
  
      tArr[_tId] = uint256( (uint256( uint64(f|o) ^ uint64(o) )<<216) & K_FLAGSMASK ) + uint256( t & K_FLAGS3MASK );
    }
  
    function storeLegacyProxyToken(bytes32 spinName,uint64 flags) private returns (address) { // saving group share contract of a split group, aka legacy group shares of the old group
      bytes32 newHash = keccak256( abi.encodePacked( getBase(), keccak256( bytes( bytes32ToStr( toLowerCaseBytes32(spinName) ) ) ) ) );     // dhash e.g. group-rebels.eth
      address gwp     = getENSOwnerExpected( newHash );                                                                                     // GroupWalletProxy contract address of spin-off group
      
      //address legacyToken = proxyToken();                                                                                                 // legacyToken contract of legacy group before spin-off
      uint256 tRecord     = uint256(uint256(uint256(K_LEGACYTOKEN & K_TYPE2MASK)<<252)&K_TYPEMASK) + uint256(uint256(uint256(flags)<<216) & K_FLAGSMASK) + uint256( uint256(uint256( nbOfConfirmations(flags) )<<208) & K_ASSETMASK ) + uint256(uint160(proxyToken())) | K_EXECUTEFLAG; // t type == 0xb, store legacy tokenContract for legacy assets

      AbstractGroupWalletProxy(gwp).submitFirstTransaction_gm{value:0}(tRecord, uint256(newHash));
      return gwp;
    }
    
    function sendSpinoffAssets(uint _tId, uint64 f, bytes32[] calldata _mem, uint totalGas) private returns (bool) { // gets executed during a spin-off of a group, aka a group splits into two
      uint cost = uint256(msg.value);
      uint64 remainingRequired;

      // ------- shares to new addresses, drain legacy shares ------------------

      {
        uint64  o  = 1;                                                         // drainShares to leaving members
        uint64 f_s = 0;
        uint256 t  = 0;
        uint    i  = 0;
        bytes32 hash = getHash();
        do {
          if ((uint64(f>>5)&o)==o) {
            t =  uint256(_mem[7+(f_s*5)]) & k_ADDRESSMASK;                      // receiver
            f_s++;
            
            getPtoken(hash).drainShares(hash,owners[i],address(uint160(t)));
            
            drainLegacySharesGWP(hash,i,address(uint160(t)));
            
            deleteMemberFromStructure(owners[i]);                               // remove spin-off group member
          }
          
          o = o<<1;
          i++;
        } while(i<(owners.length & MAX_OWNER_COUNT));
        
        remainingRequired = uint64((activeOwners()>>1)+1);

        f_s = uint64(uint64(f|uint64(MAX_OWNER_COUNT)) ^ uint64(MAX_OWNER_COUNT))+remainingRequired; // reset majority spinOff CMD
        saveFlags(_tId,f_s);
      }

      // --------------------- compute member share of cost  -------------------
      
      uint nbm  = uint64((_mem.length-5)/5);                                    // nb of members of spinoff group

      {
        cost    += uint(uint256((totalGas-gasleft())-uint(23504*nbm))*__gasPrice());// cost of this spinoff transaction in wei
        cost     = cost/nbm;                                                    // cost per member
      }
      
      
      uint64 ownerId = 0;
    
      // ---------------- store one legacy token contract adddress -------------
      
      address gwp = storeLegacyProxyToken(_mem[3],f);                           // new spin-off group name, spinOff flags

      {                                                                         // pay back deposits to leaving members (ex-members)
        uint flag = uint64(uint64(2**nbm)-1);                                   // 2**nb -1 = all members mask, e.g. 0x7 for 3 members
        uint i    = 0;                                                          // index i                          
        uint64 o;                                                               // owner ID
        uint256 t = 0;                                                          // transaction record
        address depositReceiver;                                                // member of spinOff group that receives its deposit back
        uint    depositValue;
        
        do {                                                                    // iterate transaction records t
          t = tArr[i];
          
          if ((t&K_EXECUTEFLAG==0) && isExpectedCmd(t,K_DEPOSIT)) {             // cmd type = 10 = deposit ether/funds, not yet executed
            o = uint8((uint256( uint256(t)&K_ASSETMASK )>>208) & K_ASSET2MASK); // nb/id of new owner
            
            depositReceiver = address(uint160(uint256(_mem[7+(o*5)]) & k_ADDRESSMASK));
            depositValue    = uint(uint256(t) & k_ADDRESSMASK);
            
            if ( (cost>0) && (depositValue > cost) && (payable(this).balance >= (depositValue-cost)) ) {
              my_transfer(depositReceiver,depositValue-cost,"L");

              emit Deposit(depositReceiver,depositValue-cost);
            
              tArr[i] = uint256(uint256( uint256(uint256( remainingRequired )<<216) & K_FLAGSMASK ) + uint256( t & K_FLAGS3MASK )) | K_EXECUTEFLAG; // mark deposit DONE and paid back
            }
            
            flag = flag ^ uint64(2**uint64(o));                                 // computes new member nb of sender in spinoff group
          }
          
          // ---------------- store older legacy token contracts ---------------
          
          if (isExpectedCmd(t,K_LEGACYTOKEN)) AbstractGroupWalletProxy(gwp).submitLegacyTransaction{value:0}(i+1,t);  // legacy token, legacyTransactionRecords
      
         i++;
        } while(t>0);
        
        ownerId = uint64(ownerIdFromFlag(uint64(flag)));
      }

      // -------------------- compensate msg.sender ----------------------------
      
      {
        uint256 target = uint256(_mem[7+(ownerId*5)]) & k_ADDRESSMASK;          // receiver of new spinoff address, new address of sending member

        if (msg.value<cost || payable(this).balance==0) return true;            // avoid underflow error
        uint payback = uint(msg.value)-cost;                                    // msg.value
        
        if (payable(this).balance < payback) payback = payable(this).balance;
        
        my_transfer(address(uint160(target)),payback,"P");

        emit Deposit(address(uint160(target)),payback);
      }
      
      return true;
    }
    
    function _didVoteForSplitExecuteSpinOff(uint _tId, uint64 _flags) private view returns (bool) {
      uint64 f_s = uint64( (uint256( uint256( tArr[checkSplitPreconditions(_tId,128)] ) & K_FLAGSMASK )>>216) & K_FLAGS2MASK ); // must have voted for split before
      my_require((f_s & getOwnerMask(msg.sender))!=0,"Y");                                                                      // ignore non-eligable votes
      return (uint64(uint64(_flags>>5) & uint64(f_s>>5))==uint64(f_s>>5));                                                      // split flag == spin-off flag ?
    }

    function confirmSpinOffGroup_L51b(bytes32[] calldata _in, bytes calldata data32, bytes32[] calldata _mem, bytes32[] calldata _abi) external nonReentrant onlyOwners payable {
        // Special confirmation command:
        // A group member / the calling member address votes on a spin-off proposal, thus participating in a split group event, leaving the group.
        // A split-group / spin-off event splits the group into 2 seperate groups, organizing common goods the fair way.
        // Splitting of groups is a core feature of Ungravel Groups: It makes it easy to leave a group, yet keeping shares and common assets.
        // Group members joining a split/spin-off group, remain in control on their assets. They take their own Ether to the new group,
        // they still control their individual stake of the remaining group. This feature makes it easy and comfortable to split groups,
        // perhaps, once a group gets too big or one fraction wants to start a new endeavor. 
        // We believe that Ungravel Society grows organically, keeping member assets safe, even if groups split.

        uint totalGas = gasleft();
        uint _tId = uint256(_in[0]);
        uint256 t = tArr[ _tId ];
    
        uint64 f = getFlagsT(t);
        my_require(msg.value!=0&&uint64(f&getOwnerMask(msg.sender))==0 && getAssetT(t)<128 && isExpectedCmd(t,K_SPINOFFGROUP),"D"); // not voted ? not exec ? 
        
        f  = uint64(f|getOwnerMask(msg.sender));                                                         // confirm spin-off transaction

        if (_didVoteForSplitExecuteSpinOff(_tId,f)) {                                                    // executeMultiSigCommand(_tId,t,f) immediately
          getRsv().setABI(getHash(),128,abi.encodePacked(_abi));                                         // update current group - before executing spin-off
          
          AbstractGroupWalletFactory(GWF).replicate_group_l9Y{value: msg.value}(_in,data32,_mem);        // payout/return 100% = msg.value to new spinoff contract
          
          saveExecuted(_tId,f,t);                                                                        // spinoff transaction saved as executed and completed
          
          my_require(sendSpinoffAssets(_tId, f, _mem, totalGas),"U");                                    // pay back deposits, transfer legacy shares and contracts
        }
        else {
          saveNotExecuted(_tId,f,t);
        }
    }
    
    function drainLegacySharesGWP(bytes32 dhash,uint nb,address target) private { // transferring legacy group shares to members of the new group
      uint i=0;
      uint256 tt;      
      do {
        tt = tArr[i];

        if (isExpectedCmd(tt,K_LEGACYTOKEN)) {                                    // cmd type = 11 = legacy token contract
          AbstractTokenProxy( address(uint160(uint(uint256(tt) & k_ADDRESSMASK))) ).drainLegacyShares(dhash,owners[nb],target);
        }

        i++;
       } while(tt>0);
    }

    // Hint: This function gets also called from other GWP, other groups.
    function submitFirstTransaction_gm(uint firstTRecord, uint256 dhash) external onlyOwnersOrGWP payable { // the very first transaction/proposal gets treated differently:
      // Storing a 32-bytes transaction record containing type, flags, majority, asset, target and value.
      // 
      // Hint:
      // It also stores the group domain hash - linking this Group Voting contract to a group name, e.g. "ethereum-bidders.eth", using a 32-bytes hash.
      //
      // The hash of the group domain name is a unique identifier to interact with group assets across all Ungravel contracts and across the
      // Ungravel Unified Name Space, UUNS, which spans 22+ chains, today. This creates a huge, unified transaction space, spanning many chains:
      // e.g. transfer assets from "famous-group.base" to "some-other-group.stable", perhaps Ether or USDC, of course across chains. (x-chain)

      my_require((isAddressOwner(msg.sender) || isExpectedCmd(firstTRecord,K_LEGACYTOKEN)),"E"); // only first transaction, member transaction or legacyProxy contract
      
      uint mask = (isExpectedCmd(firstTRecord,K_LEGACYTOKEN)) ? K_FLAGS4MASK : K_FLAGS3MASK;
      initGWF_firstRecord(firstTRecord,dhash,mask);                                   // GWP stores project domain hash
      emit GroupWalletDeployed(msg.sender,owners.length,uint256(__timeStamp()));
    }
    
    function submitLegacyTransaction(uint tNb,uint tRecord) external onlyOtherGWP payable { // saving the legacy group share / token contract of the given transaction Id
      my_require(tNb>0 && tArr[tNb]==0 && isExpectedCmd(tRecord,K_LEGACYTOKEN),"H");
      tArr[tNb] = uint256(uint256( uint256(uint256( requiredDefault() )<<216) & K_FLAGSMASK ) + uint256( uint256(tRecord) & K_FLAGS4MASK )) | K_EXECUTEFLAG;
    }

    function _submitTrans(uint _tRecord) private onlyOwners { // saving transaction record, adding a new proposal/transaction to the log
      // Hint: While submitting a new proposal/transaction, the number of wei sent to the contract identifies the new transaction number.
      // Submitting a proposal costs a few wei. Storing flags and indicating member id has voted for this proposal.
      // Assures that the proposal is NOT YET executed, it gets only 1 vote while submitted by a member.

      tArr[msg.value] = uint256( uint256( uint256( uint64( getTRequired(msg.value-1) ) | getOwnerMask(msg.sender) )<<216) & K_FLAGSMASK ) + uint256( _tRecord & K_FLAGS3MASK );
    }

    function submitTransaction_m79(uint aTRecord) public onlyOwnersAndValue payable {         // 0x0000ad72 group member submits a new proposal / transaction record, 
      // the number of wei sent identifies the transaction id to store any proposal.
      _submitTrans(aTRecord);
    }
    function submitInvestTransaction_b3j(uint aTRecord) external onlyOwnersAndValue payable { // 0x0000c7c1 Submitting a special transaction / proposal:
      // Group member / calling group member address proposes to invest into a other Ungravel Group,
      // perhaps to participate in a Funding Auction of the remote group. Reveal proposal and Cancel proposals are executed immediately.
      // Wei amount identifies the target transaction id, storing the new proposal.

      uint8 asset = getAssetT(aTRecord);
      my_require(((asset==120||asset==118)) && isExpectedCmd(aTRecord,K_ASSET) && (uint(uint256(aTRecord & K_VALUEMASK)>>160) & K_VALUE2MASK)==0,"M");
      _submitTrans(aTRecord);
      executeMultiSigCommand(msg.value,tArr[msg.value],getFlags(msg.value));
    }

    function submitSplitTransaction(uint aTRecord, bytes32 _commitment, bytes32 _dname) external onlyOwners payable { // split group proposal
      // A Split group proposal may lead to a spin-off event, actually splitting the current group into 2 separate groups.
      //
      // The amount of wei sent with this proposal identifies the new transaction id.
      //
      // Split group votes will not be executed by majority, any group member may join the departing group,
      // as long as at least 2 active members or more remain.
      //
      // Once any of the departing group members proceeds, it submits a spin-off proposal that will perform and execute
      // the actual split of groups. Any members voted for the split may also vote for the second proposal, the spin-off.
      //
      // Once all departing members will have voted for the spin-off, the new group departs and assets get transferred.
      //
      // The remaining group will keep departed group members as inactive members that have left the group.
      // Common group assets are divided by stake and member, splitting groups the fair way.
      // In this sense, split-group and spin-off group are 2 steps required to split one group into two separate groups.
      //
      // This may seem complicated, yet, for departing members it is simple and easy to use. The advantage is that
      // even groups with conflict will survive and both seperate groups will remain active and productive.
      // In this sense, splitting groups helps to grow Ungravel Society over time. It is part of a strategy designed to
      // go viral in the future.
      // In addition: Ungravel group management has mediation built-in. In case of tension among members or conflict, 
      // there are several ways to mediate. First, proposing a split group is a hint to the group that someone is not happy
      // anymore. Yet, after resolving a conflict or a problem, the member may easily revoke the split proposal.
      // Each proposal submitted is a message to the entire group.
      // If someone proposes to expell another member, it is a clear signal of serious conflict or misbehaviour.
      // Again, after resolving potential problems, it is easy to revoke the proposal.
      // The bigger groups become, the more likely members may get into conflict often.

      checkPreconditions(msg.value,aTRecord,K_SPLITGROUP);
      my_require(checkSplitPreconditions(msg.value,0)==0&&tArr[uint256(_commitment)&k_ADDRESSMASK]==0&&tArr[(uint256(_commitment)&k_ADDRESSMASK)+1]==0,"l");

      _submitTrans(aTRecord);                                                                        // transaction type 7 will NOT be executed by majority vote
      
      tArr[uint256(_commitment)&k_ADDRESSMASK]     = uint256(_commitment);                           // save 32-byte commitment
      tArr[(uint256(_commitment)&k_ADDRESSMASK)+1] = uint256(_dname);                                // save spinOff / split project domain name
      
      AbstractGroupWalletFactory(GWF).reserve_replicate(dHashFromLabelBytes32(_dname), _commitment); // commitment = reserve new spinOff domain
    }
    
    // ENS V3 2023 requirements

    function isENSV3() private view returns (bool) { // on Ethereum mainnet, e.g., domain names get wrapped into NFTs
      // We call this ENSV3, although this is not an official name. Generally, Ungravel uses EVM Names across all chains.
      // On Ethereum, this is the ENS. On all other target chains, this is the Ungravel EVM Name stack, installed on all
      // target chains. EVM Names are ENS domain names, ported to different chains and adapted to different name spaces:
      // "some-group.base" is a group on BASE, while "anygroup.stable" might be a group on LISK mainnet.

      return (address(AbstractGroupWalletFactory(GWF).ensNameWrapper()) != address(0));
    }

    function onERC1155Received(address,address,uint256,uint256,bytes calldata) public pure returns (bytes4) { // 0xf23a6e61
      return this.onERC1155Received.selector;
    }

    function setENSSubnode(bytes32 _label) private { // add subdomain name to the group domain name
      getENS().setSubnodeRecord(getHash(),_label,address(this),address(getRsv()),uint64(__timeStamp()*1000) & K_TIMEMASK); // e.g joe.ethereum.eth
    }

    function setENSV3Subnode(string memory _label) private { // add subdomain name to the group domain name on an ENSV3 chain
      getNWrap().setSubnodeRecord(getHash(),_label,address(this),address(getRsv()),uint64(__timeStamp()*1000) & K_TIMEMASK,0,0);
    }

    function getENSOwnerExpected(bytes32 _hash) private view returns (address) { // provide owner of group domain hash
      if (isENSV3()) return AbstractGroupWalletFactory(GWF).getOwner(_hash);
      return getENS().owner(_hash);
    }

    function submitExecuteSplitTransaction(uint aTRecord, uint256 _secret) external nonReentrant onlyOwners payable { // special transaction type 0xd8197658 submitExecuteSplitTransaction(uint256,uint256)
      // Submitting a spin-off proposal / transaction record.

      uint tNb = msg.value & 0x000000000000000000000000000000000000000000000000000000ffffffffff;
      checkPreconditions(tNb,aTRecord,K_SPINOFFGROUP);

      uint splitTNb = checkSplitPreconditions(tNb,0);
      my_require( uint256(tArr[uint160(aTRecord)&k_ADDRESSMASK]&k_ADDRESSMASK) == (uint256(aTRecord)&k_ADDRESSMASK) &&  // check commitment lower 160 bits
                  splitTNb>0,
             "Z"); 
      
      tArr[splitTNb] = uint256( uint256(tArr[splitTNb]) | K_EXECUTEFLAG);                  // mark: split transaction type 7 = executed
      
      // -------------- register new domain ------------------------------------
      
      bytes32 splitName    = bytes32(tArr[ uint256(uint160( uint256( aTRecord ) & k_ADDRESSMASK ) + 1) ]);
      bytes32 dHash        = dHashFromLabelBytes32(splitName);
      string memory _dname = labelStrFromBytes32(splitName);                               // domainName
      
      // Unfortunately, some code deals with chains that support ENSV3 and the other one is ENSV2.
      // We differentiate with the isENSV3() function. ENS on mainnet supports the NameWrapper, wrapping all domain names into NFTs.
      // On all other chains, Ungravel supports what we coined ENSV2, ENS - compatible to ENS on mainnet, except NameWrapper() support.
      // Hint: NameWrapper() makes things really complicate and we do not need more NFTs.
      // Without NameWrapper(), you have ERC721 token as well, we do not support or need tradable, wrapped NFTs, sorry.

      if (!isENSV3()) {                                                                          // ENSV2 without wrapped domain names
        getCtrl().registerWithConfig{value: getCtrl().rentPrice(_dname,31536000)}(_dname,address(this),31536000,bytes32(_secret),address(getRsv()),GWF); // one year
        getRsv().setName(dHash,string(abi.encodePacked(_dname,AbstractGroupWalletFactory(GWF).tld())));
        getENS().setOwner(dHash,GWF);
      }
      else                                                                                       // ENS V3 with NameWrapper() support on mainnet
      {
        (uint _rent,uint _dd) = AbsEthRegV3(address(getCtrl())).rentPrice(_dname,31536000);      // rent ENS V3 rentPrice 0x83e7f6ff // one year
        _dd = 0;                                                                                 // silence compiler warning
        AbstractGroupWalletFactory(GWF)._register(dHash,_rent,_dname,31536000,bytes32(_secret)); // one year
      }
      
      tArr[tNb] = uint256( (uint256( uint64( getTRequired(tNb-1) ) | getOwnerMask(msg.sender) )<<216) & K_FLAGSMASK ) + uint256( uint256(aTRecord) & K_FLAGS3MASK );
    }

    function initGWF_firstRecord(uint256 _aTRecord, uint256 _dhash, uint _mask) private {
      my_require(tArr[0]==0&&tArr[uint256(uint160(GWF))]==0,"b"); 
      tArr[0] = uint256( (uint256( requiredDefault() | getOwnerMask(msg.sender) )<<216) & K_FLAGSMASK ) + uint256( uint256(_aTRecord) & _mask );
      tArr[uint256(uint160(GWF))] = _dhash; // store project domain hash
    }

    function submitTransaction_addUser_kCY(uint256 aTRecord, uint256 dhash, uint256 label, uint256 len, uint256 bytesLen, bytes calldata data) external nonReentrant onlyOwners payable {
      // Proposal to add a new member to the group.
      // Amount of wei sent to group voting contract identifies the new transaction id to save this proposal.
      // Adding a new member to the group requires group majority to gets executed.
      uint256 targetId     = uint256(aTRecord&k_ADDRESSMASK);

      my_require( isExpectedCmd(aTRecord,K_ADDOWNER) && (msg.value!=0 || (msg.value==0 && dhash!=0x0)) && targetId!=0 && (tArr[targetId+1]==0x0),"B" ); 
  
      tArr[targetId+1]     = label;                                                // ENS2 = labelHash || ENS3 = label string with length byte
      tArr[targetId+2]     = len;                                                  // nb of bytes
      tArr[targetId+3]     = bytesLen;                                             // nb padding bytes
      structures[targetId] = data;                                                 // save new structure with added member
      
      if (dhash==0x0) _submitTrans(aTRecord);
      else                                                                         // is first transaction nb = 0, init and store domain hash
      {                           
        initGWF_firstRecord(aTRecord,dhash,K_FLAGS3MASK);                          // store project domain hash
        emit GroupWalletDeployed(msg.sender,owners.length,uint256(__timeStamp())); // GroupWallet deployed === GroupWalletProxy GWP deployed
      }
    }
    
    function submitTransaction_proposal(uint256 aTRecord, bytes calldata data) external nonReentrant onlyOwners payable { // submit a proposal to change
      // text, such as #claim, #unique, #benefit, #skill: These tags identify text blocks describing the current group.
      // They belong to the PITCH chart, where any group may present its core values and mission.
      // Since the PITCH chart may become publicly visible, groups change entries per majority vote.
      // The PITCH may become a groups' public business card, a very short group or company description.

      my_require(isExpectedCmd(aTRecord,K_PROPOSAL),"N");         // only proposals, such as #claim, #skillset etc.
      structures[ uint256(aTRecord&k_ADDRESSMASK) ] = data;       // save updated structure including claim,unique,skill,benefit strings
      submitTransaction_m79(aTRecord);
    }
  
    function executeTransaction_G1A(uint _tId) external onlyOwners payable { // group members vote on proposals.
      // Once a vote is decisive, actually reaching majority, the transaction/proposal to vote for 
      // will be executed immediately.
      // Again, the amount of wei identifies the transaction / proposal id.

      if (msg.value==0) return;

      uint256 t = tArr[_tId];
      uint64 f  = getFlagsT(t);

      my_require(uint64(f&getOwnerMask(msg.sender))>0&&(uint256(t)&K_EXECUTEFLAG)==0&&getAssetT(t)<128,"I");
      
      if (getTRequired(_tId)<=nbOfConfirmations(f)) executeMultiSigCommand(_tId,t,f);
    }
    
    function getMemberWelcome(address target) external view onlyNewOwners(target) returns (bytes memory) { // called by new group members to get attached to the group
      return abi.encode( tArr[uint256(uint160(target)+2)], tArr[uint256(uint160(target)+3)] );
    }
    
    function welcomeOneNewOwner(address target) private { // gets called, once group voting reached required majority, 
      // to acutally add a new member to group, perhaps "Vitalik" or "Linda".
      // This method assigns the new domain name, s.a. "vitalik.groupname.eth" or "linda.groups.stable".
      // Additionally, group structure gets updated to include the new member and its member address.
      // Also, the new name, "vitalik.groupname.eth" or "linda.groups.stable", becomes part of the Ungravel Name space.
      // If the group is liquid, any new member will receive a bit of funding as a welcome gift.
      // This helps to on-board new members quickly, since they are fully functional with only one click.
      // A new member receives 100 group shares from the common group share reserve.
      // This is required to participate in group voting and group decisions and makes the new member part
      // of the group almost instantly.

      bytes32 l_dHash         = getHash();                                      // domainHash
      bytes32 l_label         = bytes32( tArr[uint256(uint160(target)+1)] );    // ens2 labelhash || ens3 labelString with length
      bytes32 l_dlabelHash;
      string memory l_labelStr;

      if (!isENSV3()) {
        l_dlabelHash = keccak256( abi.encodePacked(l_dHash,l_label) );
        setENSSubnode(l_label);                                                 // l_label = labelhash
      }
      else
      {
        l_labelStr   = labelStrFromBytes32(l_label);
        l_dlabelHash = getLabelDHash( keccak256(bytes(l_labelStr)) );
        setENSV3Subnode(l_labelStr);                                            // labelString
      }

      getRsv().setAddr(l_dlabelHash,target);                                    // set resolvedAddress to member addr
      getRsv().setABI (l_dHash,32,abi.encodePacked(structures[uint256(uint160(target))])); // update group structure, include new member
      
      if (!isENSV3()) getENS().setOwner(l_dlabelHash,target);
      else            getNWrap().setSubnodeOwner(l_dHash,l_labelStr,target,0,0);
      
      if (__selfbalance()>=WELCOMEBUDGET) {                                     // gets e.g. 0.0025 ether minimal budget
        my_transfer(address(target),WELCOMEBUDGET,"F");
        emit Deposit(target, WELCOMEBUDGET);          
      }
      
       getPtoken(l_dHash).transfer_G8l(target, 1e4);                            // 100 welcome shares
    }
    
    // main multi-sig command execution, if majority voted
    function executeMultiSigCommand(uint _tId,uint256 t,uint64 f) private nonReentrant { // the core of group voting:
      // This function actually executes tranactions, aka proposals that have reached majority votes.
      // Execution of proposals covers any of the 15 different types of group voting.
      // #1  = sending group assets, e.g. Ether to a target address
      // #2  = adding new member to group
      // #3  = remove group member by majority vote (excluded member will be compensated)
      // #4  = not used
      // #5  = change required majority, i.e. requiring three votes to execute instead of 2
      // #6  = transferring group shares to a target address, e.g. to promote a member with free shares
      // #7  = split group (gets not actually executed, handled at submitExecuteSplitTransaction())
      // #8  = spin-off group: gets not executed here, instead, gets handled at confirmSpinOffGroup_L51b()
      // #9  = migrate group, swapping an entire group from one chain to another (the whole group)
      // #10 = deposit, saving a deposit of personal assets, e.g. 0.75 Ether, before splitting and leaving group
      // #11 = legacyToken, saving the contract group share address of the old group, while departing
      // #12 = letter of intent: A group may "send" a letter-of-intent to another group, to announce investment
      // #13 = propose pitch texts, such as #claim, #skill, #benefit or #unique
      // #14 = upgrade master contracts: GWF, GWM or TM
      // #15 = start a Funding Auction, offering 10.000 group shares, e.g. to internal or external investors

      uint    aValue;
      uint8   cmd    = uint8( (uint256( uint256( t ) & K_TYPEMASK )>>252) & K_TYPE2MASK );             // cmd type 0..15
      address target = address(uint160( uint256( t ) & k_ADDRESSMASK ));

      if (cmd==2) {                                                                                    // K_ADDOWNER addOwner
        my_require(!isAddressOwner(target)&&(owners.length<MAX_OWNER_COUNT)&&uint64(f & uint64(MAX_OWNER_COUNT)) >= 2,"2");
        owners.push(target);
        welcomeOneNewOwner(target);
        return saveExecuted(_tId,adjustMajority(f),t);
      }
      
      if (cmd==3) {                                                                                    // K_RMVOWNER removeOwner OK with ENSV3 
        removeOneOwner(target);
        return saveExecuted(_tId,adjustMajority(f),t);
      }

      uint8 asset = getAssetT(t);                                                                      // input parameter e.g. to change requirement

      if (cmd==5) {                                                                                    // K_MAJORITY changeRequirement
        my_require((asset>=2) && (asset<=MAX_OWNER_COUNT),"5");
        return saveExecuted(_tId,(uint64(f|uint64(MAX_OWNER_COUNT)) ^ uint64(MAX_OWNER_COUNT))+uint64(asset),t);
      }

      if ((cmd==1)||(cmd==6)||(cmd==12)||(cmd==13)||(cmd==15))                                         // K_ASSET,K_GWASSET,K_LETTEROFINTENT,K_PROPOSAL,K_AUCTION
        aValue = uint(uint256(t & K_VALUEMASK)>>160) & K_VALUE2MASK;                                   // nb of token/shares to be transferred, label of proposal


      if (cmd==1) {                                                                                    // K_ASSET send ETH
        if (asset==119) {                                                                              // ***** in case of a finalize auction transaction: target === BidBucket proxy contract
          my_require(tArr[_tId+1]==0,"m");
          address targGW = AbsReg(AbsExtDeed(target).registrar()).getGWPfromAuction( AbsExtDeed(target).lhash());
          getIntention().storeInvestment( AbstractTokenProxy(AbsGwm(targGW).proxyToken()).balanceOf( address(AbsExtDeed(target).registrar()) ), targGW, target.balance, getHash());
          tArr[_tId+1] = K_TYPELEGACYMSK + uint256( uint256( uint256( getTRequired(_tId) | getOwnerMask(msg.sender) )<<216) & K_FLAGSMASK ) + uint256(uint160( AbsGwm(targGW).proxyToken() ) & k_ADDRESSMASK) | K_EXECUTEFLAG; // store proxyToken contract somewhere
        }

        if (asset==117) { 
           AbstractTokenProxy(proxyToken()).buy_uae{ value: aValue<<20 }();                            // calls TokenContract to buy group shares
        }
        else
        {
          (bool succ,bytes memory returnData) = target.call{ value: aValue<<20 }("");                  // mul 1.048.576 = 2**20 This call to the BidBucket, e.g. , runs registrar.finalizeExternalAuction_WmS(lhash);
          my_require(succ,string(abi.encode( returnData )));
        }

        emit Deposit(target, uint256(aValue<<20));
        return saveExecuted(_tId,f,t);
      }
    
      if (cmd==12) {                                                                                   // K_LETTEROFINTENT
        uint l_rent = getCtrl().rentPrice("abcd",31536000);                                            // calculate rent for 4-character name for one year
        my_require(aValue!=0 && __selfbalance()>=l_rent,"j");
        getIntention().saveLetterOfIntent{value:l_rent}(target,uint(aValue));                          // transaction payment required, in order to avoid spam and LoI grabber
      }

      AbstractTokenProxy l_token = AbstractTokenProxy(proxyToken());                                   // project ProxyToken contract

      if (cmd==6) {                                                                                    // K_GWASSET transferShares / transfer GroupWallet Token
        my_require(aValue!=0,"6");
        if (asset==125)                   l_token.sell_LA2(aValue);                                    // 125 = sell groupWallet shares to tokenContract to get liquidity
        if ((asset==126) || (asset==124)) l_token.transfer_G8l(target,aValue);                         // 126 = shares transaction | 124 = claim bonus shares

        if (asset<64) {
          AbstractTokenProxy(getTarget(uint(asset))).transfer_G8l(target,aValue);                      // <64 = transfer/convert investment group shares of other groups to target === Ungravel Global Shares
          AbsGlobalT(target).convertGroupSharesToEther(getTarget(uint(asset)),aValue);                 // call Ungravel Global Shares contract to convert group shares to ETH, apply for conversion and liquidity
        }
        
        return saveExecuted(_tId,f,t);
      }

      bytes32 dHash = getHash();                                                                       // domain hash of this group wallet name, s.a. "my-group.blast"

      if ((cmd==13)&&(aValue!=0x44bb0000000)) {                                                        // K_PROPOSAL proposal to change pitch tags #
        getRsv().setABI( dHash,32,abi.encodePacked(structures[uint256(uint160(target))]) );            // proposal, except polls, update abi32 with group structure and pitch
      }
      
      if (cmd==14) {                                                                                   // K_UPGRADECTR upgrade
        if (asset==127) {
          AbstractGroupWalletFactory(GWF).upgradeGWF(dHash,target);                                    // upgrade GWF contract. calls current GWF, upgradeGWF() calls new GWF
          GWF = target;                                                                                // upgrade GWF to new GWF
          tArr[uint256(uint160(GWF))] = uint256(dHash);                                                // GWP stores project domain hash
        }

        if (asset==123) l_token.upgradeTokenMaster(dHash,target);                                      // upgrade TMC contract
        if (asset==122) l_token.upgradeGWM(dHash,target);                                              // upgrade GWM contract
      }
      
      if (cmd==15) {                                                                                   // K_AUCTION start funding auction
        uint period = (uint(uint64(asset) & 127) >> 2)*60;                                             // auction reveal period in minutes * 60 = seconds
        AbstractAuctionRegistrar(target).startAuction_ge0( keccak256( bytes(bytes32ToStr(bytes32(uint256(aValue)<<208))) ),period); // domain name = tag of auction, s.a. "door"
      
        aValue = uint(uint64(asset) & 3);                                                              // compute nb of batches of shares, each 10,000 shares
        l_token.transfer_G8l(target,uint64( (1+(aValue*aValue))*100*10000 ));                          // auction registrar holds assets = group shares
        
        if (!isENSV3()) setENSSubnode( getLabelHash(t) );                                              // assign ENS name, s.a. "seed.groupwallet.eth" for ENS2
        else          setENSV3Subnode( bytes32ToStr(bytes32(uint256(t&K_VALUEMASK)<<48)) );            // assign ENS name, s.a. "seed.groupwallet.eth" for ENS3/with NameWrapper

        setResolvedAddress(t,address(this));                                                           // this GWP contract address, finished auctions assign winning deed contract
      }
    
      if ((cmd==7)||(cmd==8))  return saveNotExecuted(_tId,f,t);                                       // K_SPLITGROUP split-group | K_SPINOFFGROUP spin-off, DO NOT execute split-group yet
      
      // *** migrate and legacy token transactions handled elsewhere, only for reference ***
      //if (cmd==9)  return saveExecuted(_tId,f,t);                                                    // K_MIGRATE migrate group to another chain, x-chain migration
      //if (cmd==11) return saveExecuted(_tId,f,t);                                                    // K_LEGACYTOKEN legacy token, shares from another group before split-group
      
      return saveExecuted(_tId,f,t);
    }
    

    function removeOneOwner(address target) private {
      uint bal       = __selfbalance();
      uint LOWBUDGET = 0.200 ether; // GWP - GroupWalletProxy contract keeps ether if members depart
      
      if (bal>=LOWBUDGET) {
        uint val = (bal-LOWBUDGET) / activeOwners();
        if ((val!=0) && (val<bal)) {
          my_transfer(target,val,"s");
          emit Deposit(target, val);          
        }
      }
      deleteMemberFromStructure(target);
    }
    
    function activeOwners() private view returns (uint8 count) { // return number of owners that are active
      // (not yet excluded or departed from group)
      count = 0;
      
      uint i=0;
      do {
        if (uint160(owners[i])!=0x0) count++; 
        i++;
      } while(i<(owners.length & MAX_OWNER_COUNT));

      return count;
    }
    
    function getLabelHash(uint256 t) private pure returns (bytes32) { // gets 32-bytes label hash from transaction record
      return keccak256(bytes(bytes32ToStr(bytes32(uint256(t&K_VALUEMASK)<<48)))); // e.g. label hash of "seed" | "gavin"
    }
    
    function getLabelDHash(bytes32 _lhash) private view returns (bytes32) { // gets domain name hash, s.a. hash ("gavin.ether.eth")
      return keccak256(abi.encodePacked(getHash(),_lhash));
    }
    
    function setResolvedAddress(uint256 t, address target) private { // assign target address to a domain name label hash of transaction record
      getRsv().setAddr(getLabelDHash(getLabelHash(t)),target);
    }
    
    // called by tokenProxy contract --> the proxy that handles group shares individually for each group, implementation can be found at the TokenMaster2
    function reserveAuctionENSname(uint _tId, uint _payment, address deedContract) onlyByTokenProxy external {   // Funding Auctions receive a random, unique domain name with a random label
      // such as: "travel.mygroup.stable" | "book.somegroup.eth"
      //
      // This function gets called by the group's token proxy contract, TPC or TP
      // in transferAdjustPrices(). Since "mygroup.stable" is owned by the group,
      // only the group voting contract, GWP, may add a subdomain to the name space.
      // This is a vital part of UUNS Name Space security.

      uint256 t = tArr[_tId];
      setResolvedAddress(t,deedContract); // setAddress of "seed.groupwallet.eth"
      my_require(t!=0&&((t & K_EXECUTEFLAG)!=0)&&(payable(this).balance>(_payment*5)/1000)&&AbstractGroupWalletFactory(GWF).receivePayment{value: ((_payment*5)/1000)}(),"p"); // pay 0.5% ungravel license fee to GWF
    }
    function nameAuctionBidBucketLabel(bytes32 labelhashOrStr, address deedContract) external onlyByTokenProxy { // used by the token proxy contract
      // to assign new domain names to the existing group.
      // Typically, it assigns a domain name for each external Funding Auction, s.a. "green-dog.mygroup.stable"
      // or a Prepaid Account domain name, s.a. "blue-belt.mygroup.base".

      string memory label;
      bytes32 l_dlabelHash;                                                     // labelhashOrStr = hash of label || label string with len
                                                                      
      if (!isENSV3()) {
        setENSSubnode(labelhashOrStr);
        l_dlabelHash = getLabelDHash(labelhashOrStr);
      }
      else
      {
        label = labelStrFromBytes32(labelhashOrStr);
        setENSV3Subnode(label);                                                // assign ENS name, s.a. "bucket1.groupwallet.eth" || "bucket1"
        l_dlabelHash = getLabelDHash( keccak256(bytes(label)) );
      }

      getRsv().setAddr(l_dlabelHash,deedContract);
    }
    

    function getTNumberPublic() public view returns (uint count) { // gets current number of transactions
      count = 0;
      
      if (tArr[0]==0) return count;
      
      uint i = 0;
      do {
        if (tArr[i] > 0) count += 1;
        i++;
      } while(tArr[i] > 0);
    }

    function requiredDefault() private view returns (uint64) {
      return (uint64(owners.length>>1)+1);
    }

    function isConfirmed(uint _tNb) public view returns (bool) {
      uint64 r;
      
      if (_tNb!=0)           r = uint64(getTRequired(_tNb-1));
      if ((_tNb==0)||(r==0)) r = requiredDefault();

      return (r <= nbOfConfirmations(getFlags(_tNb)));
    }

    function getRequiredPublic(uint _tNb) external view returns (uint count) { // gets nb of votes required to execute proposals
      if (_tNb==0) return uint( requiredDefault() );
      else return getTRequired(_tNb-1);
    }
    
    function getIsOwner(address _owner) external view returns (bool) { // is _owner a member of the current group ?
      return isAddressOwner(_owner);
    }
    
    function getTransactionsCount() external view returns (uint) { // gets current number of transactions
      return getTNumberPublic();
    }
    
    function getTransactions(uint _tNb) external view returns (address destination, uint value, uint8 asset, bool executed, uint64 flags, uint8 typ, bool conf) { // provide a single transaction record
      if (getTNumberPublic()!=0)
        return (getTarget(_tNb),getTValue(_tNb),getAsset(_tNb),isTExecuted(_tNb),getFlags(_tNb),getType(_tNb),isConfirmed(_tNb));
    }
    
    function getTransactionRecord(uint _tNb) external view returns (uint256) { // gets a single transaction record as a 32-bytes number (bytes32)
      if (getTNumberPublic()!=0) return tArr[_tNb];
      return 0;
    }
    
    function getAllTransactions() public view returns (uint256[] memory) { // gets an array of all transaction records
      if (tArr[0]==0) return new uint256[](0);
      
      uint count = 0;
      uint     i = 0;
      do {
        if (tArr[i] > 0) count += 1;
        i++;
      } while(tArr[i] > 0);
      
      uint256[] memory resultArr = new uint256[](count);

      i = 0;
      uint256 t;
      address token;
      do {
        t = tArr[i];
        
        if (isExpectedCmd(t,K_LEGACYTOKEN)) {
          token = address(uint160(uint256( t & k_ADDRESSMASK )));
          resultArr[i] = uint256(t & K_VALUE3MASK) + uint256(uint256( uint256(AbstractTokenProxy(token).balanceOf(tx.origin)) << 160 ) & K_VALUEMASK); // legacy token balance of current member
        }
        else
        {
          resultArr[i] = t;                                                     // transaction record
        }
        
        i++;
      } while(i<count);

      return resultArr;
    }

    function getConfirmationCount(uint _tNb) external view returns (uint) { // gets nb of confirmations of a transaction record / proposal
      return uint(nbOfConfirmations(getFlags(_tNb)));
    }
    
    function getTransactionCount(bool pending, bool executed) external view returns (uint count) { // gets transactions: yet pending, yet executed
      uint i = 0;
      uint t = getTNumberPublic();
      
      if (t==0) return 0;
      
      do {
        if (pending && !isTExecuted(i) || executed && isTExecuted(i)) count += 1;
        i++;
      } while(i<t);
    }

    function addressConfirmations(uint _tNb,address _owner) external view returns (bool) { // did owner confirm on proposal ?
      return ownerConfirmed(_tNb,_owner);
    }

    function getOwners() external view returns (address[] memory) { // gets an array of owner addresses of this group
      return owners;
    }

    function getConfirmations(uint _tId) external view returns (address[] memory _confirmations) { // returns an array of member addresses that did confirm transaction
      uint m = (owners.length & MAX_OWNER_COUNT);
      address[] memory confirmationsTemp = new address[](m);
      uint count = 0;
      uint i=0;
      
      do
      {
        if (ownerConfirmed(_tId,owners[i])) confirmationsTemp[count++] = owners[i];
        i++;
      } while (i<m);
      
      _confirmations = new address[](count);
      
      i=0;
      do
      {
        _confirmations[i] = confirmationsTemp[i];
        i++;
      } while (i<count);      
    }
    
    function nbOfConfirmations(uint64 confirmFlags) private view returns (uint64 nb) { // nb of member confirms in the flags
      uint64 m  = 32;
      uint o    = (owners.length & MAX_OWNER_COUNT);
      
      nb = 0;
      
      do
      {
        if ((confirmFlags & m) > 0) nb++;
        m = m<<1;
        o--;
      } while (o>0);
      
      return nb;
    }
    
    function isAddressOwner(address _owner) private view returns (bool) { // checks if a given address is an owner of this group  
      uint m = (owners.length & MAX_OWNER_COUNT);
      if (m==0) return false;
  
      uint i=0;
      do {
        if (owners[i]==_owner) return true;
        i++;
      } while(i<m);

      return false;
    }
    
    function deleteMemberFromStructure(address _member) private { // changing / deleting _member address from group structure
      uint i=0;
      do {
        if ((_member!=address(0))&&(owners[i]==_member)) owners[i] = address(0);
        i++;
      } while(i<(owners.length & MAX_OWNER_COUNT));
    }
    
    function getOwnerMask(address _owner) private view returns (uint64) { // returns a bit mask of _owner
      uint64 mask = 32;
      uint i=0;
      uint len = (owners.length & MAX_OWNER_COUNT);
      do {
        if (owners[i]==_owner) return mask;
        mask = mask<<1;
        i++;
      } while(i<len);

      return 0;
    }
    
    function ownerIdFromFlag(uint64 _ownerFlag) private pure returns (uint64) { // provides owner id from a given bit mask
      uint64 id = 1;
      uint64 i=0;
      do {
        if (_ownerFlag==id) return i;
        id = id<<1;
        i++;
      } while(i<MAX_OWNER_COUNT);

      return 0;
    }

    function isTExecuted(uint _tNb) private view returns (bool) { // returns if transaction / proposal has been executed yet
      return (getAsset(_tNb)>127);
    }

    function getOpenSplitTransactionNb(uint _tNb, uint8 execVal) private view returns (uint) { // returns a split group proposal / transaction id      
      uint256 t;
      uint64 f;
      
      if ((tArr[0]==0) || (_tNb==0)) return 0;
      
      uint i = (_tNb & 255); // add security: NOT more than 255 transactions in theory, in reality: not more than 115!
      do {
        t = tArr[i];
        f = getFlagsT(t);
        
        if ( (t!=0) && isExpectedCmd(t,K_SPLITGROUP) && ((getAssetT(t)&128)==execVal) && (nbOfConfirmations(f)>0) ) return i; // did find split group proposal !

        i--;
      } while(i>0);
      
      return 0;
    }

    function ownerConfirmed(uint _tNb, address _owner) private view returns (bool) { // did owner confirm transaction id ?
      return (uint64(getFlags(_tNb) & getOwnerMask(_owner))>0);
    }
    
    function getTRequired(uint _tId) private view returns (uint64) { // return the nb of votes required from transaction record
      return uint64(getFlags(_tId) & uint64(MAX_OWNER_COUNT));
    }
    
    // init of group wallet proxy and GWF contract address
    function newProxyGroupWallet_j5O(address[] calldata _owners) external onlyWhileDeploying payable { // gets only called by GWF.
      // Init of group wallet with owner addresses, this is only during group deployment. Only once.
      // Also assigning GWF while deploying group.
      // GWF = GroupWalletFactory contract is the top contract organizing Ungravel Groups.
      // GWF address links this Voting Group contract to the current factory.

      uint i=0;
      do {
        my_require(_owners[i]!=address(0) && owners.length==i,"a");
        owners.push(_owners[i]);
        i++;
      } while(i<(_owners.length & MAX_OWNER_COUNT));      
      
      GWF = msg.sender;
    }
    
    function saveAsset(bytes32 dhash, uint256 asset, string calldata key, string calldata data) external nonReentrant ungravelNameSpaceOwners(dhash) payable { // saving color tables, ChainScripts or setENSproperties() attached
      // to this group domain name. Custom color tables customize dApp look and feel.
      // Custom ChainScripts enhance group methods with custom, tailored scripts, scripting group activities or procedures.
      // Custom scripts allow groups to develop and use custom functionality around groups and transactions.
      
      if (asset!=3) {
        bytes32 pHash = bytes32(uint256(getHash()));
        my_require(__isNameSpace(pHash) && pHash==dhash,"q"); // extra security for color tables and Chainscripts ?
      }

      getRsv().setText(dhash,key,data);
        
      if (asset==1) emit ColorTableSaved (dhash);
      if (asset==2) emit EtherScriptSaved(dhash,key);
    }

    function my_transfer(address _beneficiary, uint _value, string memory _caller) internal {
      (bool succ,) = payable(_beneficiary).call{value: _value}("");
      my_require(succ,_caller);
    }

    function forwardEther(address payable receiver) external nonReentrant payable { // while leaving a group, group member transfers Ether assets to the new member address
      my_require(msg.value!=0&&receiver!=address(0),"f");
      my_transfer(receiver,msg.value,"e");
      emit Deposit(receiver, msg.value);
    }
    
    function depositEther(uint aTRecord, uint tNb) external onlyOwners payable { // while confirming the spin-off, a group member
      // deposits Ether assets to the current group wallet contract (proxy contract).
      // During the final step of the spin-off process, member deposits will be sent to the new member address.

      // In addition, this method submits a new proposal / transaction record, a deposit type.

      my_require(msg.value!=0&&tNb>0&&tArr[tNb]==0&&isExpectedCmd(aTRecord,K_DEPOSIT),"i");

      tArr[tNb] = uint256( uint256(uint256( uint64( getTRequired(tNb-1) ) | getOwnerMask(msg.sender) )<<216) & K_FLAGSMASK ) + uint256( uint256(aTRecord) & (K_ADDRESS2MASK-K_FLAGSMASK) ) + uint256( msg.value & k_ADDRESSMASK );
      emit Deposit(address(payable(this)), uint256(msg.value));
    }

    function setIntentionsContract(address intCtr) external onlyDeployer() payable {
      my_require(intCtr!=address(0),"C");
      intent = intCtr;
    }

    receive() external payable { emit Deposit(msg.sender, msg.value); }

    function version() external pure returns(uint256) {
      return 20010144;
    }
    
    constructor(AbstractReverseRegistrar _reverse, address[] memory _owners) payable {
      uint i;

      do {
        my_require(_owners[i]!=address(0)&&address(_reverse)!=address(0),"C");
        owners.push(_owners[i]);
        i++;
      } while(i<(_owners.length & MAX_OWNER_COUNT));
      
      masterCopy = msg.sender;                                                  // save owner of GroupWalletMaster
      _reverse.setName(string(bytes.concat(bytes('gwallet.ungravel'),bytes(AbsMultiFour(address(owners[0])).tld())))); // assigning reverse resolver record GWM, e.g. ".stable"
    }
}