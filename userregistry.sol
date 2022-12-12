/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The UserRegistry Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The UserRegistry Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the UserRegistry Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrator.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrable.sol";


contract UserRegistry is Ownable, IArbitrable
{
    event Deployed();
    event ArbitratorChanged(address arbitrator);
    event HashOfSecretLoaded(address indexed user, bytes hash);
    event SuccessorRequested(uint256 indexed disputeId, address indexed user, address indexed successor, bytes extraData);
    event SuccessorAppealed(uint256 indexed disputeId, bytes extraData);
    event SuccessorApproved(uint256 indexed disputeId);
    event SuccessorRejected(uint256 indexed disputeId);

    IArbitrator public   arbitrator;
    uint256     constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    mapping(address => bytes)   public hashOfSecret;
    mapping(address => address) public successors;

    struct SuccessorRequest
    {
        address user;
        address successor;
    }
    mapping(uint256 => SuccessorRequest) public disputes;

    constructor(address arb)
    {
        emit Deployed();
        setArbitrator(arb);
    }
    
    function setArbitrator(address arb) public onlyOwner
    {
        arbitrator = IArbitrator(arb);
        emit ArbitratorChanged(arb);
    }

    function loadHashOfSecret(bytes memory hash) public
    {
        hashOfSecret[_msgSender()] = hash;
        emit HashOfSecretLoaded(_msgSender(), hash);
    }

    function successorRequest(address user, bytes calldata extraData) public payable returns(uint256)
    {
        uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
        disputes[disputeId] = SuccessorRequest(user, _msgSender());
        emit SuccessorRequested(disputeId, user, _msgSender(), extraData);
        return disputeId;
    }

    function successorRequestAppeal(uint256 disputeId, bytes calldata extraData) public payable
    {
        require(disputes[disputeId].successor == _msgSender(), "UserRegistry: not the owner of the request");
        arbitrator.appeal{value: msg.value}(disputeId, extraData);
        emit SuccessorAppealed(disputeId, extraData);
    }

    function rule(uint256 disputeId, uint256 ruling) external override
    {
        require(_msgSender() == address(arbitrator), "UserRegistry: not the arbitrator");
        require(ruling <= numberOfRulingOptions, "UserRegistry: invalid ruling");
        SuccessorRequest memory request = disputes[disputeId];
        if (ruling == 1)
        {
            // hasOfSecret is compromized, need to delete it
            delete hashOfSecret[request.user];
            successors[request.user] = request.successor;
            emit SuccessorApproved(disputeId);
        }
        else
        {
            emit SuccessorRejected(disputeId);
        }
        delete disputes[disputeId];
    }
}
