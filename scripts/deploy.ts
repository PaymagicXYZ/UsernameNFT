import { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";

async function main() {
  const price = parseEther("0.000001");
  const [owner, addr1, addr2] = await ethers.getSigners();

  const Oracle = await ethers.getContractFactory("Oracle");
  const oracle = await Oracle.deploy(price);

  const UsernameNFT = await ethers.getContractFactory("UsernameNFT");
  const usernameNFT = await UsernameNFT.deploy("UsernameNFT", "UNFT");

  const UsernameController = await ethers.getContractFactory(
    "UsernameController"
  );
  const usernameController = await UsernameController.deploy(
    oracle.address,
    usernameNFT.address
  );

  await usernameNFT.setController(usernameController.address);

  console.log(`Oracle: ${oracle.address}`)
  console.log(`UsernameNFT: ${usernameNFT.address}`)
  console.log(`UsernameController: ${usernameController.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
