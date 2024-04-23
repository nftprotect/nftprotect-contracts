import { readFileSync, existsSync } from 'fs';
import hre from "hardhat";

const jsonFilePath = './contracts.json'; // Path to your JSON file

if (!existsSync(jsonFilePath)) {
  console.error("Error: contracts.json file does not exist. Please run the deploy script first.");
  process.exit(1);
}

let contractsData = JSON.parse(readFileSync(jsonFilePath, 'utf-8'));
const networkName = hre.network.name;
let networkData = contractsData[networkName];

if (!networkData) {
  console.error(`Error: No contract data found for network ${networkName} in contracts.json file.`);
  process.exit(1);
}

async function main() {
  try {
    for (const contractName in networkData) {
      const contractAddress = networkData[contractName];
      console.log(`Verifying contract ${contractName} at address ${contractAddress} on network ${networkName}`);

      let constructorArguments: any[] = [];
      if (contractName === "UserRegistry") {
        constructorArguments = [networkData["ArbitratorRegistry"], networkData["NFTProtect"]];
      } else if (contractName === "NFTProtect") {
        constructorArguments = [networkData["ArbitratorRegistry"], networkData["SignatureVerifier"]];
      } else if (contractName === "MultipleProtectHelper") {
        constructorArguments = [networkData["NFTProtect"]];
      }

      await hre.run("verify:verify", {
        network: networkName,
        address: contractAddress,
        constructorArguments: constructorArguments,
      });
    }
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}

main();