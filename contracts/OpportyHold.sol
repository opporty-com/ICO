pragma solidity ^0.4.15;

import "./SafeMath.sol";
import "./OpportyToken.sol";
import "./Ownable.sol";

contract OpportyHold is Ownable {
	using SafeMath for uint256;

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

	function unlockFirst() external {
		if (firstUnlocked) revert();
		if (msg.sender != postFreezeDestination) revert();
		if (now < firstThawDate) revert();

		firstUnlocked = true;

		uint totalBalance = OpportyToken(OppToken).balanceOf(this);

		OpportyToken(OppToken).transfer(msg.sender, totalBalance);
	}

	function changeDestinationAddress(address _newAddress) external {
		if (msg.sender != postFreezeDestination) revert();
		postFreezeDestination = _newAddress;
	}
  
}
