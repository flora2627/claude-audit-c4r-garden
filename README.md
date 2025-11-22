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

The 4naly3er report can be found [here](https://github.com/code-423n4/2025-09-garden/blob/main/4naly3er-report.md).

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._

# Known Issues  
### EVM  
- In `ArbHTLC` and `HTLC` contracts, user can redeem after `block.number + timelock` value expires.  
- Unused parameter `destinationData` in `HTLC` and `ArbHTLC` contracts. It is required for event logs for off-chain verification of destination swap information.    
- Centralization risk in `HTLCRegistry` contract. The ownership is present only to set implementation contract addresses for the UDAs and to set valid HTLC addresses.
- No timelock validation provided: timelock can be set to an unreasonably large value, risking indefinite fund locks    
  
### Solana  
- The PDA for the swap data is closed after the swap is complete, so creating a duplicate order will be possible  
- User can redeem after `expiry_slot` has been reached    
- Missing validation for zero values: No checks prevent swap_amount from being set to 0 or zero-address values from being passed  
- No timelock validation provided: timelock can be set to an unreasonably large value, risking indefinite fund locks  
  
### Sui  
- The chain ID is hardcoded in the `create_order_id` function. To avoid same order ID generation in testnet and mainnet, we manually change it before deployment.  
  
### Starknet  
- User can redeem after the timelock expires, similar to EVM.
- No timelock validation provided: timelock can be set to an unreasonably large value, risking indefinite fund locks 

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

# Overview

[ ⭐️ SPONSORS: add info here ]

## Links

- **Previous audits:**  [LightChaser Report](https://gist.github.com/ChaseTheLight01/5c433d8291cbed5b02f0ebe92dbc4bdb)  
[Previous Audits](https://github.com/gardenfi/audits)  
  - ✅ SCOUTS: If there are multiple report links, please format them in a list.
- **Documentation:** https://docs.garden.finance/
- **Website:** https://garden.finance/
- **X/Twitter:** https://x.com/gardenfi

---

# Scope

[ ✅ SCOUTS: add scoping and technical details here ]

### Files in scope
- ✅ This should be completed using the `metrics.md` file
- ✅ Last row of the table should be Total: SLOC
- ✅ SCOUTS: Have the sponsor review and and confirm in text the details in the section titled "Scoping Q amp; A"

*For sponsors that don't use the scoping tool: list all files in scope in the table below (along with hyperlinks) -- and feel free to add notes to emphasize areas of focus.*

| Contract | SLOC | Purpose | Libraries used |  
| ----------- | ----------- | ----------- | ----------- |
| [contracts/folder/sample.sol](https://github.com/code-423n4/repo-name/blob/contracts/folder/sample.sol) | 123 | This contract does XYZ | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) |

### Files out of scope
✅ SCOUTS: List files/directories out of scope

# Additional context

## Areas of concern (where to focus for bugs)
- Ensure no loss of funds for both parties  

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

## Main invariants

- Duplicate orders should not be possible  
  - In Solana, duplicate orders are possible only after the first one is completed and closed.  
- Only owner should be able to change values in `HTLCRegistry`  

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

## All trusted roles in the protocol

- In Solana and Sui, ownership of contract allows us to upgrade the contract to the same address  
- In EVM, `HTLCRegistry` has ownership to set UDA implementation and valid HTLC addresses.   

✅ SCOUTS: Please format the response above 👆 using the template below👇

| Role                                | Description                       |
| --------------------------------------- | ---------------------------- |
| Owner                          | Has superpowers                |
| Administrator                             | Can change fees                       |

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

## Running tests

# Solana  
## Prerequisites
Install [Anchor framework](https://www.anchor-lang.com/docs/installation)

## Getting Started
1. Clone the repository.
`git clone https://github.com/harshasingamshetty1/garden-audit-scope.git`

2. Change into the Solana contracts directory (SPL or Native).
`cd garden-audit-scope`
`cd solana/solana-spl-token`

3. To build the program:  
`anchor build`

4. To run the tests:  
`anchor test`  

# EVM  
To build the project:
```bash
git clone https://github.com/harshasingamshetty1/garden-audit-scope.git
cd garden-audit-scope
cd evm
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.2.0
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0
forge build
```

To test:
`forge test`

For coverage:
`forge coverage`

# Sui  
To build the project:  
```bash
git clone https://github.com/harshasingamshetty1/garden-audit-scope.git
cd garden-audit-scope
cd sui
sui move build
```

To test:  
`sui move test`

For coverage:  
```bash
sui move test --coverage
sui move coverage summary
```

# Starknet  
Prerequisite: `shardlabs/starknet-devnet-rs:0.3.0 `  
To build:  
```bash
git clone https://github.com/harshasingamshetty1/garden-audit-scope.git
cd garden-audit-scope
cd starknet
yarn
scarb build
```

To test:  
```bash
starknet-devnet
yarn test
```


✅ SCOUTS: Please format the response above 👆 using the template below👇

```bash
git clone https://github.com/code-423n4/2023-08-arbitrum
git submodule update --init --recursive
cd governance
foundryup
make install
make build
make sc-election-test
```
To run code coverage
```bash
make coverage
```

✅ SCOUTS: Add a screenshot of your terminal showing the test coverage

## Miscellaneous
Employees of Garden and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.


# Scope

*See [scope.txt](https://github.com/code-423n4/2025-11-garden/blob/main/scope.txt)*

### Files in scope


| File   | Logic Contracts | Interfaces | nSLOC | Purpose | Libraries used |
| ------ | --------------- | ---------- | ----- | -----   | ------------ |
| /evm/src/swap/ArbHTLC.sol | 1| 1 | 144 | |@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol<br>@openzeppelin/contracts/utils/cryptography/EIP712.sol<br>@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol|
| /evm/src/swap/ArbNativeHTLC.sol | 1| 1 | 127 | |@openzeppelin/contracts/utils/cryptography/EIP712.sol<br>@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol|
| /evm/src/swap/HTLC.sol | 1| **** | 142 | |@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol<br>@openzeppelin/contracts/utils/cryptography/EIP712.sol<br>@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol|
| /evm/src/swap/HTLCRegistry.sol | 1| **** | 112 | |@openzeppelin/contracts/proxy/Clones.sol<br>@openzeppelin/contracts/utils/Address.sol<br>@openzeppelin/contracts/access/Ownable.sol<br>@openzeppelin/contracts/token/ERC20/IERC20.sol|
| /evm/src/swap/NativeHTLC.sol | 1| **** | 125 | |@openzeppelin/contracts/utils/cryptography/EIP712.sol<br>@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol|
| /evm/src/swap/UDA.sol | 2| **** | 71 | |@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol<br>@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol<br>@openzeppelin/contracts/proxy/Clones.sol|
| /solana/solana-native/programs/solana-native-swaps/src/lib.rs | ****| **** | 260 | ||
| /solana/solana-spl-swaps/programs/solana-spl-swaps/src/lib.rs | ****| **** | 378 | ||
| /starknet/src/htlc.cairo | ****| **** | 328 | ||
| /starknet/src/interface/events.cairo | ****| **** | 27 | ||
| /starknet/src/interface/sn_domain.cairo | ****| **** | 23 | ||
| /starknet/src/interface/struct_hash.cairo | ****| **** | 87 | ||
| /starknet/src/interface.cairo | ****| **** | 60 | ||
| /starknet/src/lib.cairo | ****| **** | 2 | ||
| /sui/sources/main.move | ****| **** | 277 | ||
| **Totals** | **7** | **2** | **2163** | | |

### Files out of scope

*See [out_of_scope.txt](https://github.com/code-423n4/2025-11-garden/blob/main/out_of_scope.txt)*

| File         |
| ------------ |
| ./evm/certora/HTLCHarness.sol |
| ./evm/script/DeployArbHTLC.s.sol |
| ./evm/script/DeployArbNativeHTLC.s.sol |
| ./evm/script/DeployNativeHTLC.s.sol |
| ./evm/script/DeployRegistry.s.sol |
| ./evm/script/deployHTLC.s.sol |
| ./evm/test/HTLC.t.sol |
| ./evm/test/HTLCRegistry.t.sol |
| ./evm/test/MockSmartAccount.sol |
| ./evm/test/NativeHTLC.t.sol |
| ./sui/tests/test.move |
| Totals: 11 |

