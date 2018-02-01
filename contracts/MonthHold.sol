pragma solidity ^0.4.18;

import "./OpportyToken.sol";
import "./Pausable.sol";

contract MonthHold is Pausable {
  using SafeMath for uint256;
  OpportyToken public token;

  uint public holdPeriod;
  address public multisig;

  uint public endDate;
  uint public endSaleDate;

  uint private price;

  uint public minimalContribution;

  enum SaleState { NEW, SALE, ENDED }
  SaleState public state;

  mapping (uint => address) private assetOwners;
  mapping (address => uint) private assetOwnersIndex;
  uint public assetOwnersIndexes;

  struct Bonus {
    uint minAmount;
    uint maxAmount;
    uint8 bonus;
  }

  Bonus[]  bonuses;

  struct Holder {
    bool isActive;
    uint tokens;
    uint holdPeriodTimestamp;
    bool withdrawed;
  }

  mapping(address => Holder) public holderList;
  mapping(uint => address) private holderIndexes;
  uint private holderIndex;


  event TokensTransfered(address contributor , uint amount);
  event Hold(address sender, address contributor, uint amount, uint8 holdPeriod);
  event ManualChangeEndDate(uint beforeDate, uint afterDate);
  event ChangeMinAmount(uint oldMinAmount, uint minAmount);
  event BonusChanged(uint minAmount, uint maxAmount, uint8 newBonus);
  event HolderAdded(address addr, uint tokens, uint holdPeriodTimestamp);
  event FundsTransferredToMultisig(address multisig, uint value);
  event SaleNew();
  event SaleStarted();
  event SaleEnded();
  event ManualPriceChange(uint beforePrice, uint afterPrice);
  event HoldChanged(address holder, uint tokens, uint timest);

  modifier onlyAssetsOwners() {
    require(assetOwnersIndex[msg.sender] > 0 || msg.sender == owner);
    _;
  }

  function MonthHold(address tokenAddress, address walletAddress, uint end, uint endSale) public {
    holdPeriod = 30 days;
    token = OpportyToken(tokenAddress);
    state = SaleState.NEW;

    endDate = end;
    endSaleDate = endSale;
    price = 0.0002 * 1 ether;
    multisig = walletAddress;
    minimalContribution = 0.3 * 1 ether;

    bonuses.push(Bonus({minAmount: 0, maxAmount: 50, bonus: 25 }));
    bonuses.push(Bonus({minAmount: 50, maxAmount: 100, bonus: 30 }));
    bonuses.push(Bonus({minAmount: 100, maxAmount: 250, bonus: 35 }));
    bonuses.push(Bonus({minAmount: 250, maxAmount: 500, bonus: 40 }));
    bonuses.push(Bonus({minAmount: 500, maxAmount: 1000, bonus: 45 }));
    bonuses.push(Bonus({minAmount: 1000, maxAmount: 5000, bonus: 55 }));
    bonuses.push(Bonus({minAmount: 5000, maxAmount: 99999999, bonus: 70 }));
  }

  function changeBonus(uint minAmount, uint maxAmount, uint8 newBonus) public {
    bool find = false;
    for (uint i = 0; i < bonuses.length; ++i) {
      if (bonuses[i].minAmount == minAmount && bonuses[i].maxAmount == maxAmount ) {
        bonuses[i].bonus = newBonus;
        find = true;
        break;
      }
    }
    if (!find) {
      bonuses.push(Bonus({minAmount:minAmount, maxAmount: maxAmount, bonus:newBonus}));
    }
    BonusChanged(minAmount, maxAmount, newBonus);
  }

  function getBonus(uint am) public view returns(uint8) {
    uint8 bon = 0;
    am /= 10 ** 18;
    
    for (uint i = 0; i < bonuses.length; ++i) {
        if (am >= bonuses[i].minAmount && am<bonuses[i].maxAmount) 
          bon = bonuses[i].bonus;
    }

    return bon;
  }

  function() public payable {
    require(state == SaleState.SALE);
    require(msg.value >= minimalContribution);

    if (now > endDate) {
      state = SaleState.ENDED;
      msg.sender.transfer(msg.value);
      return ;
    }

    uint tokenAmount = msg.value.div(price);
    tokenAmount += tokenAmount.mul(getBonus(msg.value)).div(100);
    tokenAmount *= 10 ** 18;

    uint holdTimestamp = endSaleDate.add(holdPeriod);
    addHolder(msg.sender, tokenAmount, holdTimestamp);
    HolderAdded(msg.sender, tokenAmount, holdTimestamp);
    
    forwardFunds();
    
  }

  function addHolder(address holder, uint tokens, uint timest) internal {
    if (holderList[holder].isActive == false) {
        holderList[holder].isActive = true;
        holderList[holder].tokens = tokens;
        holderList[holder].holdPeriodTimestamp = timest;
        holderIndexes[holderIndex] = holder;
        holderIndex++;
    } else {
        holderList[holder].tokens += tokens;
        holderList[holder].holdPeriodTimestamp = timest;
    }
  }

  function changeHold(address holder, uint tokens, uint timest) onlyAssetsOwners public {
      if (holderList[holder].isActive == true) {
        holderList[holder].tokens = tokens;
        holderList[holder].holdPeriodTimestamp = timest;
        HoldChanged(holder, tokens, timest);
      }
  }

  function forwardFunds() internal {
    multisig.transfer(msg.value);
    FundsTransferredToMultisig(multisig, msg.value);
  }

  function newPresale() public onlyOwner {
    state = SaleState.NEW;
    SaleNew();
  }

  function startPresale() public onlyOwner {
    state = SaleState.SALE;
    SaleStarted();
  }

  function endPresale() public onlyOwner {
    state = SaleState.ENDED;
    SaleEnded();
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

  function getBalance() public constant returns (uint) {
    return token.balanceOf(this);
  }

  function returnTokens(uint nTokens) public onlyOwner returns (bool) {
    require(nTokens <= getBalance());
    token.transfer(msg.sender, nTokens);
    TokensTransfered(msg.sender, nTokens);
    return true;
  }

  function unlockTokens() public returns (bool) {
    require(holderList[msg.sender].isActive);
    require(!holderList[msg.sender].withdrawed);
    require(now >= holderList[msg.sender].holdPeriodTimestamp);

    token.transfer(msg.sender, holderList[msg.sender].tokens); 
    holderList[msg.sender].withdrawed = true;
    TokensTransfered(msg.sender, holderList[msg.sender].tokens);
    return true;
  }

  function setEndSaleDate(uint date) public onlyOwner {
    uint oldEndDate = endSaleDate;
    endSaleDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }

  function setEndDate(uint date) public onlyOwner {
    uint oldEndDate = endDate;
    endDate = date;
    ManualChangeEndDate(oldEndDate, date);
  }
  
  function setPrice(uint newPrice) public onlyOwner {
    uint oldPrice = price;
    price = newPrice;
    ManualPriceChange(oldPrice, newPrice);
  }

  function setMinimalContribution(uint minimumAmount) public onlyOwner {
    uint oldMinAmount = minimalContribution;
    minimalContribution = minimumAmount;
    ChangeMinAmount(oldMinAmount, minimalContribution);
  }

  function batchChangeHoldPeriod(uint holdedPeriod) public onlyAssetsOwners {
    for (uint i = 0; i < holderIndex; ++i) {
        holderList[holderIndexes[i]].holdPeriodTimestamp = holdedPeriod;
        HoldChanged(holderIndexes[i], holderList[holderIndexes[i]].tokens, holdedPeriod);
    }
  }
  
}