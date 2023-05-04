import hre, { ethers } from "hardhat";
import { UsernameNFT, UsernameController, Oracle } from "../typechain-types";

async function main() {
  const { deployments } = hre;
  const { get } = deployments;

  const usernameNFTAddress = (await get("UsernameNFT")).address;
  const usernameControllerAddress = (await get("UsernameController")).address;
  const oracleAddress = (await get("Oracle")).address;

  const usernameNFTContract = (await ethers.getContractAt(
    "UsernameNFT",
    usernameNFTAddress
  )) as UsernameNFT;

  const usernameControllerContract = (await ethers.getContractAt(
    "UsernameController",
    usernameControllerAddress
  )) as UsernameController;

  const oracleContract = (await ethers.getContractAt(
    "Oracle",
    oracleAddress
  )) as Oracle;

  const username = "longname";

  const price = await oracleContract.price(username.length, 100000000);

  const tx = await usernameControllerContract.register(username, 100000000, {
    value: price,
  });

  const receipt = await tx.wait();

  console.log("Minted!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
