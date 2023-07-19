import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = ".example Username NFTs";
  const symbol = "EXAMPLE";
  const domain = "example";

  await deploy("ExampleUsernameNFT", {
    from: deployer,
    args: [name, symbol, domain],
    log: true,
  });
};

export default func;
func.tags = ["MockUsernameNFT"];
