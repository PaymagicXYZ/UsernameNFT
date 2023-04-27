import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { parseEther, formatEther } from "ethers/lib/utils";
import { Oracle__factory } from "../typechain-types";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

describe("Oracle", function () {
  async function deployOracle() {
    const price = parseEther("0.5");

    const [owner, random] = await ethers.getSigners();

    const Oracle = new Oracle__factory(owner);
    const oracle = await Oracle.deploy(price);

    return { oracle, random, price };
  }

  describe("Oracle", function () {
    describe("Price", function () {
      it("should set the correct base price on deployment", async () => {
        const { oracle } = await loadFixture(deployOracle);

        const basePrice = await oracle.basePrice();
        expect(basePrice).to.equal(parseEther("0.5"));
      });
      it("should return the base price if username length is 3", async () => {
        const { oracle } = await loadFixture(deployOracle);

        const price = await oracle.price(3, 1);
        expect(price).to.equal(await oracle.basePrice());
      });
      it("should revert if username length is less than 3", async () => {
        const { oracle } = await loadFixture(deployOracle);

        await expect(oracle.price(2, 1)).to.be.revertedWithCustomError(
          oracle,
          "UsernameTooShortError"
        );
      });
      it("Should return correct price inversely proportional to username length", async function () {
        const { oracle } = await loadFixture(deployOracle);

        const price3 = await oracle.price(3, 1);
        const price4 = await oracle.price(4, 1);
        const price5 = await oracle.price(5, 1);

        expect(price3).to.be.gt(price4);
        expect(price4).to.be.gt(price5);
      });
    });
    describe("setBasePrice", function () {
      it("Should allow owner to set a new base price", async function () {
        const { oracle, price } = await loadFixture(deployOracle);
        const newPrice = parseEther("2");
        const tx = await oracle.setBasePrice(newPrice);
        expect(await oracle.basePrice()).to.equal(newPrice);
        expect(tx).to.emit(oracle, "PriceChanged").withArgs(price, newPrice);
      });
      it("Should not allow non-owner to set a new base price", async function () {
        const { oracle, price, random } = await loadFixture(deployOracle);
        const newPrice = parseEther("2");
        expect(oracle.connect(random).setBasePrice(newPrice)).to.revertedWith(
          "Ownable: caller is not the owner"
        );
      });
    });
  });
});
