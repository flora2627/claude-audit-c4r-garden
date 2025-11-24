# Garden audit details
- Total Prize Pool: $37,500 in USDC
  - HM awards: up to $33,600 in USDC
    - If no valid Highs are found, the HM pool is $6,720 in USDC
    - If no valid Highs or Mediums are found, the HM pool is $0 
  - QA awards: $1,400 in USDC
  - Judge awards: $2,000 in USDC
  - Scout awards: $500 in USDC
- [Read our guidelines for more details](https://docs.code4rena.com/competitions)
- Starts November 24, 2025 20:00 UTC
- Ends December 8, 2025 20:00 UTC

**❗ Important notes for wardens** 
1. Since this audit includes live/deployed code, **all submissions will be treated as sensitive**:
    - Wardens are encouraged to submit High-risk submissions affecting live code promptly, to ensure timely disclosure of such vulnerabilities to the sponsor and guarantee payout in the case where a sponsor patches a live critical during the audit.
    - Submissions will be hidden from all wardens (SR and non-SR alike) by default, to ensure that no sensitive issues are erroneously shared.
    - If the submissions include findings affecting live code, there will be no post-judging QA phase. This ensures that awards can be distributed in a timely fashion, without compromising the security of the project. (Senior members of C4 staff will review the judges’ decisions per usual.)
    - By default, submissions will not be made public until the report is published.
    - Exception: if the sponsor indicates that no submissions affect live code, then we’ll make submissions visible to all authenticated wardens, and open PJQA to SR wardens per the usual C4 process.
    - [The "live criticals" exception](https://docs.code4rena.com/awarding#the-live-criticals-exception) therefore applies. 
2. Judging phase risk adjustments (upgrades/downgrades):
    - High- or Medium-risk submissions downgraded by the judge to Low-risk (QA) will be ineligible for awards.
    - Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.
    - As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

## Automated Findings / Publicly Known Issues

[V12](https://v12.zellic.io/) is [Zellic](https://zellic.io)'s in-house AI auditing tool. It is the only autonomous Solidity auditor that [reliably finds Highs and Criticals](https://www.zellic.io/blog/introducing-v12/). All issues found by V12 will be judged as out of scope and ineligible for awards.

V12 findings will be included here, once available. 

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._

### Known Issues  
**EVM**
- In `ArbHTLC` and `HTLC` contracts, user can redeem after `block.number + timelock` value expires.  
- Unused parameter `destinationData` in `HTLC` and `ArbHTLC` contracts. It is required for event logs for off-chain verification of destination swap information.    
- Centralization risk in `HTLCRegistry` contract. The ownership is present only to set implementation contract addresses for the UDAs and to set valid HTLC addresses.
- No timelock validation provided: timelock can be set to an unreasonably large value, risking indefinite fund locks    
- The `redeem()` enforces a strict requirement that secrets must be exactly 32 bytes in length. In case a user initiates using a secret hash whose pre-image is of length n, such that n != 32, then the counterparty will not be able to redeem funds. The funds can then only be refunded.  

**Solana**
- The PDA for the swap data is closed after the swap is complete, so creating a duplicate order will be possible  
- User can redeem after `expiry_slot` has been reached    
- Missing validation for zero values: No checks prevent swap_amount from being set to 0 or zero-address values from being passed  
- No timelock validation provided: timelock can be set to an unreasonably large value, risking indefinite fund locks  
- The `redeem()` enforces a strict requirement that secrets must be exactly 32 bytes in length. In case a user initiates using a secret hash whose pre-image is of length n, such that n != 32, then the counterparty will not be able to redeem funds. The funds can then only be refunded.  
  
**Sui**  
- The chain ID is hardcoded in the `create_order_id` function. To avoid same order ID generation in testnet and mainnet, we manually change it before deployment.  
- The `redeem()` enforces a strict requirement that secrets must be exactly 32 bytes in length. In case a user initiates using a secret hash whose pre-image is of length n, such that n != 32, then the counterparty will not be able to redeem funds. The funds can then only be refunded.  
  
**Starknet**  
- User can redeem after the timelock expires, similar to EVM.
- No timelock validation provided: timelock can be set to an unreasonably large value, risking indefinite fund locks  
- The `redeem()` enforces a strict requirement that secrets must be exactly 32 bytes in length. In case a user initiates using a secret hash whose pre-image is of length n, such that n != 32, then the counterparty will not be able to redeem funds. The funds can then only be refunded.  

# Overview

Garden is the fastest Bitcoin bridge, enabling cross-chain Bitcoin swaps in as little as 30 seconds. It is built using an intents-based architecture with trustless settlements, ensuring zero custody risk for the users.

## Links

- **Previous audits:**  
  - 2025: [LightChaser Report](https://gist.github.com/ChaseTheLight01/5c433d8291cbed5b02f0ebe92dbc4bdb), [Zellic Report](https://github.com/gardenfi/audits/blob/main/Zellic.pdf)
  - 2024: [Trail of Bits Report](https://github.com/gardenfi/audits/blob/main/TrailOfBits.pdf)
  - 2023: [OtterSec Report](https://github.com/gardenfi/audits/blob/main/OtterSec.pdf)
- **Documentation:** https://docs.garden.finance/
- **Website:** https://garden.finance/
- **X/Twitter:** https://x.com/gardenfi

---

# Scope

### Files in scope

> Note: The nSLoC counts in the following table have been automatically generated and may differ depending on the definition of what a "significant" line of code represents. As such, they should be considered indicative rather than absolute representations of the lines involved in each contract.

| File   | nSLOC |
| ------ | ----- |
|[evm/src/swap/ArbHTLC.sol](https://github.com/code-423n4/2025-11-garden/blob/main/evm/src/swap/ArbHTLC.sol)| 144 |
|[evm/src/swap/ArbNativeHTLC.sol](https://github.com/code-423n4/2025-11-garden/blob/main/evm/src/swap/ArbNativeHTLC.sol)| 127 |
|[evm/src/swap/HTLC.sol](https://github.com/code-423n4/2025-11-garden/blob/main/evm/src/swap/HTLC.sol)| 142 |
|[evm/src/swap/HTLCRegistry.sol](https://github.com/code-423n4/2025-11-garden/blob/main/evm/src/swap/HTLCRegistry.sol)| 112 |
|[evm/src/swap/NativeHTLC.sol](https://github.com/code-423n4/2025-11-garden/blob/main/evm/src/swap/NativeHTLC.sol)| 125 |
|[evm/src/swap/UDA.sol](https://github.com/code-423n4/2025-11-garden/blob/main/evm/src/swap/UDA.sol)| 71 |
|[solana/solana-native/programs/solana-native-swaps/src/lib.rs](https://github.com/code-423n4/2025-11-garden/blob/main/solana/solana-native/programs/solana-native-swaps/src/lib.rs)| 260 |
|[solana/solana-spl-swaps/programs/solana-spl-swaps/src/lib.rs](https://github.com/code-423n4/2025-11-garden/blob/main/solana/solana-spl-swaps/programs/solana-spl-swaps/src/lib.rs)| 378 |
|[starknet/src/htlc.cairo](https://github.com/code-423n4/2025-11-garden/blob/main/starknet/src/htlc.cairo)| 328 |
|[starknet/src/interface/events.cairo](https://github.com/code-423n4/2025-11-garden/blob/main/starknet/src/interface/events.cairo)| 27 |
|[starknet/src/interface/sn_domain.cairo](https://github.com/code-423n4/2025-11-garden/blob/main/starknet/src/interface/sn_domain.cairo)| 23 |
|[starknet/src/interface/struct_hash.cairo](https://github.com/code-423n4/2025-11-garden/blob/main/starknet/src/interface/struct_hash.cairo)| 87 |
|[starknet/src/interface.cairo](https://github.com/code-423n4/2025-11-garden/blob/main/starknet/src/interface.cairo)| 60 |
|[starknet/src/lib.cairo](https://github.com/code-423n4/2025-11-garden/blob/main/starknet/src/lib.cairo)| 2 |
|[sui/sources/main.move](https://github.com/code-423n4/2025-11-garden/blob/main/sui/sources/main.move)| 277 |
|**Totals**| **2163** |


*For a machine-readable version, see [scope.txt](https://github.com/code-423n4/2025-11-garden/blob/main/scope.txt)*
### Files out of scope

> Note: Any file not explicitly listed in the table above is considered out-of-scope, and the list below is indicative

| File         |
| ------------ |
| [evm/certora/HTLCHarness.sol](https://github.com/code-423n4/2025-11-garden/blob/main/evm/certora/HTLCHarness.sol) |
| [evm/script/\*\*.\*\*](https://github.com/code-423n4/2025-11-garden/tree/main/evm/script) |
| [evm/test/\*\*.\*\*](https://github.com/code-423n4/2025-11-garden/tree/main/evm/test) |
| [sui/tests/test.move](https://github.com/code-423n4/2025-11-garden/blob/main/sui/tests/test.move) |
| Totals: 11 |

*For a machine-readable version, see [out_of_scope.txt](https://github.com/code-423n4/2025-11-garden/blob/main/out_of_scope.txt)*


# Additional context

## Areas of concern (where to focus for bugs)

The main focus of wardens should be that there is no way to cause fund loss for any party involved in a swap.

## Main invariants

### Order Duplication

Duplicate orders should not be possible in the system except for the Solana implementation, in which duplicate orders are only possible after the original one has been completed and closed.

### Access Control

Only the owner should be able to change the configuration of the `HTLCRegistry`.

## All trusted roles in the protocol

- In Solana and Sui, ownership of contracts allows us to upgrade the contract to the same address  
- In EVM, `HTLCRegistry` has ownership to set UDA implementation and valid HTLC addresses

## Running tests

### Solana  

**Prerequisites**

Install [Anchor framework](https://www.anchor-lang.com/docs/installation)

**Getting Started**

1. Clone the repository.
```bash
git clone https://github.com/code-423n4/2025-11-garden.git
```

2. Change into the Solana contracts directory (SPL or Native).
```bash
cd 2025-11-garden/solana/solana-spl-token
```

3. To build the program:  
```bash
anchor build
```

4. To run the tests:  
```bash
anchor test
```

### EVM  

To build the project:

```bash
git clone https://github.com/code-423n4/2025-11-garden.git
cd 2025-11-garden/evm
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.2.0
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0
forge build
```

Alternatively, the relevant dependencies can be pulled in as submodules.

To test:

```bash
forge test
```

For coverage:

```bash
forge coverage
```

### Sui  

To build the project:  

```bash
git clone https://github.com/code-423n4/2025-11-garden.git
cd 2025-11-garden/sui
sui move build
```

To test:  

```bash
sui move test
```

For coverage:  

```bash
sui move test --coverage
sui move coverage summary
```

### Starknet  

Prerequisite: `shardlabs/starknet-devnet-rs:0.3.0` 

To build:  

```bash
git clone https://github.com/code-423n4/2025-11-garden.git
cd 2025-11-garden/starknet
yarn
scarb build
```

To test:  

```bash
starknet-devnet --seed 0 --port 5050
yarn test
```


## Miscellaneous
Employees of Garden and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.


