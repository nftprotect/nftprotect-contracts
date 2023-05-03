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


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@kleros/erc-792/contracts/IArbitrator.sol";
import "./iarbitrableproxy.sol";


contract DyArbitratorRegistry is Ownable
{
    event Deployed();
    event SetMasterArbitrator(IArbitrableProxy arbitratorProxy);
    event SetMasterOperation(uint256 indexed operation, bytes extraData);
    event ArbitratorAddRequested(uint256 indexed requestId, uint256 disputeId, address manager, string name);
    event ArbitratorAdded(IArbitrableProxy indexed arbAddr, string name, address manager);
    event ArbitratorDeleted(IArbitrableProxy indexed arbAddr);
    event ArbitratorManagerChanged(IArbitrableProxy indexed arbAddr, address manager);
    event OperationsAddRequested(uint256 indexed requestId, uint256 disputeId, address manager, IArbitrableProxy indexed arbAddr);
    event OperationAdded(IArbitrableProxy indexed arbAddr, uint256 indexed operation, bytes extraData);
    event OperationChanged(IArbitrableProxy indexed arbAddr, uint256 indexed operation, bytes extraData);
    event OperationRemoved(IArbitrableProxy indexed arbAddr, uint256 indexed operation);
    event ContractsAddRequested(uint256 indexed requestId, uint256 disputeId, address manager, IArbitrableProxy indexed arbAddr);
    event ContractAdded(IArbitrableProxy indexed arbAddr, address indexed contr);
    event ContractRemoved(IArbitrableProxy indexed arbAddr, address indexed contr);
    event DisputeAccepted(uint256 indexed requestId);
    event DisputeRejected(uint256 indexed requestId);

    struct Arbitrator
    {
        string                      name;
        address                     manager;
        mapping(uint256 => bytes)   extraData;  // operation id -> extraData
        mapping(address => bool)    contracts;
        bool                        allContracts;
    }
    mapping(IArbitrableProxy => Arbitrator) public arbitrators;
    
    IArbitrableProxy                        public master;
    mapping(MasterOperations => bytes)      public masterExtraData;
    mapping(MasterOperations => string)     public metaEvidences;
    enum MasterOperations
    {
        AddArbitrator,
        AddContracts,
        AddOperations
    }
    struct Request
    {
        IArbitrableProxy master;
        MasterOperations op;
        IArbitrableProxy arb;
        string           name;
        address          manager;
        uint256[]        operations;
        bytes[]          extraData;
        address[]        contracts;
    }
    mapping(uint256 => Request) public disputes;
    uint256 constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    constructor()
    {
        emit Deployed();
    }

    function getRequest(uint256 requestId) public view returns (
        IArbitrableProxy m,
        MasterOperations op,
        IArbitrableProxy arb,
        string memory name,
        address manager,
        bytes memory operations,
        bytes[] memory extraData,
        bytes memory contracts
    ) {
        Request storage dispute = disputes[requestId];
        return (
            dispute.master,
            dispute.op,
            dispute.arb,
            dispute.name,
            dispute.manager,
            abi.encodePacked(dispute.operations),
            dispute.extraData,
            abi.encodePacked(dispute.contracts));
    }

    function setMaster(
        IArbitrableProxy  arb,
        bytes[]  calldata extraData,
        string[] calldata evidence) public onlyOwner
    {
        master = arb;
        emit SetMasterArbitrator(arb);
        for(uint256 i = 0; i < extraData.length; i++)
        {
            masterExtraData[MasterOperations(i)] = extraData[i];
            metaEvidences[MasterOperations(i)] = evidence[i];
            emit SetMasterOperation(i, extraData[i]);
        }
    }

    /* Adding arbitrator allowed through disputing only */
    function addArbitrator(
        string              memory    name,
        IArbitrableProxy              arb,
        uint256[]           calldata  operations,
        bytes[]             calldata  extraData,
        address[]           calldata  contracts,
        string              calldata  evidence) public payable
    {
        require(address(master) != address(0), "no master");
        require(masterExtraData[MasterOperations.AddArbitrator].length > 0, "no extradata");
        uint256 externalDisputeId = master.createDispute{value: msg.value}(
            masterExtraData[MasterOperations.AddArbitrator],
            metaEvidences[MasterOperations.AddArbitrator],
            numberOfRulingOptions);
        uint256 disputeId = master.externalIDtoLocalID(externalDisputeId);
        disputes[disputeId] = Request(
            master,
            MasterOperations.AddArbitrator,
            arb,
            name,
            _msgSender(),
            operations,
            extraData,
            contracts);
        master.submitEvidence(disputeId, evidence);
        emit ArbitratorAddRequested(disputeId, externalDisputeId, _msgSender(), name);
    }

    function addArbitrator(uint256 disputeId) internal
    {
        Request storage request = disputes[disputeId];
        require(address(request.master) != address(0), "unknown");
        Arbitrator storage arb = arbitrators[request.arb];
        arb.name = request.name;
        arb.manager = request.manager;
        emit ArbitratorAdded(request.arb, request.name, request.manager);
        addOperations(request.arb, disputeId);
        addContracts(request.arb, disputeId);
    }

    function addOperations(IArbitrableProxy arbAddr, uint256 disputeId) internal
    {
        Request storage request = disputes[disputeId];
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(request.master) != address(0), "unknown request");
        require(address(arb.manager) != address(0), "unknown arbitrator");
        for(uint256 i = 0; i < request.operations.length; i++)
        {
            arb.extraData[request.operations[i]] = request.extraData[i];
            emit OperationAdded(arbAddr, request.operations[i], request.extraData[i]);
        }
    }

    function addContracts(IArbitrableProxy arbAddr, uint256 disputeId) internal
    {
        Request storage request = disputes[disputeId];
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(request.master) != address(0), "unknown request");
        require(address(arb.manager) != address(0), "unknown arbitrator");
        arb.allContracts = (request.contracts.length == 0);
        for(uint256 i = 0; i < request.contracts.length; i++)
        {
            arb.contracts[request.contracts[i]] = true;
            emit ContractAdded(arbAddr, request.contracts[i]);
        }
    }

    function changeArbitratorManager(IArbitrableProxy arbAddr, address newManager) public
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(arb.manager) != address(0), "not found");
        require(_msgSender()==address(arbAddr) || _msgSender()==arb.manager, "not permitted");
        arb.manager = newManager;
        emit ArbitratorManagerChanged(arbAddr, newManager);
    }

    /* Arbitrator can delete itself or be deleted by owner without disputing */
    function deleteArbitrator(IArbitrableProxy arbAddr) public
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(arb.manager) != address(0), "not found");
        require(_msgSender()==address(arbAddr) ||
                _msgSender()==arb.manager ||
                _msgSender()==owner(), "not permitted");
        delete arbitrators[arbAddr];
        emit ArbitratorDeleted(arbAddr);
    }

    /* Adding operations allowed through disputing only */
    function addOperations(
            IArbitrableProxy    arbAddr,
            uint256[] calldata  operations,
            bytes[]   calldata  extraData,
            string    calldata  evidence) public payable
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(arb.manager) != address(0), "not found");
        require(_msgSender()==address(arbAddr) || _msgSender()==arb.manager, "not permitted");
        require(address(master) != address(0), "no master");
        require(masterExtraData[MasterOperations.AddOperations].length > 0, "no extradata");
        uint256 externalDisputeId = master.createDispute{value: msg.value}(
            masterExtraData[MasterOperations.AddOperations],
            metaEvidences[MasterOperations.AddOperations],
            numberOfRulingOptions);
        uint256 disputeId = master.externalIDtoLocalID(externalDisputeId);
        address[] memory dummy;
        disputes[disputeId] = Request(
            master,
            MasterOperations.AddOperations,
            IArbitrableProxy(arbAddr),
            "",
            address(0),
            operations,
            extraData,
            dummy);
        master.submitEvidence(disputeId, evidence);
        emit OperationsAddRequested(disputeId, externalDisputeId, arb.manager, arbAddr);
    }

    /* Set extraData for already assigned operations allowed to arbitrator without disputing */
    function changeOperations(
            IArbitrableProxy    arbAddr,
            uint256[] calldata  operations,
            bytes[]   calldata  extraData) public
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(arb.manager) != address(0), "not found");
        require(_msgSender()==address(arbAddr) || _msgSender()==arb.manager, "not permitted");
        for(uint256 i=0; i<operations.length; i++)
        {
            require(arb.extraData[operations[i]].length>0, "not assigned");
            arb.extraData[operations[i]] = extraData[i];
            emit OperationChanged(arbAddr, operations[i], extraData[i]);
        }
    }

    /* Removing operations allowed to arbitrator without disputing */
    function removeOperations(
            IArbitrableProxy    arbAddr,
            uint256[] calldata  operations) public
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(arb.manager) != address(0), "not found");
        require(_msgSender()==address(arbAddr) || _msgSender()==arb.manager, "not permitted");
        for(uint256 i=0; i<operations.length; i++)
        {
            delete arb.extraData[operations[i]];
            emit OperationRemoved(arbAddr, operations[i]);
        }
    }

    /* Adding contracts allowed through disputing only */
    function addContracts(
            IArbitrableProxy    arbAddr,
            address[] calldata  contracts,
            string    calldata  evidence) public payable
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(arb.manager) != address(0), "not found");
        require(_msgSender()==address(arbAddr) || _msgSender()==arb.manager, "not permitted");
        require(!arb.allContracts, "don't need");
        require(address(master) != address(0), "no master");
        require(masterExtraData[MasterOperations.AddContracts].length > 0, "no extradata");
        uint256 externalDisputeId = master.createDispute{value: msg.value}(
            masterExtraData[MasterOperations.AddContracts],
            metaEvidences[MasterOperations.AddContracts],
            numberOfRulingOptions);
        uint256 disputeId = master.externalIDtoLocalID(externalDisputeId);
        uint256[] memory dummy1;
        bytes[]   memory dummy2;
        disputes[disputeId] = Request(
            master,
            MasterOperations.AddContracts,
            IArbitrableProxy(arbAddr),
            "",
            address(0),
            dummy1,
            dummy2,
            contracts);
        master.submitEvidence(disputeId, evidence);
        emit ContractsAddRequested(disputeId, externalDisputeId, arb.manager, arbAddr);
    }

    /* Removing contracts allowed to arbitrator without disputing */
    function removeContracts(
            IArbitrableProxy    arbAddr,
            address[] calldata  contracts) public
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        require(address(arb.manager) != address(0), "not found");
        require(_msgSender()==address(arbAddr) || _msgSender()==arb.manager, "not permitted");
        for(uint256 i=0; i<contracts.length; i++)
        {
            delete arb.contracts[contracts[i]];
            emit ContractRemoved(arbAddr, contracts[i]);
        }
    }

    function checkArbitrator(IArbitrableProxy arbAddr) public view returns(bool)
    {
        return address(arbitrators[arbAddr].manager) != address(0);
    }

    function checkArbitratorByOperation(
        IArbitrableProxy arbAddr,
        uint256          operation,
        address          contr) public view returns(bool)
    {
        Arbitrator storage arb = arbitrators[arbAddr];
        return address(arb.manager) != address(0) &&
            arb.extraData[operation].length > 0 &&
            (arb.contracts[contr] || arb.allContracts);
    }

    function extraDataForOperation(
        IArbitrableProxy arbAddr,
        uint256          operation) public view returns(bytes memory)
    {
        return arbitrators[arbAddr].extraData[operation];
    }

    function arbitrationCost(
        IArbitrableProxy arbAddr,
        uint256          operation) public view returns (uint256)
    {
        IArbitrator finalArbitrator = IArbitrableProxy(arbAddr).arbitrator();
        return finalArbitrator.arbitrationCost(extraDataForOperation(arbAddr, operation));
    }

    function fetchRuling(uint256 disputeId) external
    {
        Request memory request = disputes[disputeId];
        IArbitrableProxy arb = request.arb;
        (, bool isRuled, uint256 ruling,) = arb.disputes(disputeId);
        require(isRuled, "ruling pending");

        if (ruling == 1)
        {
            if(request.op == MasterOperations.AddArbitrator)
            {
                addArbitrator(disputeId);
            }
            else if(request.op == MasterOperations.AddOperations)
            {
                addOperations(arb, disputeId);
            }
            else if(request.op == MasterOperations.AddContracts)
            {
                addContracts(arb, disputeId);
            }
            emit DisputeAccepted(disputeId);
        }
        else
        {
            emit DisputeRejected(disputeId);
        }
        delete disputes[disputeId];
    }
}
