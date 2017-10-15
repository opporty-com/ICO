pragma solidity ^0.4.15;

import "./OpportyToken.sol";
import "./Ownable.sol";

contract HoldPresaleContract is Ownable {
  using SafeMath for uint256;
  // Addresses and contracts
  OpportyToken public OppToken;

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
  event Hold(address contributor , uint amount, uint8 holdPeriod);

  function OpportyHold(
    address _OppToken,
    address _postFreezeDestination,
    uint start
  ) {
    OppToken = OpportyToken(_OppToken);

    startDate = start;
    firstDate = startDate.add(30 days);
    secondDate = startDate.add(91 days);
    thirdDate = startDate.add(182 days);
    fourthDate = startDate.add(1 years);
  }

  function addHolder(address holder, uint tokens, uint8 timed) public onlyOwner {
    // добавить холд по таймстампу т.е. указывать с какого момента расхолдиться токен. Это позволит юзера просматривать инфу и знать точно когда.
    // предлогаю холд сразу в контракт передавать выситчыая его в самом контракте пресейла или сейла
    // uint oneMonth = 1 * 30 days;
    // holderList[contributor].holdPeriodTimestamp = startDate.add(timed * oneMonth)
    if (holderList[holder].isActive == false) {
      holderList[holder].isActive = true;
      holderList[holder].tokens = tokens;
      holderList[holder].holdPeriod = timed;
      holderIndexes[holderIndex] = holder;
      holderIndex++;
    } else {
      holderList[holder].tokens = tokens;
      holderList[holder].holdPeriod = timed;
    }
    Hold(holder, tokens, timed);
  }

  function getBalance() constant returns (uint)
  {
    return OppToken.balanceOf(this);
  }

  function unlockTokens() external {
    address contributor = msg.sender;
    bool tosent = false;

    if (holderList[contributor].isActive && !holderList[contributor].withdrawed) {
      // if (now >= holderList[contributor].holdPeriodTimestamp)
      if ( holderList[contributor].holdPeriod == 1  && now > firstDate) tosent = true;
      if ( holderList[contributor].holdPeriod == 3  && now > secondDate) tosent = true;
      if ( holderList[contributor].holdPeriod == 6  && now > thirdDate) tosent = true;
      if ( holderList[contributor].holdPeriod == 12 && now > fourthDate) tosent = true;
      if ( tosent == true && OppToken.transfer( msg.sender, holderList[contributor].tokens ) ) {
        holderList[contributor].withdrawed = true;
        TokensTransfered(contributor,  holderList[contributor].tokens);
      }
    } else {
      revert();
    }
  }

}
