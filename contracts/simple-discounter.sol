/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The NFTProtect Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The NFTProtect Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the NFTProtect Contract. If not, see <http://www.gnu.org/licenses/>.

@author Oleg Dubinkin <odubinkin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./idiscounter.sol";

/* @title SimpleDiscounter
 * @dev Implementation of the IDiscounter interface for the NFT Protect project.
 *
 * This contract allows for the management of discounts for users. Discounts are represented
 * as a simple count of available discounts per user. The contract owner can grant discounts
 * to users, and a designated discount consumer can apply these discounts to user transactions.
 */
contract SimpleDiscounter is IDiscounter, Ownable {
    // Mapping from user addresses to their available discount count.
    mapping(address => uint256) public discounts;
    // Address allowed to consume discounts
    address public discountConsumer;

    // Event emitted when a discount is used.
    event DiscountUsed(address indexed user, uint256 amount);
    // Event emitted when the discount consumer address is changed.
    event DiscountConsumerChanged(address indexed consumer);

    /**
     * @dev Sets the initial discount consumer address upon contract deployment.
     * @param consumer The address of the initial discount consumer.
     */
    constructor(address consumer) {
        discountConsumer = consumer;
    }

    /**
     * @dev Ensures that only the designated discount consumer can call a function.
     */
    modifier onlyDiscountConsumer() {
        require(msg.sender == discountConsumer, "SimpleDiscounter: caller is not the discount consumer");
        _;
    }

    /**
     * @dev Allows the contract owner to set or change the discount consumer address.
     * @param consumer The address to become the new discount consumer.
     *
     * Requirements:
     * - `discountConsumer` cannot be the zero address.
     */
    function setDiscountConsumer(address consumer) external onlyOwner {
        require(consumer != address(0), "SimpleDiscounter: invalid discount consumer address");
        discountConsumer = consumer;
        emit DiscountConsumerChanged(discountConsumer);
    }

    /**
     * @dev Checks if a user has any discounts available.
     * @param user The address of the user to check.
     * @return bool Returns true if the user has any discounts, false otherwise.
     */
    function hasDiscount(address user) external view override returns (bool) {
        return discounts[user] > 0;
    }

    /**
     * @dev Consumes a single discount for a user. This is an override of the IDiscounter interface.
     * @param user The address of the user whose discount is to be used.
     *
     * Requirements:
     * - The user must have at least one discount available.
     */
    function useDiscount(address user) external override onlyDiscountConsumer {
        require(discounts[user] > 0, "SimpleDiscounter: no discount to use");
        discounts[user] -= 1;
        emit DiscountUsed(user, 1);
    }

    /**
     * @dev Consumes a specified amount of discounts for a user.
     * @param user The address of the user whose discounts are to be used.
     * @param amount The number of discounts to use.
     *
     * Requirements:
     * - The user must have a sufficient number of discounts available.
     */
    function useDiscount(address user, uint256 amount) external onlyDiscountConsumer {
        require(discounts[user] >= amount, "SimpleDiscounter: not enough discounts to use");
        discounts[user] -= amount;
        emit DiscountUsed(user, amount);
    }

    /**
     * @dev Grants a specified amount of discounts to a user.
     * @param user The address of the user to receive the discounts.
     * @param amount The number of discounts to grant.
     *
     * Requirements:
     * - `amount` must be greater than zero.
     */
    function grantDiscount(address user, uint256 amount) external onlyOwner {
        require(amount > 0, "SimpleDiscounter: amount must be greater than zero");
        discounts[user] += amount;
    }
}