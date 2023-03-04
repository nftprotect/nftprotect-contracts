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

import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Address.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrator.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrable.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/erc-1497/IEvidence.sol";
import "./iuserregistry.sol";
import "./arbitratorregistry.sol";
import "./iuserdid.sol";


contract UserRegistry is Ownable, IArbitrable, IEvidence, IUserRegistry
{
    using Address for address payable;

    event Deployed();
    event ArbitratorRegistryChanged(address areg);
    event AffiliatePercentChanged(uint256 userPercent, uint256 partnerPercent);
    event AffiliatePayment(address indexed from, address indexed to, uint256 amountWei);
    event ReferrerSet(address indexed user, address indexed referrer);
    event PartnerSet(address indexed partnet, bool state);
    event DIDRegistered(address indexed did, string provider);
    event DIDUnregistered(address indexed did);
    event SuccessorRequested(uint256 indexed disputeId, address indexed user, address indexed successor, bytes extraData, uint256 arbitratorId);
    event SuccessorAppealed(uint256 indexed disputeId, bytes extraData);
    event SuccessorApproved(uint256 indexed disputeId);
    event SuccessorRejected(uint256 indexed disputeId);

    modifier onlyNFTProtect()
    {
        require(_msgSender() == nftprotect);
        _;
    }

    uint256            public   metaEvidenceCounter;
    address            public   nftprotect;
    ArbitratorRegistry public   arbitratorRegistry;
    IUserDID[]         public   dids;
    uint256            public   affiliateUserPercent;
    uint256            public   affiliatePartnerPercent;
    uint256            constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    mapping(address => address)         public successors;
    mapping(address => address payable) public referrers;
    mapping(address => bool)            public partners;

    struct SuccessorRequest
    {
        address     user;
        address     successor;
        IArbitrator arbitrator;
        uint256     evidenceId;
    }
    mapping(uint256 => SuccessorRequest) public disputes;

    constructor(address areg, IUserDID did, address nftprotectaddr)
    {
        emit Deployed();
        nftprotect = nftprotectaddr;
        setAffiliatePercent(10, 20);
        setArbitratorRegistry(areg);
        registerDID(did);
    }
    
    function setArbitratorRegistry(address areg) public onlyOwner
    {
        arbitratorRegistry = ArbitratorRegistry(areg);
        emit ArbitratorRegistryChanged(areg);
    }

    function setAffiliatePercent(uint256 userPercent, uint256 partnerPercent) public onlyOwner
    {
        affiliateUserPercent = userPercent;
        affiliatePartnerPercent = partnerPercent;
        emit AffiliatePercentChanged(userPercent, partnerPercent);
    }

    function setPartner(address partner, bool state) public onlyOwner
    {
        partners[partner] = state;
        emit PartnerSet(partner, state);
    }

    function processPayment(address user, address payable referrer) public override payable onlyNFTProtect
    {
        if (referrers[user] == address(0) && referrer != address(0))
        {
            referrers[user] = referrer;
            emit ReferrerSet(user, referrer);
        }
        referrer = referrers[user];
        uint256 value = msg.value;
        if (referrer != address(0))
        {
            require(referrer != user, "UserRegistry: invalid referrer");
            uint256 percent = partners[referrer] ? affiliatePartnerPercent : affiliateUserPercent;
            uint256 reward = value * percent / 100;
            if (reward > 0)
            {
                value -= reward;
                referrer.sendValue(reward);
                emit AffiliatePayment(user, referrer, reward);
            }
        }
        if (value > 0)
        {
            payable(owner()).sendValue(value);
        }
    }

    function registerDID(IUserDID did) public onlyOwner
    {
        dids.push(did);
        emit DIDRegistered(address(did), did.provider());
    }

    function unregisterDID(IUserDID did) public onlyOwner
    {
        for(uint256 i = 0; i < dids.length; ++i)
        {
            if(dids[i] == did)
            {
                dids[i] = dids[dids.length - 1];
                dids.pop();
                emit DIDUnregistered(address(did));
                break;
            }
        }
    }

    function isRegistered(address user) public view override returns(bool)
    {
        for(uint256 i = 0; i < dids.length; ++i)
        {
            if(dids[i].isIdentified(user))
            {
                return true;
            }
        }
        return false;
    }

    function scores(address user) public view override returns(uint256)
    {
        uint256 scoresMax = 0;
        for(uint256 i = 0; i < dids.length; ++i)
        {
            uint256 scoresCur = dids[i].scores(user);
            if(scoresCur > scoresMax)
            {
                scoresMax = scoresCur;
            }
        }
        return scoresMax;
    }

    function isSuccessor(address user, address successor) public view override returns(bool)
    {
        return successors[user] == successor;
    }

    function hasSuccessor(address user) public view override returns(bool)
    {
        return successors[user] != address(0);
    }

    function successorOf(address user) external view override returns(address)
    {
        return successors[user];
    }

    function successorRequest(address user, bytes calldata extraData, string memory evidence, uint256 arbitratorId) public payable returns(uint256)
    {
        require(isRegistered(user), "UserRegistry: Unregistered user");
        IArbitrator arbitrator = arbitratorRegistry.arbitrator(arbitratorId);
        metaEvidenceCounter++;
        emit MetaEvidence(metaEvidenceCounter, evidence);
        uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
        disputes[disputeId] = SuccessorRequest(user, _msgSender(), arbitrator, metaEvidenceCounter);
        emit SuccessorRequested(disputeId, user, _msgSender(), extraData, arbitratorId);
        emit Dispute(arbitrator, disputeId, metaEvidenceCounter, metaEvidenceCounter);
        return disputeId;
    }

    function successorRequestAppeal(uint256 disputeId, bytes calldata extraData) public payable
    {
        require(disputes[disputeId].successor == _msgSender(), "UserRegistry: not the owner of the request");
        disputes[disputeId].arbitrator.appeal{value: msg.value}(disputeId, extraData);
        emit SuccessorAppealed(disputeId, extraData);
    }

    function submitEvidence(uint256 disputeId, string memory evidence) public
    {
        require(disputes[disputeId].successor == _msgSender(), "UserRegistry: not the owner of the request");
        SuccessorRequest memory request = disputes[disputeId];
        emit Evidence(request.arbitrator, request.evidenceId, _msgSender(), evidence);
    }

    function rule(uint256 disputeId, uint256 ruling) external override
    {
        require(_msgSender() == address(disputes[disputeId].arbitrator), "UserRegistry: invalid arbitrator");
        require(ruling <= numberOfRulingOptions, "UserRegistry: invalid ruling");
        SuccessorRequest memory request = disputes[disputeId];
        if (ruling == 1)
        {
            successors[request.user] = request.successor;
            emit SuccessorApproved(disputeId);
        }
        else
        {
            emit SuccessorRejected(disputeId);
        }
        emit Ruling(request.arbitrator, disputeId, ruling);
        delete disputes[disputeId];
    }
}
