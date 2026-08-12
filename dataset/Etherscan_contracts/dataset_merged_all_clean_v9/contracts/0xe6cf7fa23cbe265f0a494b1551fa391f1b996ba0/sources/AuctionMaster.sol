// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.33;

// AuctionMaster, intDeedMaster, extDeedMaster, IntDeedProxy, BiddingProxy ( by pepihasenfuss.eth, copyright (c) 2026, 
// based on ENS 1.0 Temporary Hash Registrar, a Vickrey Auction introduced by Nick Johnson and the ENS team )
// A Vickrey auction or sealed-bid second-price auction (SBSPA) is a type of sealed-bid auction.

// ungravel.eth, ungravel, GroupWallet, Cooperation Markets, Virtual Enterprises, GroupWalletFactory, GroupWalletMaster, GroupWallet, ProxyWallet, TokenMaster, ProxyToken, 
// AuctionMaster, BiddingProxy, intDeedMaster, extDeedMaster, IntDeedProxy, Intentions, PrePaidContract by pepihasenfuss.eth 2016-2026, Copyright (c) 2026

// AuctionMaster and Ungravel is entirely based on Ethereum Name Service, "ENS", the domain name registry.
// Although, Ungravel extends ENS to 25+ different chains: EVM Names across chains create an Ungravel Unified Name Space, UUNS.

//   ENS, ENSRegistryWithFallback, PublicResolver, Resolver, FIFS-Registrar, Registrar, AuctionRegistrar, BaseRegistrar, ReverseRegistrar, DefaultReverseResolver, 
//   ETHRegistrarController, PriceOracle, SimplePriceOracle, StablePriceOracle, ENSMigrationSubdomainRegistrar, CustomRegistrar, Root, RegistrarMigration 
//   are contracts of "ENS", by Nick Johnson and team.
//
//   Copyright (c) 2018, True Names Limited / ENS Labs Limited
//
//   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
//   to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//   and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//   The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
//   IN THE SOFTWARE.


// TLTR;
// AuctionMaster is a beast: It enables groups or group members to invest
// in other groups, acquiring group shares - the safe way. This contract consists
// of 5 different contracts that provide safe and yet affordable funding, but it is complex.
//
// Funding Auctions are so-called Vickrey auctions: Winners pay the second-highest price.
//
// Ungravel auctions are safe because all participating parties will act inside of UUNS:
// Ungravel Unified Name Space. Example: "ethereum.eth" invests into "arc-testnet.eth".
//
// But also "vitalik.ethereum.eth" may invest into his own group: "ethereum.eth".
//
// Everything is happing inside of UUNS, thus making outside attacks virtually impossible.

// Even smart contracts, such as "GroupWalletMaster", (GWM), "AuctionMaster", (AM), and all other masters,
// have proper UUNS names assigned, therefore, they are all agents acting indide of UUNS.
// (resolver and reverse resolver records are automatically assigned - while instantiating each contract)

interface IAbsAucEns {
  function owner(bytes32 node) external view  returns(address);
  function resolver(bytes32 node) external view  returns(address);
  function ttl(bytes32 node) external view  returns(uint64);
  function setOwner(bytes32 node, address ensowner)  external;
  function setSubnodeOwner(bytes32 node, bytes32 label, address ensowner)  external;
  function setResolver(bytes32 node, address ensresolver)  external;
  function setTTL(bytes32 node, uint64 ensttl)  external;
  function recordExists(bytes32 nodeENS) external view returns (bool);

  event NewOwner(bytes32 indexed node, bytes32 indexed label, address ensowner);
  event Transfer(bytes32 indexed node, address ensowner);
  event NewResolver(bytes32 indexed node, address ensresolver);
  event NewTTL(bytes32 indexed node, uint64 ensttl);
}
abstract contract AbsTokenProxy {
  function owner() external virtual view returns (address ow);
  function balanceOf(address tokenOwner) external virtual view returns (uint thebalance);
  function name() external virtual view returns (string memory);
  function transferFrom_78S(address from, address toReceiver, uint amount) external virtual;
  function tokenAllow(address tokenOwner,address spender) external virtual view returns (uint256 tokens);
  function transfer_G8l(address toReceiver, uint amount) external virtual;
  function transferAdjustPrices(address toReceiver, uint amount, uint payment, bytes32 dhash, address deedContract) external virtual;
  function nameBidBucket(bytes32 dhash,bytes32 labelhash,address deedContract) external virtual;
}
abstract contract AbsResolver {
  event AddrChanged(bytes32 indexed node, address a);
  event AddressChanged(bytes32 indexed node, uint coinType, bytes newAddress);
  event NameChanged(bytes32 indexed node, string name);
  event ABIChanged(bytes32 indexed node, uint256 indexed contentType);
  event PubkeyChanged(bytes32 indexed node, bytes32 x, bytes32 y);
  event TextChanged(bytes32 indexed node, string indexed indexedKey, string key);
  event ContenthashChanged(bytes32 indexed node, bytes hash);
  function name(bytes32 node) external virtual view returns (string memory);
  function addr(bytes32 node) external virtual view returns (address payable);
  function setABI(bytes32 node, uint256 contentType, bytes calldata data) external virtual;
  function setAddr(bytes32 node, address r_addr) external virtual;
  function setAddr(bytes32 node, uint coinType, bytes calldata a) external virtual;
  function setName(bytes32 node, string calldata _name) external virtual;
  function setText(bytes32 node, string calldata key, string calldata value) external virtual;
  function setAuthorisation(bytes32 node, address target, bool isAuthorised) external virtual;
  function supportsInterface(bytes4 interfaceId) external virtual view returns (bool);
}
abstract contract AbsReverseRegistrar {
  IAbsAucEns   public immutable ens;
  function setName(string memory name) external virtual returns (bytes32);
  function node(address addr) external virtual pure returns (bytes32);
}
abstract contract AbsIntentions {
  function getGWF() public virtual view returns (AbsGwf);
  function saveLetterOfIntent(address target, uint nbOfShares) public virtual payable;
  function getIntendedLOIShares(address target, address investor) public virtual view returns (uint);
  function mCap(address _gwp) public virtual view returns (uint);
  function getGlobalTokenAddr() public virtual view returns (address);
}
abstract contract AbsGwp {
  function getIsOwner(address _owner)      external view virtual returns (bool);
  function getOwners()                     external view virtual returns (address[] memory);
  function getGWF()                        external view virtual returns (address);
  function getTransactionsCount()          external view virtual returns (uint);
  function getTransactionRecord(uint _tNb) external view virtual returns (uint256);
  function getIntention()                  public   view virtual returns (AbsIntentions);
}
abstract contract NmWrapper {
  function setSubnodeRecord(bytes32 parentNode,string memory label,address owner,address resolver,uint64 ttl,uint32 fuses,uint64 expiry) external virtual returns (bytes32 node);
  function setSubnodeOwner(bytes32 node,string calldata label,address newOwner,uint32 fuses,uint64 expiry) external virtual returns (bytes32);
  function ownerOf(uint256 id) external virtual view returns (address);
  function setApprovalForAll(address operator,bool approved) external virtual;
}
abstract contract AbsGwf {
  NmWrapper  public   ensNameWrapper;
  IAbsAucEns public   ens;
  function getProxyToken(bytes32 _domainHash) public virtual view returns (address p);
  function getGWProxy(bytes32 _dHash) external view virtual returns (address);
  function getOwner(bytes32 _domainHash) external view virtual returns (address);
  function getGWF() external view virtual returns (address);
}
abstract contract AbsReg {
  AbsReverseRegistrar public reverseR;
  function __calledByUngravelGWP(address sender) public virtual view;
  function __calledByGWMember(bytes32 _hash) public virtual view returns (bool);
  function state_pln(bytes32 _hash) public view virtual returns (uint);
  function saveExtDeedCntr_gm9(address _sender,bytes32 _hash,uint _value) public payable virtual;
  function unsealExternalBid_qfG(bytes32 _hash) public payable virtual;
  function finalizeExternalAuction_WmS(bytes32 _hash) public payable virtual;
  function cancelExternalBid_9ig(bytes32 seal, bytes32 hash) public payable virtual;
}
abstract contract AbsIntDeedMaster {
  AbsReg public theRegistrar;
}
abstract contract AbsExtDeed {
  address public  masterCopy;
  AbsReg  public  registrar;
  address public  beneficiary;
}
abstract contract AbsGenericDeed {
  address public  owner;
  address public  beneficiary;
  uint64  public  creationDate;
  function closeDeed_igk(address receiver) public virtual payable;
  function adjustBal_1k3(uint newValue) external virtual payable;
}
abstract contract AbsMultiFour {
  address   public masterCopy; // deployer, owner of this contract
  AbsGwf    public GWF;        // GroupWalletFactory Ungravel.com
  event Deployment(address owner, address theContract);
  event DeploymentMulticall4(address theContract, bytes32 dhash);
  event Deposit(address from, uint256 value);
  function tld() public virtual view returns (string memory);
  function chainName() public virtual view returns (string memory);
}

