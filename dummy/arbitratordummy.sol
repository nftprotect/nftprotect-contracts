/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The ArbitratorDummy Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The ArbitratorDummy Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the ArbitratorDummy Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Address.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrator.sol";


contract ArbitratorDummy is Ownable, IArbitrator
{
    using Address for address payable;

    error InsufficientPayment(uint256 available, uint256 required);
    error InvalidRuling(uint256 ruling, uint256 numberOfChoices);
    error InvalidStatus(DisputeStatus current, DisputeStatus expected);

    struct Dispute
    {
        IArbitrable   arbitrated;
        uint256       choices;
        uint256       ruling;
        DisputeStatus status;
    }

    Dispute[] public disputes;

    function arbitrationCost(bytes memory /*extraData*/) public pure override returns (uint256)
    {
        return 0.1 ether;
    }

    function appealCost(uint256 /*disputeID*/, bytes memory /*extraData*/) public pure override returns (uint256)
    {
        // An unaffordable amount which practically avoids appeals
        return 2**250;
    }

    function createDispute(uint256 choices, bytes memory extraData) public payable override returns(uint256 disputeID)
    {
        uint256 requiredAmount = arbitrationCost(extraData);
        if(msg.value < requiredAmount)
        {
            revert InsufficientPayment(msg.value, requiredAmount);
        }

        disputes.push(Dispute({arbitrated: IArbitrable(msg.sender), choices: choices, ruling: 0, status: DisputeStatus.Waiting}));
        disputeID = disputes.length - 1;
        emit DisputeCreation(disputeID, IArbitrable(msg.sender));
    }

    function disputeStatus(uint256 disputeID) public view override returns (DisputeStatus status)
    {
        status = disputes[disputeID].status;
    }

    function currentRuling(uint256 disputeID) public view override returns (uint256 ruling)
    {
        ruling = disputes[disputeID].ruling;
    }

    function rule(uint256 disputeID, uint256 ruling) public onlyOwner
    {
        Dispute storage dispute = disputes[disputeID];

        if(ruling > dispute.choices)
        {
            revert InvalidRuling(ruling, dispute.choices);
        }
        if(dispute.status != DisputeStatus.Waiting)
        {
            revert InvalidStatus(dispute.status, DisputeStatus.Waiting);
        }

        dispute.ruling = ruling;
        dispute.status = DisputeStatus.Solved;

        payable(msg.sender).sendValue(arbitrationCost(""));
        dispute.arbitrated.rule(disputeID, ruling);
    }

    function appeal(uint256 disputeID, bytes memory extraData) public payable override
    {
        uint256 requiredAmount = appealCost(disputeID, extraData);
        if(msg.value < requiredAmount)
        {
            revert InsufficientPayment(msg.value, requiredAmount);
        }
    }

    function appealPeriod(uint256 /*disputeID*/) public pure override returns (uint256 start, uint256 end)
    {
        return (0, 0);
    }
}
