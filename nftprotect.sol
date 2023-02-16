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

import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Address.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrable.sol";
import "./iuserregistry.sol";
import "./arbitratorregistry.sol";
import "./nftpcoupons.sol";


contract NFTProtect is ERC721, IERC721Receiver, IERC1155Receiver, IArbitrable, Ownable, ReentrancyGuard
{
    using Address for address payable;

    event Deployed();
    event FeeChanged(Security indexed level, uint256 feeWei);
    event UserRegistryChanged(address ureg);
    event ArbitratorRegistryChanged(address areg);
    event BurnOnActionChanged(bool boa);
    event BaseChanged(string base);
    event ScoreThresholdChanged(uint256 threshold);
    event Wrapped721(address indexed owner, address contr, uint256 tokenIdOrig, uint256 indexed tokenId, Security level);
    event Wrapped1155(address indexed owner, address contr, uint256 tokenIdOrig, uint256 indexed tokenId, uint256 amount, Security level);
    event Wrapped20(address indexed owner, address contr, uint256 indexed tokenId, uint256 amount, Security level);
    event Unwrapped(address indexed dst, uint256 indexed tokenId);
    event BurnArbitrateAsked(uint256 indexed requestId, uint256 indexed disputeId, address dst, uint256 indexed tokenId, bytes extraData, address arbitrator);
    event OwnershipAdjusted(address indexed newowner, address indexed oldowner, uint256 indexed tokenId);
    event OwnershipAdjustmentAsked(uint256 indexed requestId, address indexed newowner, address indexed oldowner, uint256 tokenId, address arbitrator);
    event OwnershipAdjustmentAnswered(uint256 indexed requestId, bool accept);
    event OwnershipAdjustmentArbitrateAsked(uint256 indexed requestId, uint256 indexed disputeId, address dst, uint256 indexed tokenId, bytes extraData, address arbitrator);
    event OwnershipAdjustmentAppealed(uint256 indexed requestId, bytes extraData);
    event OwnershipRestoreAsked(uint256 indexed requestId, address indexed newowner, address indexed oldowner, uint256 tokenId, address arbitrator);
    event OwnershipRestoreAppealed(uint256 indexed requestId, bytes extraData);
    event OwnershipRestoreAnswered(uint256 indexed requestId, bool accept);

    enum Security
    {
        Basic,
        Ultra
    }

    enum Standard
    {
        ERC721,
        ERC1155,
        ERC20
    }

    struct Original
    {
        Standard standard;
        ERC721   contr721;
        ERC1155  contr1155;
        IERC20   contr20;
        uint256  tokenId;
        uint256  amount; // ERC1155 and ERC20 only
        address  owner;
        Security level;
    }
    // Wrapped tokenId to original
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
        ReqType     reqtype; 
        uint256     tokenId;
        address     newowner;
        uint256     timeout;
        Status      status;
        IArbitrator arbitrator;
        uint256     disputeId;
    }
    mapping(uint256 => Request)  public requests;
    mapping(uint256 => uint256)  public tokenToRequest;
    mapping(uint256 => uint256)  public disputeToRequest;
    mapping(Security => uint256) public feeWei;
    
    uint256            constant duration = 2 days;
    uint256            constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    uint256            public   tokensCounter;
    uint256            public   requestsCounter;
    ArbitratorRegistry public   arbitratorRegistry;
    IUserRegistry      public   userRegistry;
    bool               public   burnOnAction;
    string             public   base;
    uint256            public   scoreThreshold;
    NFTPCoupons        public   coupons;
    uint256            internal allow;

    constructor(address areg, address ureg) ERC721("NFT Protect", "wNFT")
    {
        emit Deployed();
        setFee(Security.Basic, 0);
        setFee(Security.Ultra, 0);
        setArbitratorRegistry(areg);
        setUserRegistry(ureg);
        setBurnOnAction(true);
        setScoreThreshold(0);
        setBase("");
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

    /**
     * @dev Accept only tokens which internally allowed by `allow` property
     */
    function onERC721Received(address /*operator*/, address /*from*/, uint256 /*tokenId*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow == 1);
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address /*operator*/, address /*from*/, uint256 /*id*/, uint256 /*value*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow == 1);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address /*operator*/, address /*from*/, uint256[] calldata /*ids*/, uint256[] calldata /*values*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow == 1);
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for original
     * token, wrapped in `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory)
    {
        require(_exists(tokenId));
        Original memory token = tokens[tokenId];
        return bytes(base).length==0 ?
                token.standard == Standard.ERC721 ?
                    token.contr721.tokenURI(token.tokenId) :
                    token.standard == Standard.ERC1155 ?
                        token.contr1155.uri(token.tokenId) :
                        "" :
                super.tokenURI(tokenId);
    }

    function originalOwnerOf(uint256 tokenId) public view returns(address)
    {
        address owner = tokens[tokenId].owner;
        while(userRegistry.hasSuccessor(owner))
        {
            owner = userRegistry.successorOf(owner);
        }
        return owner;
    }

    function isOriginalOwner(uint256 tokenId, address candidate) public view returns(bool)
    {
        Original memory token = tokens[tokenId];
        return !userRegistry.hasSuccessor(candidate) &&
            (token.owner == candidate ||
             userRegistry.isSuccessor(token.owner, candidate));
    }

    function _wrapBefore(Security level, address payable referrer) internal
    {
        require(level == Security.Basic || userRegistry.scores(_msgSender()) >= scoreThreshold, "NFT Protect: not enough scores");
        require(userRegistry.isRegistered(_msgSender()), "NFTProtect: unregistered");
        if (coupons.balanceOf(_msgSender()) > 0)
        {
            coupons.burnFrom(_msgSender(), 1);
        }
        else
        {
            require(msg.value == feeWei[level], "NFTProtect: wrong payment");
            userRegistry.processPayment{value: msg.value}(_msgSender(), referrer);
        }
    }

    /**
     * @dev Wrap ERC721 token, described as pair `contr` and `tokenId`.
     * Owner of token must approve `tokenId` for NFTProtect contract to make
     * it possible to safeTransferFrom this token from the owner to NFTProtect
     * contract. Mint wrapped token for owner.
     * If referrer is given, pay affiliatePercent of user payment to him.
     */
    function wrap721(ERC721 contr, uint256 tokenId, Security level, address payable referrer) public nonReentrant payable
    {
        require(address(contr) != address(this), "NFTProtect: doublewrap");
        _wrapBefore(level, referrer);
        _mint(_msgSender(), ++tokensCounter);
        tokens[tokensCounter] = Original(Standard.ERC721, contr, ERC1155(address(0)), IERC20(address(0)), tokenId, 1, _msgSender(), level);
        allow = 1;
        contr.safeTransferFrom(_msgSender(), address(this), tokenId);
        allow = 0;
        emit Wrapped721(_msgSender(), address(contr), tokenId, tokensCounter, level);
    }

    /**
     * @dev Wrap ERC1155 token, described as pair `contr` and `tokenId`.
     * Owner of token must approve `tokenId` for NFTProtect contract to make
     * it possible to safeTransferFrom this token from the owner to NFTProtect
     * contract. Mint wrapped token for owner.
     * If referrer is given, pay affiliatePercent of user payment to him.
     */
    function wrap1155(ERC1155 contr, uint256 tokenId, uint256 amount, Security level, address payable referrer) public nonReentrant payable
    {
        _wrapBefore(level, referrer);
        _mint(_msgSender(), ++tokensCounter);
        tokens[tokensCounter] = Original(Standard.ERC1155, ERC721(address(0)), contr, IERC20(address(0)), tokenId, amount, _msgSender(), level);
        allow = 1;
        contr.safeTransferFrom(_msgSender(), address(this), tokenId, amount, '');
        allow = 0;
        emit Wrapped1155(_msgSender(), address(contr), tokenId, amount, tokensCounter, level);
    }

    /**
     * @dev Wrap ERC20 tokens, issued by `contr` contract.
     * Owner of token must approve 'amount' of tokens for NFTProtect contract to make
     * it possible to transferFrom this tokens from the owner to NFTProtect
     * contract. Mint wrapped token for owner.
     * If referrer is given, pay affiliatePercent of user payment to him.
     */
    function wrap20(IERC20 contr, uint256 amount, Security level, address payable referrer) public nonReentrant payable
    {
        _wrapBefore(level, referrer);
        _mint(_msgSender(), ++tokensCounter);
        tokens[tokensCounter] = Original(Standard.ERC20, ERC721(address(0)), ERC1155(address(0)), contr, 0, amount, _msgSender(), level);
        contr.transferFrom(_msgSender(), address(this), amount);
        emit Wrapped20(_msgSender(), address(contr), amount, tokensCounter, level);
    }

    /**
     * @dev Burn wrapped token and send original token to the owner.
     * The owner of the original token and the owner of wrapped token must
     * be the same. If not, need to call askOwnershipAdjustment() first.
     */
    function burn(uint256 tokenId, bytes calldata extraData, address dst, uint256 arbitratorId) public payable
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: not owner");
        require(isOriginalOwner(tokenId, _msgSender()), "NFTProtect: need to askOwnershipAdjustment");
        if(tokens[tokenId].level == Security.Basic)
        {
            _burn(dst == address(0) ? _msgSender() : dst, tokenId);
        }
        else
        {
            require(dst != address(0) && dst != _msgSender(), "NFTProtect: bad dst");
            requestsCounter++;
            IArbitrator arbitrator = arbitratorRegistry.arbitrator(arbitratorId);
            uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
            requests[requestsCounter] =
                Request(
                    ReqType.Burn,
                    tokenId,
                    dst,
                    0,
                    Status.Disputed,
                    arbitrator,
                    disputeId);
            tokenToRequest[tokenId] = requestsCounter;
            disputeToRequest[disputeId] = requestsCounter;
            emit BurnArbitrateAsked(requestsCounter, disputeId, dst, tokenId, extraData, address(arbitrator));
        }
    }

    function _burn(address dst, uint256 tokenId) internal
    {
        super._burn(tokenId);
        Original memory token = tokens[tokenId];
        if(token.standard == Standard.ERC721)
        {
            token.contr721.safeTransferFrom(address(this), dst, token.tokenId);
        }
        else if(token.standard == Standard.ERC1155)
        {
            token.contr1155.safeTransferFrom(address(this), dst, token.tokenId, token.amount, '');
        }
        else // ERC20
        {
            token.contr20.transfer(dst, token.amount);
        }
        delete tokens[tokenId];
        delete requests[tokenToRequest[tokenId]];
        emit Unwrapped(dst, tokenId);
    }

    function _hasRequest(uint256 tokenId) internal view returns(bool)
    {
        uint256 requestId = tokenToRequest[tokenId];
        if (requestId != 0)
        {
            Request memory request = requests[requestId];
            return (request.timeout < block.timestamp &&
                request.status == Status.Initial) ||
                request.status == Status.Disputed;
        }
        return false;
    }

    /** @dev Transfer ownerhip for `tokenId` to the owner of wrapped token. Must
     *  be called by the current owner of `tokenId`.
     */
    function adjustOwnership(uint256 tokenId, bytes calldata extraData, uint256 arbitratorId) public payable
    {
        require(!_hasRequest(tokenId), "NFTProtect: have request");
        require(isOriginalOwner(tokenId, _msgSender()), "NFTProtect: not owner");
        Original storage token = tokens[tokenId];
        if(token.level == Security.Basic)
        {
            token.owner = ownerOf(tokenId);
            emit OwnershipAdjusted(token.owner, _msgSender(), tokenId);
            if (burnOnAction)
            {
                _burn(token.owner, tokenId);
            }
        }
        else
        {
            requestsCounter++;
            IArbitrator arbitrator = arbitratorRegistry.arbitrator(arbitratorId);
            uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
            requests[requestsCounter] =
                Request(
                    ReqType.OwnershipAdjustment,
                    tokenId,
                    ownerOf(tokenId),
                    0,
                    Status.Disputed,
                    arbitrator,
                    disputeId);
            tokenToRequest[tokenId] = requestsCounter;
            disputeToRequest[disputeId] = requestsCounter;
            emit OwnershipAdjustmentArbitrateAsked(requestsCounter, disputeId, ownerOf(tokenId), tokenId, extraData, address(arbitrator));
        }
    }

    /**
     * @dev Create request for ownership adjustment for `tokenId`. It requires
     * when somebody got ownership of wrapped token. Owner of original token
     * must confirm or reject ownership transfer by calling answerOwnershipAdjustment().
     */
    function askOwnershipAdjustment(uint256 tokenId, address dst, uint256 arbitratorId) public 
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: not owner");
        require(!_hasRequest(tokenId), "NFTProtect: have request");
        require(!isOriginalOwner(tokenId, _msgSender()), "NFTProtect: already owner");
        requestsCounter++;
        Original storage token = tokens[tokenId];
        if (token.level == Security.Ultra)
        {
            require(dst != address(0) && dst != _msgSender(), "NFTProtect: invalid destination");
        }
        address newowner = dst == address(0) ? _msgSender() : dst;
        IArbitrator arbitrator = arbitratorRegistry.arbitrator(arbitratorId);
        require(address(arbitrator) != address(0), "NFTProtect: no arbitrator");
        requests[requestsCounter] =
            Request(
                ReqType.OwnershipAdjustment,
                tokenId,
                newowner,
                block.timestamp + duration,
                Status.Initial,
                arbitrator,
                0);
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipAdjustmentAsked(requestsCounter, newowner, token.owner, tokenId, address(arbitrator));
    }

    /**
     * @dev Must be called by the owner of the original token to confirm or reject
     * ownership transfer to the new owner of the wrapped token.
     */
    function answerOwnershipAdjustment(uint256 requestId, bool accept, bytes calldata extraData) public payable
    {
        Request storage request = requests[requestId];
        require(request.status == Status.Initial, "NFTProtect: answered");
        require(request.timeout > block.timestamp, "NFTProtect: timeout");
        Original storage token = tokens[request.tokenId];
        require(isOriginalOwner(request.tokenId, _msgSender()), "NFTProtect: not owner");
        if (accept)
        {
            if (token.level == Security.Basic)
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
                request.disputeId = request.arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
                request.status = Status.Disputed;
                disputeToRequest[request.disputeId] = requestId;
                emit OwnershipAdjustmentArbitrateAsked(requestId, request.disputeId, request.newowner, request.tokenId, extraData, address(request.arbitrator));
            }
        }
        else
        {
            request.status = Status.Rejected;
            emit OwnershipAdjustmentAnswered(requestId, accept);
        }
    }

    /**
     * @dev Can be called by the owner of the wrapped token if owner of
     * the original token didn't answer or rejected ownership transfer.
     * This function create dispute on external ERC-792 compatible arbitrator.
     */
    function askOwnershipAdjustmentArbitrate(uint256 requestId, bytes calldata extraData) public payable
    {
        Request storage request = requests[requestId];
        require(request.timeout > 0, "NFTProtect: unknown request");
        require(request.timeout <= block.timestamp, "NFTProtect: wait for answer");
        require(request.status == Status.Initial || request.status == Status.Rejected, "NFTProtect: wrong status");
        require(_isApprovedOrOwner(_msgSender(), request.tokenId), "NFTProtect: not owner");
        request.disputeId = request.arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
        request.status = Status.Disputed;
        disputeToRequest[request.disputeId] = requestId;
        emit OwnershipAdjustmentArbitrateAsked(requestId, request.disputeId, request.newowner, request.tokenId, extraData, address(request.arbitrator));
    }

    function ownershipAdjustmentAppeal(uint256 requestId, bytes calldata extraData) public payable
    {
        Request storage request = requests[requestId];
        require(request.timeout > 0, "NFTProtect: unknown requestId");
        require(request.status == Status.Disputed, "NFTProtect: wrong status");
        require(_isApprovedOrOwner(_msgSender(), request.tokenId), "NFTProtect: not owner");
        request.arbitrator.appeal{value: msg.value}(request.disputeId, extraData);
        emit OwnershipAdjustmentAppealed(requestId, extraData);
    }

    /**
     * @dev Create request for original ownership wrapped to `tokenId`. Can be called
     * by owner of original token if he or she lost access to wrapped token or it was stolen.
     * This function create dispute on external ERC-792 compatible arbitrator.
     */
    function askOwnershipRestoreArbitrate(uint256 tokenId, bytes calldata extraData, address dst, uint256 arbitratorId) public payable
    {
        require(!_hasRequest(tokenId), "NFTProtect: have request");
        require(isOriginalOwner(tokenId, _msgSender()), "NFTProtect: not owner");
        require(_exists(tokenId), "NFTProtect: nonexistent token");
        require(!_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: already owner");
        IArbitrator arbitrator = arbitratorRegistry.arbitrator(arbitratorId);
        uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
        if (tokens[tokenId].level == Security.Ultra)
        {
            require(dst != address(0) && dst != _msgSender(), "NFTProtect: bad dst");
        }
        requests[++requestsCounter] =
            Request(
                ReqType.OwnershipRestore,
                tokenId,
                dst == address(0) ? _msgSender() : dst,
                0,
                Status.Disputed,
                arbitrator,
                disputeId);
        disputeToRequest[disputeId] = requestsCounter;
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipRestoreAsked(requestsCounter, _msgSender(), ownerOf(tokenId), tokenId, address(arbitrator));
    }

    function ownershipRestoreAppeal(uint256 requestId, bytes calldata extraData) public payable
    {
        Request storage request = requests[requestId];
        require(request.reqtype == ReqType.OwnershipRestore, "NFTProtect: invalid request");
        require(request.status == Status.Disputed, "NFTProtect: wrong status");
        require(isOriginalOwner(request.tokenId, _msgSender()), "NFTProtect: not owner");
        request.arbitrator.appeal{value: msg.value}(request.disputeId, extraData);
        emit OwnershipRestoreAppealed(requestId, extraData);
    }

    /**
     * @dev Callback function from external arbitrator. The meaning of `ruling`
     * value is: 0 - RefusedToArbitrate, 1 - Accepted, 2 - Rejected.
     */
    function rule(uint256 disputeId, uint256 ruling) external override
    {
        require(ruling <= numberOfRulingOptions, "NFTProtect: invalid ruling");
        uint256 requestId = disputeToRequest[disputeId];
        require(requestId > 0, "NFTProtect: unknown requestId");
        Request storage request = requests[requestId];
        require(_msgSender() == address(request.arbitrator), "NFTProtect: not arbitrator");
        bool accept = ruling == 1;
        request.status = accept ? Status.Accepted : Status.Rejected;
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
            if (burnOnAction || request.reqtype == ReqType.Burn)
            {
                _burn(request.newowner, request.tokenId);
            }
        }
        emit Ruling(request.arbitrator, disputeId, ruling);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool)
    {
        return (userRegistry.hasSuccessor(spender)) ?
            false :
            super._isApprovedOrOwner(spender, tokenId) ?
                true :
                userRegistry.isSuccessor(ownerOf(tokenId), spender);
    }

    function _beforeTokenTransfer(address /*from*/, address to, uint256 tokenId) internal view override
    {
        require(userRegistry.isRegistered(to), "NFTProtect: unregistered user");
        require(!_hasRequest(tokenId), "NFTProtect: under dispute");
    }
}
