pragma solidity ^0.4.15;

import "./SafeMath.sol";
import "./OpportyToken.sol";
import "./Pausable.sol";
import "./HoldPresaleContract.sol";

contract OpportyPresale is Pausable {
  using SafeMath for uint256;

  OpportyToken public token;

  HoldPresaleContract public holdContract;

  enum SaleState  { NEW, SALE, ENDED }
  SaleState public state;

  uint public startDate;
  uint public endDate;

  // address where funds are collected
  address private wallet;

  // total ETH collected
  uint public ethRaised;

  uint private price;

  uint public tokenRaised;

  /* Events */
  event SaleStarted(uint blockNumber);
  event FundTransfered(address contrib, uint amount);
  event WithdrawedEthToWallet(uint amount);
  event ManualChangeStartDate(uint beforeDate, uint afterDate);
  event ManualChangeEndDate(uint beforeDate, uint afterDate);
  event TokensTransferedToHold(address hold, uint amount);

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
    address holdCont)
  {
    token = OpportyToken(tokenAddress);
    state = SaleState.NEW;

    startDate = start; // можно убрать т.к. нам это не нужно. мы можем вручную запустить и если что сделать паузу.
    endDate   = end;
    price     = 0.0002 * 1 ether;
    wallet = walletAddress;

    holdContract = HoldPresaleContract(holdCont);
  }

  function startPresale() public onlyOwner
  {
    require (state == SaleState.NEW);
    state = SaleState.SALE;
    SaleStarted(block.number);
  }

  function addToWhitelist(address inv, uint amount, uint8 holdPeriod, uint8 bonus) public onlyOwner {
    require(state == SaleState.NEW || state == SaleState.SALE);

    if (whiteList[inv].isActive == false) {
      whiteList[inv].isActive = true;
      whiteList[inv].payed = false;
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

    uint tokenAmount  = amount.div(price);
    tokenNeedToStart += tokenAmount.mul(whiteList[inv].bonus).div(100);
  }


  //@todo добавить перевод в статуса END
  function() whenNotPaused public payable {
    require(msg.value > 0);
    require(state == SaleState.SALE);
    require(now < endDate);

    require(whiteList[msg.sender].isActive);
    require((whiteList[msg.sender].payed == false && whiteList[msg.sender].invAmount >= msg.value) || whiteList[msg.sender].payed);

    whiteList[msg.sender].payed = true;
    contribution[msg.sender] += msg.value;
    ethRaised += msg.value;
    uint tokenAmount  = msg.value.div(price);
    tokenAmount += tokenAmount.mul(whiteList[msg.sender].bonus).div(100);
    holdContract.addHolder(msg.sender, tokenAmount, whiteList[msg.sender].holdPeriod);
    tokenRaised += tokenAmount;
    FundTransfered(msg.sender, msg.value);
  }

  function getBalanceContract() internal returns (uint) {
    return token.balanceOf(this);
  }

  function sendTokensToHold() public onlyOwner
  {
    require(state == SaleState.ENDED);
    require(getBalanceContract() >= tokenRaised);
    uint sum = tokenRaised * (10 ** 18);
    if (token.transfer(holdContract, sum )) {
      TokensTransferedToHold(holdContract, sum );
    }
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

  function getTokenBalance() constant returns (uint) {
    return token.balanceOf(this);
  }
  // для вызова в sale контракте
  function getEthRaised() constant returns (uint) {
    return ethRaised;
  }
}
