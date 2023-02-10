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
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrator.sol";
import "github.com/kleros/erc-792/blob/v8.0.0/contracts/IArbitrable.sol";
import "./iuserregistry.sol";
import "./nftpcoupons.sol";


contract NFTProtect is ERC721, IERC721Receiver, IERC1155Receiver, IArbitrable, Ownable, ReentrancyGuard
{
    using Address for address payable;

    event Deployed();
    event FeeChanged(Security indexed level, uint256 feeWei);
    event ArbitratorChanged(address arbitrator);
    event UserRegistryChanged(address ureg);
    event BurnOnActionChanged(bool boa);
    event BaseChanged(string base);
    event ScoreThresholdChanged(uint256 threshold);
    event AffiliatePercentChanged(uint256 userPercent, uint256 partnerPercent);
    event Wrapped721(address indexed owner, address contr, uint256 tokenIdOrig, uint256 indexed tokenId, Security level);
    event Wrapped1155(address indexed owner, address contr, uint256 tokenIdOrig, uint256 indexed tokenId, uint256 amount, Security level);
    event Wrapped20(address indexed owner, address contr, uint256 indexed tokenId, uint256 amount, Security level);
    event Unwrapped(address indexed owner, uint256 indexed tokenId);
    event AffiliatePayment(address indexed from, address indexed to, uint256 amountWei);
    event ReferrerSet(address indexed user, address indexed referrer);
    event PartnerSet(address indexed partnet, bool state);
    event BurnArbitrateAsked(uint256 indexed requestId, uint256 indexed disputeId, bytes extraData);
    event OwnershipAdjusted(address indexed newowner, address indexed oldowner, uint256 tokenId);
    event OwnershipAdjustmentAsked(uint256 indexed requestId, address indexed newowner, address indexed oldowner, uint256 tokenId);
    event OwnershipAdjustmentAnswered(uint256 indexed requestId, bool accept);
    event OwnershipAdjustmentArbitrateAsked(uint256 indexed requestId, uint256 indexed disputeId, bytes extraData);
    event OwnershipAdjustmentAppealed(uint256 indexed requestId, bytes extraData);
    event OwnershipRestoreAsked(uint256 indexed requestId, address indexed newowner, address indexed oldowner, uint256 tokenId);
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
        ReqType reqtype; 
        uint256 tokenId;
        address newowner;
        uint256 timeout;
        Status  status;
        uint256 disputeId;
    }
    mapping(uint256 => Request) public requests;
    mapping(uint256 => uint256) public tokenToRequest;
    mapping(uint256 => uint256) public disputeToRequest;
    
    uint256       constant duration = 2 days;
    uint256       constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate

    mapping(Security => uint256) public feeWei;
    uint256       public   tokensCounter;
    uint256       public   requestsCounter;
    IArbitrator   public   arbitrator;
    IUserRegistry public   userRegistry;
    bool          public   burnOnAction;
    string        public   base;
    uint256       public   affiliateUserPercent;
    uint256       public   affiliatePartnerPercent;
    uint256       public   scoreThreshold;
    NFTPCoupons   public   coupons;

    mapping(address => address payable) public referrers;
    mapping(address => bool)            public partners;

    uint256       internal allow;

    constructor(address arb, address ureg) ERC721("NFT Protect", "wNFT")
    {
        emit Deployed();
        setFee(Security.Basic, 0);
        setFee(Security.Ultra, 0);
        setArbitrator(arb);
        setUserRegistry(ureg);
        setBurnOnAction(true);
        setAffiliatePercent(10, 20);
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

    function setArbitrator(address arb) public onlyOwner
    {
        arbitrator = IArbitrator(arb);
        emit ArbitratorChanged(arb);
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

    function setAffiliatePercent(uint256 userPercent, uint256 partnerPercent) public onlyOwner
    {
        affiliateUserPercent = userPercent;
        affiliatePartnerPercent = partnerPercent;
        emit AffiliatePercentChanged(userPercent, partnerPercent);
    }

    function setScoreThreshold(uint256 threshold) public onlyOwner
    {
        scoreThreshold = threshold;
        emit ScoreThresholdChanged(threshold);
    }

    function setPartner(address partner, bool state) public onlyOwner
    {
        partners[partner] = state;
        emit PartnerSet(partner, state);
    }

    /**
     * @dev Accept only tokens which internally allowed by `allow` property
     */
    function onERC721Received(address /*operator*/, address /*from*/, uint256 /*tokenId*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow == 1, "NFTProtect: illegal transfer");
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address /*operator*/, address /*from*/, uint256 /*id*/, uint256 /*value*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow == 1, "NFTProtect: illegal transfer");
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address /*operator*/, address /*from*/, uint256[] calldata /*ids*/, uint256[] calldata /*values*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(allow == 1, "NFTProtect: illegal transfer");
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for original
     * token, wrapped in `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory)
    {
        require(_exists(tokenId), "NFTProtect: URI query for nonexistent token");
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
        require(level == Security.Basic || userRegistry.scores(_msgSender()) >= scoreThreshold, "NFT Protect: not enough scores for this level of security");
        require(userRegistry.isRegistered(_msgSender()), "NFTProtect: user must be registered");
        uint256 value = msg.value;
        if (coupons.balanceOf(_msgSender()) > 0)
        {
            coupons.burnFrom(_msgSender(), 1);
        }
        else
        {
            require(value == feeWei[level], "NFTProtect: wrong payment");
            if(referrers[_msgSender()] == address(0) && referrer != address(0))
            {
                referrers[_msgSender()] = referrer;
                emit ReferrerSet(_msgSender(), referrer);
            }
            referrer = referrers[_msgSender()];
            if (referrer != address(0))
            {
                require(referrer != _msgSender(), "NFTProtect: invalid referrer");
                uint256 percent = partners[referrer] ? affiliatePartnerPercent : affiliateUserPercent;
                uint256 reward = value * percent / 100;
                if (reward > 0)
                {
                    value -= reward;
                    referrer.sendValue(reward);
                    emit AffiliatePayment(_msgSender(), referrer, reward);
                }
            }
            if (value > 0)
            {
                payable(owner()).sendValue(value);
            }
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
    function burn(uint256 tokenId, bytes calldata extraData) public payable
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: not the owner");
        require(isOriginalOwner(tokenId, _msgSender()), "NFTProtect: need to askOwnershipAdjustment first");
        if(tokens[tokenId].level == Security.Basic)
        {
            _burn(_msgSender(), tokenId);
        }
        else
        {
            requestsCounter++;
            uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
            requests[requestsCounter] =
                Request(
                    ReqType.Burn,
                    tokenId,
                    _msgSender(),
                    0,
                    Status.Disputed,
                    disputeId);
            tokenToRequest[tokenId] = requestsCounter;
            disputeToRequest[disputeId] = requestsCounter;
            emit BurnArbitrateAsked(requestsCounter, disputeId, extraData);
        }
    }

    function _burn(address owner, uint256 tokenId) internal
    {
        super._burn(tokenId);
        Original memory token = tokens[tokenId];
        if(token.standard == Standard.ERC721)
        {
            token.contr721.safeTransferFrom(address(this), owner, token.tokenId);
        }
        else if(token.standard == Standard.ERC1155)
        {
            token.contr1155.safeTransferFrom(address(this), owner, token.tokenId, token.amount, '');
        }
        else // ERC20
        {
            token.contr20.transfer(owner, token.amount);
        }
        delete tokens[tokenId];
        delete requests[tokenToRequest[tokenId]];
        emit Unwrapped(owner, tokenId);
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
    function adjustOwnership(uint256 tokenId, bytes calldata extraData) public payable
    {
        require(!_hasRequest(tokenId), "NFTProtect: already have request");
        require(isOriginalOwner(tokenId, _msgSender()), "NFTProtect: not the original owner");
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
            uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
            requests[requestsCounter] =
                Request(
                    ReqType.OwnershipAdjustment,
                    tokenId,
                    ownerOf(tokenId),
                    0,
                    Status.Disputed,
                    disputeId);
            tokenToRequest[tokenId] = requestsCounter;
            disputeToRequest[disputeId] = requestsCounter;
            emit OwnershipAdjustmentArbitrateAsked(requestsCounter, disputeId, extraData);
        }
    }

    /**
     * @dev Create request for ownership adjustment for `tokenId`. It requires
     * when somebody got ownership of wrapped token. Owner of original token
     * must confirm or reject ownership transfer by calling answerOwnershipAdjustment().
     */
    function askOwnershipAdjustment(uint256 tokenId) public 
    {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: not the owner");
        require(!_hasRequest(tokenId), "NFTProtect: already have request");
        require(!isOriginalOwner(tokenId, _msgSender()), "NFTProtect: already owner");
        requestsCounter++;
        Original storage token = tokens[tokenId];
        requests[requestsCounter] =
            Request(
                ReqType.OwnershipAdjustment,
                tokenId,
                _msgSender(),
                block.timestamp + duration,
                Status.Initial,
                0);
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipAdjustmentAsked(requestsCounter, _msgSender(), token.owner, tokenId);
    }

    /**
     * @dev Must be called by the owner of the original token to confirm or reject
     * ownership transfer to the new owner of the wrapped token.
     */
    function answerOwnershipAdjustment(uint256 requestId, bool accept, bytes calldata extraData) public payable
    {
        Request storage request = requests[requestId];
        require(request.status == Status.Initial, "NFTProtect: already answered");
        require(request.timeout > block.timestamp, "NFTProtect: timeout");
        Original storage token = tokens[request.tokenId];
        require(isOriginalOwner(request.tokenId, _msgSender()), "NFTProtect: not the original owner");
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
                request.disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
                request.status = Status.Disputed;
                disputeToRequest[request.disputeId] = requestId;
                emit OwnershipAdjustmentArbitrateAsked(requestId, request.disputeId, extraData);
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
        require(request.timeout > 0, "NFTProtect: unknown requestId");
        require(request.timeout <= block.timestamp, "NFTProtect: wait for answer more");
        require(request.status == Status.Initial || request.status == Status.Rejected, "NFTProtect: wrong status");
        require(_isApprovedOrOwner(_msgSender(), request.tokenId), "NFTProtect: not the owner");
        request.disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
        request.status = Status.Disputed;
        disputeToRequest[request.disputeId] = requestId;
        emit OwnershipAdjustmentArbitrateAsked(requestId, request.disputeId, extraData);
    }

    function ownershipAdjustmentAppeal(uint256 requestId, bytes calldata extraData) public payable
    {
        Request storage request = requests[requestId];
        require(request.timeout > 0, "NFTProtect: unknown requestId");
        require(request.status == Status.Disputed, "NFTProtect: wrong status");
        require(_isApprovedOrOwner(_msgSender(), request.tokenId), "NFTProtect: not the owner");
        arbitrator.appeal{value: msg.value}(request.disputeId, extraData);
        emit OwnershipAdjustmentAppealed(requestId, extraData);
    }

    /**
     * @dev Create request for original ownership wrapped to `tokenId`. Can be called
     * by owner of original token if he or she lost access to wrapped token or it was stolen.
     * This function create dispute on external ERC-792 compatible arbitrator.
     */
    function askOwnershipRestoreArbitrate(uint256 tokenId, bytes calldata extraData) public payable
    {
        require(!_hasRequest(tokenId), "NFTProtect: already have request");
        require(isOriginalOwner(tokenId, _msgSender()), "NFTProtect: not the owner of the original token");
        require(_exists(tokenId), "NFTProtect: nonexistent token");
        require(!_isApprovedOrOwner(_msgSender(), tokenId), "NFTProtect: already owner");
        uint256 disputeId = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, extraData);
        requests[++requestsCounter] =
            Request(
                ReqType.OwnershipRestore,
                tokenId,
                _msgSender(),
                0,
                Status.Disputed,
                disputeId);
        disputeToRequest[disputeId] = requestsCounter;
        tokenToRequest[tokenId] = requestsCounter;
        emit OwnershipRestoreAsked(requestsCounter, _msgSender(), ownerOf(tokenId), tokenId);
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
        Request storage request = requests[requestId];
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
        emit Ruling(arbitrator, disputeId, ruling);
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
        require(userRegistry.isRegistered(to), "NFTProtect: user must be registered");
        require(!_hasRequest(tokenId), "NFTProtect: can't transfer token under dispute");
    }
}