bytes32 constant KSALT = 0x4db45745d63e3d3fca02d388bb6d96a256b72fa6a5ca7e7b2c10c90c84130f3b;

// ******************************* DeedProxy CONTRACT **************************
// The internal deed proxy is a cheap contract deployed for each bid of a member of the group, aka internal bidder.
// This proxy contract is for one bid of one group member bidding in a internal Funding Auction.
pragma solidity 0.8.33;
contract IntDeedProxy {
    address   public           masterCopy;
    bytes32   public           lhash;
    address   public           owner;
    uint64    public           creationDate;
    event DeedCreated(address indexed);
  
    modifier onlyMember() {
      AbsReg reg =AbsIntDeedMaster(masterCopy).theRegistrar();

      if (msg.sender!=address(reg))
        reg.__calledByGWMember(lhash);
      _;
    }

    constructor(address _masterCopy,address _owner,bytes32 _lhash) payable { 
      masterCopy   =  _masterCopy;
      owner        =  _owner;
      creationDate =   uint64(block.timestamp);
      lhash        = _lhash;
      emit DeedCreated(address(this));
    }
    
    fallback () external onlyMember payable
    {   
      // solium-disable-next-line security/no-inline-assembly
      assembly {
          let ptr := mload(0x40)
          calldatacopy(ptr, 0, calldatasize())
          let success := delegatecall(gas(),and(sload(0),0xffffffffffffffffffffffffffffffffffffffff),ptr,calldatasize(),0,0)
          returndatacopy(0, 0, returndatasize())
          if eq(success,0) { revert(0,0x204) }
          return(0, returndatasize())
      }
    }

    receive() external onlyMember payable
    { 
      // solium-disable-next-line security/no-inline-assembly
      assembly {
          let ptr := mload(0x40)
          calldatacopy(ptr, 0, calldatasize())
          let success := delegatecall(gas(),and(sload(0),0xffffffffffffffffffffffffffffffffffffffff),ptr,calldatasize(),0,0)
          returndatacopy(0, 0, returndatasize())
          if eq(success,0) { revert(0,0x204) }
          return(0, returndatasize())
      }
    }
}
// ******************************* DEED MASTER CONTRACT ************************
// The internal DeedMaster provides functionality for internal bids. Most important,
// it may adjust the actual price being paid during an auction. And it may close
// "the deed", transferring the deposit funding to the organizing group of the auction.
// Once a deed is closed, it will not longer be used, but it still owns its own domain name.
// s.a. "sun.my-company.stable"  |  "someauction.the-team.arc"
// To use proper, unique domain names for contracts makes investments more transparent.

pragma solidity 0.8.33;
contract intDeedMaster {
  address internal           masterCopy;
  bytes32   public           lhash;
  address   public           owner;
  uint64    public           creationDate;
  AbsReg    public immutable theRegistrar;

  uint256 private _guardCounter  = 1;

  event DeedMasterCreated(address indexed);
  event AdjustBalance(uint indexed);
  event CloseDeed(address indexed, address indexed);

  modifier nonReentrant() {
      _guardCounter += 1;
      uint256 localCounter = _guardCounter;
      _;
      require(localCounter == _guardCounter,"r"); // this may lead to a warning if calling my_require() !
  }

  modifier onlyTheRegistrar() {
    my_require(msg.sender==address(theRegistrar),"x");
    _;
  }

  function my_require(bool b, string memory str) internal pure {
    require(b,str);
  }
  
  constructor(string memory _intDName) payable
  {
    masterCopy   = msg.sender;
    owner        = msg.sender;
    theRegistrar = AbsReg(msg.sender); // AuctionMaster contract
    creationDate = uint64(block.timestamp);
    emit DeedMasterCreated(address(this));
    AbsReverseRegistrar(theRegistrar.reverseR()).setName(_intDName);
  }

  function my_transfer(address _beneficiary, uint _value, string memory _caller) internal {
    (bool succ,) = payable(_beneficiary).call{value: _value}("");
    my_require(succ,_caller);
  }
  
  function getMasterCopy() external view returns (address) { return masterCopy; }
  function registrar()     external view returns (AbsReg)  { return AbsIntDeedMaster(masterCopy).theRegistrar(); }

  function adjustBal_1k3(uint newValue) external nonReentrant onlyTheRegistrar payable { // 0x0000f6a6
    if (address(this).balance<=newValue) return;
    my_transfer(owner, address(this).balance-newValue, "G");
    emit AdjustBalance(newValue);
  }
  
  function closeDeed_igk(address receiver) external nonReentrant onlyTheRegistrar payable { // 0x00004955
    my_transfer( address( (receiver!=address(0)) ? receiver : owner ), address(this).balance, "I");
    emit CloseDeed(address(this), receiver);
  }
}
// ******************************* EXT DEED MASTER CONTRACT ********************
// An external bidder is also an Ungravel Group. A proxy bidding contract is deployed
// for each external bidder in order to participate in a Funding Auction.
//
// Any group will issue a Letter of Intent, LOI, before it can invest in any other group.
//
// The Letter of Intent indicates interest in investing into the other group,
// potentially participating in future Funding Auctions.
//
// Example: The Group "ethereum.eth" shows interest in "ens.eth" and sends an LOI,
// the Letter of Intent, indicating its interest to invest into ens.eth.
//
// The group "ens.eth" will have to complete one internal auction, first of all.
//
// Let‘s assume that "ens.eth" needs a bit of funding and one of the members invests
// during an internal funding auction, then he or she or it gets more group shares,
// consequently, the group gets common funding and increased liquidity.
//
// The internal funding auction is for group members only. It can be considered an 
// ultra-sound method to deposit common assets. Only group majority may decide on how
// to use the funding and what to do with it.
//
// Once completed, the group is entitled to organize an External Funding Auction.
// It has "qualified" to proceed and to target external investors.
//
// Since "ethereum.eth" did show interest, "ens.eth" starts yet another auction,
// this time around, they also create / deploy a BidBucket, aka BiddingProxy.
// This is a simple contract that enables external groups to bid in a Funding Auction, the safe way.

// Why so complicated?
//
// Because only an auction provides a safe and fair method to 
// distribute group shares: To members of the group, who can always bid in any auction.
//
// To other groups, aka external investors, who want to acquire a stake of the group.
//
// The auction we are using was first introduced by ENS, Nick Johnson and his team, back then.
// It is a so-called Vickrey Auction, a blind auction, where the winner will only pay
// the second-highest bid price, if he wins the auction. The Vickrey auction is a complicated
// beast itself. But it offers some advantages: Economists and researches argue that the
// Vickrey auction ultimately leads to better results, since each bidder is incentivized
// to bet a "fair" price for group shares. Knowing that he will only pay the second-best price!
// This is incentives design at its best!
// Anyway, since this type of auction was done before, in a smart contract on Ethereum,
// we decided to adapt the concept to Ungravel Funding requirements. Thanks to ENS and Nick Johnson, btw.

// This master contract, AuctionMaster, is yet another beast: It is a master that 
// deploys two other master contracts: The "intDeedMaster" and the "extDeedMaster".
//
// Both deed master contracts are needed to offer slightly different functionality  
// during an auction, depending on internal or external bidders.
//
// Why so many masters?
//
// Both masters are needed to safe gas and funding! Otherwise, deployment of bidding contracts
// would have been too costly. Therefore, we decided that we need two more contracts:
// The "IntDeedProxy" aka internal deed and bidding proxy contract, and the 
// "BiddingProxy" aka the external deed and bidding proxy contract.
//
// Yes, this leads to 5 contracts in a single solidity file. Sorry, but needed.
//
// Consequently, implementation and APIs to access 5 contracts leads to more complexity.
//
// But this is not true from the perspective of a group or a group member, seen from
// the user. From her or his or its point-of-view, this leads to ultra-safe bidding
// procedures, each bid gets its own bidding proxy installed. Since we are using
// proxies, this is still relatively cheap. It can even be used on Ethereum mainnet :)

