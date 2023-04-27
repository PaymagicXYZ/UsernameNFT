import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { parseEther } from "ethers/lib/utils";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const basePrice = parseEther("1.0"); // Set the initial base price for the Oracle contract

  await deploy("Oracle", {
    from: deployer,
    args: [basePrice],
    log: true,
  });
};

export default func;
func.tags = ["Oracle"];
