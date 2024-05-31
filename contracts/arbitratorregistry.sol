/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The ArbitratorRegistry Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The ArbitratorRegistry Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the ArbitratorRegistry Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@kleros/erc-792/contracts/IArbitrator.sol";
import "./iarbitrableproxy.sol";


contract ArbitratorRegistry is Ownable
{
    event Deployed();
    event ArbitratorAdded(uint256 indexed id, string name, IArbitrableProxy arbitratorProxy, bytes extraData);
    event ExtraDataChanged(uint256 indexed id, bytes extraData);
    event ArbitratorDeleted(uint256 indexed id);

    error ArbitratorNotFound(uint256 id);

    struct Arbitrator
    {
        string           name;
        IArbitrableProxy arbitrator;
        bytes            extraData;
    }

    uint256                        public counter;
    mapping(uint256 => Arbitrator) public arbitrators;

    constructor() Ownable(_msgSender())
    {
        emit Deployed();
    }

    function addArbitrator(string memory name, IArbitrableProxy arb, bytes calldata extraData) public onlyOwner returns(uint256)
    {
        ++counter;
        arbitrators[counter].name = name;
        arbitrators[counter].arbitrator = arb;
        arbitrators[counter].extraData = extraData;
        emit ArbitratorAdded(counter, name, arb, extraData);
        return counter;
    }

    function setExtraData(uint256 id, bytes calldata extraData) public onlyOwner
    {
        arbitrators[id].extraData = extraData;
        emit ExtraDataChanged(id, extraData);
    }

    function deleteArbitrator(uint256 id) public onlyOwner
    {
        if (address(arbitrators[id].arbitrator) == address(0)) {
            revert ArbitratorNotFound(id);
        }
        delete arbitrators[id];
        emit ArbitratorDeleted(id);
    }

    function checkArbitrator(uint256 id) public view returns(bool)
    {
        return address(arbitrators[id].arbitrator) != address(0);
    }

    function arbitrator(uint256 id) public view returns(IArbitrableProxy, bytes memory)
    {
        return (arbitrators[id].arbitrator, arbitrators[id].extraData);
    }

    function arbitrationCost(uint256 id) public view returns (uint256)
    {
        IArbitrator finalArbitrator = arbitrators[id].arbitrator.arbitrator();
        return finalArbitrator.arbitrationCost(arbitrators[id].extraData);
    }
}