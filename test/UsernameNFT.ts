import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import {
  Oracle__factory,
  UsernameController__factory,
  UsernameNFT__factory,
} from "../typechain-types";
import { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";
import {
  setBlockTimestamp,
  getBlockTimestamp,
  getRandomAddress,
} from "../utils";
import { SECONDS_PER_YEAR } from "../constants";

describe("UsernameNFT", function () {
  async function deployUsernameNFT() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Oracle = new Oracle__factory(owner);
    const oracle = await Oracle.deploy();

    const UsernameNFT = new UsernameNFT__factory(owner);
    const usernameNFT = await UsernameNFT.deploy("UsernameNFT", "UNFT", "evm");

    const UsernameController = new UsernameController__factory(owner);
    const usernameController = await UsernameController.deploy(
      oracle.address,
      usernameNFT.address
    );

    await usernameNFT.setController(usernameController.address);

    return {
      oracle,
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
        const { usernameNFT, owner } = await loadFixture(deployUsernameNFT);
        expect(await usernameNFT.owner()).to.equal(owner.address);
      });
      it("Should have zero total supply initially", async function () {
        const { usernameNFT } = await loadFixture(deployUsernameNFT);
        expect(await usernameNFT.totalSupply()).to.equal(0);
      });
    });
    describe("SetController", function () {
      it("Should set the correct controller address when called by owner", async function () {
        const { usernameNFT, owner } = await loadFixture(deployUsernameNFT);
        await usernameNFT.setController(owner.address);
        expect(await usernameNFT.controller()).to.equal(owner.address);
      });
      it("Should revert when called by non-owner", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await expect(
          usernameNFT.connect(addr1).setController(owner.address)
        ).to.revertedWith("Ownable: caller is not the owner");
      });
    });
    describe("Mint", function () {
      it("Should not allow minting by non-controller", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        expect(
          usernameNFT.connect(addr1).mint(owner.address, name, duration)
        ).to.revertedWithCustomError(usernameNFT, "OnlyControllerError");
      });
      it("Should allow minting a new NFT with the correct data", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        const tx = await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);
        expect(tokenData.name).to.equal(name);
        expect(tokenData.resolveAddress).to.equal(owner.address);
        expect(tokenData.duration).to.equal(duration);
      });
      it("Should not allow minting a token with an existing name", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployUsernameNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.setController(owner.address);
        await usernameNFT.mint(owner.address, name, duration);
        await expect(
          usernameNFT.mint(owner.address, name, duration)
        ).to.be.revertedWithCustomError(
          usernameNFT,
          "NameAlreadyRegisteredError"
        );
      });
      it("Should not allow minting to the zero address", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployUsernameNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.setController(owner.address);
        await expect(
          usernameNFT.mint(ethers.constants.AddressZero, name, duration)
        ).to.be.revertedWith("ERC721: mint to the zero address");
      });
    });
    describe("Updating token data", function () {
      it("Should update the token data correctly", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = SECONDS_PER_YEAR;
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        const newDuration = 2 * SECONDS_PER_YEAR;
        const newData = {
          resolveAddress: addr1.address,
          mintTimestamp: Math.floor(Date.now() / 1000),
          duration: newDuration,
          name,
        };
        await usernameNFT.updateTokenData(tokenId, newData);
        const updatedTokenData = await usernameNFT.tokenData(tokenId);
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
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.setController(owner.address);
        await usernameNFT.mint(owner.address, name, duration);
        expect(await usernameNFT.resolveName(name)).to.equal(owner.address);
        expect(await usernameNFT.resolveAddress(owner.address)).to.equal(name);
      });
      it("Should return address(0) for expired names", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        const blocktimestamp = await getBlockTimestamp();
        await usernameNFT.mint(owner.address, name, duration);
        await setBlockTimestamp(blocktimestamp + 10002);
        expect(await usernameNFT.resolveName(name)).to.equal(
          ethers.constants.AddressZero
        );
      });
      it("Should return an empty string for expired addresses", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        const blocktimestamp = await getBlockTimestamp();
        await usernameNFT.mint(owner.address, name, duration);
        await setBlockTimestamp(blocktimestamp + 10002);
        await expect(await usernameNFT.resolveAddress(addr1.address)).to.equal(
          ""
        );
      });
    });
    describe("Available", () => {
      it("Should return true if a given name is available for registration", async () => {
        const { usernameNFT } = await loadFixture(deployUsernameNFT);
        expect(await usernameNFT.available("username1")).to.equal(true);
      });
      it("Should return false if a given name is not available for registration", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, name, duration);
        expect(await usernameNFT.available("testname")).to.equal(false);
      });
    });
    describe("ResolveName", () => {
      it("Should return zero address if name unregistered ", async () => {
        const { usernameNFT } = await loadFixture(deployUsernameNFT);
        const name = "Test";
        expect(await usernameNFT.resolveName(name)).to.eq(
          ethers.constants.AddressZero
        );
      });
    });
    describe("ResolveAddress", () => {
      it("Should return empty string", async () => {
        const { usernameNFT } = await loadFixture(deployUsernameNFT);
        const randomAddress = getRandomAddress();
        expect(await usernameNFT.resolveAddress(randomAddress)).to.eq("");
      });
    });
    describe("UpdateTokenData", () => {
      it("Should allow controller to call update token data", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);
        const newTokenData = {
          resolveAddress: owner.address,
          mintTimestamp: tokenData.mintTimestamp,
          duration: tokenData.duration,
          name,
        };
        const tx = await usernameNFT.updateTokenData(tokenId, newTokenData);
        expect(tx)
          .to.emit(usernameNFT, "TokenDataUpdated")
          .withArgs(owner.address, tokenData.mintTimestamp, tokenData.duration);
      });
      it("Should not allow non-controller to call updateTokenData", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);
        await expect(
          usernameNFT.connect(addr1).updateTokenData(tokenId, tokenData)
        ).to.revertedWithCustomError(usernameNFT, "OnlyControllerError");
      });
      it("Should not allow update of tokenData if resolvedAddress is zero address", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);
        const newTokenData = {
          resolveAddress: ethers.constants.AddressZero,
          mintTimestamp: tokenData.mintTimestamp,
          duration: tokenData.duration,
          name,
        };
        await expect(
          usernameNFT.updateTokenData(tokenId, newTokenData)
        ).to.revertedWithCustomError(
          usernameNFT,
          "ZeroAddressNotAvailableError"
        );
      });
    });
    describe("UpdateResolveAddress", () => {
      it("Should allow owner to update the resolved address for the given NFT", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);

        await usernameNFT.updateResolveAddress(tokenId, addr1.address);
        expect(await usernameNFT.resolveName(name)).to.equal(addr1.address);

        // Update the resolved address again
        await usernameNFT.updateResolveAddress(tokenId, addr2.address);
        expect(await usernameNFT.resolveName(name)).to.equal(addr2.address);

        // Check if primary name for old resolve address is updated
        expect(await usernameNFT.primaryNameTokenId(addr1.address)).to.equal(0);

        // Check if primary name for new resolve address is updated
        expect(await usernameNFT.primaryNameTokenId(addr2.address)).to.equal(
          tokenId
        );
      });
      it("Should not allow non-owner to update the resolved address for the given NFT", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);
        await expect(
          usernameNFT
            .connect(addr1)
            .updateResolveAddress(tokenId, owner.address)
        ).to.revertedWithCustomError(usernameNFT, "OnlyNFTOwnerError");
      });
      it("Should not allow updating resolved address to the zero address", async () => {
        const { usernameNFT, owner } = await loadFixture(deployUsernameNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);

        await expect(
          usernameNFT.updateResolveAddress(
            tokenId,
            ethers.constants.AddressZero
          )
        ).to.revertedWithCustomError(
          usernameNFT,
          "ZeroAddressNotAvailableError"
        );
      });
      it("Should not update primary name for old resolve address if it's not the primary name", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);

        // Mint another NFT with a different name for the same owner
        const anotherName = "anothername";
        await usernameNFT.mint(owner.address, anotherName, duration);
        const anotherTokenId = await usernameNFT.nameToTokenId(anotherName);

        // Set the primary name for the old resolve address to anotherTokenId
        await usernameNFT.updatePrimaryName(anotherTokenId);

        // Update the resolved address for the first NFT
        await usernameNFT.updateResolveAddress(tokenId, addr1.address);

        // Check if primary name for old resolve address is not updated
        expect(await usernameNFT.primaryNameTokenId(owner.address)).to.equal(
          anotherTokenId
        );
      });
      it("Should not update primary name for new resolve address if already set", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);

        // Mint another NFT with a different name for addr1
        const anotherName = "anothername";
        await usernameNFT.mint(addr1.address, anotherName, duration);
        const anotherTokenId = await usernameNFT.nameToTokenId(anotherName);

        // Set the primary name for addr1 to anotherTokenId
        await usernameNFT.connect(addr1).updatePrimaryName(anotherTokenId);

        // Update the resolved address for the first NFT
        await usernameNFT.updateResolveAddress(tokenId, addr1.address);

        // Check if primary name for new resolve address is not updated
        expect(await usernameNFT.primaryNameTokenId(addr1.address)).to.equal(
          anotherTokenId
        );
      });
    });
    describe("IsExpired", () => {
      it("Should return false if a given name is not expired", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        expect(await usernameNFT.isExpired(tokenId)).to.equal(false);
      });
      it("Should return true if a given name is expired", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, name, duration);
        const blocktimestamp = await getBlockTimestamp();
        await setBlockTimestamp(blocktimestamp + 10000 + 1);
        const tokenId = await usernameNFT.nameToTokenId(name);
        expect(await usernameNFT.isExpired(tokenId)).to.equal(true);
      });
    });
    describe("UpdatePrimaryName", () => {
      it("Should update primary name for the resolve address", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        await usernameNFT.mint(await addr1.getAddress(), "alice", 1000);
        await usernameNFT.mint(await addr1.getAddress(), "bob", 1000);

        // Get tokenIds for the minted tokens
        const tokenId1 = await usernameNFT.nameToTokenId("alice");
        const tokenId2 = await usernameNFT.nameToTokenId("bob");

        // Check if primary name is set to the first minted token
        expect(
          await usernameNFT.primaryNameTokenId(await addr1.getAddress())
        ).to.equal(tokenId1);

        // Update primary name to the second minted token
        await usernameNFT.connect(addr1).updatePrimaryName(tokenId2);

        // Check if primary name is updated to the second minted token
        expect(
          await usernameNFT.primaryNameTokenId(await addr1.getAddress())
        ).to.equal(tokenId2);
      });
      it("Should revert if the caller is not the resolve address", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, name, duration);

        // Get tokenId for the minted token
        const tokenId = await usernameNFT.nameToTokenId(name);
        await expect(
          usernameNFT.connect(addr1).updatePrimaryName(tokenId)
        ).to.be.revertedWithCustomError(
          usernameNFT,
          "AddressNotRegisteredError"
        );
      });
    });
    describe("GetDisplayName", () => {
      it("Should return concatenation of name + '.' + domain", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        expect(await usernameNFT.getDisplayName(tokenId)).to.equal(
          "testname.evm"
        );
      });
    });
    describe("TokenURI", () => {
      it("Should return the correct tokenURI for tokenId ", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        expect(await usernameNFT.getDisplayName(tokenId)).to.equal(
          "testname.evm"
        );

        const tokenURI = await usernameNFT.tokenURI(tokenId);

        //base64 decode the tokenURI
        const tokenURIBuffer = Buffer.from(tokenURI.split(",")[1], "base64");

        //convert the buffer to string
        const tokenURIString = tokenURIBuffer.toString("utf-8");

        //parse the string to JSON
        const tokenURIJSON = JSON.parse(tokenURIString);

        expect(tokenURIJSON.name).to.equal(
          ".zkevm Username NFT #37965850388819898014548320000627034371487626544378754384039597861099344279940"
        );
      });
      it("Should revert if tokenId does not exist", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(
          deployUsernameNFT
        );
        await usernameNFT.setController(owner.address);
        const tokenId = 9999;
        await expect(
          usernameNFT.tokenURI(tokenId)
        ).to.be.revertedWithCustomError(usernameNFT, "InvalidTokenError");
      });
    });
  });
});
