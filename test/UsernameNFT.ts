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

describe("UsernameNFT", function () {
  async function deployDummyNFT() {
    const price = parseEther("1");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Oracle = new Oracle__factory(owner);
    const oracle = await Oracle.deploy(price);

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
        const { usernameNFT, owner } = await loadFixture(deployDummyNFT);
        expect(await usernameNFT.owner()).to.equal(owner.address);
      });
      it("Should have zero total supply initially", async function () {
        const { usernameNFT } = await loadFixture(deployDummyNFT);
        expect(await usernameNFT.totalSupply()).to.equal(0);
      });
    });
    describe("SetController", function () {
      it("Should set the correct controller address when called by owner", async function () {
        const { usernameNFT, owner } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        expect(await usernameNFT.controller()).to.equal(owner.address);
      });
      it("Should revert when called by non-owner", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        expect(
          usernameNFT.connect(addr1).setController(owner.address)
        ).to.rejectedWith("Ownable: new owner is the zero address");
      });
    });
    describe("Mint", function () {
      it("Should not allow minting by non-controller", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        expect(
          usernameNFT
            .connect(addr1)
            .mint(owner.address, addr1.address, name, duration)
        ).to.revertedWithCustomError(usernameNFT, "OnlyControllerError");
      });
      it("Should allow minting a new NFT with the correct data", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        const tx = await usernameNFT.mint(
          owner.address,
          addr1.address,
          name,
          duration
        );
        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);
        expect(tokenData.resolvedAddress).to.equal(addr1.address);
        expect(tokenData.duration).to.equal(duration);
      });
      it("Should not allow minting a token with an existing name", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.setController(owner.address);
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
        await expect(
          usernameNFT.mint(owner.address, addr2.address, name, duration)
        ).to.be.revertedWithCustomError(
          usernameNFT,
          "NameAlreadyRegisteredError"
        );
      });
      it("Should not allow minting to the zero address", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.setController(owner.address);
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
        await expect(
          usernameNFT.mint(
            ethers.constants.AddressZero,
            addr2.address,
            name,
            duration
          )
        ).to.be.revertedWithCustomError(
          usernameNFT,
          "ZeroAddressNotAvailableError"
        );
      });
      it("Should not minting with resolvedAddress set to zero address", async function () {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.setController(owner.address);
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
        await expect(
          usernameNFT.mint(
            owner.address,
            ethers.constants.AddressZero,
            name,
            duration
          )
        ).to.be.revertedWithCustomError(
          usernameNFT,
          "ZeroAddressNotAvailableError"
        );
      });
    });
    describe("Updating token data", function () {
      it("Should update the token data correctly", async function () {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
        const tokenId = await usernameNFT.nameToTokenId(name);
        const newDuration = 63072000; // 2 years in seconds
        const newData = {
          resolvedAddress: addr1.address,
          mintTimestamp: Math.floor(Date.now() / 1000),
          duration: newDuration,
        };
        await usernameNFT.updateTokenData(tokenId, newData);
        const updatedTokenData = await usernameNFT.tokenData(tokenId);
        expect(updatedTokenData.resolvedAddress).to.equal(
          newData.resolvedAddress
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
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.setController(owner.address);
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
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
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
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
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
        await setBlockTimestamp(blocktimestamp + 10002);
        await expect(await usernameNFT.resolveAddress(addr1.address)).to.equal(
          ""
        );
      });
    });
    describe("IsAvailable", () => {
      it("Should return true if a given name is available for registration", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );

        expect(await usernameNFT.isAvailable("username1")).to.equal(true);
      });

      it("Should return false if a given name is not available for registration", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);
        expect(await usernameNFT.isAvailable("testname")).to.equal(false);
      });
    });
    describe("ResolveName", () => {
      it("Should revert if name unregistered ", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);

        const name = "Test";

        expect(usernameNFT.resolveName(name)).to.revertedWithCustomError(
          usernameNFT,
          "NameNotRegisteredError"
        );
      });
    });
    describe("ResolveAddress", () => {
      it("Should revert if address unregistered", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);

        const randomAddress = getRandomAddress();

        expect(
          usernameNFT.resolveAddress(randomAddress)
        ).to.revertedWithCustomError(usernameNFT, "AddressNotRegisteredError");
      });
    });
    describe("UpdateTokenData", () => {
      it("Should allow controller to call update token data", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);

        const newTokenData = {
          resolvedAddress: owner.address,
          mintTimestamp: tokenData.mintTimestamp,
          duration: tokenData.duration,
        };

        const tx = await usernameNFT.updateTokenData(tokenId, newTokenData);

        expect(tx)
          .to.emit(usernameNFT, "TokenDataUpdated")
          .withArgs(owner.address, tokenData.mintTimestamp, tokenData.duration);
      });
      it("Should not allow non-controller to call updateTokenData", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);

        expect(
          usernameNFT.connect(addr1).updateTokenData(tokenId, tokenData)
        ).to.revertedWithCustomError(usernameNFT, "OnlyControllerError");
      });
      it("Should not allow update of tokenData if resolvedAddress is zero address", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.tokenData(tokenId);

        const newTokenData = {
          resolvedAddress: ethers.constants.AddressZero,
          mintTimestamp: tokenData.mintTimestamp,
          duration: tokenData.duration,
        };

        expect(
          usernameNFT.updateTokenData(tokenId, newTokenData)
        ).to.revertedWithCustomError(
          usernameNFT,
          "ZeroAddressNotAvailableError"
        );
      });
    });
    describe("UpdateResolveAddress", () => {
      it("Should allow owner update the resolved address for the given NFT", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        const tokenId = await usernameNFT.nameToTokenId(name);
        // const tokenData = await usernameNFT.getTokenData(tokenId);

        await usernameNFT.updateResolveAddress(tokenId, owner.address);

        expect(await usernameNFT.resolveName(name)).to.equal(owner.address);
      });
      it("Should not allow non-owner to update the resolved address for the given NFT", async () => {
        const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 31536000; // 1 year in seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        const tokenId = await usernameNFT.nameToTokenId(name);
        // const tokenData = await usernameNFT.getTokenData(tokenId);

        expect(
          usernameNFT
            .connect(addr1)
            .updateResolveAddress(tokenId, owner.address)
        ).to.revertedWithCustomError(usernameNFT, "OnlyNFTOwnerError");
      });
    });
    describe("IsExpired", () => {
      it("Should return false if a given name is not expired", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        const tokenId = await usernameNFT.nameToTokenId(name);

        expect(await usernameNFT.isExpired(tokenId)).to.equal(false);
      });
      it("Should return true if a given name is expired", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        const blocktimestamp = await getBlockTimestamp();
        await setBlockTimestamp(blocktimestamp + 10000 + 1);

        const tokenId = await usernameNFT.nameToTokenId(name);

        expect(await usernameNFT.isExpired(tokenId)).to.equal(true);
      });
    });
    describe("GetDisplayName", () => {
      it("Should return concatenation of name + '.' + domain", async () => {
        const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
          deployDummyNFT
        );
        await usernameNFT.setController(owner.address);
        const name = "testname";
        const duration = 10000; // 10000 seconds
        await usernameNFT.mint(owner.address, addr1.address, name, duration);

        expect(await usernameNFT.getDisplayName(addr1.address)).to.equal(
          "testname.evm"
        );
      });
    });
  });
});
