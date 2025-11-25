# Accounting Entities Identification

| 模块名 (Module Name) | 有资产？(Assets) | 有负债？(Liabilities) | 有权益？(Equity) | 是否拆分账目 (Split?) | 合约入口 (Contract Entry) | 说明备注 (Remarks) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **HTLC (EVM)** | ✅ | ✅ | ❌ | **是 (Yes)** | `evm/src/swap/HTLC.sol` | Holds ERC20 tokens in custody against Orders. |
| **NativeHTLC (EVM)** | ✅ | ✅ | ❌ | **是 (Yes)** | `evm/src/swap/NativeHTLC.sol` | Holds ETH in custody against Orders. |
| **ArbHTLC (EVM)** | ✅ | ✅ | ❌ | **是 (Yes)** | `evm/src/swap/ArbHTLC.sol` | Arbitrum-specific ERC20 HTLC. |
| **ArbNativeHTLC (EVM)** | ✅ | ✅ | ❌ | **是 (Yes)** | `evm/src/swap/ArbNativeHTLC.sol` | Arbitrum-specific ETH HTLC. |
| **UniqueDepositAddress (EVM)** | ✅ | ✅ | ❌ | **是 (Yes)** | `evm/src/swap/UDA.sol` | Transiently holds ERC20 tokens before forwarding to HTLC. |
| **NativeUniqueDepositAddress (EVM)** | ✅ | ✅ | ❌ | **是 (Yes)** | `evm/src/swap/UDA.sol` | Transiently holds ETH before forwarding to NativeHTLC. |
| **HTLCRegistry (EVM)** | ❌ | ❌ | ❌ | **否 (No)** | `evm/src/swap/HTLCRegistry.sol` | Factory/Registry. Does not hold funds. |
| **Solana Native Swap** | ✅ | ✅ | ❌ | **是 (Yes)** | `solana-native/.../lib.rs` | Holds SOL in PDA vault. |
| **Solana SPL Swap** | ✅ | ✅ | ❌ | **是 (Yes)** | `solana-spl/.../lib.rs` | Holds SPL tokens in TokenVault. |
| **Starknet HTLC** | ✅ | ✅ | ❌ | **是 (Yes)** | `starknet/src/htlc.cairo` | Holds ERC20 tokens. |
| **Sui AtomicSwap** | ✅ | ✅ | ❌ | **是 (Yes)** | `sui/sources/main.move` | Holds Coins in Order objects. |
