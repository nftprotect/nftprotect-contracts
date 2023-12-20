import fs from 'fs';

// Reading files
const contractsJson = JSON.parse(fs.readFileSync('contracts.json', 'utf-8'));
let readmeMd = fs.readFileSync('README.md', 'utf-8');

// Generating contracts block
let contractsBlock = '## Contracts\n';
for (const network in contractsJson) {
  const capitalizedNetwork = network.charAt(0).toUpperCase() + network.slice(1);
  contractsBlock += `### ${capitalizedNetwork}\n`;
  for (const contract in contractsJson[network]) {
    const address = contractsJson[network][contract];
    contractsBlock += `- [${contract}](https://${network}.etherscan.io/address/${address})\n`;
  }
  contractsBlock += '\n';
}

// Checking if contracts block exists
const contractsBlockExists = readmeMd.includes('## Contracts');

if (contractsBlockExists) {
  // Replacing existing block
  const contractsBlockRegex = /## Contracts[\s\S]*?(?=##(?![\s\S]*##)|$)/;
  readmeMd = readmeMd.replace(contractsBlockRegex, contractsBlock);
} else {
  // Adding contracts block
  readmeMd += contractsBlock + '\n\n##';
}

// Writing README.md
fs.writeFileSync('README.md', readmeMd);