/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The NFTProtect Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The NFTProtect Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the NFTProtect Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./iuserregistry.sol";
import "./arbitratorregistry.sol";
import "./signature-verifier.sol";

contract NFTProtect is ERC721, IERC721Receiver, IERC1155Receiver, Ownable
{
    using Address for address payable;

    event Deployed();
    event UserRegistryChanged(address ureg);
    event ArbitratorRegistryChanged(address areg);
    event BurnOnActionChanged(bool boa);
    event BaseChanged(string base);
    event ScoreThresholdChanged(uint256 threshold);
    event MetaEvidenceLoaderChanged(address mel);
    event MetaEvidenceSet(MetaEvidenceType evidenceType, string evidence);
    // Event emitted when the signature verifier is changed
    event SignatureVerifierChanged(address newSigVerifier);
    event Protected(uint256 indexed assetType, address indexed owner, address contr, uint256 tokenIdOrig, uint256 indexed tokenId, uint256 amount);
    event Unprotected(address indexed dst, uint256 indexed tokenId);
    event BurnArbitrateAsked(uint256 indexed requestId, address dst, uint256 indexed tokenId);
    event BurnAnswered(uint256 indexed requestId, bool accept);
    event OwnershipAdjusted(address indexed newowner, address indexed oldowner, uint256 indexed tokenId);
    event OwnershipAdjustmentAsked(uint256 indexed requestId, address indexed newowner, address indexed oldowner, uint256 tokenId);
    event OwnershipAdjustmentAnswered(uint256 indexed requestId, bool accept);
    event OwnershipAdjustmentArbitrateAsked(uint256 indexed requestId, address dst, uint256 indexed tokenId);
    event OwnershipRestoreAsked(uint256 indexed requestId, address indexed newowner, address indexed oldowner, uint256 tokenId);
    event OwnershipRestoreAnswered(uint256 indexed requestId, bool accept);

    enum Standard
    {
        ERC721,
        ERC1155,
        ERC20
    }

    struct Original
    {
        Standard standard;
        address  contr;
        uint256  tokenId;
        uint256  amount; // ERC1155 and ERC20 only
        address  owner;
        uint256 nonce; //for security reasons
    }
    // Protected tokenId to original
    mapping(uint256 => Original) public tokens;
    
    enum Status
    {
        Initial,
        Accepted,
        Rejected,
        Disputed
    }
    enum ReqType
    {
        OwnershipAdjustment,
        OwnershipRestore,
        Burn
    }
    struct Request
    {
        ReqType          reqtype; 
        uint256          tokenId;
        address          newowner;
        uint256          timeout;
        Status           status;
        uint256          arbitratorId;
        uint256          localDisputeId;
        uint256          externalDisputeId;
        MetaEvidenceType metaevidence;
    }

    // Contract to verify a signature provided
    SignatureVerifier            public sigVerifier;
    mapping(uint256 => Request)  public requests;
    mapping(uint256 => uint256)  public tokenToRequest;
    mapping(uint256 => uint256)  public disputeToRequest;
    enum MetaEvidenceType
    {
        burn, // used in burn() - ultra
        adjustOwnership, // used in adjustOwnership() - ultra
        answerOwnershipAdjustment, // used in answerOwnershipAdjustment() - ultra
        askOwnershipAdjustmentArbitrate, // used in askOwnershipAdjustmentArbitrate() - basic
        askOwnershipRestoreArbitrateMistake, // used in askOwnershipRestoreArbitrate() - basic
        askOwnershipRestoreArbitratePhishing, // used in askOwnershipRestoreArbitrate() - basic
        askOwnershipRestoreArbitrateProtocolBreach // used in askOwnershipRestoreArbitrate() - basic
    }
    mapping(MetaEvidenceType => string)    public metaEvidences;
    
    uint256            constant duration = 2 days;
    uint256            constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    bool               internal allow = false;

    address            public   metaEvidenceLoader;
    uint256            public   tokensCounter;
    uint256            public   requestsCounter;
    ArbitratorRegistry public   arbitratorRegistry;
    IUserRegistry      public   userRegistry;
    bool               public   burnOnAction;
    bool               public   allowThirdPartyTransfers;
    string             public   base;
    uint256            public   scoreThreshold;

    constructor(address areg, address signatureVerifier) ERC721("NFT Protect", "pNFT")
    {
        emit Deployed();
        setArbitratorRegistry(areg);
        setSignatureVerifier(signatureVerifier);
        setBurnOnAction(false);
        setScoreThreshold(50);
        setBase("");
        setMetaEvidenceLoader(_msgSender());
    }

    /**
     * @dev Sets the signature verifier contract address.
     * This method can only be called by the owner of the contract.
     * @param newSigVerifier The address of the new signature verifier contract.
     */
    function setSignatureVerifier(address newSigVerifier) public onlyOwner {
        require(newSigVerifier != address(0), "SignatureVerifier address cannot be zero");
        sigVerifier = SignatureVerifier(newSigVerifier);
        emit SignatureVerifierChanged(newSigVerifier);
    }

    function setArbitratorRegistry(address areg) public onlyOwner
    {
        arbitratorRegistry = ArbitratorRegistry(areg);
        emit ArbitratorRegistryChanged(areg);
    }

    function setUserRegistry(address ureg) public onlyOwner
    {
        userRegistry = IUserRegistry(ureg);
        emit UserRegistryChanged(ureg);
    }

    function setBurnOnAction(bool boa) public onlyOwner
    {
        burnOnAction = boa;
        emit BurnOnActionChanged(boa);
    }

    function setBase(string memory b) public onlyOwner
    {
        base=b;
        emit BaseChanged(b);
    }

    function _baseURI() internal view override returns (string memory)
    {
        return base;
    }

    function setScoreThreshold(uint256 threshold) public onlyOwner
    {
        scoreThreshold = threshold;
        emit ScoreThresholdChanged(threshold);
    }

    function setMetaEvidenceLoader(address mel) public onlyOwner
    {
        metaEvidenceLoader = mel;
        emit MetaEvidenceLoaderChanged(mel);
    }

    /**
     * @dev Accept only tokens which internally allowed by `allow` property
     */
    function onERC721Received(address /*operator*/, address /*from*/, uint256 /*tokenId*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow);
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address /*operator*/, address /*from*/, uint256 /*id*/, uint256 /*value*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address /*operator*/, address /*from*/, uint256[] calldata /*ids*/, uint256[] calldata /*values*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow);
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for original
     * token, protected in `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory)
    {
        require(_exists(tokenId));
        Original memory token = tokens[tokenId];
        return bytes(base).length==0 ?
                token.standard == Standard.ERC721 ?
                    ERC721(token.contr).tokenURI(token.tokenId) :
                    token.standard == Standard.ERC1155 ?
                        ERC1155(token.contr).uri(token.tokenId) :
                        "" :
                super.tokenURI(tokenId);
    }

    function originalOwnerOf(uint256 tokenId) public view returns(address)
    {
        address owner = tokens[tokenId].owner;
        return owner;
    }

    function isOriginalOwner(uint256 tokenId, address candidate) public view returns(bool)
    {
        Original memory token = tokens[tokenId];
        return token.owner == candidate;
    }

    /**
     * @dev Protect token, issued by `contr` contract.
     * Owner of token must approve 'amount' of 'tokenId' tokens for NFTProtect contract to make
     * it possible to transferFrom this tokens from the owner to NFTProtect
     * contract. Mint protected token for owner.
     * If referrer is given, pay affiliatePercent of user payment to him.
     * Using parameters:
     * * ERC721:  tokenId
     * * ERC1155: tokenId, amount
     * * ERC20:   emount
     */
    function protect(Standard std, address contr, uint256 tokenId, uint256 amount, address user, address payable referrer) public payable returns(uint256)
    {
        if (user == address(0)) 
        {
            user = _msgSender();
        } 
        userRegistry.processPayment{value: msg.value}(
            _msgSender(),
            user,
            referrer,
            IUserRegistry.FeeType.Entry
        );
        _mint(user, ++tokensCounter);
        tokens[tokensCounter] = Original(std, contr, tokenId, amount, user, 0);
        allow = true;
        if(std == Standard.ERC721)
        {
            ERC721(contr).safeTransferFrom(_msgSender(), address(this), tokenId);
        }
        else if(std == Standard.ERC1155)
        {
            ERC1155(contr).safeTransferFrom(_msgSender(), address(this), tokenId, amount, '');
        }
        else if(std == Standard.ERC20)
        {
            IERC20(contr).transferFrom(_msgSender(), address(this), amount);
        }
        emit Protected(uint256(std), user, contr, tokenId, tokensCounter, amount);
        allow = false;
        return tokensCounter;
    }

    /**
     * @dev Burn protected token and send original token to the owner.
     * The owner of the original token and the owner of protected token must
     * be the same. If not, need to call askOwnershipAdjustment() first.
     */
    function burn(uint256 tokenId, address dst, bytes memory signature) public payable
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "not owner");
        require(isOriginalOwner(tokenId, _msgSender()), "need to askOwnershipAdjustment");
        Original memory token = tokens[tokenId];
        require(sigVerifier.verify(
            tokenId,
            _msgSender(),
            _msgSender(),
            token.nonce,
            signature
        ), "invalid signature");
        // token.nonce++; // Not needed because we burn the token
        _burn(dst == address(0) ? _msgSender() : dst, tokenId);
    }

    function _burn(address dst, uint256 tokenId) internal
    {
        super._burn(tokenId);
        Original memory token = tokens[tokenId];
        if(token.standard == Standard.ERC721)
        {
            ERC721(token.contr).safeTransferFrom(address(this), dst, token.tokenId);
        }
        else if(token.standard == Standard.ERC1155)
        {
            ERC1155(token.contr).safeTransferFrom(address(this), dst, token.tokenId, token.amount, '');
        }
        else // ERC20
        {
            IERC20(token.contr).transfer(dst, token.amount);
        }
        delete tokens[tokenId];
        delete requests[tokenToRequest[tokenId]];
        emit Unprotected(dst, tokenId);
    }

    function _hasRequest(uint256 tokenId) internal view returns(bool)
    {
        uint256 requestId = tokenToRequest[tokenId];
        if (requestId != 0)
        {
            Request memory request = requests[requestId];
            return request.status == Status.Initial ||
                request.status == Status.Disputed;
        }
        return false;
    }

    /**
     * @dev Internal function to process payment and create a dispute.
     * This function is used to avoid code duplication when both actions are always performed together.
     * @param user The user on whose behalf the payment is processed.
     * @param arbitratorId The ID of the arbitrator to create the dispute with.
     * @param metaEvidenceType The type of meta evidence to be used for the dispute.
     * @param evidence The evidence to be submitted for the dispute.
     * @return localDisputeId The local ID of the created dispute.
     * @return externalDisputeId The external ID of the created dispute as assigned by the arbitrable proxy.
     */
    function _processPaymentAndCreateDispute(
        address user,
        uint256 arbitratorId,
        MetaEvidenceType metaEvidenceType,
        string memory evidence
    ) internal returns (uint256 localDisputeId, uint256 externalDisputeId) {
        IArbitrableProxy arbitrableProxy;
        bytes memory extraData;
        (arbitrableProxy, extraData) = arbitratorRegistry.arbitrator(arbitratorId);
        uint256 finalFee = userRegistry.feeForUser(user, IUserRegistry.FeeType.OpenCase);
        userRegistry.processPayment{value: finalFee}(
            user,
            user,
            payable(address(0)), // Referrer is already set on entry
            IUserRegistry.FeeType.OpenCase
        );
        externalDisputeId = arbitrableProxy.createDispute{value: msg.value - finalFee}(extraData, metaEvidences[metaEvidenceType], numberOfRulingOptions);
        localDisputeId = arbitrableProxy.externalIDtoLocalID(externalDisputeId);
        arbitrableProxy.submitEvidence(localDisputeId, evidence);
        return (localDisputeId, externalDisputeId);
    }

    /** @dev Transfer ownerhip for `tokenId` to the owner of protected token. Must
     *  be called by the current owner of `tokenId`.
     */
    function adjustOwnership(uint256 tokenId, bytes memory signature) public payable
    {
        require(!_hasRequest(tokenId), "have request");
        require(isOriginalOwner(tokenId, _msgSender()), "not owner");
        Original storage token = tokens[tokenId];
        require(sigVerifier.verify(
            tokenId,
            _msgSender(),
            ownerOf(tokenId),
            tokens[tokenId].nonce,
            signature
        ), "invalid signature");
        tokens[tokenId].nonce++;
        token.owner = ownerOf(tokenId);
        emit OwnershipAdjusted(token.owner, _msgSender(), tokenId);
        if (burnOnAction)
        {
            _burn(token.owner, tokenId);
        }
    }

    /**
     * @dev Create request for ownership adjustment for `tokenId`. It requires
     * when somebody got ownership of protected token. Owner of original token
     * must confirm or reject ownership transfer by calling answerOwnershipAdjustment().
     */
    function askOwnershipAdjustment(uint256 tokenId, address dst, uint256 arbitratorId) public 
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "not owner");
        require(!_hasRequest(tokenId), "have request");
        require(!isOriginalOwner(tokenId, _msgSender()), "already owner");
        requestsCounter++;
        Original storage token = tokens[tokenId];
        address newowner = dst == address(0) ? _msgSender() : dst;
        IArbitrableProxy arbitrableProxy;
        (arbitrableProxy, ) = arbitratorRegistry.arbitrator(arbitratorId);
        require(address(arbitrableProxy) != address(0), "no arbitrator");
        requests[requestsCounter] =
            Request(
                ReqType.OwnershipAdjustment,
                tokenId,
                newowner,
                block.timestamp + duration,
                Status.Initial,
                arbitratorId,
                0, 0,
                MetaEvidenceType.answerOwnershipAdjustment // ask have no dispute case, but answer does (ultra) 
            );
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipAdjustmentAsked(requestsCounter, newowner, token.owner, tokenId);
    }

    /**
     * @dev Must be called by the owner of the original token to confirm or reject
     * ownership transfer to the new owner of the protected token.
     */
    function answerOwnershipAdjustment(uint256 requestId, bool accept, bytes memory signature) public payable
    {
        Request storage request = requests[requestId];
        require(request.status == Status.Initial || request.status == Status.Rejected, "answered");
        Original storage token = tokens[request.tokenId];
        require(isOriginalOwner(request.tokenId, _msgSender()), "not owner");
        require(sigVerifier.verify(
            token.tokenId,
            _msgSender(),
            ownerOf(token.tokenId),
            token.nonce,
            signature
        ), "invalid signature");
        token.nonce++;

        if (accept)
        {
            request.status = Status.Accepted;
            token.owner = request.newowner;
            emit OwnershipAdjustmentAnswered(requestId, accept);
            if (burnOnAction)
            {
                _burn(token.owner, request.tokenId);
            }
        }
        else
        {
            request.status = Status.Rejected;
            emit OwnershipAdjustmentAnswered(requestId, accept);
        }
    }

    /**
     * @dev Can be called by the owner of the protected token if owner of
     * the original token didn't answer or rejected ownership transfer.
     * This function create dispute on external ERC-792 compatible arbitrator.
     */
    function askOwnershipAdjustmentArbitrate(uint256 requestId, string memory evidence) public payable
    {
        Request storage request = requests[requestId];
        require(request.timeout > 0, "unknown request");
        require(request.status == Status.Initial || request.status == Status.Rejected, "wrong status");
        require(request.status == Status.Rejected || request.timeout <= block.timestamp, "wait for answer");
        require(_isApprovedOrOwner(_msgSender(), request.tokenId), "not owner");
        (request.localDisputeId, request.externalDisputeId ) = _processPaymentAndCreateDispute(
            _msgSender(),
            request.arbitratorId,
            MetaEvidenceType.askOwnershipAdjustmentArbitrate,
            evidence
        );
        request.metaevidence = MetaEvidenceType.askOwnershipAdjustmentArbitrate;
        request.status = Status.Disputed;
        disputeToRequest[request.localDisputeId] = requestId;
        emit OwnershipAdjustmentArbitrateAsked(requestId, request.newowner, request.tokenId);
    }

    /**
     * @dev Create request for original ownership protected to `tokenId`. Can be called
     * by owner of original token if he or she lost access to protected token or it was stolen.
     * This function create dispute on external ERC-792 compatible arbitrator.
     */
    function askOwnershipRestoreArbitrate(uint256 tokenId, address dst, uint256 arbitratorId, MetaEvidenceType metaEvidenceType, string memory evidence) public payable
    {
        require(!_hasRequest(tokenId), "have request");
        require(isOriginalOwner(tokenId, _msgSender()), "not owner");
        require(_exists(tokenId), "no token");
        require(!_isApprovedOrOwner(_msgSender(), tokenId), "already owner");
        require(
            metaEvidenceType == MetaEvidenceType.askOwnershipRestoreArbitrateMistake ||
            metaEvidenceType == MetaEvidenceType.askOwnershipRestoreArbitratePhishing ||
            metaEvidenceType == MetaEvidenceType.askOwnershipRestoreArbitrateProtocolBreach,
            "wrong MetaEvidence"
        );
        requestsCounter++;
        (uint256 disputeId, uint256 externalDisputeId) = _processPaymentAndCreateDispute(
            _msgSender(),
            arbitratorId,
            metaEvidenceType,
            evidence
        );
        requests[++requestsCounter] =
            Request(
                ReqType.OwnershipRestore,
                tokenId,
                dst == address(0) ? _msgSender() : dst,
                0,
                Status.Disputed,
                arbitratorId,
                disputeId,
                externalDisputeId,
                metaEvidenceType
            );
        disputeToRequest[disputeId] = requestsCounter;
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipRestoreAsked(requestsCounter, _msgSender(), ownerOf(tokenId), tokenId);
    }

    function submitMetaEvidence(MetaEvidenceType evidenceType, string memory evidence) public
    {
        require(_msgSender() == metaEvidenceLoader, "forbidden");
        metaEvidences[evidenceType] = evidence;
        emit MetaEvidenceSet(evidenceType, evidence);
    }

    /**
     * @dev Fetch the ruling that is stored in the arbitrable proxy.
     * value is: 0 - RefusedToArbitrate, 1 - Accepted, 2 - Rejected.
     */
    function fetchRuling(uint256 requestId) external payable
    {
        require(requestId > 0, "unknown requestId");
        Request storage request = requests[requestId];
        require(request.status != Status.Accepted && request.status != Status.Rejected, "request over");
        IArbitrableProxy arbitrableProxy;
        (arbitrableProxy, ) = arbitratorRegistry.arbitrator(request.arbitratorId);
        (, bool isRuled, uint256 ruling,) = arbitrableProxy.disputes(request.localDisputeId);
        require(isRuled, "ruling pending");
        bool accept = ruling == 1;
        request.status = accept ? Status.Accepted : Status.Rejected;
        userRegistry.processPayment{value: msg.value}(
            _msgSender(),
            _msgSender(),
            payable(address(0)), // Referrer is already set on entry
            IUserRegistry.FeeType.FetchRuling
        );
        if (request.reqtype == ReqType.OwnershipAdjustment)
        {
            emit OwnershipAdjustmentAnswered(requestId, accept);
        }
        else if (request.reqtype == ReqType.OwnershipRestore)
        {
            emit OwnershipRestoreAnswered(requestId, accept);
        }
        else if (request.reqtype == ReqType.Burn)
        {
            emit BurnAnswered(requestId, accept);
        }
        if (accept)
        {
            if (request.reqtype == ReqType.OwnershipAdjustment)
            {
                tokens[request.tokenId].owner = request.newowner;
            }
            else if (request.reqtype == ReqType.OwnershipRestore)
            {
                safeTransferFrom(ownerOf(request.tokenId), request.newowner, request.tokenId);
            }
            if (burnOnAction || request.reqtype == ReqType.Burn)
            {
                _burn(request.newowner, request.tokenId);
            }
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal virtual override(ERC721)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        require(!_hasRequest(tokenId), "under dispute");
        if (!allowThirdPartyTransfers) {
            address originalOwner = originalOwnerOf(tokenId);
            address owner = ownerOf(tokenId);
            if (owner != originalOwner) {
                require(to == originalOwner, "Transfer to non-original owner not allowed");
            }
        }
    }

    function rescueERC20(address erc20, uint256 amount, address receiver) public onlyOwner
    {
        IERC20(erc20).transfer(receiver, amount);
    }
}
