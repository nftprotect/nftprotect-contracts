# NFT Protect Contracts

This repository contains the smart contracts for NFT Protect. The system consists of several contracts responsible for various functions, including arbitration, user identity management, coupon generation and redemption, and NFT protection.

## Contracts

- `ArbitratorRegistry.sol`: contract for managing arbitrators.

- `IUserDid.sol`: interface for the user DID contract.

- `UserDidPoh.sol`: contract for proving user identity.

- `IUserRegistry.sol`: interface for the user registry contract.

- `NftProtect.sol`: the main NFT Protect contract.
UserRegistry.sol: contract for managing user accounts.

## Installation
To install and use these contracts, follow these steps:

1. Clone this repository to your local machine.

 `git clone https://github.com/<username>/nft-protect-contracts.git`

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
Protect your NFT using the `NftProtect` contract.
3. If a dispute arises, the `ArbitratorRegistry` contract will be used to resolve it.

## License
This project is licensed under the GNU GPL v2.1 license.