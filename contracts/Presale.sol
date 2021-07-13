// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IKatanainu.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

	/* the maximum amount of tokens to be sold */
	uint256 constant maxGoal = 10000000 * (10**18);
	/* how much has been raised by crowdale (in ETH) */
	uint256 public amountRaised;
	/* how much has been raised by crowdale (in Katanainu) */
	uint256 public amountRaisedKatanainu;

	/* the start & end date of the crowdsale */
	uint256 public start;
	uint256 public deadline;
	uint256 public endOfICO;

	/* there are different prices in different time intervals */
	uint256 constant price = 100000;

	/* the address of the token contract */
	IKatanainu private tokenReward;
	/* the balances (in ETH) of all investors */
	mapping(address => uint256) public balanceOf;
	/* the balances (in Katanainu) of all investors */
	mapping(address => uint256) public balanceOfKatanainu;
	/* indicates if the crowdsale has been closed already */
	bool public presaleClosed = false;
	/* notifying transfers and the success of the crowdsale*/
	event GoalReached(address beneficiary, uint256 amountRaised);
	event FundTransfer(address backer, uint256 amount, bool isContribution, uint256 amountRaised);

    /*  initialization, set the token address */
    constructor(IKatanainu _token, uint256 _start, uint256 _dead, uint256 _end) {
        tokenReward = _token;
		start = _start;
		deadline = _dead;
		endOfICO = _end;
    }

    /* invest by sending ether to the contract. */
    receive () external payable {
		if(msg.sender != owner()) //do not trigger investment if the multisig wallet is returning the funds
        	invest();
		else revert();
    }

	function checkFunds(address addr) external view returns (uint256) {
		return balanceOf[addr];
	}

	function checkKatanainuFunds(address addr) external view returns (uint256) {
		return balanceOfKatanainu[addr];
	}

	function getETHBalance() external view returns (uint256) {
		return address(this).balance;
	}

    /* make an investment
    *  only callable if the crowdsale started and hasn't been closed already and the maxGoal wasn't reached yet.
    *  the current token price is looked up and the corresponding number of tokens is transfered to the receiver.
    *  the sent value is directly forwarded to a safe multisig wallet.
    *  this method allows to purchase tokens in behalf of another address.*/
    function invest() public payable {
    	uint256 amount = msg.value;
		require(presaleClosed == false && block.timestamp >= start && block.timestamp < deadline, "Presale is closed");
		require(msg.value >= 2 * 10**17, "Fund is less than 0.2 ETH");

		balanceOf[msg.sender] = balanceOf[msg.sender].add(amount);
		require(balanceOf[msg.sender] <= 2 * 10**18, "Fund is more than 2 ETH");

		amountRaised = amountRaised.add(amount);

		balanceOfKatanainu[msg.sender] = balanceOfKatanainu[msg.sender].add(amount.mul(price));
		amountRaisedKatanainu = amountRaisedKatanainu.add(amount.mul(price));

		if (amountRaisedKatanainu >= maxGoal) {
			presaleClosed = true;
			emit GoalReached(msg.sender, amountRaised);
		}
		
        emit FundTransfer(msg.sender, amount, true, amountRaised);
    }

    modifier afterClosed() {
        require(block.timestamp >= endOfICO, "Distribution is off.");
        _;
    }

	function getKatanainu() external afterClosed nonReentrant {
		require(balanceOfKatanainu[msg.sender] > 0, "Zero ETH contributed.");
		uint256 amount = balanceOfKatanainu[msg.sender];
		uint256 balance = tokenReward.balanceOf(address(this));
		require(balance >= amount, "Contract has less fund.");
		balanceOfKatanainu[msg.sender] = 0;
		tokenReward.transfer(msg.sender, amount);
	}

	function withdrawETH() external onlyOwner afterClosed {
		uint256 balance = this.getETHBalance();
		require(balance > 0, "Balance is zero.");
		address payable payableOwner = payable(owner());
		payableOwner.transfer(balance);
	}

	function withdrawKatanainu() external onlyOwner afterClosed{
		uint256 balance = tokenReward.balanceOf(address(this));
		require(balance > 0, "Balance is zero.");
		tokenReward.transfer(owner(), balance);
	}
}