import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = ".zkevm Username NFTs";
  const symbol = "zkevm";
  const domain = "zkevm";

  await deploy("UsernameNFT", {
    from: deployer,
    args: [name, symbol, domain],
    log: true,
  });
};

export default func;
func.tags = ["UsernameNFT"];
