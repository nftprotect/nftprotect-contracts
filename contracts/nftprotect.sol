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
    event AllowThirdPartyTransfersChanged(bool allowed);
    event MetaEvidenceLoaderChanged(address mel);
    event MetaEvidenceSet(MetaEvidenceType indexed evidenceType, string evidence);
    // Event emitted when the signature verifier is changed
    event SignatureVerifierChanged(address newSigVerifier);
    event Protected(uint256 indexed assetType, address indexed owner, address contr, uint256 tokenIdOrig, uint256 indexed tokenId, uint256 amount);
    event Unprotected(address indexed dst, uint256 indexed tokenId);
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

    struct DisputeKey {
        uint256 arbitratorId;
        uint256 disputeId;
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
    mapping(bytes32 => uint256) public disputeToRequest;
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

    constructor(address areg, address signatureVerifier) ERC721("NFT Protect", "pNFT")
    {
        emit Deployed();
        setArbitratorRegistry(areg);
        setSignatureVerifier(signatureVerifier);
        setBurnOnAction(false);
        setBase("");
        setAllowThirdPartyTransfers(false);
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

    /**
     * @dev Sets the arbitrator registry contract address.
     * This method can only be called by the owner of the contract.
     * @param areg The address of the new arbitrator registry contract.
     */
    function setArbitratorRegistry(address areg) public onlyOwner
    {
        arbitratorRegistry = ArbitratorRegistry(areg);
        emit ArbitratorRegistryChanged(areg);
    }

    /**
     * @dev Sets the user registry contract address.
     * This method can only be called by the owner of the contract.
     * @param ureg The address of the new user registry contract.
     */
    function setUserRegistry(address ureg) public onlyOwner
    {
        userRegistry = IUserRegistry(ureg);
        emit UserRegistryChanged(ureg);
    }

    /**
     * @dev Sets whether actions (such as protect, adjustOwnership) should result in burning the pNFT.
     * This method can only be called by the owner of the contract.
     * @param boa A boolean indicating whether to burn on actions.
     */
    function setBurnOnAction(bool boa) public onlyOwner
    {
        burnOnAction = boa;
        emit BurnOnActionChanged(boa);
    }

    /**
     * @dev Sets the base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `base` and the `tokenId`. If not, the URI will
     * be fetched from the original token contract.
     * This method can only be called by the owner of the contract.
     * @param b The base URI to set.
     */
    function setBase(string memory b) public onlyOwner
    {
        base=b;
        emit BaseChanged(b);
    }

    /**
     * @dev Sets whether third-party transfers of the protected NFTs are allowed.
     * This method can only be called by the owner of the contract.
     * @param _allow A boolean indicating whether to allow third-party transfers.
     */
    function setAllowThirdPartyTransfers(bool _allow) public onlyOwner {
        allowThirdPartyTransfers = _allow;
        emit AllowThirdPartyTransfersChanged(_allow);
    }

    function _baseURI() internal view override returns (string memory)
    {
        return base;
    }

    /**
     * @dev Sets the address as meta evidence uploaderer.
     * This method can only be called by the owner of the contract.
     * @param mel The address of the new meta evidence loader contract.
     */
    function setMetaEvidenceLoader(address mel) public onlyOwner
    {
        metaEvidenceLoader = mel;
        emit MetaEvidenceLoaderChanged(mel);
    }

    /**
     * @dev Accepts only tokens which are internally allowed by the `allow` property.
     * This function ensures that the contract can only receive ERC721 tokens that it has explicitly allowed.
     * @return bytes4 Returns `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(address /*operator*/, address /*from*/, uint256 /*tokenId*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow);
        return this.onERC721Received.selector;
    }

    /**
     * @dev Accepts a batch of ERC1155 tokens. This function ensures that the contract can receive 
     * multiple ERC1155 tokens in a single transaction.
     * @return bytes4 Returns `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     */
    function onERC1155Received(address /*operator*/, address /*from*/, uint256 /*id*/, uint256 /*value*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow);
        return this.onERC1155Received.selector;
    }

    /**
     * @dev Accepts a batch of ERC1155 tokens. This function ensures that the contract can receive multiple ERC1155 tokens in a single transaction.
     * @return bytes4 Returns `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(address /*operator*/, address /*from*/, uint256[] calldata /*ids*/, uint256[] calldata /*values*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow);
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for the original token protected in the specified `tokenId`.
     * If a base URI is set, it returns the concatenation of the base URI and the `tokenId`. Otherwise, it fetches the URI
     * from the original token contract based on its standard (ERC721 or ERC1155).
     * @param tokenId The token ID of the protected token.
     * @return string The URI of the original token.
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

    /**
     * @dev Returns the original owner of the token. This function is used to query the owner of the original token that corresponds to a protected token.
     * @param tokenId The token ID of the protected token
     * @return address The address of the original owner
     */
    function originalOwnerOf(uint256 tokenId) public view returns(address)
    {
        address owner = tokens[tokenId].owner;
        return owner;
    }

    /**
     * @dev Checks if a given address is the original owner of the token. This function is used to verify ownership of the original token.
     * @param tokenId The token ID of the protected token
     * @param candidate The address being verified as the original owner
     * @return bool True if the candidate address is the original owner, false otherwise
     */
    function isOriginalOwner(uint256 tokenId, address candidate) public view returns(bool)
    {
        Original memory token = tokens[tokenId];
        return token.owner == candidate;
    }

    /**
     * @dev Protects a token by transferring it to this contract and minting a corresponding protected token.
     * The original token can be an ERC721, ERC1155, or ERC20 token. The owner of the original token must approve
     * this contract to transfer the token on their behalf.
     * @param std The standard of the original token (ERC721, ERC1155, or ERC20).
     * @param contr The contract address of the original token.
     * @param tokenId The token ID of the original token (for ERC721 and ERC1155).
     * @param amount The amount of the original token (for ERC1155 and ERC20).
     * @param user The user to whom the protected token will be minted. If zero address, the sender is used.
     * @param referrer The referrer to receive affiliate fees, if any.
     * @return The token ID of the minted protected token.
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
     * @dev Burns a protected token and returns the original token to a specified address.
     * The caller must be the owner or approved for the protected token. The original owner
     * must match the caller.
     * @param tokenId The token ID of the protected token to burn.
     * @param dst The destination address to send the original token to. If zero, the sender is used.
     * @param signature A signature proving the original owner authorized the burn.
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

    /**
     * @dev Internal function to burn a protected token. 
     * This function is called by the public burn function after all checks have passed.
     * @param dst The destination address to send the original token to
     * @param tokenId The token ID of the protected token to burn
     */
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

    /**
     * @dev Checks if a token has an associated request. This function is used to determine 
     * if a protected token is currently involved in a dispute or ownership adjustment request.
     * @param tokenId The token ID of the protected token
     * @return bool True if there is an associated request, false otherwise
     */
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

    /**
     * @dev Transfers ownership of the original token to the owner of the protected token.
     * Can only be called by the current owner of the original token. A signature from the
     * original owner is required to prevent unauthorized transfers.
     * @param tokenId The token ID of the protected token.
     * @param signature A signature from the original owner authorizing the ownership transfer.
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
     * @dev Initiates a request for ownership adjustment. This is necessary when the ownership
     * of the protected token has changed and the original owner needs to transfer ownership
     * of the original token to the new owner of the protected token.
     * @param tokenId The token ID of the protected token.
     * @param dst The address to transfer ownership to. If zero, the sender is used.
     * @param arbitratorId The ID of the arbitrator to use for dispute resolution, if needed.
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
     * @dev Responds to an ownership adjustment request. The original owner of the token
     * calls this function to accept or reject the transfer of ownership to the new owner
     * of the protected token.
     * @param requestId The ID of the ownership adjustment request.
     * @param accept True to accept the transfer, false to reject.
     * @param signature A signature from the original owner authorizing the response.
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
     * @dev Initiates arbitration for an ownership adjustment request. This is called by the
     * new owner of the protected token if the original owner does not respond or rejects
     * the ownership adjustment request.
     * @param requestId The ID of the ownership adjustment request.
     * @param evidence A string containing evidence supporting the request for arbitration.
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
        bytes32 disputeKey = _getDisputeKeyHash(request.arbitratorId, request.localDisputeId);
        disputeToRequest[disputeKey] = requestId;
        emit OwnershipAdjustmentArbitrateAsked(requestId, request.newowner, request.tokenId);
    }

    /**
     * @dev Initiates a request for ownership restoration. This function is used when the original owner
     * has lost access to the protected token, allowing them to request the restoration of ownership.
     * @param tokenId The token ID of the protected token.
     * @param dst The destination address for the ownership restoration. If zero, the sender's address is used.
     * @param arbitratorId The ID of the arbitrator to be used for dispute resolution.
     * @param metaEvidenceType The type of meta evidence to be used for the dispute.
     * @param evidence A string containing evidence supporting the request for ownership restoration.
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
        bytes32 disputeKey = _getDisputeKeyHash(arbitratorId, disputeId);
        disputeToRequest[disputeKey] = requestsCounter;
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipRestoreAsked(requestsCounter, _msgSender(), ownerOf(tokenId), tokenId);
    }

    /**
     * @dev Submits meta evidence to be used in arbitration. This function allows
     * the meta evidence loader to update the meta evidence used in disputes.
     * @param evidenceType The type of meta evidence being submitted.
     * @param evidence The URI pointing to the meta evidence JSON file.
     */
    function submitMetaEvidence(MetaEvidenceType evidenceType, string memory evidence) public
    {
        require(_msgSender() == metaEvidenceLoader, "forbidden");
        metaEvidences[evidenceType] = evidence;
        emit MetaEvidenceSet(evidenceType, evidence);
    }

    /**
     * @dev Fetches the ruling from the arbitrable proxy and processes the outcome of the dispute.
     * This function is called after a dispute has been resolved to enforce the ruling.
     * @param requestId The ID of the request associated with the dispute.
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
        }
    }

    function _getDisputeKeyHash(uint256 arbitratorId, uint256 disputeId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(arbitratorId, disputeId));
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal virtual override(ERC721)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        require(!_hasRequest(tokenId), "under dispute");
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(allowThirdPartyTransfers || from == originalOwnerOf(tokenId) || to == originalOwnerOf(tokenId), "transfer allowed only to/from original owner");
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
        require(allowThirdPartyTransfers || from == originalOwnerOf(tokenId) || to == originalOwnerOf(tokenId), "transfer allowed only to/from original owner");
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function approve(address to, uint256 tokenId) public override {
        require(allowThirdPartyTransfers || _msgSender() == originalOwnerOf(tokenId), "approve allowed only from original owner");
        super.approve(to, tokenId);
    }

    /**
     * @dev Transfers a specified amount of ERC20 tokens from this contract to a receiver address.
     * Can only be called by the owner of the contract.
     * @param erc20 The address of the ERC20 token contract.
     * @param amount The amount of tokens to be transferred.
     * @param receiver The address of the recipient.
     */
    function rescueERC20(address erc20, uint256 amount, address receiver) public onlyOwner
    {
        IERC20(erc20).transfer(receiver, amount);
    }
}
