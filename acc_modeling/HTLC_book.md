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

## 4. ⚙️ 模型约束 (Constraints)

### 4.1 Order Uniqueness & Identity
$$
\text{OrderID} = \text{Hash}(\text{ChainID}, \text{SecretHash}, \text{Initiator}, \text{Redeemer}, \text{Timelock}, \text{Amount}, \text{Contract})
$$
*   **Constraint**: OrderID does **NOT** include the Funder (`msg.sender`).
*   **Implication**: Two different funders cannot create orders with identical parameters. This is intentional to support Relayers (Funder $\neq$ Initiator).

### 4.2 Asset-Liability Matching
$$
\text{balanceOf}(this) \ge \sum_{\text{active}} \text{orders}[i].\text{amount}
$$
*   **Assumption**: Token transfer logic is 1:1 (no fee-on-transfer, no rebasing).
*   **Risk**: If fee-on-transfer tokens are used, Assets < Liabilities immediately upon deposit. Protocol documentation must exclude these token types.
