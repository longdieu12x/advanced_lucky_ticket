const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
	expectRevert,
	send,
	time, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");
const { Contract } = require("ethers");
// this is function for testing
// start testing
async function mineNBlocks(n) {
	for (let index = 0; index < n; index++) {
		await ethers.provider.send("evm_mine");
	}
}
describe("Dao", () => {
	let daoContract;
	let nftContract;
	let lotteryContract;
	let owner;
	let addr1;
	let addrs;
	beforeEach(async () => {
		[owner, addr1, ...addrs] = await ethers.getSigners();
		const FlashNFT = await ethers.getContractFactory("FlashNFT");
		nftContract = await FlashNFT.deploy("i'm image");
		const DaoNFT = await ethers.getContractFactory("FlashDao");
		daoContract = await DaoNFT.deploy(nftContract.address);
		const Lottery = await ethers.getContractFactory("Lottery");
		lotteryContract = await Lottery.deploy(
			50000,
			86400,
			"0xe42B1F6BE2DDb834615943F2b41242B172788E7E"
		);
		await nftContract.setValidTarget(owner.address, true);
		await nftContract.mintValidTarget(100);
		await nftContract.setValidTarget(addr1.address, true);
		await nftContract.connect(addr1).mintValidTarget(50);
		await nftContract.connect(addr1).delegate(addr1.address);
		await nftContract.delegate(owner.address);
	});
	xit("Deployed successfully", async () => {
		console.log("Address of nft address is ", nftContract.address);
		console.log("Address of flash dao address is ", daoContract.address);
	});
	xit("Test mint nft", async () => {
		let balanceUser = parseInt(await nftContract.balanceOf(owner.address));
		expect(balanceUser).to.be.eq(100);
	});
	xit("Get current vote", async () => {
		const ownerVotes = await nftContract.getVotes(owner.address);
		const blockNow = await time.latestBlock();
		expect(parseInt(ownerVotes)).to.be.eq(100);
	});
	xit("Create propose and expired it!", async () => {
		let lotteryABI = ["function setTicketFee(uint _ticketFee) public"];
		let ILottery = new ethers.utils.Interface(lotteryABI);
		let lotteryHashCallData = ILottery.encodeFunctionData("setTicketFee", [50]);
		const lotteryAddress = lotteryContract.address;
		const proposal_hash = await daoContract.hashProposal(
			lotteryAddress,
			0,
			lotteryHashCallData,
			ethers.utils.keccak256(
				ethers.utils.hexlify(ethers.utils.toUtf8Bytes("test set ticket fee"))
			)
		);
		const timer = await time.latestBlock();

		await daoContract.propose(
			lotteryAddress,
			0,
			lotteryHashCallData,
			"test set ticket fee"
		);
		const stateProposal = await daoContract.state(proposal_hash);
		console.log(`Proposal state: ${stateProposal}`);
		expect(parseInt(stateProposal)).to.be.eq(0);
		await daoContract.castVote(proposal_hash, 0);
		await daoContract.connect(addr1).castVote(proposal_hash, 1);
		// proposal se thua o day
		const proposalDeadline = await daoContract.proposalDeadline(proposal_hash);
		await mineNBlocks(1200);
		console.log(
			(await daoContract.getBlockNumber()).toString(),
			proposalDeadline.toString()
		);
		const defeatStateProposal = await daoContract.state(proposal_hash);
		expect(parseInt(defeatStateProposal)).to.be.eq(4);
	});
	xit("Create propose and execute it!", async () => {
		let lotteryABI = ["function setTicketFee(uint _ticketFee) public"];
		let ILottery = new ethers.utils.Interface(lotteryABI);
		let lotteryHashCallData = ILottery.encodeFunctionData("setTicketFee", [50]);
		const lotteryAddress = lotteryContract.address;
		const proposal_hash = await daoContract.hashProposal(
			lotteryAddress,
			0,
			lotteryHashCallData,
			ethers.utils.keccak256(
				ethers.utils.hexlify(ethers.utils.toUtf8Bytes("test set ticket fee"))
			)
		);
		const timer = await time.latestBlock();

		await daoContract.propose(
			lotteryAddress,
			0,
			lotteryHashCallData,
			"test set ticket fee"
		);
		const stateProposal = await daoContract.state(proposal_hash);
		console.log(`Proposal state: ${stateProposal}`);
		expect(parseInt(stateProposal)).to.be.eq(0);
		await daoContract.castVote(proposal_hash, 1);
		await daoContract.connect(addr1).castVote(proposal_hash, 0);
		// proposal se thua o day
		const proposalDeadline = await daoContract.proposalDeadline(proposal_hash);
		await mineNBlocks(1200);
		console.log(
			(await daoContract.getBlockNumber()).toString(),
			proposalDeadline.toString()
		);
		const defeatStateProposal = await daoContract.state(proposal_hash);
		expect(parseInt(defeatStateProposal)).to.be.eq(3);
		// this state is going to queue

		// get proposal for rate
		let percentage = await daoContract.proposalForRate(proposal_hash);
		expect(parseInt(percentage)).to.be.eq(66);
		await daoContract.setFirstFinalProposal();

		const votes = await daoContract.proposalVotes(proposal_hash);
		const { forVotes, againstVotes, votedAddress } = votes;
		console.log("ForVotes:", forVotes.toString());
		console.log("Against:", againstVotes.toString());
		console.log("Voted address", votedAddress);
		await daoContract.castVote(proposal_hash, 1);
		await daoContract.connect(addr1).castVote(proposal_hash, 1);
		let percentage2 = await daoContract.proposalForRate(proposal_hash);
		expect(parseInt(percentage2)).to.be.eq(100);
		const votes2 = await daoContract.proposalVotes(proposal_hash);
		const {
			forVotes: forVotes2,
			againstVotes: againstVotes2,
			votedAddress: votedAddress2,
		} = votes2;
		console.log("ForVotes:", forVotes2.toString());
		console.log("Against:", againstVotes2.toString());
		console.log("Voted address", votedAddress2);
		await mineNBlocks(1200);
		const successStateProposal = await daoContract.state(proposal_hash);
		console.log("Do i success? ", successStateProposal);
		expect(parseInt(successStateProposal)).to.be.eq(2);
		let finalProposalId = await daoContract._finalProposalId();
		console.log("proposal id:", finalProposalId);
		expect(parseInt(finalProposalId)).to.be.eq(parseInt(proposal_hash));
		await daoContract.execute(
			lotteryAddress,
			0,
			lotteryHashCallData,
			ethers.utils.keccak256(
				ethers.utils.hexlify(ethers.utils.toUtf8Bytes("test set ticket fee"))
			)
		);
		const executeStateProposal = await daoContract.state(proposal_hash);
		console.log("Do i execute? ", executeStateProposal);
		const ticketFee = await lotteryContract.ticketFee();
		console.log(ticketFee);
	});
	it("Create propose and defeat it!", async () => {
		let lotteryABI = ["function setTicketFee(uint _ticketFee) public"];
		let ILottery = new ethers.utils.Interface(lotteryABI);
		let lotteryHashCallData = ILottery.encodeFunctionData("setTicketFee", [50]);
		const lotteryAddress = lotteryContract.address;
		const proposal_hash = await daoContract.hashProposal(
			lotteryAddress,
			0,
			lotteryHashCallData,
			ethers.utils.keccak256(
				ethers.utils.hexlify(ethers.utils.toUtf8Bytes("test set ticket fee"))
			)
		);
		await daoContract.propose(
			lotteryAddress,
			0,
			lotteryHashCallData,
			"test set ticket fee"
		);
		const stateProposal = await daoContract.state(proposal_hash);
		console.log(`Proposal state: ${stateProposal}`);
		expect(parseInt(stateProposal)).to.be.eq(0);
		await daoContract.castVote(proposal_hash, 1);
		await daoContract.connect(addr1).castVote(proposal_hash, 0);
		// proposal se thua o day
		const proposalDeadline = await daoContract.proposalDeadline(proposal_hash);
		await mineNBlocks(1200);
		console.log(
			(await daoContract.getBlockNumber()).toString(),
			proposalDeadline.toString()
		);
		const queueStateProposal = await daoContract.state(proposal_hash);
		expect(parseInt(queueStateProposal)).to.be.eq(3);
		// this state is going to queue

		// get proposal for rate
		let percentage = await daoContract.proposalForRate(proposal_hash);
		expect(parseInt(percentage)).to.be.eq(66);
		await daoContract.setFirstFinalProposal();

		await daoContract.castVote(proposal_hash, 0);
		await daoContract.connect(addr1).castVote(proposal_hash, 1);

		await mineNBlocks(1200);
		const defeatStateProposal = await daoContract.state(proposal_hash);
		console.log("Do i defeat? ", defeatStateProposal);
		expect(parseInt(defeatStateProposal)).to.be.eq(1);
	});
});
