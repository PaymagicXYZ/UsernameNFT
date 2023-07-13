import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "solidity-coverage";
import "hardhat-deploy-ethers";
import "hardhat-deploy";
import "hardhat-contract-sizer";
import "dotenv/config";

const isCoverage = process.argv.includes("coverage");

const PK = process.env.PK || "";
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999,
      },
      viaIR: !isCoverage,
    },
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks: {
    mumbai: {
      url: "https://matic-mumbai.chainstacklabs.com",
      accounts: [PK],
      chainId: 80001,
      live: true,
      saveDeployments: true,
      gasMultiplier: 2,
    },
    pzkevmt: {
      url: "https://rpc.public.zkevm-test.net",
      accounts: [PK],
      chainId: 1442,
      live: true,
      saveDeployments: true,
      gasMultiplier: 2,
    },
    pzkevm: {
      url: "https://zkevm-rpc.com",
      accounts: [PK],
      chainId: 1101,
      live: true,
      saveDeployments: true,
      gasMultiplier: 2,
    },
    lineat: {
      url: "https://rpc.goerli.linea.build",
      accounts: [PK],
      chainId: 59140,
      live: true,
      saveDeployments: true,
      gasMultiplier: 2,
    },
  },
};

export default config;
