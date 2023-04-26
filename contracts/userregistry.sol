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

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./iuserregistry.sol";
import "./arbitratorregistry.sol";
import "./iuserdid.sol";
import "./iarbitrableproxy.sol";
import "./nftpcoupons.sol";


contract UserRegistry is Ownable, IUserRegistry
{
    using Address for address payable;

    event Deployed();
    event ArbitratorRegistryChanged(address areg);
    event AffiliatePercentChanged(uint256 percent);
    event AffiliatePayment(address indexed from, address indexed to, uint256 amountWei);
    event ReferrerSet(address indexed user, address indexed referrer);
    event PartnerSet(address indexed partnet, uint256 percent);
    event DIDRegistered(address indexed did, string provider);
    event DIDUnregistered(address indexed did);
    event SuccessorRequested(uint256 indexed disputeId, address indexed user, address indexed successor, uint256 arbitratorId);
    event SuccessorAppealed(uint256 indexed disputeId);
    event SuccessorApproved(uint256 indexed disputeId);
    event SuccessorRejected(uint256 indexed disputeId);

    modifier onlyNFTProtect()
    {
        require(_msgSender() == nftprotect);
        _;
    }

    string             public   metaEvidenceURI;
    address            public   nftprotect;
    NFTPCoupons        public   coupons;
    address            public   metaEvidenceLoader;
    ArbitratorRegistry public   arbitratorRegistry;
    IUserDID[]         public   dids;
    uint256            public   affiliatePercent;
    uint256            constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    mapping(address => address)         public successors;
    mapping(address => address payable) public referrers;
    mapping(address => uint256)         public partners;

    struct SuccessorRequest
    {
        address          user;
        address          successor;
        IArbitrableProxy arbitrator;
    }
    mapping(uint256 => SuccessorRequest) public disputes;

    constructor(address areg, IUserDID did, address nftprotectaddr)
    {
        emit Deployed();
        nftprotect = nftprotectaddr;
        metaEvidenceLoader = _msgSender();
        setAffiliatePercent(10);
        setArbitratorRegistry(areg);
        registerDID(did);
        coupons = new NFTPCoupons(address(this));
        coupons.transferOwnership(_msgSender());
    }
    
    function setArbitratorRegistry(address areg) public onlyOwner
    {
        arbitratorRegistry = ArbitratorRegistry(areg);
        emit ArbitratorRegistryChanged(areg);
    }

    function setAffiliatePercent(uint256 percent) public onlyOwner
    {
        affiliatePercent = percent;
        emit AffiliatePercentChanged(percent);
    }

    function setPartner(address partner, uint256 percent) public onlyOwner
    {
        partners[partner] = percent;
        emit PartnerSet(partner, percent);
    }

    function processPayment(address user, address payable referrer, bool canUseCoupons, uint256 fee) public override payable onlyNFTProtect
    {
        if (canUseCoupons && coupons.balanceOf(user) > 0)
        {
            coupons.burnFrom(user, 1);
            return;
        }
        require(msg.value == fee, "wrong payment");
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
            uint256 percent = partners[referrer]==0 ? affiliatePercent : partners[referrer];
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

    function setMetaEvidenceLoader(address mel) public override onlyNFTProtect
    {
        metaEvidenceLoader = mel;
    }

    function successorRequest(address user, uint256 arbitratorId, string memory evidence) public payable returns(uint256)
    {
        require(isRegistered(user), "UserRegistry: Unregistered user");
        IArbitrableProxy arbitrableProxy;
        bytes memory extraData;
        (arbitrableProxy, extraData) = arbitratorRegistry.arbitrator(arbitratorId);
        uint256 externalDisputeId = arbitrableProxy.createDispute{value: msg.value}(extraData, metaEvidenceURI, numberOfRulingOptions);
        // This id works both for the userregistry request, and the arbitrableproxy local dispute
        uint256 disputeId = arbitrableProxy.externalIDtoLocalID(externalDisputeId);
        disputes[disputeId] = SuccessorRequest(user, _msgSender(), arbitrableProxy);
        emit SuccessorRequested(disputeId, user, _msgSender(), arbitratorId);
        arbitrableProxy.submitEvidence(disputeId, evidence);
        return disputeId;
    }

    function submitMetaEvidence(string memory evidence) public
    {
        require(_msgSender() == metaEvidenceLoader, "UserRegistry: forbidden");
        metaEvidenceURI = evidence;
        // todo since userregistry is no longer IEvidence, you might want to emit an event here.
        // although `setMetaEvidenceLoader` did not need an event, so maybe no event is needed anymore.
    }

    function fetchRuling(uint256 disputeId) external
    {
        SuccessorRequest memory request = disputes[disputeId];
        IArbitrableProxy arbitrator = request.arbitrator;
        (, bool isRuled, uint256 ruling,) = arbitrator.disputes(disputeId);
        require(isRuled, "UserRegistry: Ruling pending");

        if (ruling == 1)
        {
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
