import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { Contract } from "ethers";
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
    const requestRandomness = async (
      randomness: Contract,
      duration: number = 300
    ) => {
      const tx = await randomness.requestRandomness(duration);
      await tx.wait();
      const receipt = await tx.wait();

      const requestTimestamp = (await receipt.getBlock()).timestamp;
      const requestId = receipt.logs[0].args[0];

      return { requestId, requestTimestamp };
    };

    it("should be able to request randomness", async () => {
      const duration = 5 * 60;

      const { randomness } = await loadFixture(deployFixture);

      const { requestId, requestTimestamp } = await requestRandomness(
        randomness,
        duration
      );

      const request = await randomness.idToRequest(requestId);

      expect(request[0]).to.equal(requestTimestamp + duration);
      expect(request[1]).to.equal(duration);
    });

    it("should be able to commit randomness", async () => {
      const { randomness } = await loadFixture(deployFixture);

      const { requestId, requestTimestamp } = await requestRandomness(
        randomness
      );

      for (let i = 0; i < 10; i++) {
        // create a random uint256 value
        const randomValue = ethers.toBigInt(ethers.randomBytes(32));

        // hash it via the contract
        const hash = await randomness.hash(randomValue);

        // we commit the hash
        await randomness.commitRandomness(requestId, hash);

        // we check if we successfully committed the hash
        const exists = await randomness.idToRandomnessHashExists(
          requestId,
          hash
        );

        expect(exists).to.equal(1n);
      }
    });
  });
});
