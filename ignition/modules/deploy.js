const hre = require("hardhat");

async function main() {
    console.log("123123");
    
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying contracts with account: ${deployer.address}`);

  // Deploy KYC Registry
  const KYCRegistry = await hre.ethers.getContractFactory("KYCRegistry");
  const kycRegistry = await KYCRegistry.deploy();
  await kycRegistry.waitForDeployment();
  console.log("KYCRegistry deployed at:",await kycRegistry.getAddress());

//   // Deploy ERC-3643 Token
  const ERC3643Token = await hre.ethers.getContractFactory("ERC3643Token");
  const token = await ERC3643Token.deploy("RWA Token", "RWA", await kycRegistry.getAddress());
  await token.waitForDeployment();
  console.log(`ERC3643Token deployed at: ${await token.getAddress()}`);

//   // Deploy Custodial Wallet
  const CustodialWallet = await hre.ethers.getContractFactory("CustodialWallet");
  const wallet = await CustodialWallet.deploy(kycRegistry.getAddress(), token.getAddress());
  await wallet.waitForDeployment();
  console.log(`CustodialWallet deployed at: ${await wallet.getAddress()}`);

//   // Deploy Marketplace
  const Marketplace = await hre.ethers.getContractFactory("Marketplace");
  const priceFeedAddress = "0x694AA1769357215DE4FAC081bf1f309aDC325306"; // Replace with actual Chainlink price feed
  const marketplace = await Marketplace.deploy(kycRegistry.getAddress(), token.getAddress(), priceFeedAddress);
  await marketplace.waitForDeployment();
  console.log(`Marketplace deployed at: ${await marketplace.getAddress()}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
