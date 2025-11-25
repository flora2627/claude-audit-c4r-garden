# NativeHTLC (EVM) Accounting Book

## 1. 📦 资产类变量 (Assets)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `address(this).balance` | `uint256` | `NativeHTLC.sol` | The amount of native ETH held by the contract. |

## 2. 💼 负债类变量 (Liabilities)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `orders` | `mapping(bytes32 => Order)` | `NativeHTLC.sol` | Stores the details of each swap order. |
| `orders[id].amount` | `uint256` | `NativeHTLC.sol` | The amount of ETH locked in a specific order. Sum of all active order amounts should equal total assets. |

## 3. 🧾 权益类变量 (Equity)

*None. This is a pure escrow contract.*
