pragma solidity ^0.4.10;

import "./Mortal.sol";

contract Casino is Mortal{
  /* minBet: 최소 베팅액 (단위: Wei), houseEdge: 베팅 수수료 */
  uint minBet;
  uint houseEdge;

  /* 베팅 결과를 로그에 남기기 위한 코드 */
  event bettingResult(bool userWin, uint rewards, uint winningNumber, uint bettingNumber);

  /* 생성자 */
  constructor(uint _minBet, uint _houseEdge) payable public {
    /* 최소 베팅액이 0보다 크고 수수료가 100wei 이하일 때 */
    require(_minBet > 0);
    require(_houseEdge <= 100);

    /* 컨트랙트 변수를 초기화 */
    minBet = _minBet;
    houseEdge = _houseEdge;
  }

  /* 베팅 함수 */
  function bet(uint _number) payable public {
    /* 베팅넘버가 1 ~ 10 사이고 베팅액이 최소 베팅액 이상일 때 */
    require(_number > 0 && _number <= 10);
    require(msg.value >= minBet);

    // uint winningNumber = block.number % 10 + 1;
    uint winningNumber = 3;
    if (_number == winningNumber) {
      /* 상금 계산식 */
      uint amountWon = msg.value * (100 - houseEdge)/10;
      /* Win! => 베팅한 사람에게 상금을 송금 */
      if(!msg.sender.send(amountWon)) revert();
      /* event 전달 */
      emit bettingResult(true, amountWon, winningNumber, _number);
    } else {
      /* Lose! => 컨트랙트 계좌에 베팅액이 묶임 */
      /* event 전달 */
      emit bettingResult(false, 0, winningNumber, _number);
    }
  }

  /* 컨트랙트 계좌 잔액 확인 함수 */
  function checkContractBalance() onlyOwner public view returns(uint) {
      address _contract = this;
      return _contract.balance;
  }

  /* fallback 함수 */
  function() payable public {
    revert();
  }
}
