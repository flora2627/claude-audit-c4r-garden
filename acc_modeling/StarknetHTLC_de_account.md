# Starknet HTLC Double-Entry Bookkeeping

### 📌 StarknetHTLC@initiate / initiate_on_behalf / initiate_with_signature

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `token` (balance) | 借 (Debit) | 资产 (Asset) | Received tokens from initiator. |
   | `orders` (Liability) | 贷 (Credit) | 负债 (Liability) | Created new order obligation. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `token` (Asset ↑) = `orders` (Liability ↑)

### 📌 StarknetHTLC@redeem / refund / instant_refund

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `orders` (Liability) | 借 (Debit) | 负债 (Liability) | Obligation fulfilled. |
   | `token` (balance) | 贷 (Credit) | 资产 (Asset) | Transferred tokens out. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `orders` (Liability ↓) = `token` (Asset ↓)
