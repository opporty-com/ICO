pragma solidity ^0.4.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/OpportyToken.sol";


contract TestOpportyToken  {
  event test_value(address value1);

  event debuggerCast(address addresscall, string  message);
  address constant testingAddress = 0x08990456DC3020C93593DF3CaE79E27935dd69b9;

  function testInitialBalanceUsingDeployedContract() {
    OpportyToken opportytoken = OpportyToken(DeployedAddresses.OpportyToken());

    uint256 expected = 10000;

    Assert.equal(opportytoken.balanceOf(tx.origin), expected, "Owner should have 10000 OpportyToken initially");
  }

  function testInitialBalanceWithNew() {
    OpportyToken opportytoken = new OpportyToken();

    uint256 expected = 10000;

    Assert.equal(opportytoken.balanceOf(tx.origin), expected, "Owner should have 10000 OpportyToken initially");
  }

}
