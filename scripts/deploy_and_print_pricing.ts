import { ethers } from "hardhat";
import { Oracle } from "../typechain-types";
import { parseEther, formatEther } from "ethers/lib/utils";

async function main() {
  const OracleFactory = await ethers.getContractFactory("Oracle");

  // Deploy the Oracle contract with an initial base price of 100
  const oracle = (await OracleFactory.deploy(100)) as Oracle;
  await oracle.deployed();
  console.log("Oracle deployed to:", oracle.address);

  // Define base prices and username lengths to test
  const basePrices = [parseEther("0.5"), parseEther("1"), parseEther("2")];
  const usernameLengths = [3, 4, 5, 6, 7, 8, 9, 10];

  // Print the pricing chart
  console.log("\nPrice Chart:");
  console.log(
    "Base Price (Ether) | Username Length | Price for 1 Year | Price for 2 Years | Price for 3 Years"
  );
  console.log(
    "----------------------------------------------------------------------------------------------------"
  );

  for (const basePrice of basePrices) {
    await oracle.setBasePrice(basePrice);

    for (const usernameLength of usernameLengths) {
      const price1Year = formatEther(await oracle.price(usernameLength, 1));
      const price2Years = formatEther(await oracle.price(usernameLength, 2));
      const price3Years = formatEther(await oracle.price(usernameLength, 3));

      usernameLength == 3
        ? console.log(
            `${formatEther(basePrice).padEnd(18, " ")}| ${usernameLength
              .toString()
              .padStart(2, " ")
              .padEnd(16, " ")}| ${price1Year.padEnd(
              17,
              " "
            )}| ${price2Years.padEnd(17, " ")}| ${price3Years}`
          )
        : console.log(
            `${formatEther(basePrice).padEnd(18, " ")}| ${usernameLength
              .toString()
              .padStart(2, " ")
              .padEnd(16, " ")}| ${price1Year.padEnd(
              17,
              " "
            )}| ${price2Years.padEnd(17, " ")}| ${price3Years}`
          );
    }
  }
  console.log(
    "----------------------------------------------------------------------------------------------------"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
