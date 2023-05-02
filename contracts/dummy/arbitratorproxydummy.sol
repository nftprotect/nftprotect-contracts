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

import "./arbitratordummy.sol";
import "./iarbitrableproxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ArbitratorProxyDummy is Ownable, IArbitrableProxy, IArbitrable
{
    ArbitratorDummy                   public dummy;
    uint256                           public locID;
    mapping(uint256 => uint256)       public extToLoc;
    mapping(uint256 => DisputeStruct) public locToDisput;

    constructor ()
    {
        dummy = new ArbitratorDummy();
        dummy.transferOwnership(_msgSender());
    }

    function arbitrator() public override view
        returns (IArbitrator)
    {
        return IArbitrator(dummy);
    }

    function createDispute(
        bytes calldata _arbitratorExtraData,
        string calldata /*_metaevidenceURI*/,
        uint256 _numberOfRulingOptions
    ) public payable override returns (uint256 disputeID)
    {
        disputeID = dummy.createDispute{value: msg.value}(_numberOfRulingOptions, _arbitratorExtraData);
        locID++;
        extToLoc[disputeID] = locID;
        locToDisput[locID] = DisputeStruct(_arbitratorExtraData, false, 0, disputeID);
    }

    function externalIDtoLocalID(
        uint256 _externalID
    ) public override view returns (uint256 localID)
    {
        return extToLoc[_externalID];
    }

    function disputes(
        uint256 _localID
    )
        public view override
        returns (
            bytes memory extraData,
            bool isRuled,
            uint256 ruling,
            uint256 disputeIDOnArbitratorSide
        )
    {
        DisputeStruct memory d = locToDisput[_localID];
        extraData = d.arbitratorExtraData;
        isRuled = d.isRuled;
        ruling = d.ruling;
        disputeIDOnArbitratorSide = d.disputeIDOnArbitratorSide;
    }

    function submitEvidence(uint256 /*_localDisputeID*/, string calldata /*_evidenceURI*/) public override
    {
        // do nothing
    }

    function rule(uint256 _disputeID, uint256 _ruling) public override
    {
        require(_msgSender() == address(dummy), "not permitted");
        uint256 loc = extToLoc[_disputeID];
        DisputeStruct storage d = locToDisput[loc];
        d.ruling = _ruling;
        d.isRuled = true;
    }
}
