import hre, { ethers } from "hardhat";
import { UsernameNFT, UsernameController, Oracle } from "../typechain-types";

async function main() {
  const { deployments } = hre;
  const { get } = deployments;

  const newOwner = "0x74427681c620DE258Aa53a382d6a4C865738A06C";

  const usernameNFTAddress = (await get("UsernameNFT")).address;
  const usernameControllerAddress = (await get("UsernameController")).address;
  const oracleAddress = (await get("Oracle")).address;

  const usernameNFTContract = (await ethers.getContractAt(
    "UsernameNFT",
    usernameNFTAddress
  )) as UsernameNFT;

  const tx = await usernameNFTContract.setController(usernameControllerAddress);

  await tx.wait();

  console.log("UsernameNFT controller set to", usernameControllerAddress);

  const tx2 = await usernameNFTContract.transferOwnership(newOwner);

  await tx2.wait();

  console.log("UsernameNFT owner set to", newOwner);

  const usernameControllerContract = (await ethers.getContractAt(
    "UsernameController",
    usernameControllerAddress
  )) as UsernameController;

  const tx3 = await usernameControllerContract.transferOwnership(newOwner);

  await tx3.wait();

  console.log("UsernameController owner set to", newOwner);

  const oracleContract = (await ethers.getContractAt(
    "Oracle",
    oracleAddress
  )) as Oracle;

  const tx4 = await oracleContract.transferOwnership(newOwner);

  await tx4.wait();

  console.log("Oracle owner set to", newOwner);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
