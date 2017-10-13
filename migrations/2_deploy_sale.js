const moment        = require('moment');
const abi           = require('ethereumjs-abi');

const OpportyToken  = artifacts.require("./OpportyToken.sol");
const OpportyHold   = artifacts.require("./OpportyHold.sol");
const OpportySale   = artifacts.require("./OpportySale.sol");
const OpportyPresale   = artifacts.require("./OpportyPresale.sol");
module.exports = function(deployer, network) {
  console.log(network);
  if(network == "development") {
    /* OpportySale */
    let tokenAddress; // type address OpportyToken
    let walletAddress = "0xdD86E182b176F4C14E8B0c7D3b7637D60F7cbb39"; // type address Multisig
    let start = moment().unix();//type uint set timestamp start Crowdsale
    let end   = moment(start * 1000).add(30, 'minute').unix(); // type uint set timestamp finish Crowdsale

    /* OpportyHold */
    let holdCont;
    let postFreezeDestination = walletAddress;
    let holdDays = 1;

    deployer.deploy(OpportyToken)
      .then(() => {
        tokenAddress = OpportyToken.address;

        return deployer.deploy(OpportyHold, tokenAddress,postFreezeDestination,holdDays)
          .then(() => OpportyHold.deployed());
      })
      .then(() => {
        holdCont = OpportyHold.address;

        return deployer.deploy(OpportyPresale).then(()=> {
          console.log("Presale Deployed\n");
          return deployer.deploy(OpportySale, tokenAddress, walletAddress, start, end, holdCont)
            .then(() => OpportySale.deployed());
        });


      })
      .then((instanceOppSale) => {
        let contractSaleABI = abi.rawEncode(['address', 'address', 'uint', 'uint', 'address'], [tokenAddress, walletAddress, start, end, holdCont]);
        let contractHoldABI = abi.rawEncode(['address', 'address', 'uint'], [tokenAddress,postFreezeDestination,holdDays]);

        console.log('\n\n\nOpportySaleInfo\n');
        console.log('tokenAddress:  ', tokenAddress);
        console.log('walletAddress: ', walletAddress);
        console.log('start:         ', moment.unix(start).format('DD-MM-YYYY HH:mm:ss'));
        console.log('end:           ', moment.unix(end).format('DD-MM-YYYY HH:mm:ss'));
        console.log('holdContract:  ', holdCont);

        console.log('\nContractSale:');
        console.log('Address:', OpportySale.address);
        console.log('ContractABI:\n');
        console.log(contractSaleABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportySale.abi));
        console.log('\n\n\n');

        console.log('\nContractHold:');
        console.log('Address:', OpportyHold.address);
        console.log('postFreezeDestination:', postFreezeDestination);
        console.log('ContractABI:\n');
        console.log(contractHoldABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyHold.abi));
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
