# ArbNativeHTLC (EVM) Double-Entry Bookkeeping

### 📌 ArbNativeHTLC@initiate / initiateOnBehalf

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `address(this).balance` | 借 (Debit) | 资产 (Asset) | Received ETH from initiator. |
   | `orders` (Liability) | 贷 (Credit) | 负债 (Liability) | Created new order obligation. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `address(this).balance` (Asset ↑) = `orders` (Liability ↑)

### 📌 ArbNativeHTLC@redeem

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `orders` (Liability) | 借 (Debit) | 负债 (Liability) | Obligation fulfilled (redeemed). |
   | `address(this).balance` | 贷 (Credit) | 资产 (Asset) | Transferred ETH to redeemer. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `orders` (Liability ↓) = `address(this).balance` (Asset ↓)

### 📌 ArbNativeHTLC@refund / instantRefund

1. 🧾 变量变动表 (Function Delta Table):
   | 变量名 | 方向 (借/贷) | 会计科目类别 | 解释 (为什么变动) |
   | :--- | :--- | :--- | :--- |
   | `orders` (Liability) | 借 (Debit) | 负债 (Liability) | Obligation fulfilled (refunded). |
   | `address(this).balance` | 贷 (Credit) | 资产 (Asset) | Transferred ETH back to initiator. |

2. ⚖️ 函数会计平衡式 (Function Accounting Identity):
   > `orders` (Liability ↓) = `address(this).balance` (Asset ↓)
