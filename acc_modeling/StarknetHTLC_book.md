# Starknet HTLC Accounting Book

## 1. 📦 资产类变量 (Assets)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `token` | `IERC20Dispatcher` | `htlc.cairo` | The ERC20 token contract address. |
| `token.balance_of(get_contract_address())` | `u256` | `ERC20` (external) | The actual token balance held by the HTLC contract. |

## 2. 💼 负债类变量 (Liabilities)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `orders` | `Map<felt252, Order>` | `htlc.cairo` | Stores the details of each swap order. |
| `orders[id].amount` | `u256` | `htlc.cairo` | The amount of tokens locked in a specific order. |

## 3. 🧾 权益类变量 (Equity)

*None.*
