const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
	expectRevert,
	send,
	time, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");
/**
 * @dev All of test here already test for all case
 * However I can't test whether transfer money is working ok
 * but i think it worked perfectly
 *
 */
describe("Lottery", () => {
	let lotteryContract;
	let owner;
	let addr1;
	let addrs;
	let totalTicketPerPeriod;
	let period;
	let daoTreasury;
	beforeEach(async function () {
		[owner, addr1, daoTreasury, ...addrs] = await ethers.getSigners();
		const Lottery = await ethers.getContractFactory("Lottery");
		totalTicketPerPeriod = 50000;
		period = 86400;
		lotteryContract = await Lottery.deploy(
			totalTicketPerPeriod,
			period,
			daoTreasury.address
		);
		await send.ether(owner.address, lotteryContract.address, 15);
	});
	it("Get address", async () => {
		console.log("Address contract is ", lotteryContract.address);
	});
	it("Get random number", async () => {
		console.log(
			"Random number is ",
			(await lotteryContract.generateRandomNumber(145)).toString()
		);
	});
	it("Set ticket fee", async () => {
		await lotteryContract.setTicketFee(15);
		let fee = await lotteryContract.ticketFee();
		expect(fee).to.be.equal(15);
	});
	it("Set period successfully", async () => {
		await lotteryContract.setPeriod(432000);
		let lotteryPeriod = await lotteryContract.period();
		expect(lotteryPeriod).to.be.equal(432000);
	});
	it("Test rolling ticket 2 times", async () => {
		await lotteryContract.resetWheel();
		expectRevert(lotteryContract.resetWheel(), "Not right time for rolling");
		await time.increase(432000);
		lotteryContract.resetWheel();
	});
	it("Test buy ticket and after rolling ticket is reseted and we have ticket lose", async () => {
		await lotteryContract.buyTicket(35, {
			value: 1000000000000000,
		});
		await lotteryContract.randomTicketLucky();
		await lotteryContract.randomTicketLucky();
		await lotteryContract.randomTicketLucky();
		await lotteryContract.randomTicketLucky();
		await lotteryContract.randomTicketLucky();
		await lotteryContract.randomTicketJacket();
		let luckyOwner = await lotteryContract.ownerWinningLuckyTicket(
			0,
			owner.address
		);

		let jacketOwner = await lotteryContract.ownerWinningJacketTicket(
			0,
			owner.address
		);
		let totalTicketLose = await lotteryContract.getTotalTicketLose();
		let totalTicketLoseAvailable =
			await lotteryContract.getTotalTicketLoseAvailable();
		expect(parseInt(totalTicketLose)).to.eq(29);
		expect(parseInt(totalTicketLoseAvailable)).to.eq(0);
		expect(luckyOwner).to.eq(5);
		expect(jacketOwner).to.eq(1);
		await lotteryContract.resetWheel();
		totalTicketLoseAvailable =
			await lotteryContract.getTotalTicketLoseAvailable();
		expect(totalTicketLoseAvailable).to.eq(29);
		let balanceContractBefore = await lotteryContract.getBalanceContract();
		await lotteryContract.claimJacket();
		let balanceContract = await lotteryContract.getBalanceContract();
		expect(-parseInt(balanceContract) + parseInt(balanceContractBefore)).to.eq(
			100000
		);

		balanceContractBefore = await lotteryContract.getBalanceContract();
		await lotteryContract.claimLucky();
		balanceContract = await lotteryContract.getBalanceContract();
		expect(-parseInt(balanceContract) + parseInt(balanceContractBefore)).to.eq(
			25000
		);

		balanceContractBefore = await lotteryContract.getBalanceContract();
		await lotteryContract.claimRewards();
		balanceContract = await lotteryContract.getBalanceContract();
		expect(-parseInt(balanceContract) + parseInt(balanceContractBefore)).to.eq(
			29000
		);
	});
	it("Buy Ticket", async () => {
		await expectRevert(
			lotteryContract.buyTicket(35, {
				value: 1000,
			}),
			"Not enough fee"
		);
		await expectRevert(
			lotteryContract.buyTicket(51, {
				value: 100000,
			}),
			"Overallowance ticket per period"
		);
		await lotteryContract.buyTicket(35, {
			value: 35000 + 35 * 15,
		});
		let ticketBought = await lotteryContract.users(owner.address, 0);
		expect(ticketBought).to.be.equal(35);
		await lotteryContract.buyTicket(4, {
			value: 4000 + 15 * 4,
		});
		ticketBought = await lotteryContract.users(owner.address, 0);
		expect(ticketBought).to.be.equal(39);
		await expectRevert(
			lotteryContract.buyTicket(12, {
				value: 100000,
			}),
			"Overallowance ticket per period"
		);
	});
});
