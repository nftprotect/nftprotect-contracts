import { readFileSync, existsSync } from 'fs';
import hre from "hardhat";
import { PublicClient } from "viem";
import { 
    fees, 
    arbitrators,
    metaEvidences,
    metaEvidenceLoader,
    metadataURIs
} from '../contracts.config';


const contractsFilePath = './contracts.json'; // Path to your JSON file

const nullAddress = '0x0000000000000000000000000000000000000000'
const networkName = hre.network.name;

let contractsData = existsSync(contractsFilePath) ? JSON.parse(readFileSync(contractsFilePath, 'utf-8')) : {};
let networkData = contractsData[networkName] || {};
let client: PublicClient;

async function processTransaction(hash :`0x${string}`) {
    if (client) {
        console.log(`Waiting for transaction receipt ( ${hash} )...`)
        const receipt = await client.waitForTransactionReceipt({hash})
        if (receipt.status === 'success') {
            console.log('Transaction successfull')
        } else {
            console.log('Transaction unsuccessfull:', receipt)
            throw Error(`Transaction error: ${hash}`)
        }
    }
}

// ArbitratorRegistry

async function configureArbitratorRegistry() {
    let arbitratorData = arbitrators[networkName];

    if (!networkData["ArbitratorRegistry"]) {
        throw Error("ArbitratorRegistry contract address not found in contracts.json")
    }

    if (!arbitratorData) {
        throw Error(`Arbitrator data not found for ${networkName}`)
    }

    const contract = await hre.viem.getContractAt("ArbitratorRegistry", networkData["ArbitratorRegistry"]);

    const isConfigured = await contract.read.checkArbitrator([1n]);
    if (isConfigured) {
        console.log(`Arbitrator already set`);
        return contract;
    } else {
        console.log(`Setting Arbitrator...`);
    }

    const hash = await contract.write.addArbitrator([arbitratorData.name, arbitratorData.address, arbitratorData.extraData]);
    await processTransaction(hash)
    return contract
}

// NFTProtect
  
async function setNFTProtectUserRegistry() {  
    if (!networkData["NFTProtect"] || !networkData["UserRegistry"]) {
      throw Error("NFTProtect or UserRegistry contract address not found in contracts.json");
    }
  
    const contract = await hre.viem.getContractAt("NFTProtect", networkData["NFTProtect"]);
    const userRegistryAddress = await contract.read.userRegistry();
  
    if (userRegistryAddress !== nullAddress) {
      console.log(`NFTProtect: UserRegistry ${userRegistryAddress} already set`);
      return contract;
    }
    
    console.log(`Setting UserRegistry ${networkData["UserRegistry"]}...`);
    const hash = await contract.write.setUserRegistry([networkData["UserRegistry"]]);
    await processTransaction(hash)
    return contract
}

async function setNFTProtectBaseURI() {  
    if (!networkData["NFTProtect"]) {
      throw Error("NFTProtect contract address not found in contracts.json");
    }
  
    const contract = await hre.viem.getContractAt("NFTProtect", networkData["NFTProtect"]);
    const baseUri = await contract.read.base();
    const newBaseUri = metadataURIs[networkName]

    if (baseUri === newBaseUri) {
      console.log(`NFTProtect: Base URI ${baseUri} already set`);
      return contract;
    }
    
    console.log(`Setting Base URI ${newBaseUri}...`);
    const hash = await contract.write.setBase([newBaseUri]);
    await processTransaction(hash)
    return contract
}

async function setMetaEvidenceLoader(address: `0x${string}`) {
    if (!networkData["NFTProtect"]) {
        throw Error("NFTProtect contract address not found in contracts.json");
    }

    const contract = await hre.viem.getContractAt("NFTProtect", networkData["NFTProtect"]);
    const currentMetaEvidenceLoader = await contract.read.metaEvidenceLoader();

    if (currentMetaEvidenceLoader.toLowerCase() !== address.toLowerCase()) {
        console.log(`Setting metaEvidenceLoader to ${address}...`);
        const hash = await contract.write.setMetaEvidenceLoader([address]);
        await processTransaction(hash)
    } else {
        console.log(`MetaEvidenceLoader is already set to ${address}`);
    }

    return contract;
}

