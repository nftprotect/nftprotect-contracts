<img src="https://github.com/NFT-Protect/.github/raw/main/profile/git-avatar.png" width="96">

# NFT Protect Contracts

[![CodeFactor](https://www.codefactor.io/repository/github/nftprotect/nftprotect-contracts/badge)](https://www.codefactor.io/repository/github/nftprotect/nftprotect-contracts)

This repository contains the smart contracts for NFT Protect. The system consists of several contracts responsible for various functions, including arbitration, user identity management, coupon generation and redemption, and NFT protection.

## Deployment

Contracts are deployed using the deploy.ts script. This script checks if a contract has already been deployed on the network, and if not, deploys it.
```shell
yarn build
yarn deploy --network sepolia
```

## Verification

After deployment, contracts can be verified using the verify.ts script. This script reads the contract data from contracts.json and verifies each contract on the network.
```shell
yarn verify --network sepolia
```

## Configuration

To configure contracts automatically after deployment, run the following:
```shell
yarn configure --network sepolia
```
This script performs smart contracts configuration based on contracts.json and arbitrators.json.

## ABI exporting
To export ABI run this command:
```shell
yarn export-abi
```

## Contracts
### Sepolia
- [SignatureVerifier](https://sepolia.etherscan.io/address/0x023dc7bfb3d840003b39f676bc4f1cc06d78ab49)
- [ArbitratorRegistry](https://sepolia.etherscan.io/address/0x25bf41c8f7ea92091260c9e50bb44566a0719bd7)
- [UserDIDDummyAllowAll](https://sepolia.etherscan.io/address/0x4e20ddceea48ecbf26bcb4c0cedb9d4bd4df2f3f)
- [NFTProtect](https://sepolia.etherscan.io/address/0xcb0e6c944bdd44e80bd04d28e6467250f1d4c0ce)
- [UserRegistry](https://sepolia.etherscan.io/address/0x9116e40c81e19c7a7cc0286c0d861691dc0d818b)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0xbae36f93f56ac730456e25220d44c0af0cb9f4b2)

## License

This project is licensed under the GNU GPL v2.1 license.
