pragma solidity ^0.4.18;

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
  event SaleEnded(uint blockNumber);
  event FundTransfered(address contrib, uint amount);
  event WithdrawedEthToWallet(uint amount);
  event ManualChangeEndDate(uint beforeDate, uint afterDate);
  event TokensTransferedToHold(address hold, uint amount);
  event AddedToWhiteList(address inv, uint amount, uint8 holdPeriod, uint8 bonus);
  event AddedToHolder( address sender, uint tokenAmount, uint8 holdPeriod, uint holdTimestamp);

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

  struct Bonus {
    uint8 minHold;
    uint minAmount;
    uint8 bonus;
  }

  Bonus[] bonuses;

  /* constructor */
  function OpportyPresale(
    address tokenAddress,
    address walletAddress,
    uint end,
    uint endSale,
    address holdCont ) public
  {
    token = OpportyToken(tokenAddress);
    state = SaleState.NEW;

    endDate = end;
    endSaleDate = endSale;
    price = 0.0002 * 1 ether;
    wallet = walletAddress;

    bonuses.push(Bonus({minHold: 1, minAmount: 0, bonus: 25 }));
    bonuses.push(Bonus({minHold: 1, minAmount: 50, bonus: 30 }));
    bonuses.push(Bonus({minHold: 1, minAmount: 100, bonus: 35 }));
    bonuses.push(Bonus({minHold: 1, minAmount: 250, bonus: 40 }));
    bonuses.push(Bonus({minHold: 1, minAmount: 500, bonus: 45 }));
    bonuses.push(Bonus({minHold: 1, minAmount: 1000, bonus: 55 }));
    bonuses.push(Bonus({minHold: 1, minAmount: 5000, bonus: 70 }));

    bonuses.push(Bonus({minHold: 12, minAmount: 0, bonus: 35 }));
    bonuses.push(Bonus({minHold: 12, minAmount: 50, bonus: 40 }));
    bonuses.push(Bonus({minHold: 12, minAmount: 100, bonus: 45 }));
    bonuses.push(Bonus({minHold: 12, minAmount: 250, bonus: 50 }));
    bonuses.push(Bonus({minHold: 12, minAmount: 500, bonus: 70 }));
    bonuses.push(Bonus({minHold: 12, minAmount: 1000, bonus: 80 }));
    bonuses.push(Bonus({minHold: 12, minAmount: 5000, bonus: 90 }));
    
    holdContract = HoldPresaleContract(holdCont);
  }

  function changeBonus(uint8 minHold, uint minAmount, uint8 newBonus) public {
    bool find = false;
    for (uint i = 0; i < bonuses.length; ++i) {
      if (bonuses[i].minHold == minHold && bonuses[i].minAmount == minAmount) {
        bonuses[i].bonus = newBonus;
        find = true;
        break;
      }
    }
    if (!find) {
      bonuses.push(Bonus({minHold:minHold, minAmount:minAmount, bonus:newBonus}));
    }
  }

  function getBonus(uint8 hol, uint am) public view returns(uint8) {
    uint max = 0;
    uint8 bon = 0;
    for (uint i = 0; i < bonuses.length; ++i) {
      if (hol >= bonuses[i].minHold) 
        max = bonuses[i].minHold;
    }
    for (i = 0; i < bonuses.length; ++i) {
      if (bonuses[i].minHold == max) {
        if (am >= bonuses[i].minAmount) 
          bon = bonuses[i].bonus;
      }
    }

    return bon;
  }

  function startPresale() public onlyOwner {
    require(state == SaleState.NEW);
    state = SaleState.SALE;
    SaleStarted(block.number);
  }

  function endPresale() public onlyOwner {
    require(state == SaleState.SALE);
    state = SaleState.ENDED;
    SaleEnded(block.number);
  }

  function addToWhitelist(address inv, uint amount, uint8 holdPeriod) public onlyOwner {
    require(state == SaleState.NEW || state == SaleState.SALE);
    //require(holdPeriod == 1 || holdPeriod == 3 || holdPeriod == 6 || holdPeriod == 12);

    amount = amount * (10 ** 18);

    if (whiteList[inv].isActive == false) {
      whiteList[inv].isActive = true;
      whiteList[inv].payed = false;
      whitelistIndexes[whitelistIndex] = inv;
      whitelistIndex++;
    }

    uint8 bonus = getBonus(holdPeriod, amount);

    whiteList[inv].invAmount = amount;
    whiteList[inv].holdPeriod = holdPeriod;
    whiteList[inv].bonus = bonus;
    whiteList[inv].holdTimestamp = endSaleDate.add(whiteList[inv].holdPeriod * 30 days + (whiteList[inv].holdPeriod / 2) * 1 days );
    

    AddedToWhiteList(inv, whiteList[inv].invAmount, whiteList[inv].holdPeriod,  whiteList[inv].bonus);
  }

  function() whenNotPaused public payable {
    require(state == SaleState.SALE);
    require(msg.value >= 0.3 ether);
    require(whiteList[msg.sender].isActive);

    if (now > endDate) {
      state = SaleState.ENDED;
      msg.sender.transfer(msg.value);
      return ;
    }

    WhitelistContributor memory contrib = whiteList[msg.sender];
    require(contrib.invAmount <= msg.value || contrib.payed);

    if(whiteList[msg.sender].payed == false) {
      whiteList[msg.sender].payed = true;
    }

    ethRaised += msg.value;

    uint tokenAmount  = msg.value.div(price);
    tokenAmount += tokenAmount.mul(contrib.bonus).div(100);
    tokenAmount *= 10 ** 18;

    tokenRaised += tokenAmount;

    holdContract.addHolder(msg.sender, tokenAmount, contrib.holdPeriod, contrib.holdTimestamp);
    AddedToHolder(msg.sender, tokenAmount, contrib.holdPeriod, contrib.holdTimestamp);
    FundTransfered(msg.sender, msg.value);
  }

  function getBalanceContract() view internal returns (uint) {
    return token.balanceOf(this);
  }

  function sendTokensToHold() public onlyOwner {
    require(state == SaleState.ENDED);

    require(getBalanceContract() >= tokenRaised);

    if (token.transfer(holdContract, tokenRaised )) {
      tokensTransferredToHold = true;
      TokensTransferedToHold(holdContract, tokenRaised );
    }
  }

  function getTokensBack() public onlyOwner {
    require(state == SaleState.ENDED);
    require(tokensTransferredToHold == true);
    uint balance;
    balance = getBalanceContract() ;
    token.transfer(msg.sender, balance);
  }

  function withdrawEth() public {
    require(this.balance != 0);
    require(state == SaleState.ENDED);
    require(msg.sender == wallet);
    require(tokensTransferredToHold == true);
    uint bal = this.balance;
    wallet.transfer(bal);
    WithdrawedEthToWallet(bal);
  }

  function setEndSaleDate(uint date) public onlyOwner {
    require(state == SaleState.NEW);
    require(date > now);
    uint oldEndDate = endSaleDate;
    endSaleDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }

  function setEndDate(uint date) public onlyOwner {
    require(state == SaleState.NEW || state == SaleState.SALE);
    require(date > now);
    uint oldEndDate = endDate;
    endDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }

  function getTokenBalance() public constant returns (uint) {
    return token.balanceOf(this);
  }

  function getEthRaised() constant external returns (uint) {
    return ethRaised;
  }
}
