import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  Oracle__factory,
  UsernameController__factory,
  UsernameNFT__factory,
} from "../typechain-types";
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import {
  getBlockTimestamp,
  setBlockTimestamp,
  getRandomAddress,
} from "../utils";
import { SECONDS_PER_YEAR } from "../constants";

describe("UsernameController", function () {
  async function deployDummyController() {
    const price = parseEther("1");

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

  describe("UsernameController", function () {
    describe("Register", function () {
      it("Should register a new username and mint an NFT", async function () {
        const { oracle, usernameNFT, usernameController, owner, addr1 } =
          await loadFixture(deployDummyController);

        const name = "testuser";
        const duration = 2 * SECONDS_PER_YEAR;

        const price = await oracle.price(name.length, duration);

        await usernameController.register(name, duration, {
          value: price,
        });
        const tokenId = await usernameNFT.nameToTokenId(name);

        expect(await usernameNFT.ownerOf(tokenId)).to.equal(owner.address);

        const tokenData = await usernameNFT.tokenData(tokenId);

        expect(tokenData.name).to.equal(name);
      });
      it("Should register a new username and mint an NFT for a previously expired username", async function () {
        const { oracle, usernameNFT, usernameController, owner, addr1 } =
          await loadFixture(deployDummyController);

        const name = "testuser";
        const duration = 2 * SECONDS_PER_YEAR;

        const price = await oracle.price(name.length, duration);

        await usernameController.register(name, duration, {
          value: price,
        });
        const tokenId = await usernameNFT.nameToTokenId(name);

        expect(await usernameNFT.ownerOf(tokenId)).to.equal(owner.address);

        const tokenData = await usernameNFT.tokenData(tokenId);

        expect(tokenData.name).to.equal(name);

        const blocktimestamp = await getBlockTimestamp();
        const totalSeconds = duration + 1;
        await setBlockTimestamp(totalSeconds + blocktimestamp);

        expect(await usernameNFT.isExpired(tokenId)).to.equal(true);

        await usernameController.connect(addr1).register(name, duration, {
          value: price,
        });

        expect(await usernameNFT.ownerOf(tokenId)).to.equal(addr1.address);
        expect(await usernameNFT.isExpired(tokenId)).to.equal(false);
      });
      it("Should fail if not enough Ether is sent", async function () {
        const { oracle, usernameController, addr1 } = await loadFixture(
          deployDummyController
        );

        const name = "testuser";
        const duration = 2 * SECONDS_PER_YEAR;

        const actualPrice = await oracle.price(name.length, duration);

        const attemptedPrice = ethers.utils.parseEther("0.00001");

        expect(attemptedPrice).to.be.lt(actualPrice);

        await expect(
          usernameController.register(name, duration, {
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
        const { usernameController, addr1, usernameNFT, oracle } =
          await loadFixture(deployDummyController);
        const name = "testuser";
        const duration = 2 * SECONDS_PER_YEAR;
        const additionalDuration = 1 * SECONDS_PER_YEAR;
        const registrationPrice = await oracle.price(name.length, duration);
        await usernameController.register(name, duration, {
          value: registrationPrice,
        });
        const tokenId = await usernameNFT.nameToTokenId(name);

        const renewalPrice = await oracle.price(
          name.length,
          additionalDuration
        );
        await usernameController.renew(tokenId, additionalDuration, {
          value: renewalPrice,
        });
        const tokenData = await usernameNFT.tokenData(tokenId);
        expect(tokenData.duration).to.equal(duration + additionalDuration);
      });
      it("Should renew the registration of an expired username given not already taken", async function () {
        const { usernameController, addr1, usernameNFT, oracle } =
          await loadFixture(deployDummyController);
        const name = "testuser";
        const duration = 2 * SECONDS_PER_YEAR;
        const newDuration = 1 * SECONDS_PER_YEAR;
        const registrationPrice = await oracle.price(name.length, duration);
        const renewalPrice = await oracle.price(name.length, newDuration);
        await usernameController.register(name, duration, {
          value: registrationPrice,
        });
        const blocktimestamp = await getBlockTimestamp();
        const totalSeconds = duration * SECONDS_PER_YEAR;
        await setBlockTimestamp(blocktimestamp + 1 + totalSeconds);
        const tokenId = await usernameNFT.nameToTokenId(name);
        await usernameController.renew(tokenId, newDuration, {
          value: renewalPrice,
        });
        const tokenData = await usernameNFT.tokenData(tokenId);
        expect(tokenData.duration).to.equal(newDuration);
      });
      it("Should not renew the registration of an expired username given its already taken", async function () {
        const { usernameController, addr1, addr2, usernameNFT, oracle } =
          await loadFixture(deployDummyController);
        const name = "testuser";
        const durationInYears = 2;
        const additionalDurationInYears = 1;
        const registrationPrice = await oracle.price(
          name.length,
          durationInYears
        );
        const renewalPrice = await oracle.price(
          name.length,
          additionalDurationInYears
        );
        await usernameController
          .connect(addr1)
          .register(name, durationInYears, {
            value: registrationPrice,
          });
        const tokenId = await usernameNFT.nameToTokenId(name);
        const blocktimestamp = await getBlockTimestamp();
        const totalSeconds = durationInYears * SECONDS_PER_YEAR;
        await setBlockTimestamp(blocktimestamp + totalSeconds + 1);
        await usernameController
          .connect(addr2)
          .register(name, durationInYears, {
            value: registrationPrice,
          });
        await expect(
          usernameController.renew(tokenId, additionalDurationInYears, {
            value: renewalPrice,
          })
        ).to.be.revertedWithCustomError(
          usernameController,
          "NotTokenOwnerOrNameTakenError"
        );
      });
      it("Should not renew if not called by token owner", async function () {
        const { usernameController, addr1, usernameNFT, oracle } =
          await loadFixture(deployDummyController);
        const name = "testuser";
        const durationInYears = 2;
        const additionalDurationInYears = 2;
        const registrationPrice = await oracle.price(
          name.length,
          durationInYears
        );
        const renewalPrice = await oracle.price(
          name.length,
          additionalDurationInYears
        );
        await usernameController.register(name, durationInYears, {
          value: registrationPrice,
        });
        const blocktimestamp = await getBlockTimestamp();
        const totalSeconds = durationInYears * SECONDS_PER_YEAR;
        await setBlockTimestamp(blocktimestamp + totalSeconds + 1);
        const tokenId = await usernameNFT.nameToTokenId(name);
        await expect(
          usernameController
            .connect(addr1)
            .renew(tokenId, additionalDurationInYears, {
              value: renewalPrice,
            })
        ).to.be.revertedWithCustomError(
          usernameController,
          "NotTokenOwnerOrNameTakenError"
        );
      });
      it("Should fail if not enough Ether is sent", async function () {
        const { oracle, usernameNFT, usernameController, owner, addr1 } =
          await loadFixture(deployDummyController);
        const name = "testuser";
        const duration = 2 * SECONDS_PER_YEAR;
        const additionalDuration = 2 * SECONDS_PER_YEAR;
        const registrationPrice = await oracle.price(name.length, duration);
        await usernameController.connect(owner).register(name, duration, {
          value: registrationPrice,
        });
        const tokenId = await usernameNFT.nameToTokenId(name);
        await expect(
          usernameController.connect(owner).renew(tokenId, additionalDuration, {
            value: parseEther("0.0000000001"),
          })
        ).to.be.revertedWithCustomError(
          usernameController,
          "InsufficientNativeError"
        );
      });
    });
    describe("Withdraw", function () {
      it("Should withdraw the contract balance to the owner", async function () {
        const { usernameController, owner, addr1, oracle } = await loadFixture(
          deployDummyController
        );
        const name = "testuser";
        const durationInYears = 2;
        const registrationPrice = await oracle.price(
          name.length,
          durationInYears
        );
        await usernameController.register(name, durationInYears, {
          value: registrationPrice,
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
    describe("SetOracle", function () {
      it("Should allow owner to set a new Oracle instance", async () => {
        const { usernameController } = await loadFixture(deployDummyController);
        const randomAddress = getRandomAddress();
        await usernameController.setOracle(randomAddress);
        expect(await usernameController.oracle()).to.equal(randomAddress);
      });
      it("Shouldn't allow non-owner to set a new Oracle instance", async () => {
        const { usernameController, addr1 } = await loadFixture(
          deployDummyController
        );
        const randomAddress = getRandomAddress();
        await expect(
          usernameController.connect(addr1).setOracle(randomAddress)
        ).to.revertedWith("Ownable: caller is not the owner");
      });
    });
    describe("Withdraw", function () {
      it("Should revert upon unsuccessful withdrawal", async () => {
        const { usernameController, oracle } = await loadFixture(
          deployDummyController
        );
        await usernameController.transferOwnership(oracle.address);
        await expect(
          usernameController.withdraw()
        ).to.be.revertedWithCustomError(
          usernameController,
          "FailedWithdrawError"
        );
      });
    });
  });
});