// Consider each bidding proxy, a safe deposit contract, where each bidder may deposit
// its bid, sometimes also known as a "deed". The bid remains safe under all circum-
// stances. It can only be delegated, forwarded to the organizers of the auction,
// if bidder did actually win the auction. Otherwise, it can only be sent back to bidder,
// if he/she/it does not reveal his bid or will have to cancel the bid at the end, in
// the case that someone else won the auction. In the end, bidding proxies, combined
// with Ungravel Unified Name Space, UUNS, offer superior safety for investing on EVM chains.
//
// Due to UUNS, only groups or group members may participate, all other senders will be rejected.

// Yes, this is a closed society of participants, each of them ligitimate, authenticated by
// the unified name space, UUNS. This party is only for "invited guest".
//
// Ungravel contracts involved, such as this "AuctionMaster", the "intDeedMaster" or the 
// "extDeedMaster", they all have proper UUNS domain names by themselves, leading to a
// ultra-safe, closed and unified name space of participating agents: Whether it is a 
// group, a group member, or any of the Master contracts, they all belong to Ungravel UUNS.
//
// In this respect, UUNS is a closed, gated, safe domain, enabling ultra-sound group investments. 

// UUNS is available on 25+ different EVM compatible chains, s.a.: Ethereum, BNBmainnet, Base,
// Arbitrum, Polygon, STABLE mainnet, ARC-testnet and others.

pragma solidity 0.8.33;
contract extDeedMaster {
  address internal           masterCopy;
  uint64  public             creationDate;
  AbsReg  public             registrar;   // registrar = Auction Registrar = AuctionMaster
  bytes32 public             lhash;
  address public             beneficiary;

  event DeedMasterCreated(address indexed thisDeedContract);
  event NewBid(address indexed sender);
  event RevealBid(address indexed revealer);
  event CancelBid(address indexed canceler);
  event FinalizeBid(address indexed finalizer);
  event AdjustBalance(uint indexed theBalance, uint indexed newValue);
  event CloseDeed(address indexed deedContract, address indexed theReceiver);
  uint256 private _guardCounter  = 1;

  modifier nonReentrant() {
      _guardCounter += 1;
      uint256 localCounter = _guardCounter;
      _;
      my_require(localCounter == _guardCounter,"t");
  }
  modifier onlyReg() {
      my_require(msg.sender==address(registrar),"o");
      _;
  }
  modifier onlyGWP() {
    registrar.__calledByUngravelGWP(msg.sender);
    _;
  }

  constructor(string memory _extDName) payable
  {
    masterCopy   = msg.sender;                                                     // auction master contract
    registrar    = AbsReg(msg.sender);                                             // registrar = AuctionMaster
    creationDate = uint64(block.timestamp);
    emit DeedMasterCreated(address(this));
    AbsReverseRegistrar(registrar.reverseR()).setName(_extDName);
  }

  function my_transfer(address _beneficiary, uint _value, string memory _caller) internal {
    (bool succ,) = payable(_beneficiary).call{value: _value}("");
    my_require(succ,_caller);
  }
  function my_require(bool b, string memory str) internal pure {
    require(b,str);
  }

  function getMasterCopy() external view returns (address) { return masterCopy; }

  function adjustBal_1k3(uint newValue) external onlyReg payable {    // 0x0000f6a6 (short cmd ids are cheaper)
    my_require(address(this).balance!=0,"a");
    if (address(this).balance<=newValue) return;
    my_transfer(beneficiary, address(this).balance-newValue, "A");
    emit AdjustBalance(address(this).balance,newValue);
  }

  function closeDeed_igk(address receiver) external onlyReg payable { // 0x00004955 (short cmd ids are cheaper)
    my_transfer(address( (receiver!=address(0)) ? receiver : beneficiary ), address(this).balance, "B");
    emit CloseDeed(address(this),receiver);
  }
  
  receive() external nonReentrant onlyGWP payable {                               // receiving fallback function, catches all extDeedProxy calls
    uint lstate      = registrar.state_pln(lhash);
    uint lvalue      = msg.value;
    address lsender  = msg.sender;
    uint lthisBal    = address(this).balance;

    if (lstate==1) {                                                               // OPEN for bidding
      my_require(lhash!=0x0&&lvalue!=0&&lthisBal==lvalue,"C");
      beneficiary = lsender;
      registrar.saveExtDeedCntr_gm9(lsender,lhash,lvalue);
      emit NewBid(lsender);
    } else
    {
      my_require(lhash!=0x0&&lvalue==0&&beneficiary==lsender,"D");                 // only deed owner calls without ETH, cancel & finalize DO NOT need funding!

      if (lstate==4) {                                                      
        registrar.unsealExternalBid_qfG(lhash);                                    // REVEAL phase
        emit RevealBid(lsender);
      } else
      {
        if (lstate==2) {                                                           // FINALIZE phase
          registrar.finalizeExternalAuction_WmS(lhash);
          emit FinalizeBid(lsender);
        } else
        {
          if (lstate==6) {                                                         // CANCEL - auction done, no time-out
            registrar.cancelExternalBid_9ig(keccak256(abi.encode(lhash,beneficiary,lthisBal,KSALT)),lhash);
            emit CancelBid(lsender);
          } else
          {
            if (lstate==0) {                                                       // TIMEOUT - auction done, no bidding revealed and not finalized
              my_transfer(beneficiary,lthisBal,"E");
              emit CancelBid(lsender);
            }
          }
        }
      }
    }
  }
}
// ************************* BiddingProxy CONTRACT *****************************
// The bidding proxy contract is deployed for each external bidder, an Ungravel Group.
// External bidders are GWP from another team/group. Bidders must be from a Group.
// BiddingProxy is a safe and cost-saving method to participate and bid in a Funding Auction.

pragma solidity 0.8.33;
contract BiddingProxy {
    address   public           masterCopy;
    uint64    public           creationDate;
    AbsReg    public           registrar;
    bytes32   public           lhash;
    address   public           beneficiary;
    
    event DeedCreated(address indexed,bytes32 indexed);
    
    modifier onlyGWP() {
      if (msg.sender!=address(registrar))
        registrar.__calledByUngravelGWP(msg.sender);

      _;
    }

    constructor(address _masterCopy,bytes32 _lhash) payable { 
      masterCopy   = _masterCopy;
      registrar    = AbsReg(msg.sender);
      creationDate = uint64(block.timestamp);
      lhash        = _lhash;
      emit DeedCreated(address(this),_lhash);
    }
    
    fallback () external onlyGWP payable
    {   
      // solium-disable-next-line security/no-inline-assembly
      assembly {
          let ptr := mload(0x40)
          calldatacopy(ptr, 0, calldatasize())
          let success := delegatecall(gas(),and(sload(0),0xffffffffffffffffffffffffffffffffffffffff),ptr,calldatasize(),0,0)
          returndatacopy(0, 0, returndatasize())
          if eq(success,0) { revert(0,0x204) }
          return(0, returndatasize())
      }
    }
    receive() external onlyGWP payable
    { 
      // solium-disable-next-line security/no-inline-assembly
      assembly {
          let ptr := mload(0x40)
          calldatacopy(ptr, 0, calldatasize())
          let success := delegatecall(gas(),and(sload(0),0xffffffffffffffffffffffffffffffffffffffff),ptr,calldatasize(),0,0)
          returndatacopy(0, 0, returndatasize())
          if eq(success,0) { revert(0,0x204) }
          return(0, returndatasize())
      }
    }
}
/**
 * @title AuctionMaster
 * @dev The contract handles the auction process for fund raising
 */
