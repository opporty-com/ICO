pragma solidity ^0.4.18;

import "./OpportyToken.sol";
import "./Ownable.sol";

contract OpportyWhiteListHold is Ownable {
  using SafeMath for uint256;
  // Addresses and contracts
  OpportyToken public OppToken;

  struct Holder {
    bool isActive;
    uint tokens;
    uint8 holdPeriod;
    uint holdPeriodTimestamp;
    bool withdrawed;
  }

  mapping(address => Holder) public holderList;
  mapping(uint => address) private holderIndexes;

  mapping (uint => address) private assetOwners;
  mapping (address => uint) private assetOwnersIndex;
  uint public assetOwnersIndexes;

  uint private holderIndex;

  event TokensTransfered(address contributor , uint amount);
  event Hold(address sender, address contributor, uint amount, uint8 holdPeriod);
  event ChangeHold(address sender, address contributor, uint amount, uint8 holdPeriod);
  event TokenChanged(address newAddress);
  event ManualPriceChange(uint beforePrice, uint afterPrice);

  modifier onlyAssetsOwners() {
    require(assetOwnersIndex[msg.sender] > 0 || msg.sender == owner);
    _;
  }

  function getBalanceContract() view internal returns (uint) {
    return OppToken.balanceOf(this);
  }

  function setToken(address newToken) public onlyOwner {
    OppToken = OpportyToken(newToken);
    TokenChanged(newToken);
  }

  function changeHold(address holder, uint tokens, uint8 period, uint holdTimestamp, bool withdrawed ) public onlyAssetsOwners {
    if (holderList[holder].isActive == true) {
      holderList[holder].tokens = tokens;
      holderList[holder].holdPeriod = period;
      holderList[holder].holdPeriodTimestamp = holdTimestamp;
      holderList[holder].withdrawed = withdrawed;
      ChangeHold(msg.sender, holder, tokens, period);
    }
  }

  function addHolder(address holder, uint tokens, uint8 timed, uint timest) onlyAssetsOwners external {
    if (holderList[holder].isActive == false) {
      holderList[holder].isActive = true;
      holderList[holder].tokens = tokens;
      holderList[holder].holdPeriod = timed;
      holderList[holder].holdPeriodTimestamp = timest;
      holderIndexes[holderIndex] = holder;
      holderIndex++;
    } else {
      holderList[holder].tokens += tokens;
      holderList[holder].holdPeriod = timed;
      holderList[holder].holdPeriodTimestamp = timest;
    }
    Hold(msg.sender, holder, tokens, timed);
  }

  function getBalance() public constant returns (uint) {
    return OppToken.balanceOf(this);
  }

  function returnTokens(uint nTokens) public onlyOwner returns (bool) {
    require(nTokens <= getBalance());
    OppToken.transfer(msg.sender, nTokens);
    TokensTransfered(msg.sender, nTokens);
    return true;
  }

  function unlockTokens() public returns (bool) {
    require(holderList[msg.sender].isActive);
    require(!holderList[msg.sender].withdrawed);
    require(now >= holderList[msg.sender].holdPeriodTimestamp);

    OppToken.transfer(msg.sender, holderList[msg.sender].tokens);
    holderList[msg.sender].withdrawed = true;
    TokensTransfered(msg.sender, holderList[msg.sender].tokens);
    return true;
  }

  function addAssetsOwner(address _owner) public onlyOwner {
    assetOwnersIndexes++;
    assetOwners[assetOwnersIndexes] = _owner;
    assetOwnersIndex[_owner] = assetOwnersIndexes;
  }
  function removeAssetsOwner(address _owner) public onlyOwner {
    uint index = assetOwnersIndex[_owner];
    delete assetOwnersIndex[_owner];
    delete assetOwners[index];
    assetOwnersIndexes--;
  }
  function getAssetsOwners(uint _index) onlyOwner public constant returns (address) {
    return assetOwners[_index];
  }
}