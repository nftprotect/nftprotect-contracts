/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The UserDIDGitcoinPassport Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The UserDIDGitcoinPassport Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the UserDIDGitcoinPassport Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "./iuserdid.sol";

contract UserDIDGitcoinPassport is IUserDID, Context
{
    event PassportLoaded(address indexed user, bytes passport);

    function provider() public pure override returns(string memory)
    {
        return "GitCoin Passport";
    }

    mapping(address => bytes) public passports;

    function setPassport(bytes memory passport) public
    {
        passports[_msgSender()] = passport;
        emit PassportLoaded(_msgSender(), passport);
    }

    function isIdentified(address user) public view override returns(bool)
    {
        return passports[user].length > 0;
    }

    function scores(address user) public view override returns(uint256)
    {
        return isIdentified(user) ? 100 : 0;
    }
}
