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
- [NFTProtect](https://sepolia.etherscan.io/address/0x954edfce24448c3500b635b05dfcc051ca69d4de)
- [UserRegistry](https://sepolia.etherscan.io/address/0x8a3b109da314dde8eee77e7cb5be6e0922126ec2)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0x296be1f5f4d51fc4da19841ce266e1f15b01c7b8)

## License

This project is licensed under the GNU GPL v2.1 license.
