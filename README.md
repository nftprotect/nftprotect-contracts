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
- [NFTProtect](https://sepolia.etherscan.io/address/0x1248fdef531b944469b4a61479a2c87f861f84f2)
- [UserRegistry](https://sepolia.etherscan.io/address/0x46b2d1dfdc8f64303fe9d11c57acbcf380be6e7a)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0x9833cafecd2a6ea5703ed958b4a6eacc7ee66927)

## License

This project is licensed under the GNU GPL v2.1 license.
