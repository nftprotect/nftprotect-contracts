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

@author Oleg Dubinkin <odubinkin@gmail.com>
*/
// SPDX-License-Identifier: GNU lesser General Public License

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";


/// @title Signature Verifier for NFT Protect
/// @notice This contract provides functions to verify off-chain signatures for NFT transactions.
/// @dev This contract uses EIP-712 standard for typed structured data hashing and signing.
contract SignatureVerifier is Ownable {
    error InvalidSignatureLength();
    error InvalidSignatureValue();

    // EIP-712 Domain Separator
    bytes32 public DOMAIN_SEPARATOR;

    // EIP-712 Message TypeHash
    bytes32 public constant MESSAGE_TYPEHASH = keccak256(
        "Message(string text,uint256 tokenId,address newOwner,uint256 nonce)"
    );

    string constant MESSAGE_TEXT = "WARNING! READ CAREFULLY!\nBy signing this message, you agree to withdraw your original NFT from the NFT Protect protocol. Access to it will no longer be recoverable through NFT Protect!\n";
    bytes32 public constant MESSAGE_TEXT_HASH = keccak256(bytes(MESSAGE_TEXT));

    constructor() Ownable(_msgSender()) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("NFTProtect"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Calculates the EIP-712 hash of the message that needs to be signed by the user.
    /// @param tokenId The ID of the token being transferred.
    /// @param newOwner The new owner's address to which the token will be transferred.
    /// @param nonce A nonce to ensure the hash is unique for each transaction.
    /// @return The calculated message hash.
    function getMessageHash(
        uint256 tokenId,
        address newOwner,
        uint256 nonce
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                MESSAGE_TYPEHASH,
                MESSAGE_TEXT_HASH,
                tokenId,
                newOwner,
                nonce
            )
        );

        return keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
    }

    /// @notice Returns the warning message template used in the message hash.
    /// @return The warning message template.
    function getMessageText() public pure returns (string memory) {
        return MESSAGE_TEXT;
    }

    /// @notice Verifies if a signature is valid and was signed by the current owner of the token.
    /// @param tokenId The ID of the token being transferred.
    /// @param currentOwner The current owner's address of the token.
    /// @param newOwner The new owner's address to which the token will be transferred.
    /// @param nonce A nonce to ensure the hash is unique for each transaction.
    /// @param signature The signature to verify.
    /// @return True if the recovered address from the signature matches the current owner's address, otherwise false.
    function verify(
        uint256 tokenId,
        address currentOwner,
        address newOwner,
        uint256 nonce,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 messageHash = getMessageHash(tokenId, newOwner, nonce);
        address recovered = recoverSigner(messageHash, signature);
        return recovered == currentOwner;
    }

    /// @notice Splits a signature into its components: r, s, and v.
    /// @dev The signature must be in the [r || s || v] format where each component is a fixed size.
    ///      This function uses inline assembly for efficient extraction of these components.
    /// @param _signature The signature to split.
    /// @return v The recovery byte, either 27 or 28.
    /// @return r The first 32 bytes of the signature.
    /// @return s The second 32 bytes of the signature.
    function splitSignature(bytes memory _signature)
        internal
        pure
        returns (uint8, bytes32, bytes32)
    {
        if (_signature.length != 65) {
            revert InvalidSignatureLength();
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        // The signature is expected to be in the following format:
        // {bytes32 r}{bytes32 s}{uint8 v}
        // where 'v' is the recovery id, 'r' and 's' are the two parts of the signature.

        assembly {
            // first 32 bytes after the length prefix
            r := mload(add(_signature, 32))
            // second 32 bytes
            s := mload(add(_signature, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_signature, 96)))
        }

        // Version of signature should be 27 or 28
        if (v < 27) {
            v += 27;
        }

        return (v, r, s);
    }

    /// @notice Recovers the signer address from a given hash and signature.
    /// @dev Uses the ECDSA algorithm for signature recovery, which is a part of Ethereum's protocol.
    /// @param _ethSignedMessageHash The hash of the signed message, prefixed with the Ethereum Signed Message string.
    /// @param _signature The signature to recover the signer from.
    /// @return The address of the signer that produced the given signature.
    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        internal
        pure
        returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(_signature);

        // Ensure that 'v' is 27 or 28
        if (v != 27 && v != 28) {
            revert InvalidSignatureValue();
        }

        // Perform the ecrecover operation to recover the address from the signature
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }
}