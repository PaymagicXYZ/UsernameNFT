import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("DummyOracle", function () {
  async function deployDummyOracle() {
    const DummyOracle = await ethers.getContractFactory("DummyOracle");
    const dummyOracle = await DummyOracle.deploy();

    return { dummyOracle };
  }

  describe("DummyOracle", function () {
    describe("Price", function () {
      it("Should return the correct price", async function () {
        const { dummyOracle } = await loadFixture(deployDummyOracle);

        const price = await dummyOracle.price();

        expect(price).to.equal(ethers.utils.parseEther("1"));
      });
    });
  });
});
