// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {console2 as console} from "forge-std/console2.sol";

import {BasePaymaster} from "account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/contracts/core/Helpers.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Paymaster is BasePaymaster {
    constructor(IEntryPoint entryPoint) BasePaymaster(entryPoint) {}

    /// @dev The `paymasterAndData` field follows this structure:
    /// @dev - Address
    /// @dev - Bytes32 (a combination of two uint256 values, each 16 bytes)
    /// @dev - Bytes (ECDSA signature from the owner)
    /// @dev The signature is generated using the hash of the following message:
    /// @dev "Approved paymaster request for {sender} with {nonce} on chain ID {chainId}"

    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        (userOpHash, maxCost);

        string memory message = string.concat(
            "Approved paymaster request for ",
            Strings.toHexString(userOp.sender),
            " with ",
            Strings.toString(userOp.nonce),
            " on chain ID ",
            Strings.toString(block.chainid)
        );

        // ECDSA signatures used here are 65 bytes long, please read following for more details
        // https://docs.openzeppelin.com/contracts/2.x/utilities#checking_signatures_on_chain
        if (bytes(userOp.paymasterAndData[52:]).length != 65) {
            return (hex"", SIG_VALIDATION_FAILED);
        }

        address signer = ECDSA.recover(keccak256(abi.encodePacked(message)), userOp.paymasterAndData[52:]);

        if (signer == owner()) {
            return (hex"", SIG_VALIDATION_SUCCESS);
        } else {
            return (hex"", SIG_VALIDATION_FAILED);
        }
    }
}
