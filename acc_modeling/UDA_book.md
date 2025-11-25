# UniqueDepositAddress (EVM) Accounting Book

## 1. 📦 资产类变量 (Assets)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| `balanceOf(address(this))` | `uint256` | `ERC20` (external) | The ERC20 tokens held transiently by the UDA before initialization. |
| `address(this).balance` | `uint256` | `NativeUniqueDepositAddress` | The ETH held transiently by the Native UDA before initialization. |

## 2. 💼 负债类变量 (Liabilities)

| 变量名 | 类型 | 所在合约 | 简要含义 |
| :--- | :--- | :--- | :--- |
| *Implicit* | `N/A` | `UDA.sol` | Before `initialize()` is called, the contract holds funds that implicitly belong to the depositor (or intended for the swap). Once initialized, funds move to HTLC. |

## 3. 🧾 权益类变量 (Equity)

*None. Transient proxy.*
