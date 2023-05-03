import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { parseEther, formatEther } from "ethers/lib/utils";
import { Oracle__factory } from "../typechain-types";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { SECONDS_PER_YEAR } from "../constants";

describe("Oracle", function () {
  async function deployOracle() {
    const [owner, random] = await ethers.getSigners();

    const Oracle = new Oracle__factory(owner);
    const oracle = await Oracle.deploy();

    return { oracle, random };
  }

  describe("Oracle", function () {
    describe("Price", function () {
      it("Should have correct initial fees", async () => {
        const { oracle } = await loadFixture(deployOracle);

        const fees = await oracle.yearlyUsernameFees();
        expect(fees.lengthThree).to.equal(ethers.utils.parseEther("0.32"));
        expect(fees.lengthFour).to.equal(ethers.utils.parseEther("0.8"));
        expect(fees.lengthFiveOrMore).to.equal(
          ethers.utils.parseEther("0.0025")
        );
      });
      it("Should revert if username length is less than 3", async () => {
        const { oracle } = await loadFixture(deployOracle);

        await expect(oracle.price(2, 31557600)).to.be.revertedWithCustomError(
          oracle,
          "InvalidUsernameLength"
        );
      });
      it("Should calculate price correctly", async () => {
        const { oracle } = await loadFixture(deployOracle);

        const priceThree = await oracle.price(3, SECONDS_PER_YEAR * 2);
        expect(priceThree).to.equal(parseEther("0.32").mul(2));

        const priceFour = await oracle.price(4, SECONDS_PER_YEAR * 4.5);
        expect(priceFour).to.equal(parseEther("3.6"));

        const priceFive = await oracle.price(5, SECONDS_PER_YEAR * 5.75);
        expect(priceFive).to.equal(parseEther("0.014375"));

        const priceSix = await oracle.price(3, SECONDS_PER_YEAR * 10);
        expect(priceThree).to.equal(parseEther("0.32").mul(10));
      });
    });
    describe("ChangeFees", function () {
      it("Should change fees correctly and emit event when called by owner", async () => {
        const { oracle } = await loadFixture(deployOracle);
        const oldFees = await oracle.yearlyUsernameFees();
        const newFees = {
          lengthThree: parseEther("0.4"),
          lengthFour: parseEther("1"),
          lengthFiveOrMore: parseEther("0.003"),
        };
        const tx = await oracle.changeFees(newFees);
        expect(tx).to.emit(oracle, "FeesChanged").withArgs(oldFees, newFees);
        const fees = await oracle.yearlyUsernameFees();
        expect(fees.lengthThree).to.equal(newFees.lengthThree);
        expect(fees.lengthFour).to.equal(newFees.lengthFour);
        expect(fees.lengthFiveOrMore).to.equal(newFees.lengthFiveOrMore);
      });
      it("Should fail if called by non-owner", async () => {
        const { oracle, random } = await loadFixture(deployOracle);
        const newFees = {
          lengthThree: parseEther("0.4"),
          lengthFour: parseEther("1"),
          lengthFiveOrMore: parseEther("0.003"),
        };
        expect(oracle.connect(random).changeFees(newFees)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );
      });
    });
  });
});
