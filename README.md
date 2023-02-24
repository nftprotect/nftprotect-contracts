<img src="https://github.com/NFT-Protect/.github/raw/main/profile/git-avatar.png" width="96">

# NFT Protect Contracts

This repository contains the smart contracts for NFT Protect. The system consists of several contracts responsible for various functions, including arbitration, user identity management, coupon generation and redemption, and NFT protection.

## Contracts

- `NftProtect.sol`: the main NFT Protect contract.

- `ArbitratorRegistry.sol`: contract for managing arbitrators.

- `UserRegistry.sol`: contract for managing user accounts.

- `IUserRegistry.sol`: interface for the user registry contract.


## Installation

To install and use these contracts, follow these steps:

1. Clone this repository to your local machine.

 `git clone https://github.com/nftprotect/nftprotect-contracts.git`

2. Install the necessary dependencies.

  `npm install`

3. Compile the contracts.

 `npx hardhat compile`

4. Deploy the contracts.

 `npx hardhat run scripts/deploy.js`

## Usage

To use the NFT Protect system, follow these steps:

1. Register as a user on the `UserRegistry` contract.
2. Prove your identity using the `UserDidPoh` contract.
3. Protect your NFT using the `NftProtect` contract.
4. If a dispute arises, the `ArbitratorRegistry` contract will be used to resolve it.

## Deployment Addresses

### Goerli testnet

| Contract  | Address |
| ------------- | ------------- |
| `NftProtect.sol` | [0x1dF68B8dC2B4ECe16D240b4A7FE7158a5b2aFc0A](https://goerli.etherscan.io/address/0x1dF68B8dC2B4ECe16D240b4A7FE7158a5b2aFc0A) |
| `ArbitratorRegistry.sol` | [0x43D6b852d6f02992f636e38427EB5835b69Acfe3](https://goerli.etherscan.io/address/0x43D6b852d6f02992f636e38427EB5835b69Acfe3)  |
| `UserRegistry.sol` | [0xC27C86529267a90abe7e443419657B8CbE33AAB0](https://goerli.etherscan.io/address/0xC27C86529267a90abe7e443419657B8CbE33AAB0) |
| `IUserRegistry.sol` | [0xC27C86529267a90abe7e443419657B8CbE33AAB0](https://goerli.etherscan.io/address/0xC27C86529267a90abe7e443419657B8CbE33AAB0) |


## License

This project is licensed under the GNU GPL v2.1 license.