contract AuctionMaster {
    mapping (address bidder => mapping(bytes32 auctionHash => uint256 bidAmount)) private biddingValue;
    mapping (bytes32 auctionHash => uint256 slotValueStored_B)                    private entry_B;
    mapping (bytes32 auctionHash => uint256 slotValueStored_A)                    private entry_A;
    mapping (bytes32 auctionHash => uint256 slotValueStored_C)                    private entry_C;

    enum Mode { Open, Auction, Owned, Forbidden, Reveal, empty, Over }
    uint                public immutable registryStarted;
    address             public immutable RegOwner;
    address             public           externalDeedMaster;
    address             public           internalDeedMaster;
    AbsReverseRegistrar public immutable reverseR;
    string              public           tld;

    event AuctionStarted(bytes32 indexed hash, uint indexed regdate);
    event NewBid(bytes32 indexed hash, address indexed, uint indexed);
    event BidRevealed(bytes32 indexed hash, address indexed, uint indexed, uint8);
    event HashReleased(bytes32 indexed hash, uint indexed);
    event AuctionFinalized(bytes32 indexed hash, address indexed, uint indexed, uint);
    event TestReturn(uint256 v1, uint256 v2, uint256 v3, uint256 v4);
    event Deposit(address indexed, uint256 indexed);
    event ExternalDeedMaster(address indexed);
    event InternalDeedMaster(address indexed);

    address constant private K_ADD00        = address(0);

    // memory slot masking: Bit masks help to fit multiple values into a single memory slot. (saves gas and cost)
    uint256 constant private K_MASKBIDVAL   = 0x00000000000000000000000000000000000000000000ffffffffffffffffffff;
    uint256 constant private K_MASKSEALBID  = 0xffffffffffffffffffffffffffffffffffffffffffff00000000000000000000; 
    uint256 constant private K_ADDRESSMASK  = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff; 
    uint256 constant private K_HIGHBIDMASK  = 0x0000ffffffffffffffffffff0000000000000000000000000000000000000000;
    uint256 constant private K_REGDATAMASK  = 0x00000000000000007fffffff0000000000000000000000000000000000000000;
    uint256 constant private K_REGDATAMASK2 = 0x000000000000000000000000000000000000000000000000000000007fffffff;
    uint256 constant private K_REGDATAMASK3 = 0xffffffffffffffff80000000ffffffffffffffffffffffffffffffffffffffff; 
    uint256 constant private K_FINALIZEMASK = 0x0000000000000000800000000000000000000000000000000000000000000000;
    uint256 constant private K_FINFLAGMASK  = 0xffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 constant private K_MINPRCMASK   = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
    uint256 constant private K_MINPRCMASK2  = 0x000000000000000000000000000000000000000000000000ffffffffffffffff;
    uint256 constant private K_MINPRCMASK3  = 0x0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 constant private K_RVLPERMASK   = 0x0000000000000000000000000000000000007fffffff00000000000000000000;
    uint256 constant private K_RVLPERMASK2  = 0xffffffffffffffffffffffffffffffffffff80000000ffffffffffffffffffff;
    
    uint256 constant private K_TYPEMASK     = 0xf000000000000000000000000000000000000000000000000000000000000000;
    uint256 private _guardCounter           = 1;

    // The storage layout, 3 memory slots: entry_A, entry_B, entry_C            each of 32 bytes
    // 0000000000000000000000000000000000000000000000000000000000000000         32 bytes (minPrc:8, final:01, regDate: 4-01, gwp 20) = 32 bytes  entry_A
    //-----------------------------------------------------------------
    // 0000000000000000000000003f6d05530286f455e77b1ea1b120670bc7038669 gwp     20 bytes
    // 00000000000000007fffffff0000000000000000000000000000000000000000 regDate 4 bytes until Jan 2038 0x7fffffff
    // 0000000000000000800000000000000000000000000000000000000000000000 final   1 bit 0x8 
    // ffffffffffffffff000000000000000000000000000000000000000000000000 minPrc  8 bytes * 1000 = 18,444.00 ETH 0xffffffffffffffff
    
    // 0000000000000000000000000000000000000000000000000000000000000000         32 bytes (deed:20, hiBid: 10, notUsed: 2)                        entry_B
    //-----------------------------------------------------------------
    // 0000000000000000000000005351248ba7800602be2ccaefba6a8c626e52f803 deed    20 bytes contract address of the deed
    // 0000ffffffffffffffffffff0000000000000000000000000000000000000000 hiBid   10 bytes highest bid
    // ffff000000000000000000000000000000000000000000000000000000000000          2 bytes not used
    
    // 0000000000000000000000000000000000000000000000000000000000000000         32 bytes (val:10, rvlPer: 4-01bit, notUsed: 18)                  entry_C
    //-----------------------------------------------------------------
    // 00000000000000000000000000000000000000000000ffffffffffffffffffff val     10 bytes  0xffffffffffffffffffff  1208925 ETH
    // 0000000000000000000000000000000000007fffffff00000000000000000000 rvlPer   4 bytes - 1bit  revealPeriod
    // 000000000000000000000000000000000000                                     18 bytes not used
    
    modifier nonReentrant() {
      _guardCounter += 1;
      uint256 localCounter = _guardCounter;
      _;
      my_require(localCounter == _guardCounter,"r");
    }
    modifier onlyGWP() {                                                                // only group wallet proxy, GWP, may call
      __calledByUngravelGWP(msg.sender);
      _;
    }
    modifier onlyRegistrar(bytes32 _hash) {                                             // only this AuctionMaster may call
      __ungravelGW(_hash);
      my_require(address(AbsExtDeed(payable(msg.sender)).registrar())==address(this),"T");

      _;
    }
    modifier onlyDeployer() {                                                           // only deployer of this contract may call, e.g. withdraw()
      my_require(RegOwner==msg.sender,"S");
      _;
    }
    modifier onlyGW(bytes32 _hash) {                                                    // only known auction hash, leading to valid Ungravel Group, GWP
      __ungravelGW(_hash);
      _;
    }
    modifier onlyMember(bytes32 _hash) {                                                // only by valid GWP and member of the group
      __ungravelGW(_hash);
      __calledByGWMember(_hash);
      _;
    }
    modifier onlyDeedOwner(bytes32 _hash) {                                             // first bidder becomes owner of the "deed", the deposit proxy contract that holds the bidding
      my_require(msg.sender==AbsGenericDeed(payable(__deed(_hash))).owner(),"H");
      _;
    }
    modifier onlyExtDeedOwner(bytes32 _hash) {                                          // first external group bidding becomes beneficiary (owner) of the BiddingProxy contract 
      my_require(msg.sender==AbsExtDeed(payable(__deed(_hash))).beneficiary(),"H");
      _;
    }

    function __callerExists(address _caller) private view returns (bool) {              // check reverse name node of sender address, e.g. "silvias-bakery.eth"
      return reverseR.ens().recordExists(reverseR.node(_caller));                       // check if ENS entry of node exists: true | false
    }                                                                               
    function __calledByUngravelGWP(address sender) public view {                        // caller MUST BE valid contract, a GroupWalletProxy, GWP, belonging to Ungravel
      //my_require(_validAddress(sender)&&__callerExists(sender),"J");                  // called by a contract && check reverse name of sender, e.g. "silvias-bakery.eth"
                                                                                        // getdHash(AbsGwp(sender))  hsh = GroupWallet domain hash, from GWP contract
                                                                                        // AbsGwp(sender).getGWF()   GWF contract, derived from GWP, in this case (hopefully) the caller
      my_require(_validAddress(sender)&&__callerExists(sender)&&((sender==address(this))||(getdHash(AbsGwp(sender))!=0x0&&AbsGwf( AbsGwp(sender).getGWF() ).getOwner(getdHash(AbsGwp(sender)))==sender)),"M");// the requested GWP owns its own dName, s.a. "silvias-bakery.eth"
    }
    function __calledByGWMember(bytes32 _hash) public nonReentrant returns (bool) {     // caller MUST BE member of contract, a GroupWalletProxy GWP, belonging to Ungravel
      // used for internal bidders!

      if (intentionsFromGWP(_hash).getGlobalTokenAddr()==msg.sender) return true;       // allow access from Global Token contract "global.ungravel.tld"

      AbsGwp gwp = AbsGwp(__gwpc(_hash));                                               // valid hsh

      my_require(                                                                       // msg.sender is member of the GWP, aka belongs to GWP group
               address(gwp)!=address(0)   && 
               gwp.getIsOwner(msg.sender)
         ,"N");
      
      return true;
    }
    function __ungravelGW(bytes32 _hash) private view {                                 // _hash belongs to a domain name that belongs to Ungravel Unified Name Space
      // _hash belongs to a domain name that belongs to Ungravel - 
      // protecting the call to only accept calls from inside the unified name space, UUNS

      AbsGwp gwp = AbsGwp(__gwpc(_hash));                                               // *** hash of aseed *** _hash = auction label hash

      bytes32 hsh  = getdHash(gwp);                                                     // hsh = GroupWallet domain hash
      address gwfc = gwp.getGWF();                                                      // GWF contract, derived from GWP
      my_require(__callerExists(address(gwp))&&hsh!=0x0&&_validAddress(gwfc)&&AbsGwf(gwfc).getOwner(hsh)==address(gwp),"R"); // auction label hash identifies GWP, organizing an auction
    }
    function _validIntentionsContract(address a) private view returns (AbsIntentions intent) { // get Intentions contract address from GWP
      intent = AbsGwp(a).getIntention();
      my_require(_validAddress(a)&&_validAddress(address(intent)),"U");                 // _validAddress
      return intent;
    }
    function _validAddress(address ct) private pure returns (bool) {                    // checks for 0x0 addresses
      return ct!=address(0);
    }
    function _timeStamp() internal view returns (uint){                                 // timeStamp from block
      return uint(block.timestamp);
    }
    function getChainId() public view returns (uint) {                                  // chain id, e.g. 1 === Ethereum mainnet, 1135 = lisk
      return block.chainid;
    }
    function my_require(bool b, string memory str) internal pure {                      // avoiding require() calls, it saves deployment bytes
      require(b,str);
    }

    // State transitions for auctions:
    //   Open -> Auction (startAuction)
    //   Auction -> Reveal
    //   Reveal -> Owned
    //   Reveal -> Open (if nobody bid)
    //   Owned -> Open (releaseDeed or invalidateName)
    //   Over  -> Over (auction finalized and done)
    function state_pln(bytes32 _hash) public view returns (Mode) { // 0x00006154      
        if (__finalize(_hash)) return Mode.Over;
        uint l_regDate = __regDate(_hash);
        
        if(_timeStamp() < l_regDate) {
            if (_timeStamp() < (l_regDate - __revealPeriod(_hash))) {
                return Mode.Auction;
            } else {
                return Mode.Reveal;
            }
        } else {
            if(__highestBid(_hash) == 0) {
                return Mode.Open;
            } else {
                return Mode.Owned;
            }
        }
    }
    function entries(bytes32 _hash) external view returns (Mode, address, uint, uint, uint, uint, uint, uint) {
      uint l_reveal = __revealPeriod(_hash);
      
      Mode l_state  = state_pln(_hash);
      address l_add = address(__deed(_hash));
      
      uint[5] memory l_a;
      l_a[0]   = __minPrice(_hash);
      l_a[1]   = __finalize(_hash) ? 1 : 0;
      l_a[2]   = __highestBid(_hash);
      l_a[3]   = __deedValue(_hash);
      l_a[4]   = __regDate(_hash);
      
      return (l_state, l_add, l_a[4], l_a[3], l_a[2], l_a[1], l_a[0], l_reveal);
    }

    // bitMap methods to access bidValue and sealedBid economically (one word - one slot)
    
    function __biddVal(address bidder,bytes32 hash) private view returns (uint) {
      return uint(biddingValue[bidder][hash] & K_MASKBIDVAL);
    }
    function __sealedBid(address bidder,bytes32 hash) private view returns (address) {
      return address(uint160(uint256(uint256(uint256(biddingValue[bidder][hash])>>80) & K_ADDRESSMASK)));
    }
    function saveSealedBid(address bidder,bytes32 seal,address bid) private {
      biddingValue[bidder][seal] = uint256(uint256(uint256(uint160(bid))<<80) & K_MASKSEALBID) + uint256(biddingValue[bidder][seal] & K_MASKBIDVAL);
    }
    function saveBiddVal(address bidder,bytes32 hash,uint val) private {
      biddingValue[bidder][hash] = uint256(biddingValue[bidder][hash] & K_MASKSEALBID) + uint256(val & K_MASKBIDVAL);
    }
    function getBiddingValue(address bidder,bytes32 hash) external view returns (uint256) {
      return uint256(__biddVal(bidder,hash));
    }
    function sealedBidContract(address bidder,bytes32 hash) external view returns (address) {
      return __sealedBid(bidder,hash);
    }
  
    // deed,highestBid ----entry_B----------------------------------------------
    
    function __deed(bytes32 hash) private view returns (address) {
      return address(uint160(uint256(entry_B[hash] & K_ADDRESSMASK)));
    }
    function saveDeed(bytes32 hash,address deed) private {
      entry_B[hash] = uint256(entry_B[hash] & K_HIGHBIDMASK) + uint256(uint256(uint160(deed)) & K_ADDRESSMASK);
    }
    function __highestBid(bytes32 hash) private view returns (uint) {
      return uint(uint256(uint256(entry_B[hash] & K_HIGHBIDMASK)>>160) & K_MASKBIDVAL);
    }
    function saveHighestBid(bytes32 hash,uint highBid) private {
      entry_B[hash] = uint256(entry_B[hash] & K_ADDRESSMASK) + uint256(uint256(uint256(highBid & K_MASKBIDVAL)<<160) & K_HIGHBIDMASK);
    }
    function saveDeedAndHighBid(bytes32 hash,address deed,uint highBid) private {
      entry_B[hash] = uint256(uint256(uint160(deed)) & K_ADDRESSMASK) + uint256(uint256(uint256(highBid & K_MASKBIDVAL)<<160) & K_HIGHBIDMASK);
    }

    // gwp,regDate,final,minPrc ----entry_A-------------------------------------

    function __gwpc(bytes32 hash) private view returns (address) {
      return address(uint160(uint256(entry_A[hash] & K_ADDRESSMASK)));
    }
    function saveGWPC(bytes32 hash,address gw) private {
      entry_A[hash] = uint256(entry_A[hash] & K_HIGHBIDMASK) + uint256(uint256(uint160(gw)) & K_ADDRESSMASK);
    }
    function __regDate(bytes32 hash) private view returns (uint) {
      return uint(uint256(uint256(entry_A[hash] & K_REGDATAMASK)>>160) & K_REGDATAMASK2);
    }
    function saveRegDate(bytes32 hash,uint regDate) private {
      entry_A[hash] = uint256(entry_A[hash] & K_REGDATAMASK3) + uint256(uint256(uint256(regDate & K_REGDATAMASK2)<<160) & K_REGDATAMASK);
    }
    function __finalize(bytes32 hash) private view returns (bool) {
      return bool(uint256(uint256(entry_A[hash] & K_FINALIZEMASK))!=0);
    }
    function saveFinalize(bytes32 hash,bool finalize) private {
      if ( finalize) entry_A[hash] = uint256(entry_A[hash] & K_FINFLAGMASK) + uint256(K_FINALIZEMASK);
      if (!finalize) entry_A[hash] = uint256(entry_A[hash] & K_FINFLAGMASK);
    }
    function __minPrice(bytes32 hash) private view returns (uint) {
      return uint(uint256(uint256(entry_A[hash] & K_MINPRCMASK)>>176) & K_MINPRCMASK2);
    }
    function saveMinPrice(bytes32 hash,uint minPrc) private {
      entry_A[hash] = uint256(entry_A[hash] & K_MINPRCMASK3) + uint256(uint256(uint256(minPrc & K_MINPRCMASK2)<<176) & K_MINPRCMASK);
    }
    
    function saveGWRegDFinaMinPrc(bytes32 hash,address gw,uint regDate,bool finalize,uint minPrc) private {
      uint256 l_finalize = 0;
      if (finalize) l_finalize = uint256(K_FINALIZEMASK);

      entry_A[hash] = uint256(uint256(uint160(gw)) & K_ADDRESSMASK) + 
                      uint256(uint256(uint256(regDate & K_REGDATAMASK2)<<160) & K_REGDATAMASK) + 
                      l_finalize + 
                      uint256(uint256(uint256(minPrc & K_MINPRCMASK2)<<176) & K_MINPRCMASK);
    }

    // -val,rvlPer----entry_C---------------------------------------------------

    function __deedValue(bytes32 hash) private view returns (uint) {
      return uint(uint256(uint256(entry_C[hash] & K_MASKBIDVAL)));
    }
    function saveDeedValue(bytes32 hash,uint val) private {
      entry_C[hash] = uint256(entry_C[hash] & K_MASKSEALBID) + uint256(val & K_MASKBIDVAL);
    }
    function __revealPeriod(bytes32 hash) private view returns (uint) {
      return uint(uint256(uint256(uint256(entry_C[hash] & K_RVLPERMASK)>>80) & K_REGDATAMASK2));
    }
    function saveRevealPeriod(bytes32 hash,uint rvlPer) private {
      entry_C[hash] = uint256(entry_C[hash] & K_RVLPERMASK2) + uint256(uint256(uint256(rvlPer & K_REGDATAMASK2)<<80) & K_RVLPERMASK);
    }
    function saveRevealPerValue(bytes32 hash,uint rvlPer,uint val) private {
      entry_C[hash] = uint256(uint256(uint256(rvlPer & K_REGDATAMASK2)<<80) & K_RVLPERMASK) + uint256(val & K_MASKBIDVAL);
    }
  
    /**
     * @dev Returns lmax the maximum of two unsigned integers
     * @param a A number to compare
     * @param b A number to compare
     * @return lmax The maximum of two unsigned integers
     */
    function max(uint a, uint b) internal pure returns (uint lmax) {
        if (a >= b)
            return a;
        else
            return b;
    }
    /**
     * @dev Returns the minimum of two unsigned integers
     * @param a A number to compare
     * @param b A number to compare
     * @return lmin The minimum of two unsigned integers
     */
    function min(uint a, uint b) internal pure returns (uint lmin) {
        if (a <= b)
            return a;
        else
            return b;
    }
    /**
     * @dev Returns the length of a given string
     * @param s The string to measure the length of
     * @return len The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint len) {
        // Starting here means the LSB will be the byte we care about
        uint ptr;
        uint end;
        
        assembly {
            ptr := add(s, 1)
            end := add(mload(s), ptr)
        }
        for (; ptr < end; len++) {
            uint8 b;
            assembly { b := and(mload(ptr), 0xFF) }
            if (b < 0x80) {
                ptr += 1;
            } else if(b < 0xE0) {
                ptr += 2;
            } else if(b < 0xF0) {
                ptr += 3;
            } else if(b < 0xF8) {
                ptr += 4;
            } else if(b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
        return len;
    }
    function memcpy(uint dest, uint src, uint len) private pure {
        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            // solium-disable-next-line security/no-inline-assembly
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }
        
        if (len==0) return;

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
    function stringMemoryTobytes32(string memory _data) private pure returns(bytes32 a) {
      // solium-disable-next-line security/no-inline-assembly
      assembly {
          a := mload(add(_data, 32))
      }
    }
    function bytes32ToBytes32WithLen(bytes32 _b) private pure returns (bytes32) {
      return bytes32( uint256(uint256(_b) & 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00) + uint256(uint256(strlen(bytes32ToStr(_b)))&0xff) );
    }
    function mb32(bytes memory _data) private pure returns(bytes32 a) {
      // solium-disable-next-line security/no-inline-assembly
      assembly {
          a := mload(add(_data, 32))
      }
    }
    function bytes32ToStr(bytes32 _b) internal pure returns (string memory) {
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
      } while(i<32&&off!=0);
      
      return string(rArr); 
    }
    
    // A factor to calculate reasonable minimum bidding pricing depending on chain, based on chain transaction fees: 
    // getPercentageOfCost() gives the max. percentage of total transaction cost allowed.
    // example: calculateMinAuctionPrice() calculates estimated cost in chain currency, 
    // e.g. in matic or ether, appr. 2,433,123 gas with current gas cost of the chain, times getPercentageOfCost().
    // reason:  if total auction transactions cost is e.g. 0.2 ETH, we allow only bids that are at least 5% of the amount, 
    // e.g. 0.01 ETH on ethereum mainnet, to enforce a reasonable gas cost / bidding ratio.
    // hint:    it avoids useless bidding prices lower than the actual transaction fees (keeping transactions reasonable, somehow :)
    // while disabling/preventing Auction Spam, Auction factories and Auction Domain grabbing.

    function getPercentageOfCost() internal pure returns (uint64) {
      return 10;                        // all other chains: Transaction cost not more than 10% of minBid.
    }
    /** 
     * @dev Returns registry starting date
     * 
     */
    function getAllowedTime() external view returns (uint) {
      return registryStarted;
    }
    function getGWPfromAuction(bytes32 _hash) external onlyGW(_hash) view returns (address) { // used in UNG_Auction, sendENSextBidProxy()...
      // provide the GWP - GroupWalletProxy contract address from the hash
      // of the auction name, only if auction name belongs to Ungravel unified name space!
      return __gwpc(_hash);
    }
    function _tokenContract(AbsGwp gw) internal view returns (AbsTokenProxy) {
      // get proxy token contract of group
      // from the GWF that controls the group
      // Token Proxy is a contract that controls group shares.

      AbsGwf GWF = AbsGwf(gw.getGWF());
      my_require(address(GWF)!=address(0),"X");
      return AbsTokenProxy(GWF.getProxyToken(getdHash(gw)));
    }
    function intentionsFromGWP(bytes32 _hash) public onlyGW(_hash) view returns (AbsIntentions) { // used in GWF - GroupWalletFactory, getIntention()
      return AbsGwp(__gwpc(_hash)).getIntention();
    }
    function getAuctionMinBiddingPrice(bytes32 _hash) external view returns (uint) {
      return __minPrice(_hash);
    }
    function getGasPrice() private view returns (uint256 gasPrice) {
      assembly { gasPrice := gasprice() }
    }
    function calculateMinAuctionPrice() public view returns (uint64 minP) {
      minP = uint64(uint64(getGasPrice()) * uint(2433123) * 100) / getPercentageOfCost();
      if (minP<=0.001 ether) minP += 0.001 ether;
      return minP;
    }
    /**
     * @dev Start an auction for an available hash
     *
     * @param _hash   The hash to start an auction, auction label name hash
     * @param revealP The reveal period in seconds, length of auction = 2*revealP
     */
    function startAuction_ge0(bytes32 _hash, uint revealP) external nonReentrant onlyGWP payable { // 0x00004632  can only be called by GWP contract OK
      uint tNb              = AbsGwp(msg.sender).getTransactionsCount()-1;    // get transaction nb of the last / current auction transaction of GWP
      my_require(tNb!=0&&state_pln(_hash)==Mode.Open,"Z");                    // only if auction is NOT yet running
      
      uint32 l_revealP      = uint32(revealP)!=0 ? uint32(revealP) : 1 minutes;

      AbsIntentions intCtr  = _validIntentionsContract(msg.sender);

      uint mCapGWP          = intCtr.mCap(msg.sender);                        // market cap == value of the GWP calling
      uint minPrice         = calculateMinAuctionPrice();                     // minimum bid price, derived from gas cost of chain

      AbsTokenProxy tokenC  = _tokenContract(AbsGwp(msg.sender));             // get proxyToken (PT) contract of GWP, in order to calculate value of group share batch
      uint bal              = uint(tokenC.balanceOf(address(this)))/100;      // get nb of Group Shares yet deposited, aka left-over shares of the Funding Auction 

      uint amnt             = uint(uint8(uint256(AbsGwp(msg.sender).getTransactionRecord( tNb )>>208) & 0x03)); // nb may be 0,1,2,3
      amnt                  = bal + ((1 + (amnt*amnt)) * 1e4);                // 0 = 10,000   1 = 20,000  2 = 50,000  3 = 100,000 shares + left over shares

      if ((mCapGWP!=0)&&(mCapGWP>=minPrice)) minPrice = uint(uint(mCapGWP*amnt)/1.2e6); // also: >=10,000 shares if timed-out auctions without a winning bidder

      saveRevealPerValue(_hash,l_revealP,0);
      saveHighestBid(_hash,0);
      saveGWRegDFinaMinPrc(_hash,msg.sender,uint64(_timeStamp())+uint64(l_revealP<<1),false,minPrice);

      emit AuctionStarted(_hash,__regDate(_hash));
    }
    function saveExtDeedCntr_gm9(address _sender,bytes32 _hash,uint _value) external nonReentrant onlyRegistrar(_hash) payable {  // 0x000083bf 
      // can only be called by ext BiddingProxy contract - this gets called with an external bid

      address gwp = __gwpc(_hash);                                                            // GroupWallet Proxy contract GWP, from auction label hash
      AbsIntentions intCtr = _validIntentionsContract(gwp);                                   // gwp is valid contract and has valid Intentions contract

      bytes32 lseal = keccak256(abi.encode(_hash,_sender,_value,KSALT));                      // compute the seal, KSALT is "salt"
      my_require(intCtr.getIntendedLOIShares(gwp,_sender)!=0 && __sealedBid(_sender,lseal)==K_ADD00&&_value>=__minPrice(_hash),"s"); // LOI required, check pricing

      saveSealedBid(_sender,lseal,address(msg.sender));                                       // lseal address(msg.sender) = ext BiddingProxy contract
      saveBiddVal  (_sender,_hash,_value);                                                    // _hash _sender             = ext investor = GWP of LOI investor
    }
    /**
     * @dev Hash the values required for a secret bid
     * @param hash The node corresponding to the desired namehash
     * @param value The bid amount
     * @param salt A random value to ensure secrecy of the bid
     * @return sealedBid The hash of the bid values
     */
     function shaBid(bytes32 hash, address owner, uint value, bytes32 salt) public pure returns (bytes32 sealedBid) {
        return keccak256(abi.encode(hash, owner, value, salt));
     }
    /**
     * @dev Submit a new sealed bid on a desired hash in a blind auction 
     * Bids are sent by sending a message to the main contract with a hash and an amount. The hash
     * contains information about the bid, including the bidded hash, the bid amount, and a random
     * salt. Bids are not tied to any one auction until they are revealed. This is
     * followed by a reveal period. Bids revealed after this period will be paid back and cancelled.
     * @param seal  A sealedBid, created by the shaBid function
     * @param _hash labelhash of name of auction
     * @param masterContract Master - for IntDeedProxy
     */
    function newBidProxy_DKJ(bytes32 seal,bytes32 _hash,address masterContract) external onlyMember(_hash) payable { // 0x0000f5c2 
      // can only be called by a group member, member of GWP *** for internal bidders ***

      my_require(masterContract==internalDeedMaster&&seal!=0x0&&__sealedBid(msg.sender,seal)==K_ADD00&&msg.value>=__minPrice(_hash),"j");
    
      // msg.sender becomes owner of Deed, aka intDeedProxy contract

      address deed = address((new IntDeedProxy){value: msg.value}(masterContract,msg.sender,_hash));           // bidding proxy contract - for group members

      saveSealedBid(msg.sender,seal,deed);                                                                     // creates a new deed contract with owner    
      saveBiddVal(msg.sender,_hash,msg.value);
    }
    /**
     * @param _hash labelhash of name of auction
     * @param masterContract externalMaster - for BiddingProxy
     */
    function createBidBucketProxy(bytes32 _hash,address masterContract) public onlyGW(_hash) payable {         // new BiddingProxy contract for external bidders / investors
      // labelHash --> GWP --> dHash of GWP: GWP owns dHash of name

      my_require(masterContract==externalDeedMaster&&state_pln(_hash)==Mode.Auction&&!__finalize(_hash),"c");  // check Master, state of auction, not yet finished
      address deed = address((new BiddingProxy){value:0}(masterContract,_hash));                               // temporary deed contract, open for an external investor
      
      AbsGwp gwp          = AbsGwp(__gwpc(_hash));                                                             // GroupWallet Proxy contract GWP
      
      AbsIntentions intent = _validIntentionsContract(address(gwp));                                           // valid gwp and Intentions contract required
      address gwfc         = address(intent.getGWF());
      address gwfc2        = gwp.getGWF();
      address gwfc3        = _tokenContract(gwp).owner();
      my_require(_validAddress(gwfc)&&_validAddress(gwfc2)&&_validAddress(gwfc3)&&gwfc==gwfc2&&gwfc3==gwfc,"V");

      bytes32 labelhashOrStr = nextBucketLabel(gwp);                                                           // label hash || label string with len
      _tokenContract(gwp).nameBidBucket(getdHash(gwp),labelhashOrStr,deed);                                    // domain name hash of e.g. "bidbucket.mygroupwallet.eth"
    }

    // returns latest Auction contract and transaction Id
    function auctionTRecord(AbsGwp gwp) internal view returns (address,uint) {
      uint256 t;
      uint i = gwp.getTransactionsCount();
      my_require(i!=0,"0");

      do {
        i--;
        t = gwp.getTransactionRecord(i);
      } while( (i!=0) && (t!=0) && ((t & K_TYPEMASK) != K_TYPEMASK) );

      my_require(address(uint160(t & K_ADDRESSMASK))==address(this),"n");
      return (address(uint160(t & K_ADDRESSMASK)),i);
    }
    function getLabelBytes32(AbsGwp gw,uint _tNb) internal view returns (bytes32) {
      return bytes32(uint256(gw.getTransactionRecord(_tNb) & 0x000000000000ffffffffffff0000000000000000000000000000000000000000)<<48);  // e.g. label name "seed"
    }
    function addBucketNbToLabel(bytes32 label32,uint nb) internal pure returns (bytes32) { // *** only one byte *** 
      return bytes32( uint256(uint256(uint256(nb+96))<<248) + uint256(uint256(label32)>>8) );
    }
    function nextBucketLabel(AbsGwp gw) internal view returns (bytes32 b) {
      address gwfc = gw.getGWF();
      my_require(address(gwfc)!=address(0),"f");
      
      IAbsAucEns ens = AbsGwf(gwfc).ens();
      
      (address auctionTAddr,uint tNb) = auctionTRecord(gw);
      my_require(address(ens)!=address(0) && auctionTAddr!=address(0)&&tNb!=0,"*");

      bytes32 label   = getLabelBytes32(gw,tNb);
      bytes32 domHash = getdHash(gw);
      bytes32 labelHash;
      bytes32 dhash;
      
      uint i = 0;
      do {
        i++;
        labelHash  = keccak256(bytes(bytes32ToStr( addBucketNbToLabel(label,i) )));
        dhash      = keccak256(abi.encodePacked(domHash,labelHash));
      } while(ens.recordExists(dhash)&&i<=26);
      
      if (!ens.recordExists(dhash)) {
        if ((address(AbsGwf(gwfc).ensNameWrapper())==address(0))) return labelHash;  
        else          return bytes32ToBytes32WithLen(addBucketNbToLabel(label,i));
      }

      my_require(false,"bb"); // *** max. 26 different labels *** a-z
    }


    // UNSEAL

    /**
     * @dev Submit the properties of a bid to reveal them
     * @param _hash The node in the sealedBid
     * @param _value The bid amount in the sealedBid
     * @param _salt The sale in the sealedBid
     */
    function unsealBid_le$(bytes32 _hash, uint _value, bytes32 _salt) external onlyMember(_hash) payable {  // 0x0000bf3a
      _unseal(true, _value, _hash, msg.sender, _salt);
    }
    function unsealExternalBid_qfG(bytes32 _hash) external onlyRegistrar(_hash) payable {                   // 0x0000824d
      _unseal(false, address(msg.sender).balance, _hash, AbsExtDeed(msg.sender).beneficiary(),KSALT);
    }
    function _unseal(bool _internal, uint l_value, bytes32 _hash, address l_sender, bytes32 _salt) private {
      // generic unseal - external or internal auction
      bytes32 seal = keccak256(abi.encode(_hash,l_sender,l_value,_salt));
      
      if (!_internal) {
        my_require(_hash!=0x0 && __sealedBid(l_sender,seal)==msg.sender,"D2");
      }
      
      AbsGenericDeed bid = AbsGenericDeed(payable(__sealedBid(l_sender,seal)));
      my_require(address(bid)!=address(0),"Db");
      saveSealedBid(l_sender,seal,address(0));


      if (_internal) {
        //bid.adjustBal_1k3( min(l_value, address(bid).balance) );
        Mode auctionState = state_pln(_hash);

        if(auctionState == Mode.Owned) {
            bid.closeDeed_igk(address(0));                                    // Too late! Get's 100% back.
            saveBiddVal(l_sender,_hash,0);
        } else if (auctionState != Mode.Reveal) {
            my_require(false,"MR");                                           // Invalid phase
        } 
      }


      if (l_value < __minPrice(_hash) || bid.creationDate() > __regDate(_hash) - __revealPeriod(_hash)) {
          bid.closeDeed_igk(address(0));                                        // Bid too low or too late, refund 100%
          saveBiddVal(l_sender,_hash,0);                                        // * NOT msg.sender * instead l_sender
      } else if (l_value > __highestBid(_hash)) {
          if( __deed(_hash) != address(0)) {                                    // new winner: cancel the other bid, refund 100%
            if (!_internal) {
              AbsGenericDeed previousWinner = AbsGenericDeed(payable(__deed(_hash)));
              saveBiddVal(previousWinner.beneficiary(),_hash,0);
              previousWinner.closeDeed_igk(address(0));
            }
            else
            {
              AbsGenericDeed previousWinner = AbsGenericDeed(payable(__deed(_hash)));
              saveBiddVal(previousWinner.owner(),_hash,0);
              previousWinner.closeDeed_igk(address(0));
            }
          }
          // set new winner: per the rules of a vickery auction, the value becomes the previous highest Bid
          saveDeedValue(_hash,__highestBid(_hash));                             // will be zero if there's only 1 bidder
          saveDeedAndHighBid(_hash,address(bid),l_value);
      } else if (l_value > __deedValue(_hash)) {
          saveDeedValue(_hash,l_value);                                         // not winner, but affects second place
          bid.closeDeed_igk(address(0));
          saveBiddVal(l_sender,_hash,0);                                        // * NOT msg.sender * instead l_sender
      } else {
          bid.closeDeed_igk(address(0));                                        // bid doesn't affect auction
          saveBiddVal(l_sender,_hash,0);                                        // * NOT msg.sender * instead l_sender
      }
    }



    function getdHash(AbsGwp gw) internal view returns (bytes32) {
      address gwfc = gw.getGWF();
      my_require(address(gwfc)!=address(0),"h");
      return bytes32(gw.getTransactionRecord(uint256(uint160(gwfc)))); // domain hash, s.a. hash of "mygroupwallet.eth"
    }
    function transferGroupShares(AbsGwp gwc, address receiver) internal {
      if (!_validAddress(address(gwc))) return;
      AbsTokenProxy ptoken = _tokenContract(gwc);      // token contract of group shares
      
      my_require(address(receiver)!=address(0)&&address(ptoken)!=address(0),"p");
      
      uint bal = ptoken.balanceOf(address(this));
      if (bal != 0) ptoken.transfer_G8l(receiver,bal); // send back shares to GroupWallet
    }
    function transferGroupSharesAdjustPrices(AbsGwp gwc, address receiver, uint payment, address deedContract) internal {      
      AbsTokenProxy ptoken = _tokenContract(gwc);                             // token contract of group shares
      my_require(address(receiver)!=address(0)&&address(deedContract)!=address(0)&&payment!=0&&address(ptoken)!=address(0),"v");
      
      bytes32 dHash = getdHash(gwc);
      uint  bal     = ptoken.balanceOf(address(this));
      if (bal != 0) ptoken.transferAdjustPrices(receiver,bal,payment,dHash,deedContract);
    }
    

    // FINALIZE
    function _prepareFinalize(bytes32 _hash, AbsGenericDeed _deed) private returns (address,uint) {
      uint l_deedVal = max(__deedValue(_hash), __minPrice(_hash));              // handles the case when there's only a single bidder value is zero

      saveDeedValue(_hash,l_deedVal);
      _deed.adjustBal_1k3(l_deedVal);
      address gwp = __gwpc(_hash);

      if (!_validAddress(gwp)) _deed.closeDeed_igk(address(this));
      return (gwp,l_deedVal);
    }
    /**
     * @dev Finalize an auction after the registration date has passed
     * @param _hash The hash of the name of the auction
     */
    function finalizeAuction_H3D(bytes32 _hash) external nonReentrant onlyDeedOwner(_hash) payable { // 0x0000283b
      AbsGenericDeed l_deed = AbsGenericDeed(payable(__deed(_hash)));             // intDeedMaster
      my_require(((state_pln(_hash)==Mode.Owned) || (state_pln(_hash)==Mode.Over)),"F");
      
      (address gwp, uint l_deedVal) = _prepareFinalize(_hash, l_deed);
      
      if (_validAddress(gwp)) {
        transferGroupSharesAdjustPrices(AbsGwp(gwp),l_deed.owner(),l_deedVal,address(l_deed)); // transfer all token to highest bidder 
        l_deed.closeDeed_igk(gwp);
      }
      
      saveFinalize(_hash,true);                                                   // finalized flag      
      saveBiddVal(msg.sender,_hash,0);
      
      emit AuctionFinalized(_hash, l_deed.owner(), l_deedVal, __regDate(_hash));
    }
    function finalizeExternalAuction_WmS(bytes32 _hash) external nonReentrant onlyRegistrar(_hash) payable { // 0x00009204
      AbsGenericDeed l_deed = AbsGenericDeed(payable(__deed(_hash)));             // extDeedMaster
      my_require(!__finalize(_hash)&&__highestBid(_hash)!=0&&AbsExtDeed(msg.sender).beneficiary()==l_deed.beneficiary()&&_timeStamp()>=__regDate(_hash),"fx");
      
      (address gwp, uint l_deedVal) = _prepareFinalize(_hash, l_deed);
      
      if (_validAddress(gwp)) {
        transferGroupSharesAdjustPrices(AbsGwp(gwp),l_deed.beneficiary(),l_deedVal,address(l_deed)); // transfer all token to highest bidder 
        l_deed.closeDeed_igk(gwp);
      }
      
      saveFinalize(_hash,true);                                                   // finalized flag
      saveBiddVal(AbsExtDeed(msg.sender).beneficiary(),_hash,0);                  // AbsExtDeed(msg.sender).beneficiary() *
      
      emit AuctionFinalized(_hash, l_deed.beneficiary(), l_deedVal, __regDate(_hash));
    }


    // CANCEL
    function _transferShares(address _sender, bytes32 _hash, address _bid, bytes32 _seal) internal {
      if (address(_bid)!=address(0) && address(_sender)!=address(0)) {
        my_require((__finalize(_hash) || (state_pln(_hash)==Mode.Open)) && (_timeStamp() > (AbsGenericDeed(_bid).creationDate() + (__revealPeriod(_hash)<<1))),"d"); 
        AbsGenericDeed(_bid).closeDeed_igk(K_ADD00); // send back cancelled bid
        saveSealedBid(_sender,_seal,K_ADD00);

        saveBiddVal(_sender,_hash,0);
        address gwp = __gwpc(_hash);
        transferGroupShares(AbsGwp(gwp),gwp);
      }
    }
    function cancelBid_k4U(bytes32 _seal, bytes32 _hash) external onlyMember(_hash) payable {   // 0x000046cb
      _transferShares(msg.sender,_hash,__sealedBid(msg.sender,_seal),_seal);
    }
    function cancelExternalBid_9ig(bytes32 seal, bytes32 hash) external onlyRegistrar(hash) payable { // 0x00006a26
      address l_sender = AbsExtDeed(msg.sender).beneficiary();
      _transferShares(l_sender,hash,payable(__sealedBid(l_sender,seal)),seal);
    }


    // RELEASE
    function _release(bytes32 _hash, AbsGenericDeed _deed) private {
      my_require(state_pln(_hash)==Mode.Over&&_timeStamp()>=__regDate(_hash),"e");
      saveDeedValue(_hash,0);
      saveDeedAndHighBid(_hash,address(0),0);
      _deed.closeDeed_igk(address(0));
    }
    /**
     * @dev After some time, the owner can release the deed and get their ether back.
     * @param _hash The node to release
     */
    function releaseDeed(bytes32 _hash) external onlyDeedOwner(_hash) payable {            // 0x0230a07c
      _release(_hash,AbsGenericDeed(payable(__deed(_hash))));
    }
    function releaseExternalDeed(bytes32 _hash) external onlyExtDeedOwner(_hash) payable { // 0x2b936b7c
      _release(_hash,AbsGenericDeed(payable(__deed(_hash))));
    }


    function _deedDomainName(string memory _prefix) private view returns (string memory) {
      return string(bytes.concat(bytes(_prefix),bytes('ternal-deed.ungravel'),bytes(tld))); // e.g. external-deed.ungravel.stable | internal-deed.ungravel.arc
    }
    function deployExtDeedMaster() external onlyDeployer payable {
      externalDeedMaster = address((new extDeedMaster){value: 0}(_deedDomainName("ex"))); // external-deed.ungravel.tld
      emit ExternalDeedMaster(externalDeedMaster);
    }
    function deployIntDeedMaster() external onlyDeployer payable {
      internalDeedMaster = address((new intDeedMaster){value: 0}(_deedDomainName("in"))); // internal-deed.ungravel.tld
      emit InternalDeedMaster(internalDeedMaster);
    }

    function onERC1155Received(address,address,uint256,uint256,bytes calldata) external pure returns (bytes4) { 
      return 0xf23a6e61; // this.onERC1155Received.selector;
    }
    function version() external pure returns (uint256) { 
      return 20010192;
    }
    function withdraw() external onlyDeployer payable { 
      (bool succ,) = payable(msg.sender).call{value: address(this).balance}("");
      my_require(succ,"X");
    }
    receive() external payable {
      emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Constructs a new Auction Master Contract
     */
    constructor(AbsReverseRegistrar _reverse, AbsMultiFour _multifour) payable {
      RegOwner        = msg.sender;
      registryStarted = _timeStamp();
      reverseR        = _reverse;
      tld             = _multifour.tld();

      // ENS/UUNS reverse resolver entry of address(this) ---> "auctionmaster.ungravel.eth" | "auctionmaster.ungravel.arc" | "auctionmaster.ungravel.stable"
      _reverse.setName(string(bytes.concat(bytes('auctionmaster.ungravel'),bytes(tld)))); // assigning reverse resolver record
    }
}