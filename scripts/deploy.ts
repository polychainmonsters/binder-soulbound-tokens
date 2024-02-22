import { ethers, upgrades } from "hardhat";

async function main() {
  const SimpleStaking = await ethers.getContractFactory("SimpleStaking");
  const simpleStaking = await upgrades.deployProxy(SimpleStaking, [
    "0xBC9B77acA82f6BE43927076D71cd453b625165B8"
  ]);

  await simpleStaking.waitForDeployment();

  console.log("SimpleStaking deployed to:", await simpleStaking.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
