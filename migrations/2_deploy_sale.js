const moment        = require('moment');
const abi           = require('ethereumjs-abi');

const OpportyToken  = artifacts.require("./OpportyToken.sol");
const OpportySale   = artifacts.require("./OpportySale.sol");

module.exports = function(deployer, network) {
  if(network == "development") {
    let tokenAddress; // type address OpportyToken
    let walletAddress = web3.eth.accounts[web3.eth.accounts.length - 1]; // type address Multisig
    let start = moment().unix();//type uint set timestamp start Crowdsale
    let end   = moment(start * 1000).add(30, 'minute').unix(); // type uint set timestamp finish Crowdsale

    deployer.deploy(OpportyToken)
      .then(() => {
        tokenAddress = OpportyToken.address;

        return deployer.deploy(OpportySale, tokenAddress, walletAddress, start, end, tokenAddress)
          .then(() => OpportySale.deployed());
      })
      .then((instanceOppSale) => {
        let contractABI = abi.rawEncode(['address', 'address', 'uint', 'uint', 'address'], [tokenAddress, walletAddress, start, end, tokenAddress]);

        console.log('\n\n\nOpportySaleInfo\n');
        console.log('tokenAddress:  ', tokenAddress);
        console.log('walletAddress: ', walletAddress);
        console.log('start:         ', moment.unix(start).format('DD-MM-YYYY HH:mm:ss'));
        console.log('end:           ', moment.unix(end).format('DD-MM-YYYY HH:mm:ss'));
        console.log('holdContract:  ', tokenAddress);

        console.log('\nContract:');
        console.log('Address:', OpportySale.address);
        console.log('ContractABI:\n');
        console.log(contractABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportySale.abi));
        console.log('\n\n\n');
        return instanceOppSale.getSaleStatus()
          .then(status => {
            console.log('Contract status:', status.toString());
          })
      });
  } else {
    deployer.deploy(OpportyToken)
      .then(() => deployer.deploy(OpportySale, OpportyToken.address));
  }

};
