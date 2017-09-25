
var OpportyToken = artifacts.require("./OpportyToken.sol");
var OpportySale = artifacts.require("./OpportySale.sol");

module.exports = function(deployer) {
  deployer.deploy(OpportyToken).then(function() {
  return deployer.deploy(OpportySale, OpportyToken.address);
});

};
