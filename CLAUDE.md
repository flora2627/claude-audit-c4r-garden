# CLAUDE.md - Garden Finance Audit Codebase Guide

## Project Overview

**Garden Finance** is a Bitcoin bridge protocol enabling cross-chain atomic swaps using Hash Time-Locked Contracts (HTLCs) across multiple blockchain ecosystems. This repository contains the smart contract implementations for a Code4rena audit competition.

- **Purpose**: Trustless cross-chain atomic swaps with zero custody risk
- **Architecture**: Intent-based with trustless settlements
- **Target Speed**: Bitcoin swaps in as little as 30 seconds
- **Total Prize Pool**: $37,500 USDC (Code4rena audit competition)
- **Audit Period**: November 24 - December 8, 2025

### Key Resources
- **Documentation**: https://docs.garden.finance/
- **Website**: https://garden.finance/
- **Previous Audits**: Trail of Bits (2024), OtterSec (2023), LightChaser (2025), Zellic (2025)

## Repository Structure

```
claude-audit-c4r-garden/
├── evm/                    # Ethereum/EVM-compatible chains (Solidity 0.8.28)
│   ├── src/swap/          # Main HTLC contracts
│   │   ├── HTLC.sol           # Standard ERC20 token HTLC
│   │   ├── NativeHTLC.sol     # Native ETH HTLC
│   │   ├── ArbHTLC.sol        # Arbitrum-specific ERC20 HTLC
│   │   ├── ArbNativeHTLC.sol  # Arbitrum-specific native HTLC
│   │   ├── HTLCRegistry.sol   # Registry for HTLC management
│   │   └── UDA.sol            # Unique Deposit Addresses (proxy contracts)
│   ├── test/              # Foundry tests
│   ├── script/            # Deployment scripts (OUT OF SCOPE)
│   ├── certora/           # Formal verification (OUT OF SCOPE)
│   └── foundry.toml       # Foundry configuration
│
├── solana/
│   ├── solana-native/     # Native SOL atomic swaps (Anchor/Rust)
│   │   └── programs/solana-native-swaps/src/lib.rs (260 nSLOC)
│   └── solana-spl-swaps/  # SPL token atomic swaps (Anchor/Rust)
│       └── programs/solana-spl-swaps/src/lib.rs (378 nSLOC)
│
├── starknet/              # Starknet implementation (Cairo)
│   └── src/
│       ├── htlc.cairo         # Main HTLC contract (328 nSLOC)
│       ├── interface.cairo    # Contract interfaces
│       └── interface/         # Supporting modules
│
├── sui/                   # Sui blockchain implementation (Move)
│   └── sources/main.move      # Main HTLC contract (277 nSLOC)
│
├── README.md              # Audit details and setup instructions
├── scope.txt              # Machine-readable scope list
├── out_of_scope.txt       # Excluded files
└── known-issues.md        # Documented known issues
```

### Total Scope
- **Total nSLOC**: 2,163 lines across 15 files
- **Languages**: Solidity, Rust (Anchor), Cairo, Move
- **Chains**: EVM (Ethereum, Arbitrum, etc.), Solana, Starknet, Sui

## Chain-Specific Implementations

### EVM (Ethereum/Arbitrum) - Foundry/Solidity

**Key Files** (721 nSLOC total):
- `evm/src/swap/HTLC.sol` (142 nSLOC) - ERC20 token swaps
- `evm/src/swap/NativeHTLC.sol` (125 nSLOC) - Native ETH swaps
- `evm/src/swap/ArbHTLC.sol` (144 nSLOC) - Arbitrum ERC20 variant
- `evm/src/swap/ArbNativeHTLC.sol` (127 nSLOC) - Arbitrum native variant
- `evm/src/swap/HTLCRegistry.sol` (112 nSLOC) - Central registry with ownership
- `evm/src/swap/UDA.sol` (71 nSLOC) - Unique Deposit Address proxies

