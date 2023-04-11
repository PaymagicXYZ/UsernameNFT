import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { setBlockTimestamp, getBlockTimestamp } from "../utils";

describe("UsernameNFT", function () {
  async function deployDummyNFT() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const DummyOracle = await ethers.getContractFactory("DummyOracle");
    const dummyOracle = await DummyOracle.deploy();

    const UsernameNFT = await ethers.getContractFactory("UsernameNFT");
    const usernameNFT = await UsernameNFT.deploy();

    const UsernameController = await ethers.getContractFactory(
      "UsernameController"
    );
    const usernameController = await UsernameController.deploy(
      dummyOracle.address,
      usernameNFT.address
    );

    await usernameNFT.setController(usernameController.address);

    return {
      dummyOracle,
      usernameNFT,
      usernameController,
      owner,
      addr1,
      addr2,
    };
  }

  describe("UsernameNFT", function () {
    describe("Deployment", function () {
      it("Should set the right owner", async function () {
        const { usernameNFT, owner } = await loadFixture(deployDummyNFT);
        expect(await usernameNFT.owner()).to.equal(owner.address);
      });

      it("Should have zero total supply initially", async function () {
        const { usernameNFT } = await loadFixture(deployDummyNFT);
        expect(await usernameNFT.totalSupply()).to.equal(0);
      });
    });
    describe("Controller", function () {
      it("Should set the correct controller address", async function () {
        const { usernameNFT, owner } = await loadFixture(deployDummyNFT);

        await usernameNFT.setController(owner.address);
        expect(await usernameNFT.controller()).to.equal(owner.address);
      });
    });
    describe("Mint", function () {
      it("Should mint a new NFT with the correct data", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds

        const tx = await usernameNFT.mint(addr1.address, name, duration);

        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.getTokenData(tokenId);

        expect(tokenData.owner).to.equal(addr1.address);

        expect(tokenData.duration).to.equal(duration);
      });
      it("Should not allow minting a token with an existing name", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );

        const name = "testname";
        const duration = 31536000; // 1 year in seconds

        await usernameNFT.setController(owner.address);

        await usernameNFT.mint(addr1.address, name, duration);

        await expect(
          usernameNFT.mint(addr2.address, name, duration)
        ).to.be.revertedWith("Name already registered");
      });
    });
    describe("Updating token data", function () {
      it("Should update the token data correctly", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);

        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds

        await usernameNFT.mint(addr1.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);

        const newDuration = 63072000; // 2 years in seconds
        const newData = {
          owner: addr1.address,
          mintTimestamp: Math.floor(Date.now() / 1000),
          duration: newDuration,
        };

        await usernameNFT.updateTokenData(tokenId, newData);
        const updatedTokenData = await usernameNFT.getTokenData(tokenId);

        expect(updatedTokenData.owner).to.equal(newData.owner);
        expect(updatedTokenData.mintTimestamp).to.be.closeTo(
          newData.mintTimestamp,
          5
        );
        expect(updatedTokenData.duration).to.equal(newData.duration);
      });
    });
    describe("Resolving names and addresses", function () {
      it("Should resolve names and addresses correctly", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds

        await usernameNFT.setController(owner.address);

        await usernameNFT.mint(addr1.address, name, duration);

        expect(await usernameNFT.resolveName(name)).to.equal(addr1.address);
        expect(await usernameNFT.resolveAddress(addr1.address)).to.equal(name);
      });
      it("Should return address(0) for expired names", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );

        await usernameNFT.setController(owner.address);

        const name = "testname";
        const duration = 10000; // 10000 seconds

        const blocktimestamp = await getBlockTimestamp();
        await usernameNFT.mint(addr1.address, name, duration);

        await setBlockTimestamp(blocktimestamp + 10002);

        expect(await usernameNFT.resolveName(name)).to.equal(
          ethers.constants.AddressZero
        );
      });
      it("Should return an empty string for expired addresses", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );

        await usernameNFT.setController(owner.address);

        const name = "testname";
        const duration = 10000; // 10000 seconds

        const blocktimestamp = await getBlockTimestamp();
        await usernameNFT.mint(addr1.address, name, duration);

        await setBlockTimestamp(blocktimestamp + 10002);

        await expect(await usernameNFT.resolveAddress(addr1.address)).to.equal(
          ""
        );
      });
    });
  });
});
