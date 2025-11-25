# ArbHTLC (EVM) Double-Entry Bookkeeping

### 📌 ArbHTLC@initiate / initiateOnBehalf / initiateWithSignature

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `token` (balanceOf(this)) | 借 (Debit) | 资产 (Asset) | Received tokens from initiator. |
   | `orders` (Liability) | 贷 (Credit) | 负债 (Liability) | Created new order obligation. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `token` (Asset ↑) = `orders` (Liability ↑)

### 📌 ArbHTLC@redeem

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `orders` (Liability) | 借 (Debit) | 负债 (Liability) | Obligation fulfilled (redeemed). |
   | `token` (balanceOf(this)) | 贷 (Credit) | 资产 (Asset) | Transferred tokens to redeemer. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `orders` (Liability ↓) = `token` (Asset ↓)

### 📌 ArbHTLC@refund / instantRefund

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `orders` (Liability) | 借 (Debit) | 负债 (Liability) | Obligation fulfilled (refunded). |
   | `token` (balanceOf(this)) | 贷 (Credit) | 资产 (Asset) | Transferred tokens back to initiator. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `orders` (Liability ↓) = `token` (Asset ↓)
