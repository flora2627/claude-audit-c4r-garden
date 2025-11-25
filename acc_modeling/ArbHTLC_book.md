# ArbHTLC (EVM) Accounting Book

## 1. 📦 资产类变量 (Assets)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `token` | `IERC20` | `ArbHTLC.sol` | The ERC20 token contract address. |
| `balanceOf(address(this))` | `uint256` | `ERC20` (external) | The actual token balance held by the contract. |

## 2. 💼 负债类变量 (Liabilities)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `orders` | `mapping(bytes32 => Order)` | `ArbHTLC.sol` | Stores the details of each swap order. |
| `orders[id].amount` | `uint256` | `ArbHTLC.sol` | The amount of tokens locked in a specific order. |

## 3. 🧾 权益类变量 (Equity)

*None. This is a pure escrow contract.*
