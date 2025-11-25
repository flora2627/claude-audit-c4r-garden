# 🚨 Finding 005: Accounting Invariant Violation Risk - No Balance Reconciliation

## 📝 检查总览

| 序号 | 错误类型 | 位置 / 函数 / 文件 | 发现依据 | 风险等级 |
|------|----------|-------------------|----------|----------|
| 005 | Financial Model Flaw | `HTLC.sol` - All financial functions | No mechanism to verify `token.balanceOf(this) >= sum(active_orders.amount)` | **MEDIUM** |

---

## 🔍 详细说明

### 位置
- **File**: `evm/src/swap/HTLC.sol`
- **Functions**: All (`initiate`, `redeem`, `refund`, `instantRefund`)
- **Invariant**: `token.balanceOf(address(this)) >= sum(orders[i].amount for all active orders)`

### 问题分析

#### Expected Accounting Invariant
From `acc_modeling/account_ivar.md`:
```markdown
### 2.1 Entity A: `HTLC.sol` (EVM)
*   **Assets**: `token.balanceOf(address(this))`
*   **Liabilities**: `Sum(orders[i].amount)`
*   **[!] Intra-Entity Invariant**: `token.balanceOf(address(this)) >= Sum(active_orders.amount)`
```

#### Current Implementation - No Verification

**Initiate Functions**:
```solidity
// Line 321
token.safeTransferFrom(funder_, address(this), amount_);
```
- ✅ Increases `token.balanceOf(this)` by `amount_`
- ✅ Increases `orders[orderID].amount` by `amount_`
- ✅ Invariant maintained (assuming transfer succeeds)

**Redeem Function**:
```solidity
// Line 257
token.safeTransfer(redeemer, amount);
```
- ✅ Decreases `token.balanceOf(this)` by `amount`
- ✅ Marks order as fulfilled (`fulfilledAt = block.number`)
- ✅ Invariant maintained

**Refund Functions**:
```solidity
// Line 280, 349
token.safeTransfer(order.initiator, order.amount);
```
- ✅ Decreases `token.balanceOf(this)` by `order.amount`
- ✅ Marks order as fulfilled
- ✅ Invariant maintained

### 潜在破坏场景 (Potential Violation Scenarios)

#### Scenario 1: Fee-on-Transfer Tokens
**Token Type**: Tokens that charge a fee on transfer (e.g., USDT with fee enabled)

**Attack Flow**:
1. User calls `initiate(redeemer, timelock, 1000, secretHash)`
2. User's balance: `-1000` tokens
3. Contract receives: `1000 - fee` tokens (e.g., 990 tokens)
4. `orders[orderID].amount = 1000` (liability)
5. **Invariant Broken**: `balanceOf(this) = 990 < orders[orderID].amount = 1000`

**Impact**:
- If multiple orders exist, last redeemer cannot withdraw full amount
- Contract becomes insolvent

#### Scenario 2: Rebasing Tokens
**Token Type**: Tokens that rebase (e.g., stETH, aTokens)

**Attack Flow**:
1. User initiates order with `amount = 1000`
2. Token rebases down to 900
3. `balanceOf(this) = 900`
4. `orders[orderID].amount = 1000`
5. **Invariant Broken**: `balanceOf(this) < orders[orderID].amount`

#### Scenario 3: Direct Token Transfer
**Attack Flow**:
1. Attacker directly transfers tokens to contract (not via `initiate`)
2. `balanceOf(this)` increases
3. No corresponding order created
4. **Invariant**: `balanceOf(this) > sum(orders.amount)` (excess funds)

**Impact**:
- Excess funds stuck in contract
- No mechanism to recover

### 证据链

**Code Evidence**:
```solidity
// No balance verification in any function
// No way to check total liabilities vs total assets
// No emergency withdrawal for excess funds
```

**From Accounting Model** (`acc_modeling/account_ivar.md`):
```markdown
**[!] Intra-Entity Invariant**: `token.balanceOf(address(this)) >= Sum(active_orders.amount)`
```

### 影响分析

#### 1. **Implementation Bug (编码层)**
- **No Balance Check**: Contract assumes `safeTransferFrom` always transfers exact amount
- **No Insolvency Detection**: No way to detect if contract becomes insolvent
- **No Recovery Mechanism**: No way to recover from invariant violation

#### 2. **Financial Model Flaw (金融层)**
- **Insolvency Risk**: Contract can become insolvent with fee-on-transfer tokens
- **Last Withdrawer Problem**: Last user to redeem/refund may fail due to insufficient balance
- **Stuck Funds**: Excess funds (from direct transfers) cannot be recovered

### 建议修复

#### Option 1: Add Balance Verification (Recommended for Fee-on-Transfer)
```diff
  function _initiate(...) internal returns (bytes32 orderID) {
+     uint256 balanceBefore = token.balanceOf(address(this));
      token.safeTransferFrom(funder_, address(this), amount_);
+     uint256 balanceAfter = token.balanceOf(address(this));
+     uint256 actualReceived = balanceAfter - balanceBefore;
+     require(actualReceived == amount_, "HTLC: fee-on-transfer not supported");
      
      // ... rest of function
  }
```

#### Option 2: Document Supported Token Types
```solidity
/**
 * @notice IMPORTANT: This contract does NOT support:
 *         - Fee-on-transfer tokens
 *         - Rebasing tokens
 *         - Tokens with transfer hooks
 *         Only standard ERC20 tokens are supported.
 */
```

#### Option 3: Add Emergency Withdrawal for Owner
```solidity
function emergencyWithdraw(uint256 amount) external onlyOwner {
    uint256 excess = token.balanceOf(address(this)) - getTotalLiabilities();
    require(amount <= excess, "HTLC: insufficient excess");
    token.safeTransfer(owner(), amount);
}

function getTotalLiabilities() public view returns (uint256 total) {
    // Note: This requires tracking all active orderIDs
    // Current implementation doesn't support this
}
```

### 风险评级理由

- **MEDIUM**: 
  - Only affects specific token types (fee-on-transfer, rebasing)
  - Standard ERC20 tokens work correctly
  - No direct exploit for standard tokens
  - Documentation can mitigate risk
  - Insolvency is detectable off-chain

**Not HIGH because**:
- Most tokens don't have fees
- Can be mitigated by documentation
- Users can verify token type before using

**Not LOW because**:
- Real risk with fee-on-transfer tokens
- No recovery mechanism
- Affects protocol solvency

---

## ✅ 验证完成 (Verification Complete)

1. ✅ Analyzed accounting invariant from `account_ivar.md`
2. ✅ Verified no balance reconciliation in code
3. ✅ Identified fee-on-transfer token risk
4. ✅ Identified rebasing token risk
5. ✅ Identified stuck funds risk (direct transfers)
6. ✅ Proposed mitigation strategies
