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

/**
 * @title IDiscounter
 * @dev Interface for a discount management system for the NFT Protect project.
 *
 * This interface outlines the basic functions for checking if a user has a discount
 * and for applying a discount to a user's transaction. Implementations should handle
 * the logic for discount storage and usage.
 */
interface IDiscounter {
    /**
     * @dev Determines if a user has a discount available.
     * @param user The address of the user to check for a discount.
     * @return bool Returns true if the user has a discount, false otherwise.
     */
    function hasDiscount(address user) external view returns (bool);
    
    /**
     * @dev Applies a discount to the user's transaction.
     * @param user The address of the user to apply the discount to.
     * 
     * Requirements:
     * - The user must have a discount available.
     */
    function useDiscount(address user) external;
}