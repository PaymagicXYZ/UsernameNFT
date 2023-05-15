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

  console.log(
    await usernameControllerContract.interface.decodeFunctionData(
      "register",
      "0x9c87a1210000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000076578616d706c6500000000000000000000000000000000000000000000000000"
    )
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
