/*
This file is part of the NFT Protect project <https://nftprotect.app/>

The NFTPCoupons Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The NFTPCoupons Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the NFTPCoupons Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <is.svirin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License


pragma solidity ^0.8.0;

import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract NFTPCoupons is Ownable, ERC20
{
    event Deployed();
    event TransferrableSet(bool state);
    
    bool    public transferrable;
    address public nftprotect;

    constructor(address nftp) ERC20("NFT Protect Coupons", "NFTPC")
    {
        emit Deployed();
        nftprotect = nftp;
        setTransferrable(true);
    }

    function decimals() public view virtual override returns (uint8)
    {
        return 0;
    }

    function setTransferrable(bool state) public onlyOwner
    {
        transferrable = state;
        emit TransferrableSet(state);        
    }

    function mint(address account, uint256 amount) public onlyOwner
    {
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) public
    {
        require(_msgSender() == nftprotect, "NFTPCoupons: forbidden call");
        _burn(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 /*amount*/) internal view override
    {
        require(transferrable || from == address(0) || to == address(0), "NFTPCoupons: non-transferrable");
    }
}
