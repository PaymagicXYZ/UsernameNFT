import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  Oracle__factory,
  UsernameController__factory,
  UsernameNFT__factory,
} from "../typechain-types";
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";

describe("UsernameController", function () {
  async function deployDummyController() {
    const price = parseEther("1");

    const [owner, addr1, addr2] = await ethers.getSigners();

    const Oracle = new Oracle__factory(owner);
    const oracle = await Oracle.deploy(price);

    const UsernameNFT = new UsernameNFT__factory(owner);
    const usernameNFT = await UsernameNFT.deploy("UsernameNFT", "UNFT");

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

  describe("UsernameController", function () {
    describe("Register", function () {
      it("Should register a new username and mint an NFT", async function () {
        const { oracle, usernameNFT, usernameController, owner, addr1, addr2 } =
          await loadFixture(deployDummyController);

        const name = "testuser";
        const duration = 100;

        const price = await oracle.price(name.length);

        await usernameController.register(name, addr1.address, duration, {
          value: price,
        });
        const tokenId = await usernameNFT.nameToTokenId(name);

        expect(await usernameNFT.ownerOf(tokenId)).to.equal(owner.address);

        const resolvedName = await usernameNFT.resolvedAddressToName(
          addr1.address
        );

        expect(resolvedName).to.equal(name);
      });
      it("Should fail if not enough Ether is sent", async function () {
        const { oracle, usernameController, addr1 } = await loadFixture(
          deployDummyController
        );

        const name = "testuser";
        const duration = 100;

        const actualPrice = await oracle.price(name.length);

        const attemptedPrice = ethers.utils.parseEther("0.1");

        expect(attemptedPrice).to.be.lt(actualPrice);

        await expect(
          usernameController.register(name, addr1.address, duration, {
            value: attemptedPrice,
          })
        ).to.be.revertedWithCustomError(
          usernameController,
          "InsufficientNativeError"
        );
      });
    });
    describe("Renew", function () {
      it("Should renew the registration of not yet expired username", async function () {
        const { usernameController, addr1, usernameNFT } = await loadFixture(
          deployDummyController
        );

        const name = "testuser";
        const duration = 100;

        await usernameController.register(name, addr1.address, duration, {
          value: ethers.utils.parseEther("1"),
        });

        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.getTokenData(tokenId);

        expect(tokenData.duration).to.equal(duration);
      });
      //TO-DO
      it("Should renew the registration of an expired username", async function () {
        const { usernameController, addr1, usernameNFT } = await loadFixture(
          deployDummyController
        );

        const name = "testuser";
        const duration = 100;

        await usernameController.register(name, addr1.address, duration, {
          value: ethers.utils.parseEther("1"),
        });

        const tokenId = await usernameNFT.nameToTokenId(name);
        const tokenData = await usernameNFT.getTokenData(tokenId);

        expect(tokenData.duration).to.equal(duration);
      });
      it("Should fail if not enough Ether is sent", async function () {
        const { oracle, usernameNFT, usernameController, owner, addr1, addr2 } =
          await loadFixture(deployDummyController);

        const name = "testuser";
        const duration = 100;

        await usernameController
          .connect(owner)
          .register(name, addr1.address, duration, {
            value: ethers.utils.parseEther("1"),
          });
        const tokenId = await usernameNFT.nameToTokenId(name);

        const additionalDuration = 50;

        await expect(
          usernameController.connect(owner).renew(tokenId, additionalDuration, {
            value: ethers.utils.parseEther("0.001"),
          })
        ).to.be.revertedWithCustomError(
          usernameController,
          "InsufficientNativeError"
        );
      });
    });
    describe("Withdraw", function () {
      it("Should withdraw the contract balance to the owner", async function () {
        const { usernameController, owner, addr1 } = await loadFixture(
          deployDummyController
        );
        const name = "testuser";
        const duration = 100;

        await usernameController.register(name, addr1.address, duration, {
          value: ethers.utils.parseEther("1"),
        });

        const initialBalance = await owner.getBalance();
        const contractBalance = await ethers.provider.getBalance(
          usernameController.address
        );

        await usernameController.connect(addr1).withdraw();

        const finalBalance = await owner.getBalance();
        expect(finalBalance).to.equal(initialBalance.add(contractBalance));
      });
    });
  });
});
