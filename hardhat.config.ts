import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "solidity-coverage";
import "hardhat-deploy-ethers";
import "hardhat-deploy";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  // networks: {
  //   hardhat: {
  //     forking: {
  //       url: `https://mainnet.infura.io/v3/${process.env.ALCHEMY_KEY}`,
  //     },
  //   },
  // },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
      },
    },
  },
};

export default config;
