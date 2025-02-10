// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";

import {Paymaster} from "src/Paymaster.sol";

import {EntryPoint} from "account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";

import {SimpleAccount} from "simple-account/src/SimpleAccount.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract PaymasterIntegration is Test {
    EntryPoint private s_entryPoint;
    SimpleAccount private s_simpleAccount;
    Paymaster private s_paymaster;
    Account private s_accountOwner;
    Account private s_paymasterOwner;
    address private s_receiver;
    address private s_bundler;

    function setUp() public {
        s_receiver = makeAddr("s_receiver");
        s_bundler = makeAddr("s_bundler");

        s_entryPoint = new EntryPoint();
        s_accountOwner = makeAccount("s_accountOwner");
        s_paymasterOwner = makeAccount("s_paymasterOwner");

        s_simpleAccount = new SimpleAccount(s_entryPoint, s_accountOwner.addr);
        vm.prank(s_paymasterOwner.addr);
        s_paymaster = new Paymaster(s_entryPoint);

        // set deposit for paymaster on entryPoint
        s_entryPoint.depositTo{value: 1 ether}(address(s_paymaster));
    }

    function testSuccessfulUserOpExecOnValidPaymasterSignature() public {
        // create userOp
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(s_simpleAccount),
            nonce: 0,
            initCode: hex"",
            callData: abi.encodeWithSelector(SimpleAccount.execute.selector, s_receiver, 1 ether, hex""),
            accountGasLimits: bytes32(uint256(100_000) << 128 | uint256(100_000)),
            preVerificationGas: 0,
            gasFees: bytes32(uint256(0) << 128 | uint256(0)),
            paymasterAndData: hex"",
            signature: hex""
        });

        // create message for paymaster signature
        string memory message = string.concat(
            "Approved paymaster request for ",
            Strings.toHexString(userOp.sender),
            " with ",
            Strings.toString(userOp.nonce),
            " on chain ID ",
            Strings.toString(block.chainid)
        );

        // get signature components & encode signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(s_paymasterOwner.key, keccak256(abi.encodePacked(message)));

        // create paymasterAndData field & add it to userOp
        userOp.paymasterAndData = abi.encodePacked(
            address(s_paymaster), bytes32(uint256(100_000) << 128 | uint256(100_000)), abi.encodePacked(r, s, v)
        );

        // get hash of userOp
        bytes32 userOpHash = s_entryPoint.getUserOpHash(userOp);

        // get signature components & add signature to userOp
        (v, r, s) = vm.sign(s_accountOwner.key, userOpHash);

        userOp.signature = abi.encodePacked(r, s, v);

        // create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // check for correct event with correct paramters
        vm.expectEmit(true, true, true, false, address(s_entryPoint));
        emit IEntryPoint.UserOperationEvent(userOpHash, address(s_simpleAccount), address(s_paymaster), 0, false, 0, 0);
        // call handleOps
        s_entryPoint.handleOps(userOps, payable(s_bundler));
    }

    function testUserOpRevertsOnInalidPaymasterSignature() public {
        Account memory unauthorizedAccount = makeAccount("unauthorizedAccount");

        // create userOp
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(s_simpleAccount),
            nonce: 0,
            initCode: hex"",
            callData: abi.encodeWithSelector(SimpleAccount.execute.selector, s_receiver, 1 ether, hex""),
            accountGasLimits: bytes32(uint256(100_000) << 128 | uint256(100_000)),
            preVerificationGas: 0,
            gasFees: bytes32(uint256(0) << 128 | uint256(0)),
            paymasterAndData: hex"",
            signature: hex""
        });

        // create message for paymaster signature
        string memory message = string.concat(
            "Approved paymaster request for ",
            Strings.toHexString(userOp.sender),
            " with ",
            Strings.toString(userOp.nonce),
            " on chain ID ",
            Strings.toString(block.chainid)
        );

        // get signature components & encode signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedAccount.key, keccak256(abi.encodePacked(message)));

        // create paymasterAndData field & add it to userOp
        userOp.paymasterAndData = abi.encodePacked(
            address(s_paymaster), bytes32(uint256(100_000) << 128 | uint256(100_000)), abi.encodePacked(r, s, v)
        );

        // get hash of userOp
        bytes32 userOpHash = s_entryPoint.getUserOpHash(userOp);

        // get signature components & add signature to userOp
        (v, r, s) = vm.sign(s_accountOwner.key, userOpHash);

        userOp.signature = abi.encodePacked(r, s, v);

        // create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // check for correct event with correct paramters
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA34 signature error"));
        // call handleOps
        s_entryPoint.handleOps(userOps, payable(s_bundler));
    }
}
