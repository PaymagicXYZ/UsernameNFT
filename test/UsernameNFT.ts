import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import {
  Oracle__factory,
  UsernameController__factory,
  ExampleUsernameNFT__factory,
} from "../typechain-types";
import { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";
import {
  setBlockTimestamp,
  getBlockTimestamp,
  getRandomAddress,
} from "../utils";
import { SECONDS_PER_YEAR } from "../constants";

describe("exampleNFT", function () {
  async function deployexampleNFT() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Oracle = new Oracle__factory(owner);
    const oracle = await Oracle.deploy();

    const ExampleNFT = new ExampleUsernameNFT__factory(owner);
    const exampleNFT = await ExampleNFT.deploy(
      "ExampleexampleNFT",
      "EUNFT",
      "example"
    );

    const UsernameController = new UsernameController__factory(owner);
    const usernameController = await UsernameController.deploy(
      oracle.address,
      exampleNFT.address
    );

    await exampleNFT.setController(usernameController.address);

    return {
      oracle,
      exampleNFT,
      usernameController,
      owner,
      addr1,
      addr2,
    };
  }

  describe("exampleNFT", function () {
    describe("Deployment", function () {
      it("Should set the right owner", async function () {
        const { exampleNFT, owner } = await loadFixture(deployexampleNFT);
        expect(await exampleNFT.owner()).to.equal(owner.address);
      });
      it("Should have zero total supply initially", async function () {
        const { exampleNFT } = await loadFixture(deployexampleNFT);
        expect(await exampleNFT.totalSupply()).to.equal(0);
      });
    });
    describe("SetController", function () {
      it("Should set the correct controller address when called by owner", async function () {
        const { exampleNFT, owner } = await loadFixture(deployexampleNFT);
        await exampleNFT.setController(owner.address);
        expect(await exampleNFT.controller()).to.equal(owner.address);
      });
      it("Should revert when called by non-owner", async function () {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await expect(
          exampleNFT.connect(addr1).setController(owner.address)
        ).to.revertedWith("Ownable: caller is not the owner");
      });
    });
    describe("Mint", function () {
      it("Should not allow minting by non-controller", async function () {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        expect(
          exampleNFT.connect(addr1).mint(owner.address, name, duration)
        ).to.revertedWithCustomError(exampleNFT, "OnlyControllerError");
      });
      it("Should allow minting a new NFT with the correct data", async function () {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        const tx = await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        const tokenData = await exampleNFT.tokenData(tokenId);
        expect(tokenData.name).to.equal(name);
        expect(tokenData.resolveAddress).to.equal(owner.address);
        expect(tokenData.duration).to.equal(duration);
      });
      it("Should not allow minting a token with an existing name", async function () {
        const { exampleNFT, owner, addr1, addr2 } = await loadFixture(
          deployexampleNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.setController(owner.address);
        await exampleNFT.mint(owner.address, name, duration);
        await expect(
          exampleNFT.mint(owner.address, name, duration)
        ).to.be.revertedWithCustomError(
          exampleNFT,
          "NameAlreadyRegisteredError"
        );
      });
      it("Should not allow minting to the zero address", async function () {
        const { exampleNFT, owner, addr1, addr2 } = await loadFixture(
          deployexampleNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.setController(owner.address);
        await expect(
          exampleNFT.mint(ethers.constants.AddressZero, name, duration)
        ).to.be.revertedWith("ERC721: mint to the zero address");
      });
    });
    describe("Updating token data", function () {
      it("Should update the token data correctly", async function () {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = SECONDS_PER_YEAR;
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        const newDuration = 2 * SECONDS_PER_YEAR;
        const newData = {
          resolveAddress: addr1.address,
          mintTimestamp: Math.floor(Date.now() / 1000),
          duration: newDuration,
          name,
        };
        await exampleNFT.updateTokenData(tokenId, newData);
        const updatedTokenData = await exampleNFT.tokenData(tokenId);
        expect(updatedTokenData.resolveAddress).to.equal(
          newData.resolveAddress
        );
        expect(updatedTokenData.mintTimestamp).to.be.closeTo(
          newData.mintTimestamp,
          5
        );
        expect(updatedTokenData.duration).to.equal(newData.duration);
      });
    });
    describe("Resolving names and addresses", function () {
      it("Should resolve names and addresses correctly", async function () {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.setController(owner.address);
        await exampleNFT.mint(owner.address, name, duration);
        expect(await exampleNFT.resolveName(name)).to.equal(owner.address);
        expect(await exampleNFT.resolveAddress(owner.address)).to.equal(name);
      });
      it("Should return address(0) for expired names", async function () {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        const blocktimestamp = await getBlockTimestamp();
        await exampleNFT.mint(owner.address, name, duration);
        await setBlockTimestamp(blocktimestamp + 10002);
        expect(await exampleNFT.resolveName(name)).to.equal(
          ethers.constants.AddressZero
        );
      });
      it("Should return an empty string for expired addresses", async function () {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        const blocktimestamp = await getBlockTimestamp();
        await exampleNFT.mint(owner.address, name, duration);
        await setBlockTimestamp(blocktimestamp + 10002);
        await expect(await exampleNFT.resolveAddress(addr1.address)).to.equal(
          ""
        );
      });
    });
    describe("Available", () => {
      it("Should return true if a given name is available for registration", async () => {
        const { exampleNFT } = await loadFixture(deployexampleNFT);
        expect(await exampleNFT.available("username1")).to.equal(true);
      });
      it("Should return false if a given name is not available for registration", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await exampleNFT.mint(owner.address, name, duration);
        expect(await exampleNFT.available("testname")).to.equal(false);
      });
    });
    describe("ResolveName", () => {
      it("Should return zero address if name unregistered ", async () => {
        const { exampleNFT } = await loadFixture(deployexampleNFT);
        const name = "Test";
        expect(await exampleNFT.resolveName(name)).to.eq(
          ethers.constants.AddressZero
        );
      });
    });
    describe("ResolveAddress", () => {
      it("Should return empty string", async () => {
        const { exampleNFT } = await loadFixture(deployexampleNFT);
        const randomAddress = getRandomAddress();
        expect(await exampleNFT.resolveAddress(randomAddress)).to.eq("");
      });
    });
    describe("UpdateTokenData", () => {
      it("Should allow controller to call update token data", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        const tokenData = await exampleNFT.tokenData(tokenId);
        const newTokenData = {
          resolveAddress: owner.address,
          mintTimestamp: tokenData.mintTimestamp,
          duration: tokenData.duration,
          name,
        };
        const tx = await exampleNFT.updateTokenData(tokenId, newTokenData);
        expect(tx)
          .to.emit(exampleNFT, "TokenDataUpdated")
          .withArgs(owner.address, tokenData.mintTimestamp, tokenData.duration);
      });
      it("Should not allow non-controller to call updateTokenData", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        const tokenData = await exampleNFT.tokenData(tokenId);
        await expect(
          exampleNFT.connect(addr1).updateTokenData(tokenId, tokenData)
        ).to.revertedWithCustomError(exampleNFT, "OnlyControllerError");
      });
      it("Should not allow update of tokenData if resolvedAddress is zero address", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        const tokenData = await exampleNFT.tokenData(tokenId);
        const newTokenData = {
          resolveAddress: ethers.constants.AddressZero,
          mintTimestamp: tokenData.mintTimestamp,
          duration: tokenData.duration,
          name,
        };
        await expect(
          exampleNFT.updateTokenData(tokenId, newTokenData)
        ).to.revertedWithCustomError(
          exampleNFT,
          "ZeroAddressNotAvailableError"
        );
      });
    });
    describe("UpdateResolveAddress", () => {
      it("Should allow owner to update the resolved address for the given NFT", async () => {
        const { exampleNFT, owner, addr1, addr2 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);

        await exampleNFT.updateResolveAddress(tokenId, addr1.address);
        expect(await exampleNFT.resolveName(name)).to.equal(addr1.address);

        // Update the resolved address again
        await exampleNFT.updateResolveAddress(tokenId, addr2.address);
        expect(await exampleNFT.resolveName(name)).to.equal(addr2.address);

        // Check if primary name for old resolve address is updated
        expect(await exampleNFT.primaryNameTokenId(addr1.address)).to.equal(0);

        // Check if primary name for new resolve address is updated
        expect(await exampleNFT.primaryNameTokenId(addr2.address)).to.equal(
          tokenId
        );
      });
      it("Should not allow non-owner to update the resolved address for the given NFT", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        const tokenData = await exampleNFT.tokenData(tokenId);
        await expect(
          exampleNFT.connect(addr1).updateResolveAddress(tokenId, owner.address)
        ).to.revertedWithCustomError(exampleNFT, "OnlyNFTOwnerError");
      });
      it("Should not allow updating resolved address to the zero address", async () => {
        const { exampleNFT, owner } = await loadFixture(deployexampleNFT);
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);

        await expect(
          exampleNFT.updateResolveAddress(tokenId, ethers.constants.AddressZero)
        ).to.revertedWithCustomError(
          exampleNFT,
          "ZeroAddressNotAvailableError"
        );
      });
      it("Should not update primary name for old resolve address if it's not the primary name", async () => {
        const { exampleNFT, owner, addr1, addr2 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);

        // Mint another NFT with a different name for the same owner
        const anotherName = "anothername";
        await exampleNFT.mint(owner.address, anotherName, duration);
        const anotherTokenId = await exampleNFT.nameToTokenId(anotherName);

        // Set the primary name for the old resolve address to anotherTokenId
        await exampleNFT.updatePrimaryName(anotherTokenId);

        // Update the resolved address for the first NFT
        await exampleNFT.updateResolveAddress(tokenId, addr1.address);

        // Check if primary name for old resolve address is not updated
        expect(await exampleNFT.primaryNameTokenId(owner.address)).to.equal(
          anotherTokenId
        );
      });
      it("Should not update primary name for new resolve address if already set", async () => {
        const { exampleNFT, owner, addr1, addr2 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);

        // Mint another NFT with a different name for addr1
        const anotherName = "anothername";
        await exampleNFT.mint(addr1.address, anotherName, duration);
        const anotherTokenId = await exampleNFT.nameToTokenId(anotherName);

        // Set the primary name for addr1 to anotherTokenId
        await exampleNFT.connect(addr1).updatePrimaryName(anotherTokenId);

        // Update the resolved address for the first NFT
        await exampleNFT.updateResolveAddress(tokenId, addr1.address);

        // Check if primary name for new resolve address is not updated
        expect(await exampleNFT.primaryNameTokenId(addr1.address)).to.equal(
          anotherTokenId
        );
      });
    });
    describe("IsExpired", () => {
      it("Should return false if a given name is not expired", async () => {
        const { exampleNFT, owner, addr1, addr2 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        expect(await exampleNFT.isExpired(tokenId)).to.equal(false);
      });
      it("Should return true if a given name is expired", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await exampleNFT.mint(owner.address, name, duration);
        const blocktimestamp = await getBlockTimestamp();
        await setBlockTimestamp(blocktimestamp + 10000 + 1);
        const tokenId = await exampleNFT.nameToTokenId(name);
        expect(await exampleNFT.isExpired(tokenId)).to.equal(true);
      });
    });
    describe("UpdatePrimaryName", () => {
      it("Should update primary name for the resolve address", async () => {
        const { exampleNFT, owner, addr1, addr2 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        await exampleNFT.mint(await addr1.getAddress(), "alice", 1000);
        await exampleNFT.mint(await addr1.getAddress(), "bob", 1000);

        // Get tokenIds for the minted tokens
        const tokenId1 = await exampleNFT.nameToTokenId("alice");
        const tokenId2 = await exampleNFT.nameToTokenId("bob");

        // Check if primary name is set to the first minted token
        expect(
          await exampleNFT.primaryNameTokenId(await addr1.getAddress())
        ).to.equal(tokenId1);

        // Update primary name to the second minted token
        await exampleNFT.connect(addr1).updatePrimaryName(tokenId2);

        // Check if primary name is updated to the second minted token
        expect(
          await exampleNFT.primaryNameTokenId(await addr1.getAddress())
        ).to.equal(tokenId2);
      });
      it("Should revert if the caller is not the resolve address", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await exampleNFT.mint(owner.address, name, duration);

        // Get tokenId for the minted token
        const tokenId = await exampleNFT.nameToTokenId(name);
        await expect(
          exampleNFT.connect(addr1).updatePrimaryName(tokenId)
        ).to.be.revertedWithCustomError(
          exampleNFT,
          "AddressNotRegisteredError"
        );
      });
    });
    describe("GetDisplayName", () => {
      it("Should return concatenation of name + '.' + domain", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        expect(await exampleNFT.getDisplayName(tokenId)).to.equal(
          "testname.example"
        );
      });
    });
    describe("TokenURI", () => {
      it("Should return the correct tokenURI for tokenId ", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await exampleNFT.mint(owner.address, name, duration);
        const tokenId = await exampleNFT.nameToTokenId(name);
        expect(await exampleNFT.getDisplayName(tokenId)).to.equal(
          "testname.example"
        );

        const tokenURI = await exampleNFT.tokenURI(tokenId);

        //base64 decode the tokenURI
        const tokenURIBuffer = Buffer.from(tokenURI.split(",")[1], "base64");

        //convert the buffer to string
        const tokenURIString = tokenURIBuffer.toString("utf-8");

        //parse the string to JSON
        const tokenURIJSON = JSON.parse(tokenURIString);

        expect(tokenURIJSON.name).to.equal(
          ".example Username NFTs testname.example"
        );
      });
      it("Should revert if tokenId does not exist", async () => {
        const { exampleNFT, owner, addr1 } = await loadFixture(
          deployexampleNFT
        );
        await exampleNFT.setController(owner.address);
        const tokenId = 9999;
        await expect(
          exampleNFT.tokenURI(tokenId)
        ).to.be.revertedWithCustomError(exampleNFT, "InvalidTokenError");
      });
    });
  });
});
