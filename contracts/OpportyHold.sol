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
	uint public secondAllocation;
	uint public firstThawDate;
	uint public secondThawDate;
	bool public firstUnlocked;

	function OpportyHold(
		address _OppToken,
		address _postFreezeDestination,
    uint firstDate,
    uint secondDate
	) {
		OppToken = _OppToken;
		postFreezeDestination = _postFreezeDestination;

		firstThawDate = now + firstDate * 1 days;  // One year from now
		secondThawDate = now +  secondDate * 1 days;  // Two years from now

		firstUnlocked = false;
	}

	function unlockFirst() external {
		if (firstUnlocked) revert();
		if (msg.sender != postFreezeDestination) revert();
		if (now < firstThawDate) revert();

		firstUnlocked = true;

		uint totalBalance = OpportyToken(OppToken).balanceOf(this);

		firstAllocation = totalBalance.div(2);
		secondAllocation = totalBalance.sub(firstAllocation);

		uint tokens = firstAllocation;
		firstAllocation = 0;

		OpportyToken(OppToken).transfer(msg.sender, tokens);
	}

	function unlockSecond() external {
		if (!firstUnlocked) revert();
		if (msg.sender != postFreezeDestination) revert();
		if (now < secondThawDate) revert();

		uint tokens = secondAllocation;
		secondAllocation = 0;

		OpportyToken(OppToken).transfer(msg.sender, tokens);
	}

	function changeDestinationAddress(address _newAddress) external {
		if (msg.sender != postFreezeDestination) revert();
		postFreezeDestination = _newAddress;
	}
  
}
