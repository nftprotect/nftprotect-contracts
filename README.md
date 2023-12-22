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
- [NFTProtect](https://sepolia.etherscan.io/address/0xca2eb5a3fb5d74aecbb54fc513f678a95bb42bd4)
- [UserRegistry](https://sepolia.etherscan.io/address/0x771192e571402e4dc96636a72a40863c8daa63c8)
- [NFTPCoupons](https://sepolia.etherscan.io/address/0x46BD8813d9e66b37d99d29241cA58b92C9B0C88f)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0xa132acf9a6c67fd429d75ac97933edf4910b8f28)

### Goerli
- [UserDIDDummyAllowAll](https://goerli.etherscan.io/address/0x53FeB2b6C816a88aB192a94113d03c5E17EB1fF2)
- [ArbitratorRegistry](https://goerli.etherscan.io/address/0x094c049f25d6ea178b3262887d37ad9da36b2355)
- [NFTProtect](https://goerli.etherscan.io/address/0x04e41851820f02066341488e03e38187f3c52702)
- [UserRegistry](https://goerli.etherscan.io/address/0x69b34502cc9e31c09b18435f0e01a0f516d3ff3f)
- [NFTPCoupons](https://goerli.etherscan.io/address/0x0D33DF38CFdF1Edd499535c79a68245F94778d6a)
- [MultipleProtectHelper](https://goerli.etherscan.io/address/0xe83c71eb19a45a932e405f57841f08fd26a454b9)

## License

This project is licensed under the GNU GPL v2.1 license.
