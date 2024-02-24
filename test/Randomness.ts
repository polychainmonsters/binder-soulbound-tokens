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

    // should not be able to commit randomness after the duration
    it("should not be able to commit randomness after the duration", async () => {
      const { randomness } = await loadFixture(deployFixture);

      const duration = 5 * 60;
      const { requestId, requestTimestamp } = await requestRandomness(
        randomness,
        duration
      );

      await ethers.provider.send("evm_increaseTime", [duration + 1]);

      // create a random uint256 value
      const randomValue = ethers.toBigInt(ethers.randomBytes(32));

      // hash it via the contract
      const hash = await randomness.hash(randomValue);

      // we commit the hash
      await expect(
        randomness.commitRandomness(requestId, hash)
      ).to.be.revertedWith("commit period over");
    });

    // should be able to reveal randomness, but only after the commit period is over
    it("should be able to reveal randomness, but only after the commit period is over", async () => {
      const { randomness } = await loadFixture(deployFixture);

      const { requestId } = await requestRandomness(randomness);

      const randoms = [];

      for (let i = 0; i < 10; i++) {
        // create a random uint256 value
        const randomValue = ethers.toBigInt(ethers.randomBytes(32));
        randoms.push(randomValue);

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

      // we increase the time
      await ethers.provider.send("evm_increaseTime", [300]);

      for (let i = 0; i < 10; i++) {
        await randomness.revealRandomness(requestId, randoms[i]);
      }
    });

    // should not be able to reveal before the reveal period
    it("should not be able to reveal before the reveal period", async () => {
      const { randomness } = await loadFixture(deployFixture);

      const { requestId } = await requestRandomness(randomness);

      const randomValue = ethers.toBigInt(ethers.randomBytes(32));

      await expect(
        randomness.revealRandomness(requestId, randomValue)
      ).to.be.revertedWith("commit period not over");
    });

    // should not be able to reveal after the reveal period
    it("should not be able to reveal after the reveal period", async () => {
      const { randomness } = await loadFixture(deployFixture);

      const { requestId } = await requestRandomness(randomness);

      const randomValue = ethers.toBigInt(ethers.randomBytes(32));

      const hash = await randomness.hash(randomValue);
      await randomness.commitRandomness(requestId, hash);

      // that ends the commit period
      await ethers.provider.send("evm_increaseTime", [300]);

      // and that ends the reveal period
      await ethers.provider.send("evm_increaseTime", [300]);

      await expect(
        randomness.revealRandomness(requestId, randomValue)
      ).to.be.revertedWith("reveal period is over");
    });

    // should not be able to reveal with a invalid random number
    it("should not be able to reveal with a invalid random number", async () => {
      const { randomness } = await loadFixture(deployFixture);

      const { requestId } = await requestRandomness(randomness);

      const randomValue = ethers.toBigInt(ethers.randomBytes(32));

      const hash = await randomness.hash(randomValue);
      await randomness.commitRandomness(requestId, hash);

      // that ends the commit period
      await ethers.provider.send("evm_increaseTime", [300]);

      const fakeRandomValue = ethers.toBigInt(ethers.randomBytes(32));

      await expect(
        randomness.revealRandomness(requestId, fakeRandomValue)
      ).to.be.revertedWith("randomness hash does not exist");
    });
  });
});