**Configuration**:
- Solidity: `0.8.28` with Cancun EVM version
- Optimizer runs: `10088456095462536`
- Uses OpenZeppelin contracts v5.2.0 (upgradeable and standard)
- EIP-712 for signature verification

**Setup & Testing**:
```bash
cd evm
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.2.0
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0
forge build
forge test
forge coverage
```

**Architecture Patterns**:
- **EIP-712**: Typed structured data signing for off-chain signatures
- **Clones Pattern**: Minimal proxy pattern (EIP-1167) for UDA contracts
- **Registry Pattern**: Centralized management of HTLC implementations
- **SafeERC20**: Protection against non-standard ERC20 implementations

### Solana - Anchor Framework

**Key Files** (638 nSLOC total):
- `solana/solana-native/programs/solana-native-swaps/src/lib.rs` (260 nSLOC)
- `solana/solana-spl-swaps/programs/solana-spl-swaps/src/lib.rs` (378 nSLOC)

**Configuration**:
- Framework: Anchor (latest)
- Two separate programs: Native SOL and SPL tokens

**Setup & Testing**:
```bash
# Native swaps
cd solana/solana-native
anchor build
anchor test

# SPL swaps
cd solana/solana-spl-swaps
anchor build
anchor test
```

**Architecture Patterns**:
- **PDA (Program Derived Addresses)**: Deterministic account derivation
- **Account Model**: Explicit account management in instructions
- **CPI (Cross-Program Invocation)**: For token transfers
- **Rent Exemption**: Accounts must maintain minimum balance

### Starknet - Cairo

**Key Files** (500 nSLOC total):
- `starknet/src/htlc.cairo` (328 nSLOC) - Main HTLC implementation
- `starknet/src/interface.cairo` (60 nSLOC)
- `starknet/src/interface/struct_hash.cairo` (87 nSLOC)
- `starknet/src/interface/sn_domain.cairo` (23 nSLOC)
- `starknet/src/interface/events.cairo` (27 nSLOC)
- `starknet/src/lib.cairo` (2 nSLOC)

**Configuration**:
- Cairo Edition: `2024_07`
- Dependencies: OpenZeppelin 0.20.0, Alexandria bytes/encoding
- Framework: Starknet Foundry (snforge)

**Setup & Testing**:
```bash
cd starknet
yarn install
scarb build

# Testing (requires devnet)
starknet-devnet --seed 0 --port 5050  # In separate terminal
yarn test
```

**Architecture Patterns**:
- **Component Pattern**: Cairo's composable contract components
- **SNIP-12**: Starknet's typed message signing (similar to EIP-712)
- **Storage Pattern**: Explicit storage variable declarations
- **Event Emission**: Structured event logging

### Sui - Move Language

**Key Files** (277 nSLOC total):
- `sui/sources/main.move` (277 nSLOC)

**Configuration**:
- Edition: `2024.beta`
- Standard Library: Sui Framework
- Named Addresses: `atomic_swapv1 = "0x0"`

**Setup & Testing**:
```bash
cd sui
sui move build
sui move test
sui move test --coverage
sui move coverage summary
```

**Architecture Patterns**:
- **Shared Objects**: `OrdersRegistry<CoinType>` for concurrent access
- **Generics**: Type-safe coin handling with `<CoinType>` parameter
- **Capabilities**: Resource-oriented programming
- **Clock Object**: Time-based validation using shared clock

## Key Concepts and Architecture

### HTLC (Hash Time-Locked Contract) Pattern

All implementations follow the same core HTLC pattern:

1. **Initiate**: Lock funds with a hash of a secret and a timelock
2. **Redeem**: Unlock funds by revealing the secret (before timelock expires)
3. **Refund**: Return funds to initiator after timelock expires

**Core Parameters**:
- `secretHash`: SHA-256 hash (32 bytes) of the secret
- `timelock`: Duration/block height before refund allowed
- `initiator`: Address that locks funds
- `redeemer`: Address that can unlock with secret
- `amount`: Amount of tokens/coins to swap

