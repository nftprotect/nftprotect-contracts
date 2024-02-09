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
- [ArbitratorRegistry](https://sepolia.etherscan.io/address/0xa8d82ab740b0ba1a1b5784b86ecdc41d53e4ff15)
- [UserDIDDummyAllowAll](https://sepolia.etherscan.io/address/0xeb18ef1022810079afbe8f8b6548b3bfd5a7cc2b)
- [NFTProtect](https://sepolia.etherscan.io/address/0xe7807e973f42aea32da71c15a6441760f675d9cc)
- [NFTPCoupons](https://sepolia.etherscan.io/address/0x8f1cb013426f591220c51c516ac185a21405afa8)
- [UserRegistry](https://sepolia.etherscan.io/address/0x727718859965b1c88c79491721d9b861654f6a73)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0xf650a5911c5e527bb8bb2a31d5a23cf9865b17d4)

## License

This project is licensed under the GNU GPL v2.1 license.
