## web3와 Vue.js를 이용한 첫 이더리움 DApp 만들기 (1)

- ### DApp 설명

  >  저희가 구현할 DApp은 간단합니다. 유저는 1에서 10 사이의 수에 일정 금액을 베팅합니다. 만약 유저가 선택한 숫자가 당첨될 경우 베팅 금액의 10배를 받는 심플한 Casino DApp입니다.

  <br />

  - Part.1: 프로젝트 셋업 및 스마트 컨트랙트 생성
  - Part.2: web3.js 및 Vue.js/Vuex 소개 및 싱글페이지 웹앱 구현
  - Part.3: Vue.js와 스마트 컨트랙트 연결

  <br />

- ### 필요 도구

   저희는 Remix를 이용하여 스마트 컨트랙트를 MetaMask Ropsten 테스트넷에 배포할 예정입니다.  (https://remix.ethereum.org) 프로젝트에 앞서 node.js와 npm은 설치되어 있다고 가정하겠습니다.

  <br />

  아래 명령어를 통해서 vue-cli를 설치합니다.

  ```
    npm i vue-cli -g
  ```

   덧붙여 스마트 컨트랙트를 테스트넷에 배포하기 위한 MetaMask가 설치되어 있어야 합니다.  MetaMask는 현재 크롬과 파이어폭스를 지원합니다. (https://metamask.io)

  <br />

- ### 프로젝트 셋업

   저희가 구현할 프론트엔드 애플리케이션과 MetaMask의 테스트넷을 연결하기 위해서는 스마트 컨트랙트 address와 ABI가 필요합니다. 또한 MetaMask는 브라우저 상에서 돌아가기 때문에 web3와 Vue.js를 이용하면 프론트엔드 상에서도 충분한 상호작용이 가능합니다.

  <br />

  1. 터미널을 열고 프로젝트를 생성할 디렉토리로 이동합니다.
  2. 터미널 창에 아래 명령어를 입력하여 vue 프로젝트를 생성합니다.

  ```
  vue init webpack betting-dapp
  ```

  1. 해당 디렉토리로 이동하여 web3, vuex font-awesome npm을 설치합니다.

  ```
  cd betting-dapp
  npm install web3@^0.20.0 vuex font-awesome
  ```

  > MetaMask와의 호환성 문제로 web3 1.0.0 beta 버전은 사용하지 않습니다.

<br />

- ### 스마트 컨트랙트 작성

  컨트랙트 작성에 앞서 알아야 할 몇 가지가 있습니다.

  1. 컨트랙트에는 소유자가 존재하며 특정한 함수(ex. 컨트랙트 파기 함수)는 소유자만이 실행 가능하도록 접근제어자를 통해서 제어할 수 있습니다.

  2. 컨트랙트의 소유자는 컨트랙트를 파기하고 컨트랙트에 묶인 돈을 되찾을 수 있습니다.

  3. 유저는 1 ~ 10 사이의 수에 베팅할 수 있습니다.

  4. 저희는 코드상에서 최소 베팅액과 베팅 수수료를 설정할 수 있으며, 컨트랙트가 배포된 이후에는 수정할 수 없습니다. (예제 코드의 단순화를 위함)

     **\* 독자분들이 Solidity에 대한 기본적인 지식을 갖추셨다고 가정하고,  Solidity 문법에 대한 자세한 설명은 하지 않겠습니다.**

     <br />

  - #### Ownable 컨트랙트와 Mortal 컨트랙트 작성

    ```solidity
    /* Ownable.sol */

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
    ```

     Ownable 컨트랙트는 onlyOwner라는 접근제어자를 제공합니다. 이 제어자가 붙은 함수는 컨트랙트의 소유자만이 실행시킬 수 있는 함수가 됩니다.

    <br />

    ```solidity
    /* Mortal.sol */

    pragma solidity ^0.4.10;

    import "./Ownable.sol";

    contract Mortal is Ownable {
      function kill() public onlyOwner {
        selfdestruct(owner);
      }
    }
    ```

     보시다시피 Mortal 컨트랙트는 Ownable 컨트랙트를 상속하고 있습니다. 따라서 kill 함수에 onlyOwner 접근제어자를 사용할 수 있게되었습니다. 이에 따라 kill 함수는 컨트랙트 소유자만이 실행할 수 있는 함수가 되었습니다.

     참고로 kill 함수가 wrapping 중인 selfdestruct는 컨트랙트를 파기하는 함수로서 인자로 받은 주소에 컨트랙트에 묶인 모든 이더를 송금한 뒤에 컨트랙트를 파기합니다.

    <br />

  - ### Casino 컨트랙트 작성

    ```solidity
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

        uint winningNumber = block.timestamp % 10 + 1;

        if (_number == winningNumber) {
          /* 상금 계산식 */
          uint amountWon = msg.value * (100 - houseEdge)/10;
          /* Win! => 베팅한 사람에게 상금을 송금 */
          if(!msg.sender.send(amountWon)) revert('sending ether failed.');
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
        revert('something bad happened!');
      }
    }
    ```

    - ***event, emit:*** event는 Javascript의 이벤트 리스너 + console.log() 라고 생각하시면 편합니다. 현재 bet 함수 블록 내의 emit에 인자를 전달하여 실행하는데 이는 event로 전달되고 event가 실행되어 로그에 전달 인자들을 띄워줍니다.

    - ***fallback 함수:*** fallback 함수는 존재하지 않는 함수가 실행되거나, 필요한 데이터 없이 함수가 실행될 때, 또는 데이터 없이 컨트랙트가 이더를 받은 상황 (이를 plain ether를 받았다고 합니다.)등 에 실행되는 함수입니다. 따라서 이런 상황에 대처할 수 있도록 fallback 함수 내부에 로직을 구현합니다. 이번 예제의 경우 revert 함수를 실행되게끔 하였습니다. revert에 대한 자세한 내용은 다음 링크를 참조해주세요.

      https://medium.com/blockchannel/the-use-of-revert-assert-and-require-in-solidity-and-the-new-revert-opcode-in-the-evm-1a3a7990e06e

    - ***상금 계산 방식:*** `msg.value * (100 - houseEdge)/10` 다음 식의 결과 값이 상금이 됩니다. `msg.value`는 베팅금액이고 `houseEdge`는 베팅 수수료입니다. 상금은 컨트랙트 잔고에서 빠져나갑니다. 따라서 컨트랙트 잔고에 충분한 금액이 있어야겠죠?

    - ***checkContractBalance:*** 컨트랙트 잔고를 확인하는 함수입니다.

  <br />

- ### Remix에서 테스트해보기

  ![1](https://user-images.githubusercontent.com/31656287/44123700-8614eaae-a064-11e8-87e9-5a29a7ec9248.png)

   위 코드를 컴파일한 모습입니다. 정상적으로 컴파일되었습니다.

  <br />

  ![2](https://user-images.githubusercontent.com/31656287/44123744-ba184f6c-a064-11e8-97d1-6d2d59080a26.png)

   Run 탭으로 이동합니다. Environment를 JavaScript VM으로 설정한 뒤에, Gas limit을 적고 Value에는 500 'ether'를 넣습니다. Value에 들어가는 값은 컨트랙트 잔고에 들어갑니다. 이 금액은 이후 당첨된 유저에게 상금을 지급할 때 사용되죠. Deploy 칸에는 생성자에 들어가는 파라미터를 적습니다. (최소 베팅액과 베팅 수수료)

  <br />

  ![3](https://user-images.githubusercontent.com/31656287/44123857-2f90c008-a065-11e8-8aed-dd397ffa87b1.png)

   정상적으로 컨트랙트가 배포되었고 checkContractBalance를 통해서 잔고를 확인하였습니다. 컨트랙트 잔고에 500 ether가 있음을 확인할 수 있습니다. (Wei 단위로) 저의 JavaScript VM 계정에는 현재 400 ether가 존재합니다.

  <br />

  ![4](https://user-images.githubusercontent.com/31656287/44123888-5c51a92c-a065-11e8-89a9-c9a92963e076.png)

  20 ether를 3번 숫자에 걸고 베팅을 해봤습니다.

  <br />

  ![5](https://user-images.githubusercontent.com/31656287/44123913-772b2228-a065-11e8-9079-1b7662ffdcaa.png)

   보기 좋게 패배했습니다. 여기서 주목할 부분은 아래 로그를 보시면 현재 event의 인자들이 표시된다는 점입니다. 이를 통해서 위닝넘버는 몇이었고 승패여부와 이에 따른 보상액을 확인할 수 있습니다.

  <br />

  ![6](https://user-images.githubusercontent.com/31656287/44124043-24e0a6d6-a066-11e8-847d-5020eb599dd4.png)

   20 ether 씩 3번의 시도만에 이겼습니다. 잔고가 340 ether에서 520 ether가 된 모습입니다. 계산 로직상 9배의 이득을 취합니다. 20 ether면 기댓값보다 작은 값임에도 체감상으론 그렇지 않은 것 같습니다. ㅋㅋ

  <br />

   고생하셨습니다. 이번 편은 여기에서 마치겠습니다. 다음 편에서는 web3와 Vue 및 Vuex를 이용하여 웹 프론트를 구성하고 MetaMask와 연동하는 작업을 해보겠습니다.

   프로젝트 전체 코드는 다음 링크를 가시면 보실 수 있습니다. <https://github.com/MakeHoney/DApp_with_vue>

  ***\*이 튜토리얼은 아래 참조 링크를 바탕으로 코드 상의 경고 또는 에러를 수정하여 작성되었음을 알려드립니다***

  <br />

- ### References

  - <https://itnext.io/create-your-first-ethereum-dapp-with-web3-and-vue-js-c7221af1ed82>
