# web3와 Vue.js를 이용한 첫 이더리움 DApp 만들기 (1)

- ## DApp 설명

  >  저희가 구현할 DApp은 간단합니다. 유저는 1에서 10 사이의 수에 일정 금액을 베팅합니다. 만약 유저가 선택한 숫자가 당첨될 경우 보상금을 받는 심플한 Casino DApp입니다.

  <br />

  - Part.1: 프로젝트 셋업 및 스마트 컨트랙트 생성
  - Part.2: web3.js 및 Vue.js/Vuex 소개 및 싱글페이지 웹앱 구현
  - Part.3: Vue.js와 스마트 컨트랙트 연결

  <br />

- ## 필요 도구

   저희는 Remix를 이용하여 스마트 컨트랙트를 MetaMask Ropsten 테스트넷에 배포할 예정입니다.  (<https://remix.ethereum.org>) 프로젝트에 앞서 node.js와 npm은 설치되어 있다고 가정하겠습니다.

  <br />

  아래 명령어를 통해서 vue-cli를 설치합니다.

  ```
    npm i vue-cli -g
  ```

   덧붙여 스마트 컨트랙트를 테스트넷에 배포하기 위한 MetaMask가 설치되어 있어야 합니다.  MetaMask는 현재 크롬과 파이어폭스를 지원합니다. (<https://metamask.io>)

  <br />

- ## 프로젝트 셋업

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

- ## 스마트 컨트랙트 작성

  컨트랙트 작성에 앞서 알아야 할 몇 가지가 있습니다.

  1. 컨트랙트에는 소유자가 존재하며 특정한 함수(ex. 컨트랙트 파기 함수)는 소유자만이 실행 가능하도록 접근제어자를 통해서 제어할 수 있습니다.

  2. 컨트랙트의 소유자는 컨트랙트를 파기하고 컨트랙트에 묶인 돈을 되찾을 수 있습니다.

  3. 유저는 1 ~ 10 사이의 수에 베팅할 수 있습니다.

  4. 저희는 코드상에서 최소 베팅액과 베팅 수수료를 설정할 수 있으며, 컨트랙트가 배포된 이후에는 수정할 수 없습니다. (예제 코드의 단순화를 위함)

     **\* 독자분들이 Solidity에 대한 기본적인 지식을 갖추셨다고 가정하고,  Solidity 문법에 대한 자세한 설명은 하지 않겠습니다.**

     <br />

  - ### Ownable 컨트랙트와 Mortal 컨트랙트 작성

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

      <https://medium.com/blockchannel/the-use-of-revert-assert-and-require-in-solidity-and-the-new-revert-opcode-in-the-evm-1a3a7990e06e>

    - ***상금 계산 방식:*** `msg.value * (100 - houseEdge)/10` 다음 식의 결과 값이 상금이 됩니다. `msg.value`는 베팅금액이고 `houseEdge`는 베팅 수수료입니다. 상금은 컨트랙트 잔고에서 빠져나갑니다. 따라서 컨트랙트 잔고에 충분한 금액이 있어야겠죠?

    - ***checkContractBalance:*** 컨트랙트 잔고를 확인하는 함수입니다.

  <br />

- ## Remix에서 테스트해보기

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

   20 ether 씩 3번의 시도만에 이겼습니다. 잔고가 340 ether에서 520 ether가 된 모습입니다. 계산 로직상 9배의 이득을 취합니다. 20 ether면 기댓값보다 작은 값임에도 체감상으론 그렇지 않은 것 같네요. ㅎㅎ

  <br />

   고생하셨습니다. 이번 편은 여기에서 마치겠습니다. 다음 편에서는 web3와 Vue 및 Vuex를 이용하여 웹 프론트를 구성하고 MetaMask와 연동하는 작업을 해보겠습니다.

  ***\* 이 튜토리얼은 아래 참조 링크를 바탕으로 코드 상의 경고 또는 에러를 수정하여 작성되었음을 알려드립니다***

  <br />

- ## References

  - <https://itnext.io/create-your-first-ethereum-dapp-with-web3-and-vue-js-c7221af1ed82>

<br /><br />

# web3와 Vue.js를 이용한 첫 이더리움 DApp 만들기 (2)

- ## Vue.js

  Vue.js(이하 Vue)는 웹 프론트엔드 구축을 담당하는 JavaScript 기반 웹 라이브러리입니다. Vue를 사용하면 브라우저와 유저간의 동적인 인터랙션이 가능합니다. MetaMask가 브라우저에서 돌아가기 때문에 Vue 또는 React와 같은 라이브러리를 활용하여 DApp을 구축하면 매우 손쉽게 web3를 통해서 웹앱과 이더리움 클라이언트(+ test net)를 연동할 수 있습니다.

```vue
  <div id=”app”>
   {{ message }}
  </div>

  var app = new Vue({
   el: '#app',
   data: {
   message: 'Hello Vue!'
   }
  })
```

   다음 코드는 Vue의 가장 기본적인 코드 구조입니다. data 객체에 존재하는 `message` 프로퍼티는 app이라는 id와 함께 기본 HTML로 렌더링되어 화면에 표시됩니다. 만약 `message` 프로퍼티가 변경된다면 페이지 리프레싱 없이 변경된 데이터가 화면에 표시될 것입니다. 다음 jsfiddle 링크에 가시면 결과 값을 확인해 보실 수 있습니다.

  <https://jsfiddle.net/makehoney/jvwkqodt/2/>

  <br />

   또 다른 Vue의 주요 특징 중 하나는 Vue의 컴포넌트입니다. 컴포넌트는 작고 재사용이 가능한Vue 인스턴스로 생각하시면 됩니다. 실제로 웹 페이지는 다음 그림과 같이 Vue의 컴포넌트 간의 트리 구조로 추상화될 수 있습니다.

![19xltavitmhophmq634kfvg](https://user-images.githubusercontent.com/31656287/44133622-b0e2bad6-a09b-11e8-9c84-aa0c2d34a167.png)

<br />

- ## Vuex

  우리는 컴포넌트 간 공유되는 데이터, 즉 state를 관리하기 위해서 Vuex를 사용할 것입니다. Vuex를 통해서 우리는 손쉽게 데이터를 조작하고 애플리케이션에 예측 가능한 방식으로 데이터를 전달할 수 있습니다.

  Vuex가 동작하는 방식은 매우 직관적인데요. **컴포넌트**는 렌더링될 때 데이터를 필요로합니다. 해당 데이터를 얻기위해서 **컴포넌트**는 **action**을 dispatch합니다. 이후 **action**은 외부 API의 비동기 함수를 처리한 뒤 얻어진 데이터를 **mutation**에 commit합니다. 그러면 **mutation**은 해당 데이터를 이용하여 store의 state(저장되어 있는 데이터)를 새 데이터로 변경하고, 이렇게 변경된 새로운 데이터를 **컴포넌트**가 가져다 쓰는 구조입니다.

  사실 외부 API 등 비동기 처리를 통해 데이터를 얻을 필요가 없는 경우에는 action을 거칠 필요 없이 **컴포넌트** 자체적으로 **mutation**에 commit을 할 수 있습니다. 우리 앱의 경우 외부 API에 해당하는 부분이 web3입니다.

  ![vuex](https://user-images.githubusercontent.com/31656287/44134883-a23dd3f2-a0a1-11e8-9e06-c8dadcc2bd98.png)

   Vuex에 대한 자세한 설명은 아래 링크를 참조하시면 더 쉽게 이해하실 수 있습니다.

  <https://joshua1988.github.io/web-development/vuejs/vuex-getters-mutations/>

  <br />

- ## 기본 컴포넌트 작성

   우리는 Part.1에서 vue-cli를 이용하여 Vue 앱을 생성하고 거기에 필요한 의존성들을 설치했습니다. 만약 이 과정을 잘 따라오셨다면 저희 프로젝트 디렉토리 구조는 다음과 같겠습니다.

  ![1](https://user-images.githubusercontent.com/31656287/44269155-aa2d5500-a26e-11e8-8a2c-b97e7d1b4594.png)

  ***\* 처음 vue init을 할 때 ESLint를 설치할 것이냐고 물어보는데 저희는 ESLint를 사용하지 않습니다. 이유는 ESLint를 설치할 경우 엄격한 syntax 작성 규칙이 적용되기 때문입니다. 저희는 간단한 개인 프로젝트를 진행하는 것이므로 이와 같은 툴은 필요하지 않습니다.***



  - App.vue 파일의 img-tag를 제거하고 style 태그에 있는 모든 내용을 지웁니다.

  - components/HelloWorld.vue 파일을 지운뒤에 해당 디렉토리에 casino-dapp.vue와 hello-metamask.vue 파일을 생성합니다.

    - casino-dapp.vue: 메인 컴포넌트
    - hello-metamask: MetaMask 데이터를 포함하는 컴포넌트

  - hello-metamask.vue를 다음과 같이 작성합니다.

    ```vue
    <!-- components/hello-metamask.vue -->

    <template lang="html">
      <p>Hello</p>
    </template>

    <script>
      export default {
        name: 'hello-metamask'
      }
    </script>

    <style>
    </style>
    ```

  - 이제 우리는 casino-dapp 컴포넌트에서 hello-metamask 컴포넌트를 불러와야합니다. 이를 위해서 casino-dapp 컴포넌트에서 hello-metamask 컴포넌트를 import 한 뒤 자식 컴포넌트로 등록을 하면 템플릿에서 태그처럼 사용할 수 있습니다.

    ```vue
    <!-- components/casino-dapp.vue -->

    <template lang="html">
      <hello-metamask/>
    </template>

    <script>
      import HelloMetamask from './hello-metamask.vue'
      export default {
        name: 'casino-dapp',
        components: { HelloMetamask }
      }
    </script>

    <style>
    </style>
    ```

  - 이제 router/index.js 파일을 열어봅니다. 보시면 현재 하나의 라우터가 존재하고 여전히 HelloWorld.vue 컴포넌트를 가리키고 있는 모습을 볼 수 있는데요. 저희는 이 부분을 casino-dapp.vue을 가리키도록 수정할 것입니다.

    ```javascript
    /* router/index.js */

    import Vue from 'vue';
    import Router from 'vue-router';
    import CasinoDapp from '@/components/casino-dapp';

    Vue.use(Router);

    export default new Router({
      routes: [
        {
          path: '/',
          name: 'casino-dapp',
          component: CasinoDapp
        }
      ]
    });
    ```

  - 마지막으로 src 디렉토리 밑에 util이라는 새로운 폴더를 생성합니다. 그리고 util 밑에 constants라는 폴더를 생성한 뒤에 그 안에 networks.js를 생성합니다. networks.js를 다음과 같이 채워줍니다.

    ```javascript
    /* src/util/constants/networks.js */

    export const NETWORKS = {
     '1': 'Main Net',
     '2': 'Deprecated Morden test network',
     '3': 'Ropsten test network',
     '4': 'Rinkeby test network',
     '42': 'Kovan test network',
     '4447': 'Truffle Develop Network',
     '5777': 'Ganache Blockchain'
    }
    ```

    이 코드는 저희 이더리움 네트워크의 'id'를 대신하여 '이름'을 표시해 줄 것입니다.

  - 마지막으로 src 밑에 store라는 폴더를 생성해줍니다. 이 부분은 바로 다음 주제에서 다루겠습니다!

    여기까지 오셨다면 root directory에서 'npm start'를 입력하여 서버를 켤 수 있습니다. 브라우저에 Hello라는 메시지가 나온다면 다음 단계를 진행하셔도 좋습니다!

<br />

- ## Vuex store 세팅하기

  - 이번 주제에서는 Vuex의 store를 세팅해보겠습니다.

  - 일단 store안에 index.js와 state.js를 생성한 뒤에 state.js를 다음과 같이 작성합니다.

    ```javascript
    /* store/state.js */

    let state = {
      web3: {
        isInjected: false,
        web3Instance: null,
        networkId: null,
        coinbase: null,
        balance: null,
        error: null
      },
      contractInstance: null
    };

    export default state;
    ```



  - 다음으로 index.js를 다음과 같이 작성합니다. Vuex 라이브러리와 Vue를 사용하기 위해서 import하고 state(데이터)를 역시 사용해야하므로 import해줍니다.

    ```javascript
    /* store/index.js */

    import Vue from 'vue';
    import Vuex from 'vuex';
    import state from './state';

    Vue.use(Vuex);

    export const store = new Vuex.Store({
     strict: true,
     state,
     mutations: {},
     actions: {}
    });
    ```

  - 마지막으로 main.js에서 store를 import해 줍니다. 다음과 같이 폴더자체를 import시키면 Vuex에 의해서 안의 index.js가 자동으로 import됩니다.

    ```javascript
    /* src/main.js */

    import Vue from 'vue';
    import App from './App';
    import router from './router';
    import { store } from './store';

    Vue.config.productionTip = false;

    /* eslint-disable no-new */
    new Vue({
      el: '#app',
      router,
      store,
      components: { App },
      template: '<App/>'
    });
    ```

<br />

- ## web3와 Metamask 연동

   앞서 설명드린바와 같이 우리 Vue 앱에서 사용할 데이터를 web3로부터 얻어 오려면 비동기 API 콜을 실행시켜줄 action을 dispatch해야 합니다. 먼저, util 밑에 getWeb3.js 파일을 생성한 뒤에 다음과 같이 작성해 줍니다.

  ```javascript
  /* util/getWeb3.js */

  import Web3 from 'web3';

  let getWeb3 = new Promise((resolve, reject) => {
    var web3js = window.web3;
    if(typeof web3js !== 'undefined') {
      let web3 = new Web3(web3js.currentProvider);
      resolve({
        injectedWeb3: web3.isConnected(),
        web3 () {
          return web3;
        }
      });
    } else {
      reject(new Error('Unable to connect to Metamask'));
    }
  }).then(result => {
    return new Promise((resolve, reject) => {
      result.web3().version.getNetwork((err, networkId) => {
        if(err) {
          reject(new Error('Unable to retrieve network ID'));
        } else {
          result = Object.assign({}, result, { networkId });
          resolve(result);
        }
      });
    });
  }).then(result => {
    return new Promise((resolve, reject) => {
      result.web3().eth.getCoinbase((err, coinbase) => {
        if(err) {
          reject(new Error('Unable to retrieve coinbase'));
        } else {
          result = Object.assign({}, result, { coinbase });
          resolve(result);
        }
      });
    });
  }).then(result => {
    return new Promise((resolve, reject) => {
      result.web3().eth.getBalance(result.coinbase, (err, balance) => {
        if(err) {
          reject(new Error(`Unable to retrieve balance for addres: ${result.coinbase}`))
        } else {
          result = Object.assign({}, result, { balance });
          resolve(result);
        }
      });
    });
  });

  export default getWeb3;
  ```

   MetaMask는 브라우저 상에서 자신의 web3 인스턴스를 지니고 있습니다. 따라서 우리는 첫번째 분기문을 통해서 window.web3(브라우저 상의 web3 인스턴스)가 undefined 인지 확인합니다. 만약 undefined가 아니라면 web3 인스턴스를 currentProvider로 생성합니다. 구조를 보시면 아시겠지만 다음 Promise에서 이전의 web3 인스턴스가 포함된 객체를 전달받으며 비동기 API 콜을 실행하고 결과에 따라서 객체에 멤버를 추가해 나갑니다.

  - web3.version.getNetwork()는 현재 연결된 네트워크 ID를 반환합니다.
  - web3.eth.coinbase()는 현재 채굴중인 노드의 주소를 반환합니다. 메타마스크 사용시에는 선택된 계좌 주소에 해당됩니다.
  - web3.eth.getBalance(addr)는 인자로 전달된 주소의 잔액을 반환합니다.

   앞서 설명드린 비동기 API 콜이 일어난 뒤로 해당 결과 값이 Vuex store를 통해서 state에 저장되기 까지의 과정을 기억하실 겁니다. 이제 이 부분을 연결할건데요. 먼저 store/index.js 에서 getWeb3.js 파일을 import해준뒤 action단에서 mutation에 commit하게 되면 mutation이 store에 데이터를 저장시켜 줄 것입니다.

  ```javascript
  /* store/index.js */

  import getWeb3 from '../util/getWeb3';
  ```

   다음으로 action 객체에서 getWeb3를 불러온 뒤 해당 결과 값을 mutation에 commit하겠습니다. 또한 일련의 과정을 확인하기 쉽도록 console.log도 중간중간 삽입하겠습니다.

  ```javascript
  /* store/index.js */

   actions: {
     async registerWeb3 ({ commit }) {
       console.log('registerWeb3 Action being executed');
       try {
         let result = await getWeb3;
         console.log('registerWeb3Instance', result);
         commit('registerWeb3Instance', result);
       } catch (err) {
         console.log('error in action registerWeb3', err);
       }
     }
   }
  ```

   다음으로 우리의 데이터를 state에 저장시켜줄 mutation 객체를 채워넣겠습니다. 저희가 action에서 commit한 데이터는 두번째 인자인 payload를 통해서 접근할 수 있습니다.

  ```javascript
  /* store/index.js */

  mutations: {
     registerWeb3Insctance (state, payload) {
       console.log('registerWeb3instance Mutation being executed', payload);
       let result = payload;
       let web3Copy = state.web3;
       web3Copy.coinbase = result.coinbase;
       web3Copy.networkId = result.networkId;
       web3Copy.balance = parseInt(result.balance, 10);
       web3Copy.isInjected = result.injectedWeb3;
       web3Copy.web3Instance = result.web3;
       state.web3 = web3Copy;
     }
   }
  ```

   이제는 컴포넌트 단에서 위 요소를 실행 가능하도록 해줘야 합니다. 이를 위해서 casino-dapp 컴포넌트가 생성되기 이전에 이를 실행할 수 있도록 아래와 같이 코드를 작성해 줍니다. 뷰 인스턴스의 라이프 사이클에 대해서 잘 모르시는 분들은 [여기](https://kr.vuejs.org/v2/guide/instance.html#%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4-%EB%9D%BC%EC%9D%B4%ED%94%84%EC%82%AC%EC%9D%B4%ED%81%B4-%ED%9B%85)에서 공식 문서를 보실 수 있습니다.

  ```vue
  <!-- casino-dapp.vue -->

  export default {
    name: 'casino-dapp',
    beforeCreate () {
      console.log('registerWeb3 Action dispatched from casino-dapp.vue')
      this.$store.dispatch('registerWeb3')
    },
    components: {
      'hello-metamask': HelloMetamask
    }
  }
  ```

   자 이제 마지막으로 수정된 데이터가 렌더링되어 브라우저를 통해 보여질 수 있도록 hello-MetaMask 컴포넌트의 템플릿과 스크립트를 아래와 같이 수정해 줍니다.

  ```vue
  <!-- hello-metamask.vue -->

  <template>
   <div class='metamask-info'>
     <p>Metamask: {{ web3.isInjected }}</p>
     <p>Network: {{ web3.networkId }}</p>
     <p>Account: {{ web3.coinbase }}</p>
     <p>Balance: {{ web3.balance }}</p>
   </div>
  </template>

  <script>
  export default {
   name: 'hello-metamask',
   computed: {
     web3 () {
       return this.$store.state.web3
       }
     }
  }
  </script>

  <style scoped></style>
  ```

   이로써 저희는 브라우저 상의 MetaMask와 저희 Vue 앱을 연동하는 과정까지 해보았습니다. 만약 성공적으로 따라오셨다면 터미널에 npm start를 입력한 뒤 localhost:8080에 접속해보시면 아래와 같은 화면을 보실 수 있으실 겁니다.

  ![5](https://user-images.githubusercontent.com/31656287/44309823-6d489600-a407-11e8-8d8c-8676e6831014.png)

   Vuex의 개념을 처음 접하신 분들도 있으실 것이기에 Part.2의 부분이 전체 파트 중에서 가장 어렵다고도 볼 수 있는 부분입니다. 다음 파트에서는 저희가 앞서 작성한 스마트 컨트랙트를 Vue 앱에 올리고 앱의 간단한 UI 작업을 하는 것으로 마무리하겠습니다. 고생하셨습니다.

  <br />

  ***\* 이 튜토리얼은 아래 참조 링크를 바탕으로 코드 상의 경고 또는 에러를 수정하여 작성되었음을 알려드립니다***

- ## References

  - <https://itnext.io/create-your-first-ethereum-dapp-with-web3-and-vue-js-part-2-52248a74d58a>

<br />

# web3와 Vue.js를 이용한 첫 이더리움 DApp 만들기 (3)

- ## 데이터 폴링

  데이터 폴링: <https://ko.wikipedia.org/wiki/%ED%8F%B4%EB%A7%81_(%EC%BB%B4%ED%93%A8%ED%84%B0_%EA%B3%BC%ED%95%99)>

  <br />

   지금까지의 저희 앱은 MetaMask로부터 데이터를 불러와 브라우저에 표시를 할 수 있습니다.  하지만 유저가 MetaMask의 계정을 변경하는 경우, 저희 앱은 자동으로 변경된 데이터를 로드하지 않고 페이지를 리프레시해야 변경된 데이터가 화면에 표시됩니다. 저희 앱이 reactive하지 못하다고 할 수 있는 부분입니다. 따라서 이부분을 구현해보겠습니다.

   현재 MetaMask는 웹소켓을 지원하지 않으므로 저희가 interval을 설정하여 데이터를 폴링하는 방식으로 구현을 해나갈 생각입니다. 먼저 util 아래에 pollWeb3.js 파일을 생성합니다.

  - MetaMask 인스턴스에 의존하지 않기 위해서 Web3를 import해줍니다.
  - 우리의 store를 import해줍니다. 이를 통해 저희는 값을 비교하고 mutation에 commit할 수 있습니다.
  - web3 인스턴스를 생성합니다.
  - 계정이 변경되었는지 매번 확인할 interval을 세팅합니다. 계정이 바뀐 것이 아니라면 잔액을 비교하여 잔액 변화도 반영할 수 있도록 합니다.
  - 현재 hello-metamask 컴포넌트가 computed 프로퍼티로 web3를 가지고 있으므로 위 과정에 의한 데이터 변경은 즉각적으로 반영될 것입니다. (reactive)

  ```javascript
  /* util/pollWeb3.js */

  import Web3 from 'web3';
  import { store } from '../store';

  let pollWeb3 = state => {
    let web3 = window.web3;
    web3 = new Web3(web3.currentProvider);

    setInterval(() => {
      if(web3 && store.state.web3.web3Instance) {
        if(web3.eth.coinbase !== store.state.web3.coinbase) {
          let newCoinbase = web3.eth.coinbase;
          web3.eth.getBalance(newCoinbase, (err, newBalance) => {
            if (err) {
              console.log(err);
            } else {
              store.commit('pollWeb3Instance', {
                coinbase: newCoinbase,
                balance: parseInt(newBalance, 10)
              });
            }
          });
        } else {
          web3.eth.getBalance(store.state.web3.coinbase, (err, polledBalance) => {
            if (err) {
              console.log(err);
            } else if (parseInt(polledBalance, 10) !== store.state.web3.balance) {
              store.commit('pollWeb3Instance', {
                coinbase: store.state.web3.coinbase,
                balance: polledBalance
              });
            }
          });
        }
      }
    }, 500);
  }

  export default pollWeb3;
  ```

   이제 우리는 web3Instance가 등록되면 데이터 폴링을 시작하도록 해야합니다. web3Instance 등록은 casino-dapp 컴포넌트의 beforeCreate 단계에서 실행됩니다. (Part.2) 따라서 store/index.js에서 pollWeb3.js를 import한 뒤에 mutation 맨 마지막 라인에 pollWeb3()를 실행하여 web3Instance가 등록되면 백그라운드에서 pollWeb3함수가 돌도록 만들어 줍니다.

  ```javascript
  /* store/index.js */

  mutations: {
     registerWeb3Instance (state, payload) {
       console.log('registerWeb3instance Mutation being executed', payload);
       let result = payload;
       let web3Copy = state.web3;
       web3Copy.coinbase = result.coinbase;
       web3Copy.networkId = result.networkId;
       web3Copy.balance = parseInt(result.balance, 10);
       web3Copy.isInjected = result.injectedWeb3;
       web3Copy.web3Instance = result.web3;
       state.web3 = web3Copy;
       /* 추가 */
       pollWeb3();
     }
  ```

   또한 pollWeb3 함수에서 commit의 대상이 되는 pollWeb3Instance 함수를 mutation에 등록해줍니다.

  ```javascript
  pollWeb3Instance(state, payload) {
      console.log('pollWeb3Instance mutation being executed', payload);
      state.web3.coinbase = payload.coinbase;
      state.web3.balance = parseInt(payload.balance, 10);
  }
  ```

   여기까지 마치셨으면 이제 저희 앱은 잔액의 변화 또는 계정의 변화를 즉각적으로 반영하여 화면에 표시해 줄겁니다.

<br />



- ## 스마트 컨트랙트 초기화하기

   이번 과정에서는 먼저 컨트랙트 초기화의 뼈대가 되는 코드를 작성한 뒤에 스마트 컨트랙트를 배포하고 ABI와 address 값을 저희 앱에 넣을 것입니다.

  - 유저가 베팅할 금액을 써 넣을 input field가 필요합니다.
  - 유저가 베팅할 번호를 선택할 수 있는 버튼이 필요합니다.
  - on click 함수는 컨트랙트의 bet() 함수를 호출해야합니다.
  - 트랜잭션 중(완료되지 않음)임을 표시해주는 로딩 스피너가 필요합니다.
  - 트랜잭션이 완료됐을 때 게임의 결과를 표시해줘야 합니다.

   먼저 우리 앱과 컨트랙트를 연결해주는 작업이 필요합니다. util 아래에 getContract.js를 생성하여 아래와 같이 작성해 줍니다.

  ```javascript
  /* util/getContract.js */

  import Web3 from 'web3';
  import { address, ABI } from './constants/casinoContract';

  let getContract = new Promise((resolve, reject) => {
    let web3 = new Web3(window.web3.currentProvider);
    let casinoContract = web3.eth.contract(ABI);
    let casinoContractInstance = casinoContract.at(address);
    resolve(casinoContractInstance);
  });

  export default getContract;
  ```

   우선 주목할 부분은 두번째라인의 import하는 파일이 현재는 존재하지 않는다는 점입니다. casinoContract파일은 컨트랙트를 remix를 통해 배포한 뒤에 작성하도록 하겠습니다.

   다음으로 casino-component.vue 파일을 아래와 같이 작성해줍니다. 아래 코드는 아시겠지만 dispatch의 대상이 되는 action과 commit의 대상인 mutation이 없으면 불완전한 코드입니다.

  ```vue
  <!-- casino-component.vue -->

  export default {
   name: ‘casino’,
   mounted () {
   console.log(‘dispatching getContractInstance’)
   this.$store.dispatch(‘getContractInstance’)
   }
  }
  ```

   이제 store/index.js에서 getContract를 import한 뒤에 여기에 상응하는 action과 mutation을 작성하겠습니다.

  ```javascript
  /* action */

  async getContractInstance({ commit }) {
    try {
      let result = await getContract;
      commit('registerContractInstance', result);
    } catch (err) {
      console.log('error in action getContractInstance', err);
    }
  }
  ```

  ```javascript
  /* mutation */

  registerContractInstance(state, payload) {
    console.log('Casino contract instance: ', payload);
    state.contractInstance = () => payload;
  }
  ```

   이 작업을 통해서 우리의 컨트랙트 인스턴스가 컴포넌트로부터 store의 state에 저장될 것입니다.

  <br />

- ## 스마트 컨트랙트와 상호작용하기

   스마트 컨트랙트와의 상호작용을 위해서는 먼저 브라우저 상에서 보여질 템플릿을 작성한 뒤에 템플릿에 상응하는 data와 methods 프로퍼티를 추가해야 합니다.

  ```vue
  <!-- casino-component.vue -->

  data () {
     return {
       amount: null,
       pending: false,
       winEvent: null
     }
   }
  ```

   다음으로 숫자가 클릭되었을 때 컨트랙트의 bet() 함수를 트리거해주는 함수를 methods 프로퍼티에 추가해줍니다.

  ```vue
  <!-- casino-component -->

  methods: {
    clickNumber (event) {
      console.log(event.target.innerHTML, this.amount)
      this.winEvent = null
      this.pending = true
      this.$store.state.contractInstance().bet(event.target.innerHTML, {
        gas: 300000,
        value: this.$store.state.web3.web3Instance().toWei(this.amount, 'ether'),
        from: this.$store.state.web3.coinbase
      }, (err, result) => {
        if (err) {
          console.log(err)
          this.pending = false
        } else {
          let bettingResult = this.$store.state.contractInstance().bettingResult()
          /* .watch => solidity event를 감시 */
          bettingResult.watch((err, result) => {
            if (err) {
              console.log('could not get event Won()')
            } else {
              this.winEvent = result.args
              this.winEvent.rewards = parseInt(result.args.rewards, 10)
              console.log(`winEvent: ${result.args}`)
              this.pending = false
            }
          });
        }
      });
    }
  }
  ```

   bet() 함수의 첫번째 파라미터인 event.tartget.innerHTML은 템플릿의 li 태그 내부 값(숫자 1-10)을 가리킵니다. 그 다음 파라미터는 트랜잭션 파라미터로서 가스, 유저가 거는 금액 및 베팅하는 사람의 address 등을 받고, 마지막 파라미터는 bet() 함수의 콜백으로 동작합니다. watch 메소드는 컨트랙트 코드 상에서의 event를 감시하는 감시자입니다.

   다음은 템플릿 및 스타일 코드입니다. casino-component의 템플릿과 스타일 시트에 그대로 작성합니다.

  ```vue
  <!-- casino-component.vue -->

  <template>
   <div class="casino">
     <h1>Welcome to the Casino</h1>
     <h4>Please pick a number between 1 and 10</h4>
     Amount to bet: <input v-model="amount" placeholder="0 Ether">
     <ul>
       <li v-on:click='clickNumber'>1</li>
       <li v-on:click='clickNumber'>2</li>
       <li v-on:click='clickNumber'>3</li>
       <li v-on:click='clickNumber'>4</li>
       <li v-on:click='clickNumber'>5</li>
       <li v-on:click='clickNumber'>6</li>
       <li v-on:click='clickNumber'>7</li>
       <li v-on:click='clickNumber'>8</li>
       <li v-on:click='clickNumber'>9</li>
       <li v-on:click='clickNumber'>10</li>
    </ul>
    <img v-if="pending" id="loader" src="https://loading.io/spinners/double-ring/lg.double-ring-spinner.gif">
    <div class="event" v-if="winEvent">
      <p>Won: {{ winEvent.userWin }}</p>
      <p>Winning Number: {{ winEvent.winningNumber }}</p>
      <p>Amount: {{ winEvent.rewards }} Wei</p>
    </div>
    <div class="event" v-if="winEvent">
     <p v-if="winEvent.userWin" id="has-won"><i aria-hidden="true" class="fa fa-check"></i> Congragulations, you have won {{winEvent.rewards}} wei</p>
     <p v-else id="has-lost"><i aria-hidden="true" class="fa fa-check"></i> Sorry you lost, please try again.</p>
    </div>
   </div>
  </template>

  <style scoped>
  .casino {
   margin-top: 50px;
   text-align:center;
  }
  #loader {
   width:150px;
  }
  ul {
   margin: 25px;
   list-style-type: none;
   display: grid;
   grid-template-columns: repeat(5, 1fr);
   grid-column-gap:25px;
   grid-row-gap:25px;
  }
  li{
   padding: 20px;
   margin-right: 5px;
   border-radius: 50%;
   cursor: pointer;
   background-color:#fff;
   border: -2px solid #bf0d9b;
   color: #bf0d9b;
   box-shadow:3px 5px #bf0d9b;
  }
  li:hover{
   background-color:#bf0d9b;
   color:white;
   box-shadow:0px 0px #bf0d9b;
  }
  li:active{
   opacity: 0.7;
  }
  *{
   color: #444444;
  }
  #has-won {
    color: green;
  }
  #has-lost {
    color:red;
  }
  </style>
  ```

  <br />

- ## Ropsten 테스트넷에 컨트랙트 배포하기

   Ropsten 테스트넷에 컨트랙트를 배포하기 위해서는 Part.1의 과정에서 environment를 javascriptVM로 설정했던 것을 injected Web3로 설정한 뒤에 동일하게 배포를 하시면 됩니다.

   배포를 성공적으로 마치면 remix 콘솔창에 EtherScan의 링크가 나올 것이고 들어가면 다음과 같이 컨트랙트 배포가 된 것을 확인해 보실 수 있습니다.

  ![3](https://user-images.githubusercontent.com/31656287/44467547-18528d00-a65e-11e8-8ed6-8fd90e110169.png)

   다음으로 Remix의 Compile 탭의 Detail 버튼을 누르면 ABI를 알아낼 수 있습니다.

  ![1](https://user-images.githubusercontent.com/31656287/44467841-dece5180-a65e-11e8-8eb1-f44b6b225667.png)

   그 다음 Run 탭의 Deployed Contracts에서 배포된 컨트랙트의 address를 알 수 있습니다.

  ![2](https://user-images.githubusercontent.com/31656287/44467843-e0981500-a65e-11e8-80ba-bfda109f35c0.png)



   마지막으로 이렇게 알아낸 정보들을 util/constants 아래에 casinoContract.js를 생성하여 다음과 같이 작성하면 마침내 저희 DApp이 완성됩니다!

  ```
  const address = ‘0x…………..’
  const ABI = […]
  export {address, ABI}
  ```

  <br />

- ## 프론트엔드

   이번 주제는 필수적인 부분이 아닙니다. 위 과정에서 만족하셨으면 넘어가셔도 무방합니다!

  여기서는 hello-metamask 컴포넌트를 수정할 계획입니다. 먼저 Vuex의 mapState 헬퍼를 시용하여 템플릿에 분기문을 작성하고 HTML이 그에 따라 다르게 렌더링되도록 할 것입니다.

   이에 앞서 아이콘 사용을 위해서 main.js에서 다음과 같이 css를 import해줍니다.

  ```javascript
  /* main.js */

  import 'font-awesome/css/font-awesome.css'
  ```



   최종 hello-metamask.vue의 코드는 다음과 같습니다.

  ```vue
  <!-- hello-metamask.vue -->

  <template lang="html">
    <div class='metamask-info'>
      <p v-if="isInjected" id="has-metamask"><i aria-hidden="true" class="fa fa-check"></i> Metamask installed</p>
      <p v-else id="no-metamask"><i aria-hidden="true" class="fa fa-times"></i> Metamask not found</p>
      <p>Network: {{ network }}</p>
      <p>Account: {{ coinbase }}</p>
      <p>Balance: {{ balance }} Wei </p>
    </div>
  </template>

  <script>
    import {NETWORKS} from '../util/constants/networks'
    import {mapState} from 'vuex'
    export default {
      name: 'hello-metamask',
      computed: mapState({
        isInjected: state => state.web3.isInjected,
        network: state => NETWORKS[state.web3.networkId],
        coinbase: state => state.web3.coinbase,
        balance: state => state.web3.balance
      })
    }
  </script>

  <style scoped>
  #has-metamask {
    color: green;
  }
  #no-metamask {
    color:red;
  }</style>
  ```

  <br />

- ## 마무리

   여기까지 잘 따라오셨다면 터미널에서 앱을 실행 시킨 뒤에 localhost:8080으로 접속하시어 베팅을 해보시면 아래와 같은 결과를 보실 수 있으실 겁니다.

   ![1](https://user-images.githubusercontent.com/31656287/44472583-6d47d080-a669-11e8-9954-84862a9e507d.png)


  고생하셨습니다!

   <br />

    ***\* 이 튜토리얼은 아래 참조 링크를 바탕으로 코드 상의 경고 또는 에러를 수정하여 작성되었음을 알려드립니다***

- ## References

  - <https://itnext.io/create-your-first-ethereum-dapp-with-web3-and-vue-js-part-3-dc4f82fba4b4>
