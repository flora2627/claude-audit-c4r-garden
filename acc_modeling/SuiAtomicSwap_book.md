# Sui Atomic Swap Accounting Book

## 1. 📦 资产类变量 (Assets)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `Order.coins` | `Coin<CoinType>` | `main.move` | The actual Coin object held within the Order object. |

## 2. 💼 负债类变量 (Liabilities)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `Order.amount` | `u64` | `main.move` | The value of the coins locked in the order. |

## 3. 🧾 权益类变量 (Equity)

*None.*
