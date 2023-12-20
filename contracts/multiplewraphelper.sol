/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The MultipleProtectHelper Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The MultipleProtectHelper Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the MultipleProtectHelper Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

import "./nftprotect.sol";
import "./iuserregistry.sol";


contract MultipleProtectHelper is Context, IERC721Receiver, IERC1155Receiver
{
    NFTProtect public   nftprotect;
    IUserRegistry public userRegistry;
    uint256    internal allow;

    constructor(NFTProtect p)
    {
        nftprotect = p;
        userRegistry = IUserRegistry(address(p.userRegistry()));
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

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function protect721(
        ERC721 contr,
        uint256[] memory tokensId,
        IUserRegistry.Security level,
        address payable referrer) public payable
    {
        uint256 feeWei = userRegistry.feeForUser(msg.sender, level);
        require(msg.value == feeWei*tokensId.length, "MultipleProtectHelper: invalid value");
        allow = 1;
        for(uint256 i = 0; i < tokensId.length; i++)
        {
            contr.safeTransferFrom(_msgSender(), address(this), tokensId[i]);
            contr.approve(address(nftprotect), tokensId[i]);
            uint256 pNFT = nftprotect.protect{value: feeWei}(
                NFTProtect.Standard.ERC721,
                address(contr),
                tokensId[i],
                1,
                level,
                referrer);
            nftprotect.transferFrom(address(this), _msgSender(), pNFT);
        }
        allow = 0;
    }

    function protect1155(
        ERC1155 contr,
        uint256[] memory tokensId,
        uint256[] memory amounts,
        IUserRegistry.Security level,
        address payable referrer) public payable
    {
        uint256 feeWei = userRegistry.feeForUser(msg.sender, level);
        require(msg.value == feeWei*tokensId.length, "MultipleProtectHelper: invalid value");
        require(tokensId.length == amounts.length, "MultipleProtectHelper: wrong inputs");
        allow = 1;
        for(uint256 i = 0; i < tokensId.length; i++)
        {
            contr.safeTransferFrom(_msgSender(), address(this), tokensId[i], amounts[i], '');
            contr.setApprovalForAll(address(nftprotect), true);
            uint256 pNFT = nftprotect.protect{value: feeWei}(
                NFTProtect.Standard.ERC1155,
                address(contr),
                tokensId[i],
                amounts[i],
                level,
                referrer);
            nftprotect.transferFrom(address(this), _msgSender(), pNFT);
        }
        allow = 0;
    }
}
