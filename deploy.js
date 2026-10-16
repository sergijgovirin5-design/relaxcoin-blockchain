const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  const industryWalletAddress = process.env.METAMASK_ADDRESS || "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
  const treasuryWalletAddress = process.env.TREASURY_ADDRESS || industryWalletAddress;

  console.log("=== START DEPLOY OF RELAXCOIN ECOSYSTEM ===");
  console.log("Deployer account:", deployer.address);
  console.log("Industry wallet:", industryWalletAddress);
  console.log("Treasury wallet:", treasuryWalletAddress);

  const RelaxCoin = await hre.ethers.getContractFactory("RelaxCoin");
  const r2r = await RelaxCoin.deploy(industryWalletAddress, treasuryWalletAddress);
  await r2r.waitForDeployment();
  console.log("[1] RelaxCoin deployed at:", await r2r.getAddress());

  const R2RUSD = await hre.ethers.getContractFactory("R2RUSD");
  const stable = await R2RUSD.deploy(deployer.address);
  await stable.waitForDeployment();
  console.log("[2] R2RUSD deployed at:", await stable.getAddress());

  const R2RVault = await hre.ethers.getContractFactory("R2RVault");
  const vault = await R2RVault.deploy(r2r.target, stable.target, hre.ethers.parseUnits("1", 18));
  await vault.waitForDeployment();
  console.log("[3] R2RVault deployed at:", await vault.getAddress());

  await stable.setMinter(await vault.getAddress());
  console.log("-> R2RUSD minter set to R2RVault");

  const R2RStaking = await hre.ethers.getContractFactory("R2RStaking");
  const staking = await R2RStaking.deploy(r2r.target);
  await staking.waitForDeployment();
  console.log("[4] R2RStaking deployed at:", await staking.getAddress());

  await r2r.setStakingContract(await staking.getAddress());
  console.log("-> Staking contract linked to RelaxCoin");

  console.log("\n=== DEPLOY COMPLETE ===");
  console.log(JSON.stringify({
    RelaxCoin: await r2r.getAddress(),
    R2RUSD: await stable.getAddress(),
    R2RVault: await vault.getAddress(),
    R2RStaking: await staking.getAddress(),
    industryWallet: industryWalletAddress,
    treasuryWallet: treasuryWalletAddress
  }, null, 2));
}

main().catch((error) => {
  console.error("Deployment error:", error);
  process.exitCode = 1;
});
