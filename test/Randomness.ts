import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe.only("Randomness", async () => {
  async function deployFixture() {
    const Randomness = await ethers.getContractFactory("Randomness");
    const randomness = await upgrades.deployProxy(Randomness, []);
    await randomness.waitForDeployment();
    return { randomness };
  }

  describe("deploy", async () => {
    it("Should deploy", async () => {
      const { randomness } = await loadFixture(deployFixture);
      expect(randomness.address).to.not.equal(0);
    });
  });

  describe("request randomness", async () => {
    it("should be able to request randomness", async () => {
      const duration = 5 * 60;

      const { randomness } = await loadFixture(deployFixture);
      const tx = await randomness.requestRandomness(duration);
      const receipt = await tx.wait();

      const requestTimestamp = (await receipt.getBlock()).timestamp;
      const requestId = receipt.logs[0].args[0];

      const request = await randomness.idToRequest(requestId);

      expect(request).to.equal(requestTimestamp + duration);
    });
  });
});
