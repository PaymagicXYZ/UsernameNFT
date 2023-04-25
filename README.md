# UsernameNFT Smart Contracts

Smart contracts to create “Username NFTs” aka a Community Namespace for your project/DAO/community. Used by [Usernames.club](https://usernames.club/).

Like .lens .nouns .bayc .aave .gitcoin .shefi .safe .mask .uni .sushi .ldo…

It’s simple to setup, ENS compatible, and all username NFT fees go to support your specific community, not ENS.

The [Usernames.club](https://usernames.club/) is owned and governed by a [Nounish DAO](https://nouns.build/dao/0xcbfea5c61aa7492610bdda80a927291b485e6f95/12) on Ethereum. To get started your community must win a Pass at auction.

## Smart Contracts

- UsernameNFT.sol - Ownable ERC 721 NFT with extra `tokenData` storage for resolving addresses, resolving names from an address, and expiration times. Owner can only change the Controller.
- UsernameController.sol - Controls registrations and renewables of the UsernameNFT. Owner can only change the Oracle contract and withdraw funds to itself.
- Oracle.sol - Controls the pricing model of registering UsernameNFTs.

## Run

Try running some of the following tasks:

```shell
yearn hardhat help
yarn hardhat test
REPORT_GAS=true yarn hardhat test
yarn hardhat node
yarn hardhat run scripts/deploy.ts
```
