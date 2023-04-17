import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";
import { setBlockTimestamp, getBlockTimestamp } from "../utils";

describe("UsernameNFT", function () {
  async function deployDummyNFT() {
    const price = parseEther("1");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Oracle = await ethers.getContractFactory("Oracle");
    const oracle = await Oracle.deploy(price);

    const UsernameNFT = await ethers.getContractFactory("UsernameNFT");
    const usernameNFT = await UsernameNFT.deploy("UsernameNFT", "UNFT");

    const UsernameController = await ethers.getContractFactory(
      "UsernameController"
    );
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

        const tx = await usernameNFT.mint(
          owner.address,
          addr1.address,
          name,
          duration
        );

        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.getTokenData(tokenId);

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
        const updatedTokenData = await usernameNFT.getTokenData(tokenId);

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
    //   it("Should resolve names and addresses correctly", async function () {
    //     const { usernameNFT, owner, addr1 } = await loadFixture(deployDummyNFT);
    //     const name = "testname";
    //     const duration = 31536000; // 1 year in seconds

    //     await usernameNFT.setController(owner.address);

    //     await usernameNFT.mint(owner.address, addr1.address, name, duration);

    //     expect(await usernameNFT.resolveName(`${name}.usr.id`)).to.equal(addr1.address);
    //     expect(await usernameNFT.resolveAddress(addr1.address)).to.equal(name);
    //   });
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
      // it("Should return an empty string for expired addresses", async function () {
      //   const { usernameNFT, owner, addr1, addr2 } = await loadFixture(
      //     deployDummyNFT
      //   );

      //   await usernameNFT.setController(owner.address);

      //   const name = "testname";
      //   const duration = 10000; // 10000 seconds

      //   const blocktimestamp = await getBlockTimestamp();
      //   await usernameNFT.mint(owner.address, addr1.address, name, duration);

      //   await setBlockTimestamp(blocktimestamp + 10002);

      //   await expect(await usernameNFT.resolveAddress(addr1.address)).to.equal(
      //     ""
      //   );
      // });
    });
  });
});
