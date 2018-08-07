import Web3 from 'web3';

/*
* 1. Check for injected web3 (mist/metamask)
* 2. If metamask/mist create a new web3 instance and pass on result
* 3. Get networkId - Now we can check the user is connected to the right network to use our dApp
* 4. Get user account from metamask
* 5. Get user balance
*/

let getWeb3 = async () => {
  try {
    let result = await new Promise((res, rej) => {
      let web3js = window.web3;
      if(typeof web3js !== 'undefined'){
        let web3 = new Web3(web3js.currentProvider);
        res({ injectedWeb3: web3.isConnected(), web3() { return web3 } });
      } else {
        rej(new Error('Unable to connect to Metamask'));
      }
    });

    result = await new Promise((res, rej) => {
      result.web3().version.getNetwork((err, networkId) => {
        if(err) rej(new Error('Unable to retrieve network ID'));
        else {
          result = Object.assign({}, result, { networkId });
          res(result);
        }
      });
    });

    result = await new Promise((res, rej) => {
      result.web3().eth.getCoinbase((err, coinbase) => {
        if(err) {
          rej(new Error('Unable to retrieve coinbase'));
        } else {
          result = Object.assign({}, result, { coinbase });
          res(result);
        }
      });
    });

    return await new Promise((res, rej) => {
      result.web3().eth.getBalance(result.coinbase, (err, balance) => {
        if(err) {
          rej(new Error(`Unable to retrieve balance for address: ${result.coinbase}`));
        } else {
          result = Object.assign({}, result, { balance });
          res(result);
        }
      });
    });

  } catch(err) {
    throw err;
  }
}
export default getWeb3;
