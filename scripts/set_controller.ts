import hre, { ethers } from "hardhat";
import { UsernameNFT } from "../typechain-types";

async function main() {
  const { deployments } = hre;
  const { get } = deployments;

  const usernameNFTAddress = (await get("UsernameNFT")).address;
  const usernameControllerAddress = (await get("UsernameController")).address;

  const usernameNFTContract = (await ethers.getContractAt(
    "UsernameNFT",
    usernameNFTAddress
  )) as UsernameNFT;

  const tx = await usernameNFTContract.setController(usernameControllerAddress);

  await tx.wait();

  console.log("UsernameNFT controller set to", usernameControllerAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
