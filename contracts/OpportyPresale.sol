pragma solidity ^0.4.15;

import "./SafeMath.sol";
import "./OpportyToken.sol";
import "./Pausable.sol";
import "./HoldPresaleContract.sol";

contract OpportyPresale is Pausable {
  using SafeMath for uint256;

  OpportyToken public token;

  HoldPresaleContract public holdContract1;
  HoldPresaleContract public holdContract2;
  HoldPresaleContract public holdContract3;
  HoldPresaleContract public holdContract4;

  enum SaleState  { NEW, SALE, ENDED }
  SaleState public state;

  uint public startDate;
  uint public endDate;

  // address where funds are collected
  address private wallet;

  // total ETH collected
  uint private ethRaised;

  event WithdrawedEthToWallet(uint amount);
  event ManualChangeStartDate(uint beforeDate, uint afterDate);
  event ManualChangeEndDate(uint beforeDate, uint afterDate);

  struct WhitelistContributor {
    bool isActive;
    uint invAmount;
    uint8 holdPeriod;
    uint8 bonus;
    bool payed;
  }

  mapping(address => WhitelistContributor) public whiteList;
  mapping(uint => address) private whitelistIndexes;
  uint private whitelistIndex;
  mapping(address => uint) public contribution;

  function OpportyPresale(
    address tokenAddress,
    address walletAddress,
    uint start,
    uint end,
    address holdCont1,
    address holdCont2,
    address holdCont3,
    address holdCont4)
  {
    token = OpportyToken(tokenAddress);
    state = SaleState.NEW;

    startDate = start;
    endDate   = end;

    wallet = walletAddress;

    holdContract1 = HoldPresaleContract(holdCont1);
    holdContract2 = HoldPresaleContract(holdCont2);
    holdContract3 = HoldPresaleContract(holdCont3);
    holdContract4 = HoldPresaleContract(holdCont4);
  }

  function startPresale() public onlyOwner
  {
    require (state == SaleState.NEW);
    state = SaleState.SALE;
  }

  function addToWhitelist(address inv, uint amount, uint8 holdPeriod, uint8 bonus) public onlyOwner {
    require(state == SaleState.NEW);

    if (whiteList[inv].isActive == false) {
      whiteList[inv].isActive = true;
      whiteList[inv].invAmount = amount;
      whiteList[inv].holdPeriod = holdPeriod;

      // calculation bonus amount regarding table
      if (amount < 100 ether) {
        if (holdPeriod == 1) whiteList[inv].bonus = 21;
        if (holdPeriod == 3) whiteList[inv].bonus = 22;
        if (holdPeriod == 6) whiteList[inv].bonus = 25;
        if (holdPeriod == 12) whiteList[inv].bonus = 30;
      } else if (amount < 1000 ether) {
        if (holdPeriod == 1) whiteList[inv].bonus = 22;
        if (holdPeriod == 3) whiteList[inv].bonus = 23;
        if (holdPeriod == 6) whiteList[inv].bonus = 25;
        if (holdPeriod == 12) whiteList[inv].bonus = 35;
      } else if (amount < 1650 ether) {
        if (holdPeriod == 1) whiteList[inv].bonus = 23;
        if (holdPeriod == 3) whiteList[inv].bonus = 24;
        if (holdPeriod == 6) whiteList[inv].bonus = 30;
        if (holdPeriod == 12) whiteList[inv].bonus = 40;
      } else if (amount < 3300 ether) {
        if (holdPeriod == 1) whiteList[inv].bonus = 25;
        if (holdPeriod == 3) whiteList[inv].bonus = 30;
        if (holdPeriod == 6) whiteList[inv].bonus = 35;
        if (holdPeriod == 12) whiteList[inv].bonus = 50;
      } else {
        if (holdPeriod == 1) whiteList[inv].bonus = 30;
        if (holdPeriod == 3) whiteList[inv].bonus = 40;
        if (holdPeriod == 6) whiteList[inv].bonus = 50;
        if (holdPeriod == 12) whiteList[inv].bonus = 60;
      }

      if (bonus>0)
        whiteList[inv].bonus = bonus;

      whitelistIndexes[whitelistIndex] = inv;
      whitelistIndex++;
    } else {
      whiteList[inv].invAmount = amount;
      whiteList[inv].holdPeriod = holdPeriod;
      whiteList[inv].bonus = bonus;
    }
  }


  function() whenNotPaused public payable {
    require(msg.value > 0);
    require(state == SaleState.SALE);
    require(now < endDate);

    require(whiteList[msg.sender].isActive);
    require(whiteList[msg.sender].invAmount <= msg.value || whiteList[msg.sender].payed ) ;
    whiteList[msg.sender].payed = true;
    contribution[msg.sender] += msg.value;
    ethRaised += msg.value;
  }


  function withdrawEth() {
    require(this.balance != 0);
    require(state == SaleState.ENDED);
    require(msg.sender == wallet);
    uint bal = this.balance;
    wallet.transfer(bal);
    WithdrawedEthToWallet(bal);
  }


  function setStartDate(uint date) public onlyOwner {
    require(state == SaleState.NEW);
    require(date < endDate);
    uint oldStartDate = startDate;
    startDate = date;
    ManualChangeStartDate(oldStartDate, date);
  }

  function setEndDate(uint date) public onlyOwner {
    require(state == SaleState.NEW || state == SaleState.SALE);
    require(date > now && date > startDate);
    uint oldEndDate = endDate;
    endDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }

}
