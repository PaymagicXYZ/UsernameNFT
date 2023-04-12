import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";

describe("Oracle", function () {
  async function deployOracle() {
    const price = parseEther("1");
    const Oracle = await ethers.getContractFactory("Oracle");
    const oracle = await Oracle.deploy(price);

    return { oracle, price };
  }

  describe("Oracle", function () {
    describe("Price", function () {
      it("Should return the correct price", async function () {
        const { oracle } = await loadFixture(deployOracle);

        const price = await oracle.price();

        expect(price).to.equal(ethers.utils.parseEther("1"));
      });
      it("Should allow owner to set a new price", async function () {
        const { oracle, price } = await loadFixture(deployOracle);

        const newPrice = parseEther("2");

        const tx = await oracle.setPrice(newPrice);

        expect(await oracle.price()).to.equal(newPrice);

        expect(tx).to.emit(oracle, "PriceChanged").withArgs(price, newPrice);
      });
    });
  });
});
