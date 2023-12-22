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
    event AffiliatePercentChanged(uint8 percent);
    event AffiliatePayment(address indexed from, address indexed to, uint256 amountWei);
    event FeeChanged(Security indexed level, uint256 feeWei);
    event ReferrerSet(address indexed user, address indexed referrer);
    event PartnerSet(address indexed partner, uint8 discount, uint8 affiliatePercent);
    event DIDRegistered(address indexed did, string provider);
    event DIDUnregistered(address indexed did);
    event SuccessorRequested(uint256 indexed requestId, address indexed user, address indexed successor);
    event SuccessorApproved(uint256 indexed requestId);
    event SuccessorRejected(uint256 indexed requestId);

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
    uint8              public   affiliatePercent;
    uint256            constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    mapping(address => address)         public successors;
    mapping(address => address payable) public referrers;
    mapping(address => Partner) public partners;
    mapping(Security => uint256) public feeWei;

    struct Partner
    {
        uint8           discount;
        uint8           affiliatePercent;
    }

    struct SuccessorRequest
    {
        address          user;
        address          successor;
        IArbitrableProxy arbitrator;
        uint256          externalDisputeId;
        uint256          localDisputeId;
    }
    mapping(uint256 => SuccessorRequest) public requests;
    uint256                              public requestsCounter;

    constructor(address areg, IUserDID did, address nftprotectaddr)
    {
        emit Deployed();
        nftprotect = nftprotectaddr;
        metaEvidenceLoader = _msgSender();
        setFee(Security.Basic, 0);
        setFee(Security.Ultra, 0);
        setAffiliatePercent(10);
        setArbitratorRegistry(areg);
        registerDID(did);
        coupons = new NFTPCoupons(address(this));
        coupons.transferOwnership(_msgSender());
    }

    function setFee(Security level, uint256 fw) public onlyOwner
    {
        feeWei[level] = fw;
        emit FeeChanged(level, fw);
    }
    
    function setArbitratorRegistry(address areg) public onlyOwner
    {
        arbitratorRegistry = ArbitratorRegistry(areg);
        emit ArbitratorRegistryChanged(areg);
    }

    function setAffiliatePercent(uint8 percent) public onlyOwner
    {
        affiliatePercent = percent;
        emit AffiliatePercentChanged(percent);
    }

    function setPartner(address partner, uint8 discount, uint8 affPercent) public onlyOwner {
        require(discount <= 100, "UserRegistry: Invalid discount");
        partners[partner] = Partner(
            discount,
            affPercent
        );
        emit PartnerSet(partner, discount, affPercent);
    }

    function deletePartner(address partner) public onlyOwner {
        delete partners[partner];
        emit PartnerSet(partner, 0, 0);
    }

    function feeForUser(address user, Security level) public view returns(uint256) {
        uint8 discount = partners[user].discount;
        return feeWei[level] * (100 - discount) / 100;
    }

    function processPayment(address sender, address user, address payable referrer, bool canUseCoupons, Security level) public override payable onlyNFTProtect
    {
        if (canUseCoupons && coupons.balanceOf(user) > 0)
        {
            coupons.burnFrom(user, 1);
            return;
        }

        // Apply discount for registered partners
        uint256 finalFee = feeForUser(sender, level);

        require(msg.value == finalFee, "UserRegistry: Incorrect payment amount");

        if (referrers[user] == address(0) && referrer != address(0))
        {
            referrers[user] = referrer;
            emit ReferrerSet(user, referrer);
        }
        referrer = referrers[user];

        // Process affiliate payment if there's a referrer
        if (referrer != address(0)) {
            require(referrer != user, "UserRegistry: invalid referrer");
            uint8 ap = partners[referrer].affiliatePercent > 0 ? partners[referrer].affiliatePercent : affiliatePercent;
            uint256 affiliatePayment = finalFee * ap / 100;
            if (affiliatePayment > 0) {
                referrer.sendValue(affiliatePayment);
                emit AffiliatePayment(user, referrer, affiliatePayment);
            }
            finalFee -= affiliatePayment;
        }

        // Transfer the remaining fee to the contract owner
        if (finalFee > 0) {
            payable(owner()).sendValue(finalFee);
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
        uint256 disputeId = arbitrableProxy.externalIDtoLocalID(externalDisputeId);
        requestsCounter++;
        requests[requestsCounter] = SuccessorRequest(user, _msgSender(), arbitrableProxy, disputeId, externalDisputeId);
        emit SuccessorRequested(requestsCounter, user, _msgSender());
        arbitrableProxy.submitEvidence(disputeId, evidence);
        return requestsCounter;
    }

    function submitMetaEvidence(string memory evidence) public
    {
        require(_msgSender() == metaEvidenceLoader, "UserRegistry: forbidden");
        metaEvidenceURI = evidence;
        // todo since userregistry is no longer IEvidence, you might want to emit an event here.
        // although `setMetaEvidenceLoader` did not need an event, so maybe no event is needed anymore.
    }

    function fetchRuling(uint256 requestId) external
    {
        SuccessorRequest memory request = requests[requestId];
        IArbitrableProxy arbitrator = request.arbitrator;
        (, bool isRuled, uint256 ruling,) = arbitrator.disputes(request.localDisputeId);
        require(isRuled, "UserRegistry: Ruling pending");

        if (ruling == 1)
        {
            successors[request.user] = request.successor;
            emit SuccessorApproved(requestId);
        }
        else
        {
            emit SuccessorRejected(requestId);
        }
        delete requests[requestId];
    }
}
