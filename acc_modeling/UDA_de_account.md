# UniqueDepositAddress (EVM) Double-Entry Bookkeeping

### 📌 UDA@initialize

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `ImplicitLiability` | 借 (Debit) | 负债 (Liability) | Obligation to forward funds fulfilled. |
   | `token` / `balance` | 贷 (Credit) | 资产 (Asset) | Funds transferred to HTLC. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `ImplicitLiability` (Liability ↓) = `token` (Asset ↓)

### 📌 UDA@recover

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `ImplicitLiability` | 借 (Debit) | 负债 (Liability) | Returned funds to owner/refundAddress. |
   | `token` / `balance` | 贷 (Credit) | 资产 (Asset) | Funds transferred out. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `ImplicitLiability` (Liability ↓) = `token` (Asset ↓)
