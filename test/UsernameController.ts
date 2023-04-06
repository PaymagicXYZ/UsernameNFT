import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("UsernameController", function () {
  async function deployDummyController() {
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

  describe("UsernameController", function () {
    describe("Register", function () {
      it("Should register a new username and mint an NFT", async function () {
        const {
          dummyOracle,
          usernameNFT,
          usernameController,
          owner,
          addr1,
          addr2,
        } = await loadFixture(deployDummyController);

        const name = "testuser";
        const duration = 100;

        await usernameController.register(name, addr1.address, duration, {
          value: ethers.utils.parseEther("1"),
        });
        const tokenId = await usernameNFT.nameToTokenId(addr1.address);
        const tokenData = await usernameNFT.getTokenData(tokenId);

        // await usernameNFT.addressToName(addr1.address);

        // expect(tokenData.name).to.equal(name);
      });
      it("Should fail if not enough Ether is sent", async function () {
        const { usernameController, addr1 } = await loadFixture(
          deployDummyController
        );

        const name = "testuser";
        const duration = 100;

        await expect(
          usernameController.register(name, addr1.address, duration, {
            value: ethers.utils.parseEther("0.1"),
          })
        ).to.be.revertedWith("Not enough Ether sent for registration");
      });
    });
    describe("Renew", function () {
      it("Should renew the registration of a username", async function () {
        const { usernameController, addr1, usernameNFT } = await loadFixture(
          deployDummyController
        );

        const name = "testuser";
        const duration = 100;

        await usernameController.register(name, addr1.address, duration, {
          value: ethers.utils.parseEther("1"),
        });

        const tokenId = await usernameNFT.nameToTokenId(addr1.address);
        const tokenData = await usernameNFT.getTokenData(tokenId);

        expect(tokenData.duration).to.equal(duration);
      });
      it("Should fail if not enough Ether is sent", async function () {
        const {
          dummyOracle,
          usernameNFT,
          usernameController,
          owner,
          addr1,
          addr2,
        } = await loadFixture(deployDummyController);

        const name = "testuser";
        const duration = 100;

        await usernameController
          .connect(owner)
          .register(name, addr1.address, duration, {
            value: ethers.utils.parseEther("1"),
          });
        const tokenId = await usernameNFT.nameToTokenId(addr1.address);

        const additionalDuration = 50;
        await expect(
          usernameController.connect(owner).renew(tokenId, additionalDuration, {
            value: ethers.utils.parseEther("0.1"),
          })
        ).to.be.revertedWith("Not enough Ether sent for registration");
      });
      it("Should fail if the caller is not the owner", async function () {
        const {
          dummyOracle,
          usernameNFT,
          usernameController,
          owner,
          addr1,
          addr2,
        } = await loadFixture(deployDummyController);
        const name = "testuser";
        const duration = 100;

        await usernameController.register(name, addr1.address, duration, {
          value: ethers.utils.parseEther("1"),
        });
        const tokenId = await usernameNFT.nameToTokenId(name);

        const additionalDuration = 50;
        await expect(
          usernameController.connect(addr2).renew(tokenId, additionalDuration, {
            value: ethers.utils.parseEther("1"),
          })
        ).to.be.revertedWith("Ownable: caller is not the owner");
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
