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
- [SignatureVerifier](https://sepolia.etherscan.io/address/0x63473816e94ad6c2c8b9ec496957b900b818faf9)
- [ArbitratorRegistry](https://sepolia.etherscan.io/address/0xb8ef2a8ca0be3f5d734446cd6a13f56372a56e2b)
- [NFTProtect](https://sepolia.etherscan.io/address/0x27b6e64bf6faec53141f2a2cd2da55dc1dffa5ba)
- [UserRegistry](https://sepolia.etherscan.io/address/0xf557231b2e3b088e9b8cb1072c0ce03898975c6a)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0xebb68e730ca1bab2f8191bf150c7392e62f94fc0)

## License

This project is licensed under the GNU GPL v2.1 license.
