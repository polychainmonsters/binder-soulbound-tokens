import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

describe("Simple Staking", function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();

    const Mock20 = await ethers.getContractFactory("Mock20");
    const mock20 = await Mock20.deploy();

    const SimpleStaking = await ethers.getContractFactory("SimpleStaking");
    const simpleStaking = await upgrades.deployProxy(SimpleStaking, [
      await mock20.getAddress(),
    ]);
    await simpleStaking.waitForDeployment();

    return {
      simpleStaking,
      owner,
      otherAccount,
      mock20,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { owner, simpleStaking } = await loadFixture(deployFixture);

      expect(await simpleStaking.owner()).to.equal(
        owner.address,
        "Invalid owner"
      );
    });

    // cannot init again after deployment
    it("Should not be able to init again", async function () {
      const { simpleStaking, mock20 } = await loadFixture(deployFixture);

      await expect(
        simpleStaking.initialize(await mock20.getAddress())
      ).to.be.revertedWithCustomError(simpleStaking, "InvalidInitialization");
    });
  });
});
