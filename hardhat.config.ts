import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  // networks: {
  //   hardhat: {
  //     forking: {
  //       url: `https://mainnet.infura.io/v3/${process.env.ALCHEMY_KEY}`,
  //     },
  //   },
  // },
};

export default config;
