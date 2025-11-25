# Solana SPL Swap Double-Entry Bookkeeping

### 📌 SolanaSPLSwap@initiate

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `token_vault` | 借 (Debit) | 资产 (Asset) | Received tokens from funder. |
   | `SwapAccount.swap_amount` | 贷 (Credit) | 负债 (Liability) | Created new order obligation. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `token_vault` (Asset ↑) = `SwapAccount.swap_amount` (Liability ↑)

### 📌 SolanaSPLSwap@redeem / refund / instant_refund

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `SwapAccount.swap_amount` | 借 (Debit) | 负债 (Liability) | Obligation fulfilled. |
   | `token_vault` | 贷 (Credit) | 资产 (Asset) | Transferred tokens out. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `SwapAccount.swap_amount` (Liability ↓) = `token_vault` (Asset ↓)
