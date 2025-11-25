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

## 4. ⚙️ 模型约束 (Constraints)

### 4.1 Address Determinism
The UDA address is strictly determined by the `CREATE2` formula:
$$
Address_{UDA} = \text{keccak256}(0xFF, \text{Deployer}, \text{Salt}, \text{keccak256}(\text{Bytecode}))
$$

Where:
- **Deployer**: `HTLCRegistry` address.
- **Salt**: Hash of `(refundAddress, redeemer, timelock, secretHash, amount, destinationData)`.
- **Bytecode**: Contains the **Implementation Address** (`implUDA` or `implNativeUDA`) as an immutable argument.

**Correction/Insight**: The "Implementation Address" is a variable input to the address derivation. If the Registry owner changes the implementation, the derived address for the *same* parameters changes. This breaks the assumption that `(User Params) -> Unique Address` is a static mapping.

🔁 **Knowledge Reflection**:
- **Misunderstanding**: Assumed UDA address was solely a function of user parameters.
- **Correction**: UDA address is a function of $f(\text{User Params}, \text{Global Impl Ptr})$.
- **Checkpoint**: Always check if the "Global Impl Ptr" is mutable when analyzing CREATE2 factories.
