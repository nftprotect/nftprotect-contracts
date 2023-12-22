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
- [UserDIDDummyAllowAll](https://sepolia.etherscan.io/address/0xc29da1a7998414374c05664fedc90ecbefbe5b2d)
- [ArbitratorRegistry](https://sepolia.etherscan.io/address/0x423f42f53f67356e7bc9093410303c68c8478fe7)
- [NFTProtect](https://sepolia.etherscan.io/address/0xc8aea4812e3baf160c97782d349525327f171483)
- [UserRegistry](https://sepolia.etherscan.io/address/0x84439de25faf197929bd3f81de3a650cae6b76ff)
- [NFTPCoupons](https://sepolia.etherscan.io/address/0x0cD0E732b600b282AA5e41dc0Ca7203726608745)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0x7b508ac423a2b503c486e4bdf18df0742f1064af)

### Goerli
- [UserDIDDummyAllowAll](https://goerli.etherscan.io/address/0x53FeB2b6C816a88aB192a94113d03c5E17EB1fF2)
- [ArbitratorRegistry](https://goerli.etherscan.io/address/0x094c049f25d6ea178b3262887d37ad9da36b2355)
- [NFTProtect](https://goerli.etherscan.io/address/0xa4868ab18cf07b25e70d1bd21c7e1416103d8fd7)
- [UserRegistry](https://goerli.etherscan.io/address/0x0d009bb504d9bd71dd5f0f1cd99ba2077e23f88e)
- [NFTPCoupons](https://goerli.etherscan.io/address/0x717E3407972674C8141969d6393F81975EF14f42)
- [MultipleProtectHelper](https://goerli.etherscan.io/address/0xb1854272eeb913096d2a95565226f852cccf0478)

## License

This project is licensed under the GNU GPL v2.1 license.
