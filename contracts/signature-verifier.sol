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

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


/// @title Signature Verifier for NFT Protect
/// @notice This contract provides functions to verify off-chain signatures for NFT transactions.
/// @dev This contract uses EIP-712 standard for typed structured data hashing and signing.
contract SignatureVerifier is Ownable {
    // Warning message template used in the message hash
    string constant MESSAGE_TEXT = "WARNING! READ CAREFULLY!\n\
By signing this message, you agree to withdraw your original NFT from the NFT Protect protocol. Access to it will no longer be recoverable through NFT Protect!\n";

    /// @notice Calculates the hash of the message that needs to be signed by the user.
    /// @dev The hash is calculated using keccak256 over the concatenation of a constant message text and the transaction details.
    /// @param tokenId The ID of the token being transferred.
    /// @param currentOwner The current owner's address of the token.
    /// @param newOwner The new owner's address to which the token will be transferred.
    /// @param nonce A nonce to ensure the hash is unique for each transaction.
    /// @return The calculated message hash.
    function getMessageHash(
        uint256 tokenId,
        address currentOwner,
        address newOwner,
        uint256 nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(MESSAGE_TEXT, tokenId, currentOwner, newOwner, nonce));
    }

    /// @notice Returns the warning message template used in the message hash.
    /// @return The warning message template.
    function getMessageText() public pure returns (string memory) {
        return MESSAGE_TEXT;
    }

    /// @notice Wraps the message hash with the standard Ethereum Signed Message prefix.
    /// @dev This is used to prevent signature forgery on arbitrary messages.
    /// @param _messageHash The hash of the message that was signed.
    /// @return The hash of the message prefixed with the Ethereum Signed Message string.
    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
        );
    }

    /// @notice Verifies if a signature is valid and was signed by the current owner of the token.
    /// @dev It recovers the signer from the signature using the `ecrecover` function and compares it to the `currentOwner`.
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
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(tokenId, currentOwner, newOwner, nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        address recovered = recoverSigner(ethSignedMessageHash, signature);
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
        require(_signature.length == 65, "Invalid signature length");

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
            revert("Invalid signature 'v' value");
        }

        // Perform the ecrecover operation to recover the address from the signature
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }
}