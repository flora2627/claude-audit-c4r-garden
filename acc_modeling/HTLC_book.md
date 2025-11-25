# HTLC (EVM) Accounting Book

## 1. 📦 资产类变量 (Assets)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `token` | `IERC20` | `HTLC.sol` | The ERC20 token contract address. The HTLC holds balances of this token. |
| `balanceOf(address(this))` | `uint256` | `ERC20` (external) | The actual token balance held by the HTLC contract. |

## 2. 💼 负债类变量 (Liabilities)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `orders` | `mapping(bytes32 => Order)` | `HTLC.sol` | Stores the details of each swap order. Represents the obligation to pay `redeemer` or refund `initiator`. |
| `orders[id].amount` | `uint256` | `HTLC.sol` | The amount of tokens locked in a specific order. Sum of all active order amounts should equal total assets. |

## 3. 🧾 权益类变量 (Equity)

*None. This is a pure escrow contract.*
