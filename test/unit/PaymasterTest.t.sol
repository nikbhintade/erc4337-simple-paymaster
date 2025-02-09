// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";

import {PaymasterHarness} from "test/harness/PaymasterHarness.sol";

import {EntryPoint} from "account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/contracts/core/Helpers.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract PaymasterTest is Test {
    PaymasterHarness private paymaster;
    EntryPoint private entryPoint;
    Account private owner;

    function setUp() public {
        owner = makeAccount("owner");
        entryPoint = new EntryPoint();

        vm.prank(owner.addr);
        paymaster = new PaymasterHarness(entryPoint);
    }

    function createUserOpAndData(Account memory paymasterOwner, address sender, uint256 nonce)
        internal
        returns (PackedUserOperation memory, bytes32, uint256)
    {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: hex"",
            accountGasLimits: hex"",
            preVerificationGas: 0,
            gasFees: hex"",
            paymasterAndData: hex"",
            signature: hex""
        });

        string memory message = string.concat(
            "Approved paymaster request for ",
            Strings.toHexString(userOp.sender),
            " with ",
            Strings.toString(userOp.nonce),
            " on chain ID ",
            Strings.toString(block.chainid)
        );

        bytes32 digest = keccak256(abi.encodePacked(message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(paymasterOwner.key, digest);

        userOp.paymasterAndData = abi.encodePacked(makeAddr("paymaster"), bytes32(hex""), abi.encodePacked(r, s, v));
        return (userOp, entryPoint.getUserOpHash(userOp), uint256(digest));
    }

    function testValidatePaymasterUserOpReturnsCorrectDataOnValidSignature() public {
        (PackedUserOperation memory userOp, bytes32 userOpHash, uint256 maxCost) =
            createUserOpAndData(owner, makeAddr("sender"), 0);

        (bytes memory context, uint256 validationData) =
            paymaster.expose_validatePaymasterUserOp(userOp, userOpHash, maxCost);

        assertEq(keccak256(context), keccak256(hex""));
        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    function testValidatePaymasterUserOpReturnsCorrectDataOnInvalidSignature() public {
        Account memory randomUser = makeAccount("randomUser");
        (PackedUserOperation memory userOp, bytes32 userOpHash, uint256 maxCost) =
            createUserOpAndData(randomUser, makeAddr("sender"), 0);

        (bytes memory context, uint256 validationData) =
            paymaster.expose_validatePaymasterUserOp(userOp, userOpHash, maxCost);

        assertEq(keccak256(context), keccak256(hex""));
        assertEq(validationData, SIG_VALIDATION_FAILED);
    }
}
