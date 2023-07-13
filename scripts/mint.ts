import hre, { ethers } from "hardhat";
import { UsernameNFT, UsernameController, Oracle } from "../typechain-types";

async function main() {
  const { deployments } = hre;
  const { get } = deployments;

  const usernameControllerAddress = (await get("UsernameController")).address;
  const oracleAddress = (await get("Oracle")).address;

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

  await usernameControllerContract.register(username, 100000000, {
    value: price,
  });

  console.log("Minted!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
