const hre = require("hardhat");

async function main() {
	const Lottery = await hre.ethers.getContractFactory("Lottery");
	const lottery = await Lottery.deploy(
		50000,
		86400,
		"0xe42B1F6BE2DDb834615943F2b41242B172788E7E"
	);

	await lottery.deployed();

	console.log("Greeter deployed to:", lottery.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
