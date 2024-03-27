import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import hre from "hardhat";
import { GetContractReturnType, PublicClient, WalletClient } from "viem";

describe("SimpleDiscounter", function () {
    
    let simpleDiscounter: GetContractReturnType;
    let publicClient: PublicClient;
    let owner: WalletClient;
    let discountConsumer: WalletClient;
    let user: WalletClient;
    let otherUser: WalletClient;

    // A deployment function to set up the initial state
    const deploy = async () => {
        if (!discountConsumer.account) {
            throw new Error('No account available for discountConsumer')
        }
        const simpleDiscounter = await hre.viem.deployContract("SimpleDiscounter", [discountConsumer.account.address]);
        return { simpleDiscounter };
    };

    const getSimpleDiscounter = async (client: WalletClient) => {
        return await hre.viem.getContractAt(
            "SimpleDiscounter",
            simpleDiscounter.address,
            { walletClient: client, publicClient }
          );
    }

    before(async function () {
        // Get a list of accounts
        [owner, discountConsumer, user, otherUser] = await hre.viem.getWalletClients();
        publicClient = await hre.viem.getPublicClient();
    });

    beforeEach(async function () {
        // Load the contract instance using the deployment function
        ({ simpleDiscounter } = await loadFixture(deploy));
    });

    describe("grantDiscount", function () {
        it("should allow the owner to grant discounts to a user", async function () {
            // Arrange
            const amount = 5n;

            // Act
            await simpleDiscounter.write.grantDiscount([user.account.address, amount]);

            // Assert
            const userDiscounts = await simpleDiscounter.read.discounts([user.account.address]);
            expect(userDiscounts).to.equal(amount);
        });

        it("should not allow non-owners to grant discounts", async function () {
            // Arrange
            const amount = 5n;
            const discounterForOtherUser = await getSimpleDiscounter(otherUser);

            // Act
            const action = discounterForOtherUser.write.grantDiscount([user.account.address, amount]);

            // Assert
            await expect(action).to.be.rejectedWith(
                "Ownable: caller is not the owner"
            );
        });
    });


    describe("setDiscountConsumer", function () {
        it("should allow the owner to set a new discount consumer", async function () {
            // Act
            const action = simpleDiscounter.write.setDiscountConsumer([discountConsumer.account.address]);

            // Assert
            const discountConsumerAddress = await simpleDiscounter.read.discountConsumer();
            expect(
                discountConsumerAddress.toLowerCase()
            ).to.equal(
                discountConsumer.account.address.toLowerCase()
            );
        });

        it("should not allow non-owners to set a new discount consumer", async function () {
            // Arrange
            const discounterForUser = await getSimpleDiscounter(user);
            
            // Act
            const action = discounterForUser.write.setDiscountConsumer([otherUser.account.address]);

            // Assert
            await expect(action).to.be.rejectedWith(
                "Ownable: caller is not the owner"
            );
        });
    });

    describe("useDiscount", function () {
        it("should not allow using a discount when none are available", async function () {
            // Arrange
            const discounterForDiscountConsumer = await getSimpleDiscounter(discountConsumer);

            // Act
            const action =  discounterForDiscountConsumer.write.useDiscount([user.account.address]);

            // Assert
            await expect(action).to.be.rejectedWith(
                "SimpleDiscounter: no discount to use"
            );
        });

        it("should allow the discount consumer to use a discount for a user", async function () {
            // Arrange         
            await simpleDiscounter.write.grantDiscount([user.account.address, 1]);

            // Act
            const discounterForDiscountConsumer = await getSimpleDiscounter(discountConsumer);
            await discounterForDiscountConsumer.write.useDiscount([user.account.address]);

            // Assert
            const userDiscounts = await discounterForDiscountConsumer.read.discounts([user.account.address]);
            expect(userDiscounts).to.equal(0n);
        });

        it("should not allow non-discount consumers to use a discount", async function () {
            // Arrange
            const discounterForOtherUser = await getSimpleDiscounter(otherUser);
            await simpleDiscounter.write.grantDiscount([user.account.address, 1]);
            
            // Act
            const action = discounterForOtherUser.write.useDiscount([user.account.address]);

            // Assert
            await expect(action).to.be.rejectedWith(
                "SimpleDiscounter: caller is not the discount consumer"
            );
        });
    });

    describe("hasDiscount", function () {
        it("should return false if the user has no discounts", async function () {
            // Act
            const hasDiscount = await simpleDiscounter.read.hasDiscount([user.account.address]);

            // Assert
            expect(hasDiscount).to.be.false;
        });

        it("should return true if the user has discounts", async function () {
            // Arrange
            await simpleDiscounter.write.grantDiscount([user.account.address, 1]);

            // Act
            const hasDiscount = await simpleDiscounter.read.hasDiscount([user.account.address]);

            // Assert
            expect(hasDiscount).to.be.true;
        });
    });
});