### Unique Deposit Addresses (UDA)

**EVM Only** - Allows users to have deterministic deposit addresses:
- Uses minimal proxy pattern (EIP-1167/Clones)
- Clone doesn't exist until user deposits funds
- Automatically initiates HTLC swap upon receiving funds
- Two variants: `UniqueDepositAddress` (ERC20) and `NativeUniqueDepositAddress` (ETH)

### Order ID Generation

Deterministic order IDs prevent duplicates (except Solana after completion):

**General Pattern**:
```
OrderID = SHA-256(chain_id + secret_hash + initiator + redeemer + timelock + [additional_params])
```

### Cross-Chain Flow

Typical atomic swap between chains:
1. **Chain A**: Initiator creates HTLC with `secretHash` and timelock T1
2. **Chain B**: Redeemer creates HTLC with same `secretHash` and longer timelock T2 (T2 > T1)
3. **Chain A**: Redeemer redeems by revealing `secret`
4. **Chain B**: Initiator sees `secret` on-chain and redeems their HTLC
5. **Fallback**: If secret not revealed, both parties can refund after respective timelocks

## Development Workflow

### Branch Strategy

**CRITICAL**: Always work on the designated Claude branch:
```
Branch: claude/claude-md-midwtv9sensf12eh-01X9ugueFWNR6MutNe2gcnP6
```

**Git Operations**:
```bash
# Create branch if needed
git checkout -b claude/claude-md-midwtv9sensf12eh-01X9ugueFWNR6MutNe2gcnP6

# Commit changes
git add .
git commit -m "Description of changes"

# Push with retry logic (use -u for first push)
git push -u origin claude/claude-md-midwtv9sensf12eh-01X9ugueFWNR6MutNe2gcnP6
```

**Important**: Branch must start with `claude/` and match session ID, or push will fail with 403.

### Code Quality Standards

1. **Security First**: No vulnerabilities from OWASP Top 10
   - No SQL injection, XSS, command injection
   - Proper access control validation
   - Safe external calls and reentrancy protection

2. **Minimal Changes**:
   - Only modify what's explicitly requested
   - Don't add unsolicited features or refactoring
   - No unnecessary comments, docstrings, or type annotations

3. **No Over-Engineering**:
   - No premature abstractions
   - No feature flags for simple changes
   - Trust internal code and framework guarantees
   - Only validate at system boundaries

4. **Backwards Compatibility**:
   - No compatibility hacks for unused code
   - Delete unused code completely
   - No `// removed` comments or placeholder functions

## Testing Strategies

### EVM Testing with Foundry

**Run Tests**:
```bash
forge test                    # Run all tests
forge test -vvv              # Verbose output
forge test --match-test testFunctionName
forge coverage               # Generate coverage report
forge snapshot               # Gas snapshots
```

**Test Files** (OUT OF SCOPE but useful for understanding):
- `evm/test/HTLC.t.sol`
- `evm/test/NativeHTLC.t.sol`
- `evm/test/HTLCRegistry.t.sol`

### Solana Testing with Anchor

**Run Tests**:
```bash
anchor test                  # Build and test on local validator
anchor test --skip-build     # Skip build step
```

### Starknet Testing

**Prerequisites**: `starknet-devnet-rs:0.3.0` (Docker container)

**Run Tests**:
```bash
# Terminal 1: Start devnet
starknet-devnet --seed 0 --port 5050

# Terminal 2: Run tests
yarn test
```

### Sui Testing

**Run Tests**:
```bash
sui move test                # Run all tests
sui move test --coverage     # With coverage
sui move coverage summary    # Coverage report
```

## Known Issues and Constraints

### Multi-Chain Known Issues

**ALL CHAINS**:
- **32-byte Secret Requirement**: Secrets must be exactly 32 bytes. Pre-images of different lengths cannot be redeemed; funds can only be refunded.

### EVM-Specific

