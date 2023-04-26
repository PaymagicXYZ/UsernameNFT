import { ethers } from "hardhat";

export const getBlockTimestamp = async (): Promise<number> => {
  const block = await ethers.provider.getBlockNumber();
  const { timestamp } = await ethers.provider.getBlock(block);
  return timestamp;
};

export const setBlockTimestamp = async (timestamp: number) => {
  await ethers.provider.send("evm_mine", [timestamp]);
};

export const getRandomAddress = () => {
  return ethers.utils.getAddress(
    ethers.utils.hexlify(ethers.utils.randomBytes(20))
  );
};
