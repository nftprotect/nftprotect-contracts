/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The UserDIDPoH Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The UserDIDPoH Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the UserDIDPoH Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

import "./iuserdid.sol";

interface IPoH
{
    function isRegistered(address user) external view returns(bool);
}

contract UserDIDPoH is IUserDID
{
    /** Proof Of Humanity contract address in Ethereum network */
    address constant public PoH = 0xC5E9dDebb09Cd64DfaCab4011A0D5cEDaf7c9BDb;

    function provider() public pure override returns(string memory)
    {
        return "proofofhumanity.id";
    }

    function isIdentified(address user) public view override returns(bool)
    {
        return IPoH(PoH).isRegistered(user);
    }

    function scores(address user) public view override returns(uint256)
    {
        return isIdentified(user) ? 100 : 0;
    }
}
