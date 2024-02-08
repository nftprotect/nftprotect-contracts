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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract NFTPCoupons is Ownable, ERC20
{
    event Deployed();
    event TransferrableSet(bool state);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event BurnerAdded(address indexed burner);
    event BurnerRemoved(address indexed burner);
    
    bool    public transferrable;
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;

    constructor() ERC20("NFT Protect Coupons", "NFTPC")
    {
        emit Deployed();
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

    function mint(address account, uint256 amount) public
    {
        require(minters[_msgSender()], "NFTPCoupons: incorrect minter");
        _mint(account, amount);
    }

    function addMinter(address _minter) public onlyOwner {
        require(!minters[_minter], "NFTPCoupons: already added");
        _addMinter(_minter);
    }

    function removeMinter(address _minter) public onlyOwner {
        _removeMinter(_minter);
    }

    function addBurner(address _burner) public onlyOwner {
        require(!burners[_burner], "NFTPCoupons: already added");
        _addBurner(_burner);
    }

    function removeBurner(address _burner) public onlyOwner {
        _removeBurner(_burner);
    }

    function burnFrom(address account, uint256 amount) public
    {
        require(burners[_msgSender()], "NFTPCoupons: forbidden call");
        _burn(account, amount);
    }

    function _addMinter(address _minter) internal {
        require(_minter != address(0), "NFTPCoupons: incorrect address");
        if (!minters[_minter]) {
            minters[_minter] = true;
            emit MinterAdded(_minter);
        }
    }

    function _removeMinter(address _minter) internal {
        require(minters[_minter], "NFTPCoupons: not a minter");
        delete minters[_minter];
        emit MinterRemoved(_minter);
    }

    function _addBurner(address _burner) internal {
        require(_burner != address(0), "NFTPCoupons: incorrect address");
        if (!burners[_burner]) {
            burners[_burner] = true;
            emit BurnerAdded(_burner);
        }
    }

    function _removeBurner(address _burner) internal {
        require(burners[_burner], "NFTPCoupons: not a minter");
        delete burners[_burner];
        emit BurnerRemoved(_burner);
    }

    function _beforeTokenTransfer(address from, address to, uint256 /*amount*/) internal view override
    {
        require(transferrable || from == address(0) || to == address(0), "NFTPCoupons: non-transferrable");
    }
}