async function setMetaEvidenceLoaderCurrentUser() {
    const clients = await hre.viem.getWalletClients()
    if (clients.length === 0) {
        throw Error('No clients configured')
    }
    const address = clients[0].account.address
    return await setMetaEvidenceLoader(address)
}

async function configureNFTProtectMetaEvidence() {
    if (!networkData["NFTProtect"]) {
        throw Error("NFTProtect contract address not found in contracts.json");
    }

    if (metaEvidences.length === 0) {
        throw Error("No MetaEvidences provided!");
    }
    let setLoaderFired = false
    const contract = await hre.viem.getContractAt("NFTProtect", networkData["NFTProtect"]);

    for (const metaEvidence of metaEvidences) {
        const currentMetaEvidence = await contract.read.metaEvidences([metaEvidence.id]);

        if (currentMetaEvidence !== metaEvidence.url) {
            console.log(`Setting metaEvidence ${metaEvidence.name} to ${metaEvidence.url}...`);
            // We have to set MetaEvidenceLoader to current account to be able to submit metaEvidence
            if (!setLoaderFired) {
                await setMetaEvidenceLoaderCurrentUser()
                setLoaderFired = true
            }
            const hash = await contract.write.submitMetaEvidence([metaEvidence.id, metaEvidence.url]);
            await processTransaction(hash)
        } else {
            console.log(`MetaEvidence ${metaEvidence.name} is already set to ${metaEvidence.url}`);
        }
    }

    return contract;
}

// UserRegistry
async function configureUserRegistryFees() {
    if (!networkData["UserRegistry"]) {
        throw Error("UserRegistry contract address not found in contracts.json");
    }

    const contract = await hre.viem.getContractAt("UserRegistry", networkData["UserRegistry"]);

    // Fee types as defined in the UserRegistry contract
    const feeTypes = ['Entry', 'OpenCase'];

    // Loop through each security level and fee type to update fees
    for (let securityLevel = 0; securityLevel < fees.length; securityLevel++) {
        for (let feeTypeIndex = 0; feeTypeIndex < fees[securityLevel].length; feeTypeIndex++) {
            const currentFee = await contract.read.fees([BigInt(securityLevel), BigInt(feeTypeIndex)]);
            const newFee = fees[securityLevel][feeTypeIndex];

            if (currentFee !== newFee) {
                console.log(`Setting ${feeTypes[feeTypeIndex]}FeeWei for security level ${securityLevel} to ${newFee}...`);
                const hash = await contract.write.setFee([securityLevel, feeTypeIndex, newFee]);
                await processTransaction(hash);
            } else {
                console.log(`${feeTypes[feeTypeIndex]}FeeWei for security level ${securityLevel} is already set to ${newFee}`);
            }
        }
    }

    return contract;
}

async function main() {
    try {
        client = await hre.viem.getPublicClient();
        if (client) {
            console.log(`1. ArbitratorRegistry:`);
            const arbRegistry = await configureArbitratorRegistry();
            console.log(`ArbitratorRegistry ${arbRegistry.address} configured successfully`);
            console.log(`2. NFTProtect:`);
            await setNFTProtectUserRegistry();
            //await setNFTProtectBaseURI();
            const nftProtect = await configureNFTProtectMetaEvidence();
            console.log(`NFTProtect ${nftProtect.address} configured successfully`);
            console.log(`3. UserRegistry:`);
            const userRegistry = await configureUserRegistryFees();
            console.log(`UserRegistry ${userRegistry.address} configured successfully`);
            console.log('4. Setting metaEvidenceLoader')
            await setMetaEvidenceLoader(metaEvidenceLoader);
            console.log('All done!');
        } else {
            throw Error('No client configured')
        }
    } catch (error) {
        console.error(error);
        process.exitCode = 1;
    }
}

main();