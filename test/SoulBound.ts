import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { getProof, getTree } from "../utils/merkle-tree";
import { Contract } from "ethers";

describe.only("Soulbound", function () {
  async function deployFixture() {
    const [owner, otherAccount] = await ethers.getSigners();

    const Mock20 = await ethers.getContractFactory("Mock20");
    const mock20 = await Mock20.deploy();

    const Randomness = await ethers.getContractFactory("Randomness");
    const randomness = await upgrades.deployProxy(Randomness, []);
    await randomness.waitForDeployment();

    const Soulbound = await ethers.getContractFactory("Soulbound");
    const soulbound = await upgrades.deployProxy(Soulbound, [
      await randomness.getAddress(),
    ]);
    await soulbound.waitForDeployment();

    // the tokens to mint
    const tokens = [];
    const tokensSecondWeek = [];
    for (let i = 0; i < 10; i++) {
      tokens.push({
        address: ethers.Wallet.createRandom().address,
        points: Math.floor(Math.random() * 100),
        rank: i,
        week: 0,
      });
      tokensSecondWeek.push({
        address: ethers.Wallet.createRandom().address,
        points: Math.floor(Math.random() * 100),
        rank: i,
        week: 1,
      });
    }

    // we add the root for the tokens to the soulbound contract
    const tree = getTree(tokens);
    const root = tree.root;
    await soulbound.addWeeklyRoot(root, 0);

    return {
      soulbound,
      owner,
      otherAccount,
      mock20,
      tokens,
      tokensSecondWeek,
      randomness,
    };
  }

  async function fulfillRandomness(
    randomness: Contract,
    requestId: bigint | string | number,
    duration: bigint | string | number
  ) {
    const randomValue = ethers.toBigInt(ethers.randomBytes(32));

    const hash = await randomness.hash(randomValue);

    await randomness.commitRandomness(requestId, hash);

    // that ends the commit period

    await ethers.provider.send("evm_increaseTime", [
      Number(duration.toString()),
    ]);

    await randomness.revealRandomness(requestId, randomValue);

    // now we end the reveal period and mine a block
    await ethers.provider.send("evm_increaseTime", [
      Number(duration.toString()),
    ]);
    await ethers.provider.send("evm_mine", []);
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

  // mgmt

  describe("Minting", function () {
    it("Can mint token with valid proof", async function () {
      const { soulbound, tokens } = await loadFixture(deployFixture);

      const tree = getTree(tokens);

      const indexToMint = 0;
      const proof = getProof({
        tree,
        receiver: tokens[indexToMint].address,
      });

      expect(await soulbound.balanceOf(tokens[indexToMint].address)).to.equal(
        0
      );

      // expect the mint to succeed
      expect(
        await soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: tokens[indexToMint].week,
          },
          proof!.proof
        )
      ).to.not.be.reverted;

      // expect the balance to be updated
      expect(await soulbound.balanceOf(tokens[indexToMint].address)).to.equal(
        1
      );

      // expect the token to be minted to be the id 0
      expect(await soulbound.ownerOf(0)).to.equal(tokens[indexToMint].address);

      // expect the token to have the right properties
      const token = await soulbound.tokenIdToToken(0);
      expect(token.points).to.equal(tokens[indexToMint].points);
      expect(token.rank).to.equal(tokens[indexToMint].rank);
      expect(token.week).to.equal(tokens[indexToMint].week);
    });

    // Can not mint token with invalid proof
    it("Can not mint token with invalid proof", async function () {
      const { soulbound, tokens } = await loadFixture(deployFixture);

      const tree = getTree(tokens);

      const indexToMint = 0;

      // expect the mint to fail
      await expect(
        soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: tokens[indexToMint].week,
          },
          getProof({
            tree,
            receiver: tokens[indexToMint + 1].address,
          })?.proof
        )
      ).to.be.revertedWith("Invalid proof");

      // expect the balance to be unchanged
      expect(await soulbound.balanceOf(tokens[indexToMint].address)).to.equal(
        0
      );
    });

    // Can not mint a token twice
    it("Can not mint a token twice", async function () {
      const { soulbound, tokens } = await loadFixture(deployFixture);

      const tree = getTree(tokens);

      const indexToMint = 0;
      const proof = getProof({
        tree,
        receiver: tokens[indexToMint].address,
      });

      // expect the mint to succeed
      expect(
        await soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: tokens[indexToMint].week,
          },
          proof!.proof
        )
      ).to.not.be.reverted;

      // expect the attempt to mint the token twice to fail
      await expect(
        soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: tokens[indexToMint].week,
          },
          proof!.proof
        )
      ).to.be.revertedWith("Token already minted");

      // expect the balance to be unchanged
      expect(await soulbound.balanceOf(tokens[indexToMint].address)).to.equal(
        1
      );
    });

    // Can not mint token for a week that has not been added
    it("Can not mint token for a week that has not been added", async function () {
      const { soulbound, tokens } = await loadFixture(deployFixture);

      const tree = getTree(tokens);

      const indexToMint = 0;

      // expect the mint to fail
      await expect(
        soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: 1,
          },
          getProof({
            tree,
            receiver: tokens[indexToMint].address,
          })?.proof
        )
      ).to.be.revertedWith("Invalid proof");
    });

    // Can still mint old tokens if we add a new week
    it("Can still mint old tokens if we add a new week", async function () {
      const { soulbound, tokens, tokensSecondWeek } = await loadFixture(
        deployFixture
      );

      const tree = getTree(tokens);
      const treeSecondWeek = getTree(tokensSecondWeek);

      let indexToMint = 0;

      // we mint a token from the the first week

      expect(
        await soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: tokens[indexToMint].week,
          },
          getProof({
            tree,
            receiver: tokens[indexToMint].address,
          })!.proof
        )
      ).to.not.be.reverted;

      // we add the root for the second week
      const root = treeSecondWeek.root;
      await soulbound.addWeeklyRoot(root, 1);

      // we mint another token from the the first week
      indexToMint = 1;
      expect(
        await soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: tokens[indexToMint].week,
          },
          getProof({
            tree,
            receiver: tokens[indexToMint].address,
          })!.proof
        )
      ).to.not.be.reverted;

      // we mint a token from the the second week
      indexToMint = 3;
      expect(
        await soulbound.mint(
          tokensSecondWeek[indexToMint].address,
          {
            points: tokensSecondWeek[indexToMint].points,
            rank: tokensSecondWeek[indexToMint].rank,
            week: tokensSecondWeek[indexToMint].week,
          },
          getProof({
            tree: treeSecondWeek,
            receiver: tokensSecondWeek[indexToMint].address,
          })!.proof
        )
      ).to.not.be.reverted;
    });

    // Can mint tokens for a new week if we add it
    it("Can mint tokens for a new week if we add it", async function () {
      const { soulbound, tokens, tokensSecondWeek } = await loadFixture(
        deployFixture
      );

      const tree = getTree(tokens);
      const treeSecondWeek = getTree(tokensSecondWeek);

      // we mint a token from the the first week
      let indexToMint = 0;
      expect(
        await soulbound.mint(
          tokens[indexToMint].address,
          {
            points: tokens[indexToMint].points,
            rank: tokens[indexToMint].rank,
            week: tokens[indexToMint].week,
          },
          getProof({
            tree,
            receiver: tokens[indexToMint].address,
          })!.proof
        )
      ).to.not.be.reverted;

      // we add the root for the second week
      const root = treeSecondWeek.root;
      await soulbound.addWeeklyRoot(root, 1);

      // get the balance of the user for the second week
      const balanceBefore = await soulbound.balanceOf(
        tokensSecondWeek[indexToMint].address
      );

      // we mint a token from the the second week
      indexToMint = 0;
      expect(
        await soulbound.mint(
          tokensSecondWeek[indexToMint].address,
          {
            points: tokensSecondWeek[indexToMint].points,
            rank: tokensSecondWeek[indexToMint].rank,
            week: tokensSecondWeek[indexToMint].week,
          },
          getProof({
            tree: treeSecondWeek,
            receiver: tokensSecondWeek[indexToMint].address,
          })!.proof
        )
      ).to.not.be.reverted;

      expect(
        await soulbound.balanceOf(tokensSecondWeek[indexToMint].address)
      ).to.equal(
        balanceBefore + 1n,
        "Invalid balance for the second week after mint"
      );
    });
  });

  describe("Metadata", async function () {
    // get the right metadata for a token
    it("Should get metadata for a token", async function () {
      const { soulbound, tokensSecondWeek } = await loadFixture(deployFixture);

      const tree = getTree(tokensSecondWeek);

      const indexToMint = 5;
      const proof = getProof({
        tree,
        receiver: tokensSecondWeek[indexToMint].address,
      });

      // we add the root for the second week
      await soulbound.addWeeklyRoot(tree.root, 1);

      // expect the mint to succeed
      expect(
        await soulbound.mint(
          tokensSecondWeek[indexToMint].address,
          {
            points: tokensSecondWeek[indexToMint].points,
            rank: tokensSecondWeek[indexToMint].rank,
            week: tokensSecondWeek[indexToMint].week,
          },
          proof!.proof
        )
      ).to.not.be.reverted;

      // expect the token to return a valid uri
      await soulbound.tokenURI(0);

      console.log(tokensSecondWeek[indexToMint]);
      console.log(
        await soulbound.tokenURI((await soulbound.totalSupply()) - 1n)
      );
      console.log(
        await soulbound.tokenIdToToken((await soulbound.totalSupply()) - 1n)
      );
    });
  });

  describe("Raffle", async function () {
    it("upperLookup", async function () {
      // we mint all the tokens
      const { soulbound, tokens } = await loadFixture(deployFixture);

      let totalPoints = 1;
      for (let i = 0; i < tokens.length; i++) {
        const tree = getTree(tokens);
        const proof = getProof({
          tree,
          receiver: tokens[i].address,
        });
        await soulbound.mint(
          tokens[i].address,
          {
            points: tokens[i].points,
            rank: tokens[i].rank,
            week: tokens[i].week,
          },
          proof!.proof
        );

        for (let j = totalPoints; j < totalPoints + tokens[i].points; j++) {
          const lookup = await soulbound.upperLookupTotal(j);

          // it should be the tokenId that we just minted (which is i)
          expect(lookup).to.equal(i);
        }

        totalPoints += tokens[i].points;
      }
    });

    it("adding tokens shouldn't change the request picks", async function () {
      const { soulbound, tokens } = await loadFixture(deployFixture);

      // we mint the first 3 tokens
      let totalPoints = 0;
      for (let i = 0; i < 3; i++) {
        const tree = getTree(tokens);
        const proof = getProof({
          tree,
          receiver: tokens[i].address,
        });
        await soulbound.mint(
          tokens[i].address,
          {
            points: tokens[i].points,
            rank: tokens[i].rank,
            week: tokens[i].week,
          },
          proof!.proof
        );

        totalPoints += tokens[i].points;
      }

      // we request to get 2 winners
      const pick = await soulbound.requestWeeklyPointsPick(0, 2);

      // we safe the pick requests
      const pickRequests = await soulbound.readWeeklyPointsPick(0, 0);

      // we mint the 4th and 5th tokens
      for (let i = 3; i < 5; i++) {
        const tree = getTree(tokens);
        const proof = getProof({
          tree,
          receiver: tokens[i].address,
        });
        await soulbound.mint(
          tokens[i].address,
          {
            points: tokens[i].points,
            rank: tokens[i].rank,
            week: tokens[i].week,
          },
          proof!.proof
        );

        totalPoints += tokens[i].points;
      }

      const pickRequestsAfterNewTokenMints =
        await soulbound.readWeeklyPointsPick(0, 0);

      expect(pickRequestsAfterNewTokenMints).to.deep.equal(pickRequests);
    });

    it.only("request total points pick and get the winner", async function () {
      const { soulbound, tokens, randomness } = await loadFixture(
        deployFixture
      );

      // we mint all the tokens
      let totalPoints = 1;
      for (let i = 0; i < tokens.length; i++) {
        const tree = getTree(tokens);
        const proof = getProof({
          tree,
          receiver: tokens[i].address,
        });
        await soulbound.mint(
          tokens[i].address,
          {
            points: tokens[i].points,
            rank: tokens[i].rank,
            week: tokens[i].week,
          },
          proof!.proof
        );

        totalPoints += tokens[i].points;
      }

      // we request to get 2 winners
      await soulbound.requestTotalPointsPick(2);

      // get the randomnessRequestLength
      const randomnessRequestLength = await soulbound.randomnessRequestLength();

      // we fulfill the randomness
      await fulfillRandomness(randomness, 1n, randomnessRequestLength);

      const pickRequests = await soulbound.readTotalPointsPick(0);
      const winner = await soulbound.getTotalWinnerAtIndex(0, 0);
      const winner2 = await soulbound.getTotalWinnerAtIndex(0, 1);

      console.log(pickRequests);
      console.log(winner);
      console.log(winner2);
    });
  });
});
