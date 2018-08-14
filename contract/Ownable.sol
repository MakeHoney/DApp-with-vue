pragma solidity ^0.4.10;

contract Ownable {
  address owner;
  constructor() public payable {
    owner = msg.sender;
  }

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }
}
