pragma solidity ^0.4.15;

import "./OpportyToken.sol";

contract OpportyHold  {
	// Addresses and contracts
	address public OppToken;
	address public postFreezeDestination;

	// Freezer Data
	uint public firstAllocation;

	uint public firstThawDate;

	bool public firstUnlocked;

	function OpportyHold(
		address _OppToken,
		address _postFreezeDestination,
        uint firstDate
	) {
		OppToken = _OppToken;
		postFreezeDestination = _postFreezeDestination;

		firstThawDate = now + firstDate * 1 days;  // One year from now
		
		firstUnlocked = false;
	}

	function getBalance() constant returns (uint)
    {
      return OpportyToken(OppToken).balanceOf(this);
    }

	function unlockFirst() external {
		require (!firstUnlocked);
		require (msg.sender == postFreezeDestination);
		require (now >= firstThawDate);

		firstUnlocked = true;

		uint totalBalance = OpportyToken(OppToken).balanceOf(this);

		OpportyToken(OppToken).transfer(msg.sender, totalBalance);
	}

	function changeDestinationAddress(address _newAddress) external {
		require (msg.sender == postFreezeDestination);
		postFreezeDestination = _newAddress;
	}
  
}
