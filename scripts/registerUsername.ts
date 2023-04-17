import { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";

async function main() {
	const UsernameControllerAddress = "0x3ce451c694Ce520B0469921d8811426F020f454B"
  const UsernameController = await ethers.getContractFactory("UsernameController");
  const usernameController = await UsernameController.attach(UsernameControllerAddress);

  const price = parseEther("0.000001");
	const duration = 100;

  await usernameController.register("testalpha", "0x2413F7F1E63D0cA6BD011c9d103D20C57d163F79", duration, {
    value: price,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