1. **Post-Expiry Redemption**: Users can redeem after `block.number + timelock` expires
2. **Unused Parameter**: `destinationData` in `HTLC` and `ArbHTLC` is for event logs only (off-chain verification)
3. **Centralization**: `HTLCRegistry` owner can set implementation addresses and valid HTLC addresses
4. **No Timelock Validation**: Timelock can be unreasonably large, risking indefinite fund locks

### Solana-Specific

1. **Duplicate Orders**: Possible after original order is completed and PDA closed
2. **Post-Expiry Redemption**: Users can redeem after `expiry_slot` is reached
3. **Zero Value Validation**: No checks prevent `swap_amount = 0` or zero addresses
4. **No Timelock Validation**: Timelock can be unreasonably large

### Sui-Specific

1. **Hardcoded Chain ID**: Chain ID in `create_order_id()` must be manually changed before deployment to testnet/mainnet
2. **Timelock Validation**: Must be between 1ms and 7 days (enforced by contract)

### Starknet-Specific

1. **Post-Expiry Redemption**: Similar to EVM implementation
2. **No Timelock Validation**: Timelock can be unreasonably large

### Out of Scope Files

**DO NOT AUDIT/MODIFY**:
- `evm/certora/*` - Formal verification harness
- `evm/script/*` - Deployment scripts
- `evm/test/*` - Test files
- `sui/tests/test.move` - Test file

## Important Invariants

### Critical Invariants (Must Always Hold)

1. **No Fund Loss**: There must be no way to cause fund loss for any party in a swap
2. **Order Uniqueness**: Duplicate orders should not be possible (except Solana after completion)
3. **Access Control**: Only owner can change `HTLCRegistry` configuration (EVM)
4. **Secret Atomicity**: Revealing secret on one chain enables redemption on counterparty chain
5. **Timelock Safety**: Initiator can always refund after timelock expires (if not already redeemed)

### Security Properties

1. **Reentrancy Protection**: All external calls are safe (checks-effects-interactions pattern)
2. **Signature Validation**: EIP-712/SNIP-12 signatures properly validated
3. **Secret Hash Integrity**: Secret must hash to stored `secretHash` for redemption
4. **Address Validation**: Zero addresses rejected where inappropriate
5. **Amount Validation**: Amount must match deposited funds

## Architecture Decision Records

### Why Multiple Chain Implementations?

Garden Finance targets true cross-chain interoperability. Each chain has unique:
- **Execution Model**: EVM (account-based), Solana (account model), Sui (object model), Starknet (account abstraction)
- **Language Features**: Solidity (OOP), Rust (ownership), Move (resources), Cairo (functional)
- **Gas Models**: Different optimization strategies required

### Why UDAs Only on EVM?

- **EVM**: CREATE2 allows deterministic addresses before deployment
- **Solana**: PDAs serve similar purpose but work differently
- **Sui**: Object model doesn't require this pattern
- **Starknet**: Account abstraction provides alternative approaches

### Why Different HTLC Variants?

1. **HTLC vs NativeHTLC**: ERC20 tokens vs native ETH (different transfer mechanisms)
2. **ArbHTLC vs HTLC**: Arbitrum-specific optimizations (L2 block numbers)
3. **SPL vs Native Solana**: SPL token program vs native SOL transfers

## Security Considerations

### High-Risk Areas

1. **Secret Handling**:
   - Secret revealed on-chain during redemption
   - Anyone monitoring can extract secret and race to redeem on other chain
   - This is expected behavior but must be understood

2. **Timelock Ordering**:
   - Counterparty must have longer timelock to prevent griefing
   - If T1 > T2, initiator could wait until T2 expires and keep both sets of funds
   - Application layer must enforce T2 > T1 with sufficient buffer

3. **Front-Running**:
   - Redeem transactions can be front-run (MEV risk)
   - Mitigated by: relayers with private mempools, flashbots, etc.
   - Not a contract-level issue

4. **Signature Replay**:
   - EIP-712/SNIP-12 includes domain separator (chain ID, contract address)
   - Order IDs include chain-specific data
   - Prevents cross-chain and cross-contract replay

