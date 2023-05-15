import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = ".linea Username NFTs";
  const symbol = "LINEA";
  const domain = "linea";

  await deploy("UsernameNFT", {
    from: deployer,
    args: [name, symbol, domain],
    log: true,
  });
};

export default func;
func.tags = ["UsernameNFT"];
