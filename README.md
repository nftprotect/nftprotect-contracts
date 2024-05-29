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
- [ArbitratorRegistry](https://sepolia.etherscan.io/address/0x25bf41c8f7ea92091260c9e50bb44566a0719bd7)
- [SignatureVerifier](https://sepolia.etherscan.io/address/0xffcf59f89debd62c5821bcdea945382657ca3760)
- [NFTProtect](https://sepolia.etherscan.io/address/0x35be7e7dedc7ae13bd80ec8d26cf80ab2f7f0934)
- [UserRegistry](https://sepolia.etherscan.io/address/0x6307453103337b65636b221b4404d302539c99d5)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0x16a1536d4385ff2e5d9fe79a37108e57c4e4bc1a)

## License

This project is licensed under the GNU GPL v2.1 license.
