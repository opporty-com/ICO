pragma solidity ^0.4.13;
import "./SafeMath.sol";
import "./OpportyToken.sol";
import "./Pausable.sol";

contract OpportySale is Pausable {

    using SafeMath for uint256;

    OpportyToken token;

    uint public SOFTCAP;
    uint public HARDCAP;
    uint public startDate;
    uint public endDate;
    uint public price;
    uint public ethRaised;
    uint public totalTokens;
    uint public withdrawedTokens;
    uint public pendingEthWithdrawal;
    address public wallet;

    uint private firstBonusPhase;
    uint private firstExtraBonus;
    uint private secondBonusPhase;
    uint private secondExtraBonus;
    uint private thirdBonusPhase;
    uint private thirdExtraBonus;
    uint private fourBonusPhase;
    uint private fourExtraBonus;

    uint private minimumTokensToStart = 480000000 * (10 ** 18);

    struct ContributorData {
      bool isActive;
      uint contributionAmount;
      uint tokensIssued;
    }

    enum SaleState { NEW, SALE, ENDED }

    mapping(address => ContributorData) public contributorList;
    uint private nextContributorIndex;
    uint private nextContributorToClaim;
    uint private nextContributorToTransferTokens;

    mapping(uint => address) contributorIndexes;
    mapping(address => bool) hasClaimedEthWhenFail;
    mapping(address => bool) hasWithdrawedTokens;

    event CrowdsaleStarted(uint blockNumber);
    event CrowdsaleEnded(uint blockNumber);
    event SoftCapReached(uint blockNumber);
    event HardCapReached(uint blockNumber);
    event FundTransfered(address contrib, uint amount);
    event TokensTransfered(address contributor , uint amount);
    event Refunded(address ref, uint amount);
    event ErrorSendingETH(address to, uint amount);

    SaleState state;

    function OpportySale(address tokenAddress, address walletAddress, uint start, uint end)
    {
      token = OpportyToken(tokenAddress);
      state = SaleState.NEW;
      SOFTCAP  = 1000 * 1 ether;
      HARDCAP = 80000 * 1 ether;
      price = 0.0002 * 1 ether;
      startDate = start;
      endDate = end;

      firstBonusPhase = startDate.add(1 days);
      firstExtraBonus = 20;

      secondBonusPhase = startDate.add(3 days);
      secondExtraBonus = 15;

      thirdBonusPhase = startDate.add(8 days);
      thirdExtraBonus = 10;

      fourBonusPhase = startDate.add(14 days);
      fourExtraBonus = 5;

      wallet = walletAddress;
    }

    function getSaleStatus() constant returns (uint) {
      return uint(state);
    }

    function setStartDate(uint date) onlyOwner
    {
      require(state == SaleState.NEW);
      startDate = date;
      firstBonusPhase = startDate.add(1 days);
      secondBonusPhase = startDate.add(3 days);
      thirdBonusPhase = startDate.add(8 days);
      fourBonusPhase = startDate.add(14 days);
    }

    function setEndDate(uint date) onlyOwner
    {
      require(state == SaleState.NEW || state == SaleState.SALE);
      endDate = date;
    }

    function setSoftCap(uint softCap) onlyOwner
    {
      require(state == SaleState.NEW);
      SOFTCAP = softCap;
    }

    function setHardCap(uint hardCap) onlyOwner
    {
      require(state == SaleState.NEW);
      HARDCAP = hardCap;
    }

    function() whenNotPaused public payable
    {
      require(msg.value != 0);
      require(msg.value >= (0.5 * 1 ether));
      if (state == SaleState.ENDED) {
        revert();
      }

      bool stateChanged = checkCrowdsaleState();

      if(state == SaleState.SALE) {
        processTransaction(msg.sender, msg.value);    // Process transaction and issue tokens
      }
      else {
        refundTransaction(stateChanged);              // Set state and return funds or throw
      }
    }

    function checkBalanceContract() internal returns (uint) {
      return token.balanceOf(this);
    }

    function checkCrowdsaleState() internal returns (bool) {

      if (ethRaised >= HARDCAP && state != SaleState.ENDED) {
        state = SaleState.ENDED;
        HardCapReached(block.number); // Close the crowdsale
        CrowdsaleEnded(block.number);
        return true;
      }

      if(now > startDate && now <= endDate) {
        if (state != SaleState.SALE && checkBalanceContract() >= minimumTokensToStart ) {
          state = SaleState.SALE;
          CrowdsaleStarted(block.number);
          return true;
        }
      } else {
        if (state != SaleState.ENDED && now > endDate){        // Check if crowdsale is over
          state = SaleState.ENDED;                                                  // Set new state
          CrowdsaleEnded(block.number);                                                           // Raise event
          return true;
        }
      }

      return false;
    }

    function processTransaction(address _contributor, uint _amount) internal {
      uint maxContribution = calculateMaxContribution();
      uint contributionAmount = _amount;
      uint returnAmount = 0;

      if (maxContribution < _amount) {
        contributionAmount = maxContribution;
        returnAmount = _amount - maxContribution;
      }

      if (ethRaised + contributionAmount > SOFTCAP && SOFTCAP > ethRaised) SoftCapReached(block.number);

      if (contributorList[_contributor].isActive == false) {
        contributorList[_contributor].isActive = true;

        contributorList[_contributor].contributionAmount = contributionAmount;
        contributorIndexes[nextContributorIndex] = _contributor;
        nextContributorIndex++;
      }
      else {
        contributorList[_contributor].contributionAmount += contributionAmount;
      }
      ethRaised += contributionAmount;

      FundTransfered(_contributor, contributionAmount);

      uint tokenAmount = contributionAmount.div(price);
      uint timeBonus = calculateBonusForHours(tokenAmount);

      if (tokenAmount > 0) {
        contributorList[_contributor].tokensIssued += tokenAmount.add(timeBonus);
        totalTokens += tokenAmount.add(timeBonus);
      }
      if (returnAmount != 0) _contributor.transfer(returnAmount);
    }

    function calculateBonusForHours(uint256 _tokens) internal returns(uint256) {
      if (now >= startDate && now <= firstBonusPhase ) {
        return _tokens.mul(firstExtraBonus).div(100);
      }

      if (now > startDate && now <= secondBonusPhase ) {
        return _tokens.mul(secondExtraBonus).div(100);
      }

      if (now > startDate && now <= thirdBonusPhase ) {
        return _tokens.mul(thirdExtraBonus).div(100);
      }

      if (now > startDate && now <= fourBonusPhase ) {
        return _tokens.mul(fourExtraBonus).div(100);
      }

      return 0;
    }

    function getTokens() whenNotPaused {
      require(now > endDate && ethRaised > SOFTCAP);
      require(state == SaleState.ENDED);
      require(contributorList[msg.sender].tokensIssued > 0);
      require(!hasWithdrawedTokens[msg.sender]);

      uint tokenCount = contributorList[msg.sender].tokensIssued;

      if (token.transfer(msg.sender, tokenCount)) {
        TokensTransfered(msg.sender , tokenCount);
        withdrawedTokens += tokenCount;
        contributorList[msg.sender].tokensIssued = 0;
        hasWithdrawedTokens[msg.sender] = true;
      }

    }

    function batchReturnTokens(uint _numberOfReturns) onlyOwner whenNotPaused {
      require(now > endDate && ethRaised > SOFTCAP);
      require(state == SaleState.ENDED);

      address currentParticipantAddress;

      uint tokensCount;

      for (uint cnt = 0; cnt < _numberOfReturns; cnt++) {
        currentParticipantAddress = contributorIndexes[nextContributorToTransferTokens];
        if (currentParticipantAddress == 0x0) return;
        if (!hasWithdrawedTokens[currentParticipantAddress]) {
          tokensCount = contributorList[currentParticipantAddress].tokensIssued;
          hasWithdrawedTokens[currentParticipantAddress] = true;
          if (token.transfer(currentParticipantAddress, tokensCount)) {
              TokensTransfered(currentParticipantAddress , tokensCount);
            withdrawedTokens += tokensCount;
            contributorList[currentParticipantAddress].tokensIssued = 0;
            hasWithdrawedTokens[msg.sender] = true;
          }
        }
        nextContributorToTransferTokens += 1;
      }

    }

    function claimEthIfFailed() whenNotPaused {
      require(now > endDate && ethRaised < SOFTCAP);
      require(contributorList[msg.sender].contributionAmount > 0);
      require(!hasClaimedEthWhenFail[msg.sender]);

      uint ethContributed = contributorList[msg.sender].contributionAmount;
      hasClaimedEthWhenFail[msg.sender] = true;
      if (!msg.sender.send(ethContributed)) {
        ErrorSendingETH(msg.sender, ethContributed);
      } else {
        Refunded(msg.sender, ethContributed);
      }
    }

    function batchReturnEthIfFailed(uint _numberOfReturns) onlyOwner whenNotPaused {
      require(now > endDate && ethRaised < SOFTCAP);
      address currentParticipantAddress;
      uint contribution;
      for (uint cnt = 0; cnt < _numberOfReturns; cnt++) {
        currentParticipantAddress = contributorIndexes[nextContributorToClaim];
        if (currentParticipantAddress == 0x0) return;
        if (!hasClaimedEthWhenFail[currentParticipantAddress]) {
          contribution = contributorList[currentParticipantAddress].contributionAmount;
          hasClaimedEthWhenFail[currentParticipantAddress] = true;

          if (!currentParticipantAddress.send(contribution)){
            ErrorSendingETH(currentParticipantAddress, contribution);
          } else {
            Refunded(currentParticipantAddress, contribution);
          }
        }
        nextContributorToClaim += 1;
      }
    }

    function withdrawEth()   {
      require(this.balance != 0);
      require(ethRaised >= SOFTCAP);

      require(msg.sender == wallet);

      wallet.transfer(this.balance);
    }

    function refundTransaction(bool _stateChanged) internal {
      if (_stateChanged) {
         msg.sender.transfer(msg.value);
       }else{
         revert();
       }
    }

    function withdrawRemainingBalanceForManualRecovery() onlyOwner  {
      require(this.balance != 0);
      require(now > endDate);
      require(contributorIndexes[nextContributorToClaim] == 0x0);
      wallet.transfer(this.balance);
    }

    function getAccountsNumber() constant returns (uint) {
      return nextContributorIndex;
    }

    function getEthRaised() constant returns (uint) {
      return ethRaised;
    }

    function getTokensTotal() constant returns (uint) {
      return totalTokens;
    }

    function getWithdrawedToken() constant returns (uint) {
      return withdrawedTokens;
    }

    function calculateMaxContribution() constant returns (uint) {
       return HARDCAP - ethRaised;
    }
}
