pragma solidity ^0.4.18;

import "./OpportyToken.sol";
import "./Pausable.sol";
import "./OpportyWhiteListHold.sol";
import "./OpportyPresale.sol";

contract OpportyWhiteList is Pausable {
  using SafeMath for uint256;

  OpportyToken public token;

  OpportyWhiteListHold public holdContract;
  OpportyPresale       public preSaleContract;

  enum SaleState  { NEW, SALE, ENDED }
  SaleState public state;

  uint public endDate;
  uint public endSaleDate;
  uint public minimalContribution;

  // address where funds are collected
  address private wallet;

  address private preSaleOld;

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
  event AddedToHolder(address sender, uint tokenAmount, uint8 holdPeriod, uint holdTimestamp);
  event ManualPriceChange(uint beforePrice, uint afterPrice);
  event ChangeMinAmount(uint oldMinAmount, uint minAmount);

  event TokenChanged(address newAddress);

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

  mapping (uint => address) private assetOwners;
  mapping (address => uint) private assetOwnersIndex;
  uint public assetOwnersIndexes;

  modifier onlyAssetsOwners() {
    require(assetOwnersIndex[msg.sender] > 0);
    _;
  }

  /* constructor */
  function OpportyWhiteList(
    address walletAddress,
    uint end,
    uint endSale,
    address holdCont) public
  {
    state = SaleState.NEW;
    endDate = end;
    endSaleDate = endSale;
    price = 0.0002 * 1 ether;
    wallet = walletAddress;
    minimalContribution = 0.3 * 1 ether;

    holdContract = OpportyWhiteListHold(holdCont);
    addAssetsOwner(msg.sender);
  }

  function setOldPresaleContract(address presaleContract) public onlyOwner {
    preSaleContract = OpportyPresale(presaleContract);
  }

  function setToken(address newToken) public onlyOwner {
    token = OpportyToken(newToken);
    TokenChanged(token);
  }

  function startPresale() public onlyOwner {
    state = SaleState.SALE;
    SaleStarted(block.number);
  }

  function endPresale() public onlyOwner {
    state = SaleState.ENDED;
    SaleEnded(block.number);
  }

  function addToWhitelist(address inv, uint amount, uint8 holdPeriod, uint8 bonus) public onlyAssetsOwners {
    require(state == SaleState.NEW || state == SaleState.SALE);
    require(holdPeriod >= 1);
    require(amount >= minimalContribution);

    if (whiteList[inv].isActive == false) {
      whiteList[inv].isActive = true;
      whiteList[inv].payed = false;
      whitelistIndexes[whitelistIndex] = inv;
      whitelistIndex++;
    }

    whiteList[inv].invAmount = amount;
    whiteList[inv].holdPeriod = holdPeriod;
    whiteList[inv].bonus = bonus;

    whiteList[inv].holdTimestamp = endSaleDate.add(whiteList[inv].holdPeriod * 30 days); 
    
    AddedToWhiteList(inv, whiteList[inv].invAmount, whiteList[inv].holdPeriod,  whiteList[inv].bonus);
  }

  function() whenNotPaused public payable {
    require(state == SaleState.SALE);
    require(msg.value >= minimalContribution);
    require(whiteList[msg.sender].isActive);

    if (now > endDate) {
      state = SaleState.ENDED;
      msg.sender.transfer(msg.value);
      return;
    }

    WhitelistContributor memory contrib = whiteList[msg.sender];
    require(contrib.invAmount <= msg.value || contrib.payed);

    if (whiteList[msg.sender].payed == false) {
      whiteList[msg.sender].payed = true;
    }

    ethRaised += msg.value;

    uint tokenAmount = msg.value.div(price);
    tokenAmount += tokenAmount.mul(contrib.bonus).div(100);
    tokenAmount *= 10 ** 18;

    tokenRaised += tokenAmount;

    holdContract.addHolder(msg.sender, tokenAmount, contrib.holdPeriod, contrib.holdTimestamp);
    AddedToHolder(msg.sender, tokenAmount, contrib.holdPeriod, contrib.holdTimestamp);
    FundTransfered(msg.sender, msg.value);

    // forward the funds to the wallet
    forwardFunds();
  }

  /**
     * send ether to the fund collection wallet
     * override to create custom fund forwarding mechanisms
     */
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }


  function getBalanceContract() view internal returns (uint) {
    return token.balanceOf(this);
  }

  function sendTokensToHold() public onlyOwner {
    require(state == SaleState.ENDED);

    require(getBalanceContract() >= tokenRaised);

    if (token.transfer(holdContract, tokenRaised)) {
      tokensTransferredToHold = true;
      TokensTransferedToHold(holdContract, tokenRaised);
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

  function setPrice(uint newPrice) public onlyOwner {
    uint oldPrice = price;
    price = newPrice;
    ManualPriceChange(oldPrice, newPrice);
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

  function setMinimalContribution(uint minimumAmount) public onlyOwner {
    uint oldMinAmount = minimalContribution;
    minimalContribution = minimumAmount;
    ChangeMinAmount(oldMinAmount, minimalContribution);
  }

  function getTokenBalance() public constant returns (uint) {
    return token.balanceOf(this);
  }

  function getEthRaised() constant external returns (uint) {
    uint pre = preSaleContract.getEthRaised();
    return pre + ethRaised;
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
