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

    const signMessage = async (overrides = {}) => {
        return walletClient.signTypedData({
            account,
            domain,
            types,
            primaryType: "Message",
            message: {
                tokenId,
                newOwner,
                nonce,
                messageText,
                ...overrides
            }
        });
    };

    before(async function () {

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

        messageText = await signatureVerifier.read.getMessageText();
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
    
    describe("Verify", function () {
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

        it("should reject invalid signer", async function () {
            // Create an invalid signature
            const signature = await signMessage();

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

        it("should reject a signature with an incorrect tokenId", async function () {
            // Sign the message by the owner with the correct tokenId
            const correctSignature = await signMessage();
    
            // Incorrect tokenId for testing
            const incorrectTokenId = tokenId + 1;
    
            // Verify the signature with incorrect tokenId
            expect(
                await signatureVerifier.read.verify([
                    incorrectTokenId, 
                    account, 
                    newOwner, 
                    nonce, 
                    correctSignature
                ])
            ).to.be.false;
        });
    
        it("should reject a signature with an incorrect newOwner", async function () {
            // Sign the message by the owner with the correct newOwner
            const correctSignature = await signMessage();
    
            // Incorrect newOwner for testing
            const incorrectNewOwner = "0x1111111111111111111111111111111111111111";
    
            // Verify the signature with incorrect newOwner
            expect(
                await signatureVerifier.read.verify([
                    tokenId, 
                    account, 
                    incorrectNewOwner, 
                    nonce, 
                    correctSignature
                ])
            ).to.be.false;
        });
    
        it("should reject a signature with an incorrect nonce", async function () {
            // Sign the message by the owner with the correct nonce
            const correctSignature = await signMessage();
    
            // Incorrect nonce for testing
            const incorrectNonce = nonce + 1;
    
            // Verify the signature with incorrect nonce
            expect(
                await signatureVerifier.read.verify([
                    tokenId, 
                    account, 
                    newOwner, 
                    incorrectNonce, 
                    correctSignature
                ])
            ).to.be.false;
        });

    });
});