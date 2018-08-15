pragma solidity ^0.4.10;

contract Ownable {
  address owner;
  constructor() public payable {
    owner = msg.sender;
  }

  /* 접근 제어자 선언 */
  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }
}
