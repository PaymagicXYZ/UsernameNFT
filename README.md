# UsernameNFT Smart Contracts

Smart contracts to create “Username NFTs” aka a Community Namespace for your project/DAO/community. Used by [Usernames.club](https://usernames.club/).

Like .lens .nouns .bayc .aave .gitcoin .shefi .safe .mask .uni .sushi .ldo…

It’s simple to setup, ENS compatible, and all username NFT fees go to support your specific community, not ENS.

The [Usernames.club](https://usernames.club/) is owned and governed by a [Nounish DAO](https://nouns.build/dao/0xcbfea5c61aa7492610bdda80a927291b485e6f95/12) on Ethereum. To get started your community must win a Pass at auction.

## Smart Contracts

- UsernameNFT.sol - An ERC721 non-fungible token (NFT) contract that represents unique usernames. It stores the username data, including the resolved address and duration, and provides functionality for registering, updating, and resolving usernames to their corresponding addresses. The contract also includes functions for checking if a username is expired and handling errors related to invalid addresses or duplicate registrations. An instance of UsernameController must be set with the setController function in UsernameNFT, which can be done with the script at `scripts/set_controller.ts` after the contracts have been deployed in the manner described below.

- UsernameController.sol - Responsible for managing the registration, renewal, and updating of usernames. It interacts with the Oracle contract to determine the price for registering or renewing a username and the UsernameNFT contract to store and manage the username data. The contract enforces rules on valid usernames, such as minimum length, and handles errors related to insufficient funds or unauthorized access.

- Oracle.sol - Responsible for determining the price of registering or renewing a username based on its length. The price is inversely proportional to the natural logarithm of the username length. The contract owner can change the base price. The contract utilizes the ABDKMath64x64 library for mathematical operations and inherits from the OpenZeppelin Ownable contract for access control.

## Pricing

The pricing script is located at `scripts/deploy_and_print_pricing.ts`. It is preconfigured to print a formatted table with pricing information, including the base price, username length, and registration/renewal prices for 1, 2, and 3 years for preconfigured base pricing of 0.5, 1.0, and 2.0 Ether.

To run the pricing script, execute the following command:

```
yarn hardhat pricing
```

## Usage

### Compile Contracts

To compile the contracts, run the following command:

```
yarn hardhat compile
```

### Run Tests

To run the tests, execute the following command:

```
yarn hardhat test
```

### Generate Code Coverage Report

To generate a code coverage report using the `solidity-coverage` plugin, run the following command:

```
yarn hardhat coverage
```

### Deploy Contracts

To deploy the contracts to a local Hardhat node, run the following command:

```
yarn hardhat deploy

```

or

```
yarn hardhat deploy --network hardhat
```

If you want to deploy to a different network, replace `hardhat` with the desired network that is configured in your `hardhat.config.ts` file and update the command accordingly.
