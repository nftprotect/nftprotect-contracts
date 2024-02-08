import { readFileSync, writeFileSync, existsSync } from 'fs';
import { GetContractReturnType } from "viem";
import hre from "hardhat";

const jsonFilePath = './contracts.json'; // Path to your JSON file

let contractsData = existsSync(jsonFilePath) ? JSON.parse(readFileSync(jsonFilePath, 'utf-8')) : {};

async function getOrDeployContract(contractName: string, deployFunction: () => Promise<GetContractReturnType>) {
  const networkName = hre.network.name;
  let networkData = contractsData[networkName] || {};

  if (networkData[contractName]) {
    const contract = await hre.viem.getContractAt(contractName, networkData[contractName]);
    console.log(`Existing ${contractName}: ${contract.address}`)
    return contract;
  } else {
    const contract = await deployFunction();
    console.log(`Deployed ${contractName}: ${contract.address}`)
    networkData[contractName] = contract.address;
    contractsData[networkName] = networkData;
    return contract;
  }
}

async function deployNFTProtect(arbitratorRegistry: GetContractReturnType) {
    const nftProtect = await hre.viem.deployContract("NFTProtect", [arbitratorRegistry.address]);
    return nftProtect;
}

async function deployUserRegistry(arbitratorRegistry: GetContractReturnType, did: GetContractReturnType, nftProtect: GetContractReturnType, coupons: GetContractReturnType) {
    const userRegistry = await hre.viem.deployContract("UserRegistry", [arbitratorRegistry.address, did.address, nftProtect.address, coupons.address]);
    return userRegistry;
}

async function deployNFTPCoupons() {
    const userRegistry = await hre.viem.deployContract("NFTPCoupons");
    return userRegistry;
}

async function getCouponsAddress(userRegistry: GetContractReturnType) {
    // Get the address of the Coupons contract
    const couponsAddress = await userRegistry.read.coupons();
    console.log("Coupons contract address:", couponsAddress)
    // Save the Coupons contract address to the contractsData
    let networkData = contractsData[hre.network.name] || {};
    networkData["NFTPCoupons"] = couponsAddress;
    contractsData[hre.network.name] = networkData;
    return couponsAddress
}

async function deployArbitratorRegistry() {
    const arbRegistry = await hre.viem.deployContract("ArbitratorRegistry");
    return arbRegistry;
}

async function deployDID() {
    const did = await hre.viem.deployContract("UserDIDDummyAllowAll");
    return did;
}

async function deployMultipleProtectHelper(nftProtect: GetContractReturnType) {
    const helper = await hre.viem.deployContract("MultipleProtectHelper", [nftProtect.address]);
    return helper;
}


async function main() {
    try {
        const arbitratorRegistry = await getOrDeployContract("ArbitratorRegistry", deployArbitratorRegistry);
        const did = await getOrDeployContract("UserDIDDummyAllowAll", deployDID);
        const nftProtect = await getOrDeployContract("NFTProtect", () => deployNFTProtect(arbitratorRegistry));
        const coupons = await getOrDeployContract("NFTPCoupons", () => deployNFTPCoupons());
        const userRegistry = await getOrDeployContract("UserRegistry", () => deployUserRegistry(arbitratorRegistry, did, nftProtect, coupons));
        const protectHelper = await getOrDeployContract("MultipleProtectHelper", () => deployMultipleProtectHelper(nftProtect));
    } catch (error) {
        console.error(error);
        process.exitCode = 1;
    } finally {
        // Write the updated data back to the file after all operations
        writeFileSync(jsonFilePath, JSON.stringify(contractsData, null, 2));
    }
}

main();