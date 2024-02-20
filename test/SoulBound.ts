import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

describe.only("Soulbound", function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();

    const Mock20 = await ethers.getContractFactory("Mock20");
    const mock20 = await Mock20.deploy();

    const Soulbound = await ethers.getContractFactory("Soulbound");
    const soulbound = await upgrades.deployProxy(Soulbound, []);
    await soulbound.waitForDeployment();

    return {
      soulbound,
      owner,
      otherAccount,
      mock20,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { owner, soulbound } = await loadFixture(deployFixture);

      expect(await soulbound.owner()).to.equal(owner.address, "Invalid owner");
    });

    it("Should set the right symbol", async function () {
      const { soulbound } = await loadFixture(deployFixture);

      expect(await soulbound.symbol()).to.equal("PMBB", "Invalid symbol");
    });

    it("Should set the right name", async function () {
      const { soulbound } = await loadFixture(deployFixture);

      expect(await soulbound.name()).to.equal(
        "Polymon Binder Battles",
        "Invalid name"
      );
    });
  });

  describe("Minting", function () {
    // generate a random address to simulate a user
    const userAddress = ethers.Wallet.createRandom().address;
  });
});
