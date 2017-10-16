pragma solidity ^0.4.15;

import "./OpportyToken.sol";
import "./Ownable.sol";

contract HoldPresaleContract is Ownable {
  using SafeMath for uint256;
  // Addresses and contracts
  OpportyToken public OppToken;
  address private presaleCont;

  struct Holder {
    bool isActive;
    uint tokens;
    uint8 holdPeriod;
    uint holdPeriodTimestamp;
    bool withdrawed;
  }

  mapping(address => Holder) public holderList;
  mapping(uint => address) private holderIndexes;
  uint private holderIndex;

  event TokensTransfered(address contributor , uint amount);
  event Hold(address contributor , uint amount, uint8 holdPeriod);
  event Log(address log);
  function HoldPresaleContract(
    address _OppToken
  ) {
    OppToken = OpportyToken(_OppToken);
  }

  function setPresaleCont(address pres)  public onlyOwner
  {
    presaleCont = pres;
  }

  function addHolder(address holder, uint tokens, uint8 timed, uint timest) external  {
    // добавить холд по таймстампу т.е. указывать с какого момента расхолдиться токен. Это позволит юзера просматривать инфу и знать точно когда.
    // предлогаю холд сразу в контракт передавать выситчыая его в самом контракте пресейла или сейла
    // uint oneMonth = 1 * 30 days;
    // holderList[contributor].holdPeriodTimestamp = startDate.add(timed * oneMonth)
    Log(msg.sender);
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
    Hold(holder, tokens, timed);
  }

  function getBalance() constant returns (uint)
  {
    return OppToken.balanceOf(this);
  }

  function unlockTokens() external {
    address contributor = msg.sender;

    if (holderList[contributor].isActive && !holderList[contributor].withdrawed) {
      if (now >= holderList[contributor].holdPeriodTimestamp) {
        if ( OppToken.transfer( msg.sender, holderList[contributor].tokens ) ) {
          holderList[contributor].withdrawed = true;
          TokensTransfered(contributor,  holderList[contributor].tokens);
        }
      } else {
        revert();
      }
    } else {
      revert();
    }
  }

}
