# ⚠️ 使用固定 Gas 的 ETH 转账导致智能合约钱包无法赎回 (Native Transfer Limit)

## 1. 发现 (Discovery)

在 `NativeHTLC.sol` 合约中，`redeem` 和 `refund` 函数使用 Solidity 的原生 `.transfer()` 方法发送 ETH。该方法强制限制接收方的 Gas limit 为 2300。

### 涉及位置 (Locations)

*   **EVM**: `evm/src/swap/NativeHTLC.sol`
    *   Line 221: `orderRedeemer.transfer(amount);`
    *   Line 245: `order.initiator.transfer(order.amount);`

## 2. 详细说明 (Details)

```solidity
// evm/src/swap/NativeHTLC.sol

function redeem(...) external {
    // ...
    // NOTE: .transfer() uses 2300 gas stipend. ...
    orderRedeemer.transfer(amount); 
}

function refund(...) external {
    // ...
    order.initiator.transfer(order.amount);
}
```

虽然代码注释指出这是为了防止重入攻击的有意设计，但它对**账户分类**造成了严重的负面影响。许多现代智能合约钱包（如 Gnosis Safe）在接收 ETH 时需要执行逻辑（如更新状态、发出事件），所需的 Gas 通常超过 2300。

## 3. 影响 (Impact)

这是一个 **Medium (中等)** 级别的可用性/资产限制风险。

1.  **服务拒绝 (DoS)**: 如果 Redeemer 或 Initiator 是智能合约钱包，尝试 `redeem` 或 `refund` 将会因为 Out of Gas 而失败。
2.  **资金永久锁定**: 除非智能合约钱包有某种方式可以通过升级来降低接收 ETH 的 Gas 消耗（通常不可能），否则这些资金将永久锁定在 HTLC 合约中。
3.  **违反审计目标**: 从会计师视角看，这属于资产的**演示与披露**（Presentation）问题——资产名义上属于用户，但由于技术限制实际上无法处置。

## 4. 建议 (Recommendation)

建议使用 `.call{value: amount}("")` 替代 `.transfer()`，并结合 **Checks-Effects-Interactions** 模式和 **ReentrancyGuard** 来防止重入攻击。这是目前 Solidity 开发的最佳实践。

```solidity
(bool success, ) = recipient.call{value: amount}("");
require(success, "Transfer failed");
```

