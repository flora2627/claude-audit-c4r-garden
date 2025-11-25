# Sui Atomic Swap Double-Entry Bookkeeping

### 📌 SuiAtomicSwap@initiate

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `Order.coins` | 借 (Debit) | 资产 (Asset) | Received coins from funder. |
   | `Order.amount` | 贷 (Credit) | 负债 (Liability) | Created new order obligation. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `Order.coins` (Asset ↑) = `Order.amount` (Liability ↑)

### 📌 SuiAtomicSwap@redeem / refund / instant_refund

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `Order.amount` | 借 (Debit) | 负债 (Liability) | Obligation fulfilled. |
   | `Order.coins` | 贷 (Credit) | 资产 (Asset) | Transferred coins out. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `Order.amount` (Liability ↓) = `Order.coins` (Asset ↓)
