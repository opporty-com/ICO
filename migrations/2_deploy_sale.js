const moment        = require('moment');
const abi           = require('ethereumjs-abi');
const Promise       = require('bluebird');

const OpportyToken  = artifacts.require("./OpportyToken.sol");
const OpportyHold   = artifacts.require("./OpportyHold.sol");
const OpportySale   = artifacts.require("./OpportySale.sol");
const OpportyPresale      = artifacts.require("./OpportyPresale.sol");
const OpportyPresale2     = artifacts.require("./OpportyPresale2.sol");
const HoldPresaleContract = artifacts.require("./HoldPresaleContract.sol");

module.exports = function(deployer, network) {

  if(network === "development") {
    /* OpportySale */
    let tokenAddress; // type address OpportyToken
    let walletAddress = web3.eth.accounts[web3.eth.accounts.length - 1]; // type address Multisig
    let addPreSaleManagerAddress = web3.eth.accounts[web3.eth.accounts.length - 2]; // type address AssetsPreSaleOwner call AddToWhitelist
    let start = moment().unix();//type uint set timestamp start Crowdsale
    let end   = moment(start * 1000).add(120, 'minute').unix(); // type uint set timestamp finish Crowdsale

    /* OpportyHold */
    let holdCont;
    let postFreezeDestination = walletAddress;
    let holdDays = 1;

    /* HoldPresaleContract */
    let holdContPreSale;
    let InstancePreSaleHold;

    /* OpportyPresale */
    let presaleContAdress;
    let presaleEnd = moment().add(60, 'minute').unix();

    /* OpportyPresale2 */
    let InstancePreSale2;
    let presaleContAddress2;
    let presaleEnd2 = moment().add(100, 'minute').unix();

    deployer.deploy(OpportyToken)
      .then(() => {
        tokenAddress = OpportyToken.address;

        return deployer.deploy(OpportyHold, tokenAddress, postFreezeDestination,holdDays)
          .then(() => OpportyHold.deployed());
      })
      .then(() => {
        holdCont = OpportyHold.address;

        return deployer.deploy(HoldPresaleContract, tokenAddress)
          .then(() => HoldPresaleContract.deployed())
          .then((instance) => {
            InstancePreSaleHold = instance;
            return Promise.resolve(true);
          })
      })
      .then(() => {
        holdContPreSale = HoldPresaleContract.address;

        return deployer.deploy(OpportyPresale, tokenAddress, walletAddress, presaleEnd, end, holdContPreSale)
          .then(() => OpportyPresale.deployed());
      })
      .then(() => {
        presaleContAdress = OpportyPresale.address;

        return deployer.deploy(OpportyPresale2, tokenAddress, walletAddress, presaleEnd2, end, holdContPreSale, presaleContAdress)
          .then(() => OpportyPresale2.deployed())
          .then((instance) => {
            InstancePreSale2 = instance;
            return Promise.resolve(true);
          })
      })
      .then(() => {
        presaleContAddress2 = OpportyPresale2.address;

        return deployer.deploy(OpportySale, tokenAddress, walletAddress, start, end, holdContPreSale, presaleContAddress2)
          .then(() => OpportySale.deployed())
          .catch(e => {
            console.log(`/n/n/n`);
            console.log(e);
          });

      })
      .then(() => {
        let contractSaleABI = abi.rawEncode(
          ['address', 'address', 'uint', 'uint', 'address', 'address'],
          [tokenAddress, walletAddress, start, end, holdContPreSale, presaleContAddress2]
        );
        let contractPreSaleABI = abi.rawEncode(
          ['address', 'address', 'uint', 'uint', 'address'],
          [tokenAddress, walletAddress, presaleEnd, end, holdContPreSale]
        );
        let contractPreSaleABI2 = abi.rawEncode(
          ['address', 'address', 'uint', 'uint', 'address', 'address'],
          [tokenAddress, walletAddress, presaleEnd2, end, holdContPreSale, presaleContAdress]
        );
        let contractHoldABI = abi.rawEncode(
          ['address', 'address', 'uint'],
          [tokenAddress, postFreezeDestination, holdDays]
        );
        let contractPresaleHoldABI = abi.rawEncode(['address'], [tokenAddress]);


        console.log('\n\n\nOpportySaleInfo\n');
        console.log('tokenAddress:    ', tokenAddress);
        console.log('multisigAddress: ', walletAddress);
        console.log('addPreSaleManager:',addPreSaleManagerAddress);
        console.log('start:           ', moment.unix(start).format('DD-MM-YYYY HH:mm:ss'));
        console.log('end:             ', moment.unix(end).format('DD-MM-YYYY HH:mm:ss'));
        console.log('PreSaleContract:    ', presaleContAdress);
        console.log('PreSaleContract2:   ', presaleContAddress2);
        console.log('holdContract:       ', holdCont);
        console.log('PresaleHoldContract:', holdContPreSale);

        console.log('\nContractSale:');
        console.log('Address:', OpportySale.address);
        console.log('ContractABI:\n');
        console.log(contractSaleABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportySale.abi));
        console.log('\n\n\n');

        console.log('\nContractPreSale:');
        console.log('Address:', presaleContAdress);
        console.log('presaleEnd:', moment.unix(presaleEnd).format('DD-MM-YYYY HH:mm:ss'));
        console.log('ContractABI:\n');
        console.log(contractPreSaleABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyPresale.abi));
        console.log('\n\n\n');

        console.log('\nContractPreSale2:');
        console.log('Address:', presaleContAddress2);
        console.log('presaleEnd:', moment.unix(presaleEnd).format('DD-MM-YYYY HH:mm:ss'));
        console.log('ContractABI:\n');
        console.log(contractPreSaleABI2.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyPresale2.abi));
        console.log('\n\n\n');

        console.log('\nContractPreSaleHold:');
        console.log('Address:', holdContPreSale);
        console.log('ContractABI:\n');
        console.log(contractPresaleHoldABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(HoldPresaleContract.abi));
        console.log('\n\n\n');

        console.log('\nContractHold:');
        console.log('Address:', holdCont);
        console.log('postFreezeDestination:', postFreezeDestination);
        console.log('ContractABI:\n');
        console.log(contractHoldABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyHold.abi));
        console.log('\n\n\n');

        return Promise.resolve(true);
      })
      .then(() => {
        return Promise.all([
          InstancePreSaleHold.addAssetsOwner(presaleContAdress),
          InstancePreSaleHold.addAssetsOwner(presaleContAddress2),
          InstancePreSaleHold.addAssetsOwner(OpportySale.address),
          InstancePreSale2.addAssetsOwner(addPreSaleManagerAddress),
        ])
        .then((data) => {
          console.log(`HoldPresaleContract addAssetsOwner [${presaleContAdress}, ${OpportySale.address}]:`);
          console.log(`PreSale2 addAssetsOwner [${addPreSaleManagerAddress}]:`);

          return Promise.resolve(true);
        })
      })
      .catch(e => {
        console.log('------ ERROR ------');
        console.error(e);
      });
  } else {
    deployer.deploy(OpportyToken)
      .then(() => deployer.deploy(OpportySale, OpportyToken.address));
  }

};
