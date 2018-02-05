const moment        = require('moment');
const abi           = require('ethereumjs-abi');
const Promise       = require('bluebird');

const OpportyToken          = artifacts.require("./OpportyToken.sol");
const OpportyWhiteList      = artifacts.require("./OpportyWhiteList.sol");
const OpportyWhiteListHold  = artifacts.require("./OpportyWhiteListHold.sol");
const OpportyMonthHold      = artifacts.require("./OpportyMonthHold.sol");
const OpportyYearHold       = artifacts.require("./OpportyYearHold.sol");

module.exports = function(deployer, network) {

  if(network === "development") {

    /* base */
    let multisigAddress = web3.eth.accounts[web3.eth.accounts.length - 1]; // type address Multisig
    let managerAddress  = web3.eth.accounts[web3.eth.accounts.length - 2]; // type address AssetsPreSaleOwner call AddToWhitelist

    /* OpportyToken */
    let tokenAddress;
    let TokenInstance;

    /* OpportyWhiteListHold */
    let whiteListHoldAddress;
    let WhiteListHoldInstance;

    /* OpportyWhiteList */
    let whiteListAddress;
    let WhiteListInstance;
    let whiteListEnd = moment().add(10, 'minute').unix();// end sale
    let whiteListEndSale = whiteListEnd;// holding date start

    /* OpportyMonthHold */
    let monthHoldAddress;
    let MonthHoldInstance;
    let monthHoldStart    = moment().unix();// start sale
    let monthHoldEnd      = moment().add(20, 'minute').unix();// end sale
    let monthHoldEndSale  = monthHoldEnd;// holding date start

    /* OpportyYearHold */
    let yearHoldAddress;
    let YearHoldInstance;
    let yearHoldStart   = moment().unix();// start sale
    let yearHoldEnd     = moment().add(30, 'minute').unix();// end sale
    let yearHoldEndSale = yearHoldEnd;// holding date start

    deployer.deploy(OpportyToken)
      .then(() => OpportyToken.deployed())
      .then((instance) => {
        TokenInstance   = instance;
        tokenAddress    = OpportyToken.address;
        return true;
      })
      .then(() => {
        return deployer.deploy(OpportyWhiteListHold)
          .then(() => OpportyWhiteListHold.deployed())
          .then((instance) => {
            WhiteListHoldInstance   = instance;
            whiteListHoldAddress    = OpportyWhiteListHold.address;
            return true;
          })
      })
      .then(() => {
        return deployer.deploy(OpportyWhiteList, multisigAddress, whiteListEnd, whiteListEndSale, whiteListHoldAddress)
          .then(() => OpportyWhiteList.deployed())
          .then((instance) => {
            WhiteListInstance   = instance;
            whiteListAddress    = OpportyWhiteList.address;
            return true;
          })
      })
      .then(() => {
        return deployer.deploy(OpportyMonthHold, multisigAddress, monthHoldStart, monthHoldEnd, monthHoldEndSale)
          .then(() => OpportyMonthHold.deployed())
          .then((instance) => {
            MonthHoldInstance   = instance;
            monthHoldAddress    = OpportyMonthHold.address;
            return true;
          })
      })
      .then(() => {
        return deployer.deploy(OpportyYearHold, multisigAddress, yearHoldStart, yearHoldEnd, yearHoldEndSale)
          .then(() => OpportyYearHold.deployed())
          .then((instance) => {
            YearHoldInstance   = instance;
            yearHoldAddress    = OpportyYearHold.address;
            return true;
          })
      })
      .then(() => {

        let whiteListABI = abi.rawEncode(
          ['address', 'uint', 'uint', 'address'],
          [multisigAddress, whiteListEnd, whiteListEndSale, whiteListHoldAddress]
        );

        let monthHoldABI = abi.rawEncode(
          ['address', 'uint', 'uint', 'uint'],
          [multisigAddress, monthHoldStart, monthHoldEnd, monthHoldEndSale]
        );

        let yearHoldABI = abi.rawEncode(
          ['address', 'uint', 'uint', 'uint'],
          [multisigAddress, yearHoldStart, yearHoldEnd, yearHoldEndSale]
        );

        console.log('\n\n\nOpportyInfo\n');
        console.log('tokenAddress:          ', tokenAddress);
        console.log('multisigAddress:       ', multisigAddress);
        console.log('managerAddress:        ', managerAddress);
        console.log('OpportyWhiteListHold:  ', whiteListHoldAddress);
        console.log('OpportyWhiteList:      ', whiteListAddress);
        console.log('OpportyMonthHold:      ', monthHoldAddress);
        console.log('OpportyYearHold:       ', yearHoldAddress);

        console.log('\nOpportyToken:');
        console.log('Address:       ', tokenAddress);
        console.log('ContractABI:\n');
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyToken.abi));
        console.log('\n\n\n');

        console.log('\nOpportyWhiteListHold:');
        console.log('Address:       ', whiteListHoldAddress);
        console.log('ContractABI:\n');
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyWhiteListHold.abi));
        console.log('\n\n\n');

        console.log('\nOpportyWhiteList:');
        console.log('Address:       ', whiteListAddress);
        console.log('walletAddress: ', multisigAddress);
        console.log('end:           ', moment.unix(whiteListEnd).format('DD-MM-YYYY HH:mm:ss'));
        console.log('endSale:       ', moment.unix(whiteListEndSale).format('DD-MM-YYYY HH:mm:ss'));
        console.log('holdCont:      ', whiteListHoldAddress);
        console.log('ContractABI:\n');
        console.log(whiteListABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyWhiteList.abi));
        console.log('\n\n\n');

        console.log('\nOpportyMonthHold:');
        console.log('Address:       ', monthHoldAddress);
        console.log('walletAddress: ', multisigAddress);
        console.log('start:         ', moment.unix(monthHoldStart).format('DD-MM-YYYY HH:mm:ss'));
        console.log('end:           ', moment.unix(monthHoldEnd).format('DD-MM-YYYY HH:mm:ss'));
        console.log('endSale:       ', moment.unix(monthHoldEndSale).format('DD-MM-YYYY HH:mm:ss'));
        console.log('ContractABI:\n');
        console.log(monthHoldABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyMonthHold.abi));
        console.log('\n\n\n');

        console.log('\nOpportyYearHold:');
        console.log('Address:       ', yearHoldAddress);
        console.log('walletAddress: ', multisigAddress);
        console.log('start:         ', moment.unix(yearHoldStart).format('DD-MM-YYYY HH:mm:ss'));
        console.log('end:           ', moment.unix(yearHoldEnd).format('DD-MM-YYYY HH:mm:ss'));
        console.log('endSale:       ', moment.unix(yearHoldEndSale).format('DD-MM-YYYY HH:mm:ss'));
        console.log('ContractABI:\n');
        console.log(yearHoldABI.toString('hex'));
        console.log('\nABI:\n');
        console.log(JSON.stringify(OpportyYearHold.abi));
        console.log('\n\n\n');

        return Promise.resolve(true);
      })
      .then(() => {
        return Promise.all([
          WhiteListHoldInstance.addAssetsOwner(whiteListAddress),
          WhiteListHoldInstance.addAssetsOwner(managerAddress),
          WhiteListInstance.addAssetsOwner(managerAddress),
          MonthHoldInstance.addAssetsOwner(managerAddress),
          YearHoldInstance.addAssetsOwner(managerAddress),
          WhiteListInstance.startPresale(),
          MonthHoldInstance.startPresale(),
          YearHoldInstance.startPresale(),
        ])
        .then((data) => {
          console.log(`OpportyWhiteListHold addAssetsOwner  [${whiteListAddress},${managerAddress}]\n`);
          console.log(`OpportyWhiteList     addAssetsOwner  [${managerAddress}]\n`);
          console.log(`OpportyMonthHold     addAssetsOwner  [${managerAddress}]\n`);
          console.log(`OpportyYearHold      addAssetsOwner  [${managerAddress}]\n`);

          return Promise.resolve(true);
        })
      })
      .catch(e => {
        console.log('------ ERROR ------');
        console.error(e);
      });
  } else {

  }

};
