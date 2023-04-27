import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { Oracle, UsernameNFT } from "../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const oracleAddress = (await deployments.get("Oracle")).address;
  const usernameNFTAddress = (await deployments.get("UsernameNFT")).address;

  await deploy("UsernameController", {
    from: deployer,
    args: [oracleAddress, usernameNFTAddress],
    log: true,
  });
};

export default func;
func.dependencies = ["Oracle", "UsernameNFT"];
func.tags = ["UsernameController"];
