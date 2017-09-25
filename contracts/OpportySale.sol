pragma solidity ^0.4.13;

import "./OpportyToken.sol";

contract OpportySale {

    OpportyToken token;

    address admin;

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

    uint public firstStage;
    uint public secondStage;
    uint public thirdStage;
    uint public fourthStage;

    struct ContributorData{
      bool isActive;
      uint contributionAmount;
      uint tokensIssued;
    }

    enum SaleState { NEW, SALE, PAUSED, ENDED }

    mapping(address => ContributorData) public contributorList;
    uint public nextContributorIndex;
    uint public nextContributorToClaim;
    uint public nextContributorToTransferTokens;

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

    modifier onlyOwner {
       if (msg.sender != admin) revert();
       _;
    }

    function OpportySale(address tokenAddress, address walletAddress, uint start, uint end)
    {
      token = OpportyToken(tokenAddress);
      admin = msg.sender;
      state = SaleState.NEW;
      SOFTCAP  = 1000 * 1 ether;
      HARDCAP = 80000 * 1 ether;
      price = 0.0002 * 1 ether;
      startDate = start;
      endDate = end;
      firstStage = startDate + 1 days;
      secondStage = startDate + 3 * 1 days;
      thirdStage = startDate + 8 * 1 days;
      fourthStage = startDate + 14 * 1 days;
      wallet = walletAddress;
    }

    function getSaleStatus() constant returns (uint) {
      return uint(state);
    }

    function setStartDate(uint date) onlyOwner
    {
      require(state == SaleState.NEW);
      startDate = date;
      firstStage = startDate + 1 days;
      secondStage = startDate + 3 * 1 days;
      thirdStage = startDate + 8 * 1 days;
      fourthStage = startDate + 14 * 1 days;
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

    function pause() onlyOwner
    {
      require(state == SaleState.SALE);
      state = SaleState.PAUSED;
    }

    function resume() onlyOwner
    {
      require(state == SaleState.PAUSED);
      state = SaleState.SALE;
    }

    function() public payable
    {
      require(msg.value != 0);
      require(state != SaleState.NEW);
      if (state == SaleState.PAUSED || state == SaleState.ENDED) {
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
        if (state != SaleState.SALE && checkBalanceContract() >= 80000 * (10 ** 18) ) {
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

      uint ethToTokenConversion = price;

      if (now < firstStage) {
        ethToTokenConversion += ethToTokenConversion * (uint(1) / uint(5));
      } else if (now < secondStage) {
        ethToTokenConversion += ethToTokenConversion * (uint(3) / uint(20));
      } else if (now < thirdStage) {
        ethToTokenConversion += ethToTokenConversion * (uint(1) / uint(10));
      } else if (now < fourthStage) {
        ethToTokenConversion += ethToTokenConversion * (uint(1) / uint(20));
      }

      uint tokenAmount = contributionAmount * ethToTokenConversion;
      if (tokenAmount > 0) {
        contributorList[_contributor].tokensIssued += tokenAmount;

        totalTokens += tokenAmount;
      }
      if (returnAmount != 0) _contributor.transfer(returnAmount);
    }

    function getTokens() {
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

    function batchReturnTokens(uint _numberOfReturns) onlyOwner {
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

    function claimEthIfFailed() {
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

    function batchReturnEthIfFailed(uint _numberOfReturns) onlyOwner {
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

    function withdrawEth() onlyOwner {
      require(this.balance != 0);
      require(ethRaised >= SOFTCAP);

      pendingEthWithdrawal = this.balance;
    }

    function pullBalance() {
      require(msg.sender == wallet);
      require(pendingEthWithdrawal > 0);

      wallet.transfer(pendingEthWithdrawal);
      pendingEthWithdrawal = 0;
    }

    function refundTransaction(bool _stateChanged) internal {
      if (_stateChanged) {
         msg.sender.transfer(msg.value);
       }else{
         revert();
       }
    }

    function withdrawRemainingBalanceForManualRecovery() onlyOwner {
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
