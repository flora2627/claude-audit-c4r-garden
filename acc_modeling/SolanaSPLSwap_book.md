# Solana SPL Swap Accounting Book

## 1. 📦 资产类变量 (Assets)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `token_vault` | `TokenAccount` | `lib.rs` | The SPL token account holding the locked tokens. |

## 2. 💼 负债类变量 (Liabilities)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `SwapAccount.swap_amount` | `u64` | `lib.rs` | The amount of tokens locked in the swap, owed to redeemer or refundee. |

## 3. 🧾 权益类变量 (Equity)

*None.*