### Trust Assumptions

1. **EVM Registry Owner**: Trusted to set correct implementation addresses
2. **Solana/Sui Upgrade Authority**: Can upgrade contracts to same address
3. **Block Timestamps**: Assumed to be reasonably accurate (validator consensus)
4. **RPC Nodes**: Users must monitor both chains to extract secrets

## AI Assistant Guidelines

### When Analyzing This Codebase

1. **Read Before Suggesting**: Always read files before proposing changes
2. **Respect Scope**: Only analyze files in `scope.txt`
3. **Check Known Issues**: Verify findings aren't already in `known-issues.md`
4. **Multi-Chain Context**: Consider cross-chain implications
5. **Language Differences**: Understand each language's paradigms

### When Proposing Changes

1. **Justify Security**: Explain threat model and attack scenario
2. **Show Impact**: Demonstrate fund loss or invariant violation
3. **Consider Gas**: Optimizations should maintain security
4. **Test Coverage**: Describe how to test the finding
5. **Cross-Reference**: Check if pattern exists in other chain implementations

### When Writing Reports

1. **Chain-Specific Tags**: Clearly mark which chain(s) affected
2. **Severity Justification**:
   - **Critical**: Direct fund loss, theft, or lock
   - **High**: Fund loss under specific conditions
   - **Medium**: Protocol breaks but funds eventually recoverable
   - **Low/QA**: Best practices, gas optimizations, code quality
3. **Proof of Concept**: Provide concrete exploit code when possible
4. **Remediation**: Suggest specific, minimal fixes

### Common Pitfalls to Avoid

1. **Don't Report Known Issues**: Check `known-issues.md` first
2. **Don't Report V12 Findings**: Zellic's AI auditor findings are out of scope
3. **Don't Report Test Code Issues**: Tests are out of scope
4. **Don't Confuse Languages**: Solidity != Rust != Move != Cairo
5. **Don't Assume EVM Behavior**: Other chains work differently

### Useful Search Patterns

```bash
# Find all secret hash validations
grep -r "secretHash" --include="*.sol" --include="*.rs" --include="*.cairo" --include="*.move"

# Find all timelock checks
grep -r "timelock" --include="*.sol" --include="*.rs" --include="*.cairo" --include="*.move"

# Find all refund functions
grep -r "refund" --include="*.sol" --include="*.rs" --include="*.cairo" --include="*.move"

# Find all redeem functions
grep -r "redeem" --include="*.sol" --include="*.rs" --include="*.cairo" --include="*.move"
```

## Quick Reference

### Key Addresses (EVM)
- Native Token Address: `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`

### Key Type Hashes (EVM)
```solidity
// HTLC.sol
bytes32 constant _INITIATE_TYPEHASH =
    keccak256("Initiate(address redeemer,uint256 timelock,uint256 amount,bytes32 secretHash)");
bytes32 constant _REFUND_TYPEHASH =
    keccak256("Refund(bytes32 orderId)");
```

### Contract Names and Versions (EVM)
- `HTLC`: version "3"
- `NativeHTLC`: version "3"
- `HTLCRegistry`: version "1.0.0"

### Important Constants
- Secret Length: 32 bytes (all chains)
- Sui Timelock Range: 1ms - 7 days (604,800,000 ms)

## Contact and Resources

### For Questions About This Codebase
- Review `README.md` for audit-specific details
- Check `known-issues.md` before reporting issues
- Refer to Garden Finance docs: https://docs.garden.finance/

### For Code4rena Specific Questions
- Guidelines: https://docs.code4rena.com/competitions
- Live Code Policy: Submissions treated as sensitive
- No PJQA if live code affected
- Downgrades to QA are ineligible for awards

---

**Last Updated**: November 25, 2025
**Audit Period**: November 24 - December 8, 2025
**Repository**: claude-audit-c4r-garden
**Total Scope**: 2,163 nSLOC across 4 blockchains
