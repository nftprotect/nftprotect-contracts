import { expect } from "chai";
import { Abi, Account, GetContractReturnType, WalletClient } from "viem";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import hre from "hardhat";
import { hashTypedData } from 'viem'

// A deployment function to set up the initial state
const deploy = async () => {
    const signatureVerifier = await hre.viem.deployContract("SignatureVerifier");
    return { signatureVerifier };
};

describe("SignatureVerifier", function () {

    const tokenId: number = 1;
    const nonce: number = 99;
    const newOwner = "0x388c818ca8b9251b393131c08a736a67ccb19298";
    const nullAddress = "0x0000000000000000000000000000000000000000";
    const types = {
        Message: [
            { name: "tokenId", type: "uint256" },
            { name: "newOwner", type: "address" },
            { name: "nonce", type: "uint256" },
            { name: "messageText", type: "string" }
        ]
    };

    let walletClient: WalletClient;
    let signatureVerifier: GetContractReturnType;
    let account: `0x${string}`;
    let messageText: string;
    let domain:any;

    beforeEach(async function () {

        // Load the contract instance using the deployment function
        ({ signatureVerifier } = await loadFixture(deploy));

        // Get a list of accounts
        [walletClient] = await hre.viem.getWalletClients();

        // Set domain
        domain = {
            name: "NFTProtect",
            version: "1",
            chainId: walletClient.chain?.id,
            verifyingContract: signatureVerifier.address
        };

        account = walletClient.account?.address || nullAddress
        expect(account === nullAddress).to.be.false;

        // // Create a message hash
        // message = await signatureVerifier.read.getMessageHash([
        //     tokenId,
        //     newOwner,
        //     nonce
        // ]);
        messageText = await signatureVerifier.read.getMessageText();
        console.log("Message Text:", messageText);
        console.log("Account:", account);

        console.log("Domain:", domain);


    });

    describe("getMessageHash", function () {
        it("should return the correct hash for given message parameters", async function () {
            // Arrange
            const expectedTypedMessageHash = hashTypedData({
                domain,
                types,
                primaryType: "Message",
                message: {
                    tokenId,
                    newOwner,
                    nonce,
                    messageText,
                }
            });
    
            // Act
            const actualMessageHash = await signatureVerifier.read.getMessageHash([tokenId, newOwner, nonce]);
    
            // Assert
            expect(actualMessageHash).to.equal(expectedTypedMessageHash, "The hash returned by getMessageHash does not match the expected typed message hash.");
        });
    });

    it("should verify a valid signature", async function () {
        // Sign the message by the owner
        const signature = await walletClient.signTypedData({
            account,
            domain,
            types,
            primaryType: "Message",
            message: {
                tokenId,
                newOwner,
                nonce,
                messageText,
            }
        });    // Get the hash of the signed message

        // Verify the signature
        expect(
            await signatureVerifier.read.verify([
                tokenId, 
                account, 
                newOwner, 
                nonce, 
                signature
            ])
        ).to.be.true;
    });

    it("should reject an invalid signature", async function () {
        // Create an invalid signature
        const signature = await walletClient.signTypedData({
            account,
            domain,
            types,
            primaryType: "Message",
            message: {
                tokenId,
                newOwner,
                nonce,
                messageText,
            }
        });    // Get the hash of the signed message

        // Verify the signature
        expect(
            await signatureVerifier.read.verify([
                tokenId, 
                newOwner, // it's wrong
                newOwner, 
                nonce, 
                signature
            ])
        ).to.be.false;
    });
});