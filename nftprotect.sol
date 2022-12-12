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

import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Address.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrator.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrable.sol";


contract NFTProtect is ERC721, IERC721Receiver, IArbitrable, Ownable
{
    using Address for address payable;

    event Deployed();
    event FeeChanged(uint256 feeWei);
    event ArbitratorChanged(address arbitrator);
    event Wrapped(address indexed owner, address contr, uint256 tokenIdOrig, uint256 indexed tokenId);
    event Unwrapped(address indexed owner, uint256 indexed tokenId);
    event OwnershipAdjustmentAsked(uint256 indexed requestId, address indexed newowner, address indexed oldowner, uint256 tokenId);
    event OwnershipAdjustmentAnswered(uint256 indexed requestId, bool accept);
    event OwnershipAdjustmentArbitrateAsked(uint256 indexed requestId, uint256 indexed disputeId);

    struct Original
    {
        ERC721  contr;
        uint256 tokenId;
        address owner;
    }
    mapping(uint256 => Original) public tokens;
    
    enum Status
    {
        Initial,
        Accepted,
        Rejected,
        Disputed
    }
    struct OwnershipAdjustmentRequest
    {
        uint256 tokenId;
        address newowner;
        uint256 timeout;
        Status  status;
        uint256 disputeId;
    }
    mapping(uint256 => OwnershipAdjustmentRequest) public requests;
    mapping(uint256 => uint256) public tokenToRequest;
    mapping(uint256 => uint256) public disputeToRequest;
    
    uint256     constant duration = 2 days;
    uint256     constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    uint256     public feeWei;
    uint256     public tokensCounter;
    uint256     public requestsCounter;
    IArbitrator public arbitrator;

    uint256     internal allow;

    constructor(uint256 fw, address arb) ERC721("NFT Protect", "wNFT")
    {
        emit Deployed();
        setFee(fw);
        setArbitrator(arb);
    }

    function setFee(uint256 fw) public onlyOwner
    {
        feeWei = fw;
        emit FeeChanged(feeWei);
    }

    function setArbitrator(address arb) public onlyOwner
    {
        arbitrator = IArbitrator(arb);
        emit ArbitratorChanged(arb);
    }

    /**
     * @dev Accept only tokens which internally allowed by `allow` property
     */
    function onERC721Received(address /*operator*/, address /*from*/, uint256 /*tokenId*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow == 1, "NFTProtect: illegal transfer");
        return this.onERC721Received.selector;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for original
     * token, wrapped in `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory)
    {
        require(_exists(tokenId), "NFTProtect: URI query for nonexistent token");
        Original memory token = tokens[tokenId];
        return token.contr.tokenURI(token.tokenId);
    }

    /**
     * @dev Wrap external token, described as pair `contr` and `tokenId`.
     * Owner of token must approve `tokenId` for NFTProtect contract to make
     * it possible to safeTransferFrom this token from the owner to NFTProtect
     * contract. Mint wrapped token for owner.
     */
    function wrap(ERC721 contr, uint256 tokenId) public payable
    {
        require(msg.value == feeWei, "NFTProtect: wrong payment");
        payable(owner()).sendValue(msg.value);
        _mint(_msgSender(), ++tokensCounter);
        tokens[tokensCounter] = Original(contr, tokenId, _msgSender());
        allow = 1;
        contr.safeTransferFrom(_msgSender(), address(this), tokenId);
        allow = 0;
        emit Wrapped(_msgSender(), address(contr), tokenId, tokensCounter);
    }

    /**
     * @dev Burn wrapped token and send original token to the owner.
     * The owner of the original token and the owner of wrapped token must
     * be the same. If not, need to call askOwnershipAdjustment() first.
     */
    function burn(uint256 tokenId) public
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: not the owner");
        Original memory token = tokens[tokenId];
        require(token.owner == _msgSender(), "NFTProtect: need to askOwnershipAdjustment first");
        _burn(tokenId);
        token.contr.safeTransferFrom(address(this), _msgSender(), token.tokenId);
        delete tokens[tokenId];
        delete requests[tokenToRequest[tokenId]];
        emit Unwrapped(_msgSender(), tokenId);
    }

    function _hasOwnershipAdjustmentRequest(uint256 tokenId) internal view returns(bool)
    {
        uint256 requestId = tokenToRequest[tokenId];
        if (requestId != 0)
        {
            OwnershipAdjustmentRequest memory request = requests[requestId];
            return (request.timeout < block.timestamp &&
                request.status == Status.Initial) ||
                request.status == Status.Disputed;
        }
        return false;
    }

    /**
     * @dev Create request for ownership adjustment for `tokenId`. It requires
     * when somebody got ownership of wrapped token. Owner of original token
     * must confirm or reject ownership transfer by calling answerOwnershipAdjustment().
     */
    function askOwnershipAdjustment(uint256 tokenId) public 
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: not the owner");
        require(!_hasOwnershipAdjustmentRequest(tokenId), "NFTProtect: already have request");
        Original memory token = tokens[tokenId];
        require(token.owner != _msgSender(), "NFTProtect: already owner");
        requests[++requestsCounter] =
            OwnershipAdjustmentRequest(
                tokenId,
                _msgSender(),
                block.timestamp + duration,
                Status.Initial,
                0);
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipAdjustmentAsked(requestsCounter, _msgSender(), token.owner, tokenId);
    }

    /**
     * @dev Must be called by owner of original token to confirm or reject
     * ownership transfer to the new owner of wrapped token.
     */
    function answerOwnershipAdjustment(uint256 requestId, bool accept) public
    {
        OwnershipAdjustmentRequest storage request = requests[requestId];
        require(request.status == Status.Initial, "NFTProtect: already answered");
        require(request.timeout < block.timestamp, "NFTProtect: timeout");
        Original storage token = tokens[request.tokenId];
        require(token.owner == _msgSender(), "NFTProtect: not the original owner");
        request.status = accept ? Status.Accepted : Status.Rejected;
        if (accept)
        {
            token.owner = request.newowner;
        }
        emit OwnershipAdjustmentAnswered(requestId, accept);
    }

    /**
     * @dev Can be called by the owner of the wrapped token if owner of
     * the original token didn't answer or rejected ownership transfer.
     * This function create dispute on external ERC-792 compatible arbitrator.
     */
    function askOwnershipAdjustmentArbitrate(uint256 requestId, bytes calldata extraData) public payable
    {
        OwnershipAdjustmentRequest storage request = requests[requestId];
        require(request.timeout > 0, "NFTProtect: unknown requestId");
        require(request.timeout >= block.timestamp, "NFTProtect: wait for answer more");
        require(request.status == Status.Initial || request.status == Status.Rejected, "NFTProtect: wrong status");
        require(_isApprovedOrOwner(_msgSender(), request.tokenId), "NFTProtect: not the owner");
        request.disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
        request.status = Status.Disputed;
        disputeToRequest[request.disputeId] = requestId;
        emit OwnershipAdjustmentArbitrateAsked(requestId, request.disputeId);
    }

    /**
     * @dev Callback function from external arbitrator. The meaning of `ruling`
     * value is: 0 - RefusedToArbitrate, 1 - Accepted, 2 - Rejected.
     */
    function rule(uint256 disputeId, uint256 ruling) external override
    {
        require(_msgSender() == address(arbitrator), "NFTProtect: not the arbitrator");
        require(ruling <= numberOfRulingOptions, "NFTProtect: invalid ruling");
        uint256 requestId = disputeToRequest[disputeId];
        require(requestId > 0, "NFTProtect: unknown requestId");
        OwnershipAdjustmentRequest storage request = requests[requestId];
        bool accept = ruling == 1;
        request.status = accept ? Status.Accepted : Status.Rejected;
        if (accept)
        {
            tokens[request.tokenId].owner = request.newowner; 
        }
        emit OwnershipAdjustmentAnswered(requestId, accept);
        emit Ruling(arbitrator, disputeId, ruling);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool)
    {
        // TODO: implement delegation of ownership
        return super._isApprovedOrOwner(spender, tokenId);
    }
}
