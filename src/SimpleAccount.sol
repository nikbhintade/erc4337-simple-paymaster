// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {BaseAccount} from "account-abstraction/contracts/core/BaseAccount.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/contracts/core/Helpers.sol";
import {PackedUserOperation} from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleAccount is BaseAccount, Ownable {
    error SimpleAccount__callFailed(bytes data);

    IEntryPoint immutable i_entryPoint;

    constructor(IEntryPoint _entryPoint, address _owner) Ownable(_owner) {
        i_entryPoint = _entryPoint;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return i_entryPoint;
    }

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256 validationData)
    {
        address signer = ECDSA.recover(userOpHash, userOp.signature);
        if (owner() == signer) {
            return SIG_VALIDATION_SUCCESS;
        } else {
            return SIG_VALIDATION_FAILED;
        }
    }

    function execute(address dest, uint256 value, bytes calldata data) public {
        _requireFromEntryPoint();

        (bool success, bytes memory ret) = dest.call{value: value}(data);
        if (!success) {
            revert SimpleAccount__callFailed(ret);
        }
    }
}
