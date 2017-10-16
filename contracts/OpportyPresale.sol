pragma solidity ^0.4.15;

import "./OpportyToken.sol";
import "./Pausable.sol";
import "./HoldPresaleContract.sol";

contract OpportyPresale is Pausable {
  using SafeMath for uint256;

  OpportyToken public token;

  HoldPresaleContract public holdContract;

  enum SaleState  { NEW, SALE, ENDED }
  SaleState public state;

  uint public endDate;
  uint public endSaleDate;

  // address where funds are collected
  address private wallet;

  // total ETH collected
  uint public ethRaised;

  uint private price;

  uint public tokenRaised;
  bool public tokensTransferredToHold;

  /* Events */
  event SaleStarted(uint blockNumber);
  event FundTransfered(address contrib, uint amount);
  event WithdrawedEthToWallet(uint amount);
  event ManualChangeEndDate(uint beforeDate, uint afterDate);
  event TokensTransferedToHold(address hold, uint amount);
  event AddedToWhiteList(address inv, uint amount, uint8 holdPeriod, uint8 bonus);

  struct WhitelistContributor {
    bool isActive;
    uint invAmount;
    uint8 holdPeriod;
    uint holdTimestamp;
    uint8 bonus;
    bool payed;
  }

  mapping(address => WhitelistContributor) public whiteList;
  mapping(uint => address) private whitelistIndexes;
  uint private whitelistIndex;
  
  function OpportyPresale(
    address tokenAddress,
    address walletAddress,
    uint end,
    uint endSale,
    address holdCont )
  {
    token = OpportyToken(tokenAddress);
    state = SaleState.NEW;

    endDate   = end;
    endSaleDate = endSale;
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

      if (whiteList[msg.sender].holdPeriod==1)  whiteList[inv].holdTimestamp = endSaleDate.add(30 days); else
      if (whiteList[msg.sender].holdPeriod==3)  whiteList[inv].holdTimestamp = endSaleDate.add(92 days); else
      if (whiteList[msg.sender].holdPeriod==6)  whiteList[inv].holdTimestamp = endSaleDate.add(182 days); else
      if (whiteList[msg.sender].holdPeriod==12) whiteList[inv].holdTimestamp = endSaleDate.add(1 years);

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
      AddedToWhiteList(inv, whiteList[inv].invAmount, whiteList[inv].holdPeriod,  whiteList[inv].bonus);
    } else {
      whiteList[inv].invAmount = amount;
      whiteList[inv].holdPeriod = holdPeriod;
      if (whiteList[msg.sender].holdPeriod==1)  whiteList[inv].holdTimestamp = endSaleDate.add(30 days); else
      if (whiteList[msg.sender].holdPeriod==3)  whiteList[inv].holdTimestamp = endSaleDate.add(92 days); else
      if (whiteList[msg.sender].holdPeriod==6)  whiteList[inv].holdTimestamp = endSaleDate.add(182 days); else
      if (whiteList[msg.sender].holdPeriod==12) whiteList[inv].holdTimestamp = endSaleDate.add(1 years);
      whiteList[inv].bonus = bonus;
      AddedToWhiteList(inv, whiteList[inv].invAmount, whiteList[inv].holdPeriod,  whiteList[inv].bonus);
    }
  }

  //@todo добавить перевод в статуса END
  function() whenNotPaused public payable
  {
    require(state == SaleState.SALE);
    require(msg.value >= 0.3 ether);

    if (now > endDate) {
      state = SaleState.ENDED;
      msg.sender.transfer(msg.value);
      return ;
    }
    WhitelistContributor memory contrib = whiteList[msg.sender];
    require(contrib.invAmount <= msg.value || contrib.payed);

    whiteList[msg.sender].payed = true;
    ethRaised += msg.value;

    uint tokenAmount  = msg.value.div(price);
    tokenAmount += tokenAmount.mul(contrib.bonus).div(100);
    tokenRaised += tokenAmount;

    holdContract.addHolder(msg.sender, tokenAmount, contrib.holdPeriod, contrib.holdTimestamp);
    FundTransfered(msg.sender, msg.value);
  }

  function getBalanceContract() internal returns (uint)
  {
    return token.balanceOf(this);
  }

  function sendTokensToHold() public onlyOwner
  {
    require(state == SaleState.ENDED);
    require(getBalanceContract() >= tokenRaised);
    uint sum = tokenRaised * (10 ** 18);
    if (token.transfer(holdContract, sum )) {
      tokensTransferredToHold = true;
      TokensTransferedToHold(holdContract, sum );
    }
  }

  function getTokensBack() public onlyOwner
  {
    require(state == SaleState.ENDED);
    require(tokensTransferredToHold);
    uint balance;
    balance = getBalanceContract() ;
    token.transfer(msg.sender, balance);
  }

  function withdrawEth()
  {
    require(this.balance != 0);
    require(state == SaleState.ENDED);
    require(msg.sender == wallet);
    require(tokensTransferredToHold);
    uint bal = this.balance;
    wallet.transfer(bal);
    WithdrawedEthToWallet(bal);
  }

  function setEndSaleDate(uint date) public onlyOwner
  {
    require(state == SaleState.NEW);
    require(date > now);
    uint oldEndDate = endSaleDate;
    endSaleDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }

  function setEndDate(uint date) public onlyOwner
  {
    require(state == SaleState.NEW || state == SaleState.SALE);
    require(date > now);
    uint oldEndDate = endDate;
    endDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }

  function getTokenBalance() constant returns (uint)
  {
    return token.balanceOf(this);
  }

  // для вызова в sale контракте
  function getEthRaised() constant external returns (uint)
  {
    return ethRaised;
  }
}
