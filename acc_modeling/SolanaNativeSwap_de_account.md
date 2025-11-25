# Solana Native Swap Double-Entry Bookkeeping

### 📌 SolanaNativeSwap@initiate

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `swap_account` (lamports) | 借 (Debit) | 资产 (Asset) | Received SOL from funder. |
   | `SwapAccount.swap_amount` | 贷 (Credit) | 负债 (Liability) | Created new order obligation. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `swap_account` (Asset ↑) = `SwapAccount.swap_amount` (Liability ↑)

### 📌 SolanaNativeSwap@redeem / refund / instant_refund

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `SwapAccount.swap_amount` | 借 (Debit) | 负债 (Liability) | Obligation fulfilled. |
   | `swap_account` (lamports) | 贷 (Credit) | 资产 (Asset) | Transferred SOL out. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `SwapAccount.swap_amount` (Liability ↓) = `swap_account` (Asset ↓)
