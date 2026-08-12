// SPDX-License-Identifier: UNLICENSED
// Decompiled by luna. See luna.preventive.dev

pragma solidity 0.4.26;

interface IERC20 {
  function transfer(address _to, uint256 _value) external;
}

contract CircleDeposit1 {
  constructor(address _owner) public {
    owner = msg.sender;
    owner = _owner; // 0x55FE002aefF02F77364de339a1292923A15844B8
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  address public owner;

  event Deposit(address indexed sender, address indexed owner, uint256 value);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function transferToOwner(IERC20 _token, uint256 _amount) external onlyOwner {
    _token.transfer(owner, _amount);
  }

  function contractCall(address _target, bytes _data) public payable onlyOwner {
    require(address(_target).call.value(msg.value)(_data));
  }

  function transferOwnership(address _newOwner) external onlyOwner {
    _transferOwnership(_newOwner);
  }

  function() external payable {
    if (address(owner).call.value(msg.value)()) {
      emit Deposit(msg.sender, owner, msg.value);
    } else {
      revert();
    }
  }

  function _transferOwnership(address _newOwner) internal {
    require(_newOwner != 0);
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}