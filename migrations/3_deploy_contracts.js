
var OpportyToken = artifacts.require("./OpportyToken.sol");
var Escrow = artifacts.require("./Escrow.sol");

module.exports = function(deployer) {
  deployer.deploy(OpportyToken).then(function() {
  return deployer.deploy(Escrow, OpportyToken.address);
});

};
