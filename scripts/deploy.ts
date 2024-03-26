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

async function deployNFTProtect(arbitratorRegistry: GetContractReturnType, signatureVerifier: GetContractReturnType) {
    const nftProtect = await hre.viem.deployContract("NFTProtect", [arbitratorRegistry.address, signatureVerifier.address]);
    return nftProtect;
}

async function deployUserRegistry(arbitratorRegistry: GetContractReturnType, did: GetContractReturnType, nftProtect: GetContractReturnType) {
    const userRegistry = await hre.viem.deployContract("UserRegistry", [arbitratorRegistry.address, did.address, nftProtect.address]);
    return userRegistry;
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

async function deploySignatureVerifier() {
    const signatureVerifier = await hre.viem.deployContract("SignatureVerifier");
    return signatureVerifier;
}

async function main() {
    try {
        const signatureVerifier = await getOrDeployContract("SignatureVerifier", deploySignatureVerifier);
        const arbitratorRegistry = await getOrDeployContract("ArbitratorRegistry", deployArbitratorRegistry);
        const did = await getOrDeployContract("UserDIDDummyAllowAll", deployDID);
        const nftProtect = await getOrDeployContract("NFTProtect", () => deployNFTProtect(arbitratorRegistry, signatureVerifier));
        const userRegistry = await getOrDeployContract("UserRegistry", () => deployUserRegistry(arbitratorRegistry, did, nftProtect));
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