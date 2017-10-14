pragma solidity ^0.4.15;

import "./OpportyToken.sol";

contract HoldPresaleContract  {
  // Addresses and contracts
  address public OppToken;

  struct Holder {
    bool isActive;
    uint tokens;
    uint8 holdPeriod;
    bool withdrawed;
  }

  mapping(address => Holder) public holderList;
  mapping(uint => address) private holderIndexes;
  uint private holderIndex;

  uint private startDate;

  // Freezer Data
  uint firstDate;
  uint secondDate;
  uint thirdDate;
  uint fourthDate;

  event TokensTransfered(address contributor , uint amount);

  function OpportyHold(
    address _OppToken,
    address _postFreezeDestination,
    uint start
  ) {
    OppToken = OpportyToken(_OppToken);

    startDate = start;
    firstDate = startDate.add(1 month);
    secondDate = startDate.add(3 month);
    thirdDate = startDate.add(6 month);
    fourthDate = startDate.add(12 month);
  }

  function addHolder(address holder, uint tokens, uint time) {
    if (holderList[holder].isActive == false) {
      holderList[holder].isActive = true;
      holderList[holder].tokens = tokens;
      holderList[holder].holdPeriod = time;
      holderIndexes[holderIndex] = holder;
      holderIndex++;
    } else {
      holderList[holder].tokens = tokens;
      holderList[holder].holdPeriod = time;
    }
  }

  function getBalance() constant returns (uint)
  {
    return OpportyToken(OppToken).balanceOf(this);
  }

  function unlockTokens() external {
    address contributor = msg.sender;
    bool tosent = false;

    if (holderList[contributor].isActive && !holderList[contributor].withdrawed) {
      if ( holderList[contributor].holdPeriod == 1 && now > firstDate) tosent = true;
      if ( holderList[contributor].holdPeriod == 3 && now > secondDate) tosent = true;
      if ( holderList[contributor].holdPeriod == 6 && now > thirdDate) tosent = true;
      if ( holderList[contributor].holdPeriod == 12 && now > fourthDate) tosent = true;
      if (tosend && OpportyToken(OppToken).transfer(msg.sender, holderList[contributor].tokens)) {
        holderList[contributor].withdrawed = true;
        TokensTransfered(contributor,  holderList[contributor].tokens);
      }
    } else {
      revert();
    }
  }

}
