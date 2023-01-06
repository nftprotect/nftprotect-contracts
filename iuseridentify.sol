/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The IUserIdentify Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The IUserIdentify Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the IUserIdentify Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

interface IUserIdentify
{
    function provider() external view returns(string memory);

    function isIdentified(address user) external view returns(bool);

    /** Return scores 0 to 100 */
    function scores(address user) external view returns(uint256);
}
