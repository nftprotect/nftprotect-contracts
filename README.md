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
- [NFTProtect](https://sepolia.etherscan.io/address/0xd363012732291f68eaea10beb05c497de6a02afd)
- [UserRegistry](https://sepolia.etherscan.io/address/0x5a38518911389d409b11f4b4b9908fb1672fb082)
- [NFTPCoupons](https://sepolia.etherscan.io/address/0x47459E91900264153D331bddAf9449905bcBE6B5)
- [MultipleProtectHelper](https://sepolia.etherscan.io/address/0x23281922f679895490450a24e6854eb7fab5b0e2)

### Goerli
- [UserDIDDummyAllowAll](https://goerli.etherscan.io/address/0x53FeB2b6C816a88aB192a94113d03c5E17EB1fF2)
- [ArbitratorRegistry](https://goerli.etherscan.io/address/0x094c049f25d6ea178b3262887d37ad9da36b2355)
- [NFTProtect](https://goerli.etherscan.io/address/0x13367954799c3c89452b0a634f898f5d2f3d6e84)
- [UserRegistry](https://goerli.etherscan.io/address/0xbfdc9f6ba697312a8a86a19aaff036e720fce016)
- [NFTPCoupons](https://goerli.etherscan.io/address/0x90F888c0Da7Aa0ca87ABf2ee92bdF8C1d3A03882)
- [MultipleProtectHelper](https://goerli.etherscan.io/address/0x80248c3339dcf11d4b4819b5a27e391c86e32f58)

## License

This project is licensed under the GNU GPL v2.1 license.
