# ERC4337 Simple Paymaster

This repository provides an ERC4337-compatible paymaster built with Foundry. The paymaster allows users to execute transactions without paying for validation and execution themselves.

## Key Features

- Extends `BasePaymaster` from `account-abstraction`.
- Uses ECDSA signatures to verify that the paymaster should cover the cost of a transaction.
- Includes unit and integration tests with 100% coverage.

## Installation

Make sure Foundry is installed on your system. If not, check Foundry's documentation for installation steps.

Clone the repository:
```bash
git clone git@github.com:nikbhintade/erc4337-simple-paymaster.git
cd erc4337-simple-paymaster
```

Install dependencies with Soldeer:
```bash
forge soldeer install
```

Build the project:
```bash
forge build
```

Run all tests:
```bash
forge test -vvv
```

## Paymaster Contract Overview

The `Paymaster.sol` contract extends `BasePaymaster` and follows the `IPaymaster` interface defined in the ERC4337 specification. The interface specifies the functions required for a paymaster, while `BasePaymaster` provides basic functionality that must be customized.

A key function in our paymaster contract is `validatePaymasterUserOp`, which determines whether the paymaster will cover a transaction. This function tells the EntryPoint contract if the paymaster agrees to pay for a given operation.

The paymaster verifies this using a signature included in the `paymasterAndData` field of the user operation. The paymaster’s owner generates this signature by signing a hashed message with the following format:
```text
"Approved paymaster request for {Account Contract Address} with {Nonce of user operation} on chain ID {Chain ID of the network where user operation will be sent}"
```

If the signature is valid, the paymaster returns validation data indicating approval and vice versa.

The `validatePaymasterUserOp` function returns two values: `context` and `validationData`. In this project, only `validationData` is used, and `context` remains empty. `context` is only needed if the paymaster’s `postOp` function must be triggered, which is not required here.

## Interaction Between Account Contract, Paymaster, and EntryPoint Contract

The [ERC4337 specification](https://eips.ethereum.org/EIPS/eip-4337#extension-paymasters) explains the full process in detail. Below is a brief overview of how user operation validation and execution work:

![userOp flow with paymaster](/assets/userop-flow-with-paymaster.png)

## Contributions

Feedback and contributions are welcome. If you have suggestions for improvements, let me know.

-------

## Notes

Found out that ECDSA signatures are actually 65 bytes long, not 64 like the first Google result says. The OpenZeppelin docs explain this in more detail.  

Used Soldeer to add my own project as a dependency. First, I had to create a release for it, then install it using:  

```bash
forge soldeer install erc4337-simple-account~0.0.1 https://github.com/nikbhintade/erc4337-simple-account/archive/refs/tags/0.0.1.zip
```  

Had to update the remappings after that. Tried something new with Soldeer here. Also, the command didn’t work with a Git URL, so I had to use the zip file URL instead. Not sure why, but I’ll check later—just focusing on what works for now.