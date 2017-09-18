pragma solidity ^0.4.8;
import "./StandardToken.sol";

contract OpportyToken is StandardToken {
  string public name = "OpportyToken";
  string public symbol = "EGT";
  uint public decimals = 2;
  uint public INITIAL_SUPPLY = 10000;

  function OpportyToken() {
    totalSupply = INITIAL_SUPPLY;
    balances[tx.origin] = INITIAL_SUPPLY;
  }
}
