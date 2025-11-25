# 🚨 Finding 006: Reentrancy Vulnerability in NativeHTLC - Use of `.transfer()` Instead of CEI

## 📝 检查总览

| 序号 | 错误类型 | 位置 / 函数 / 文件 | 发现依据 | 风险等级 |
|------|----------|-------------------|----------|----------|
| 006 | Implementation Bug | `NativeHTLC.sol::redeem()` L219, `refund()` L242, `instantRefund()` L304 | Uses `.transfer()` which can fail with smart contract wallets, but state already updated | **LOW** |

---

## 🔍 详细说明

### 位置
- **File**: `evm/src/swap/NativeHTLC.sol`
- **Functions**: `redeem()`, `refund()`, `instantRefund()`
- **Lines**: 219, 242, 304

### 问题分析

#### Current Implementation
```solidity
// redeem() - Line 215-219
order.fulfilledAt = block.number;  // ✅ State updated first
emit Redeemed(orderID, secretHash, secret);
orderRedeemer.transfer(amount);  // ⚠️ Can fail with smart contracts

// refund() - Line 238-242
order.fulfilledAt = block.number;  // ✅ State updated first
emit Refunded(orderID);
order.initiator.transfer(order.amount);  // ⚠️ Can fail with smart contracts

// instantRefund() - Line 300-304
order.fulfilledAt = block.number;  // ✅ State updated first
emit Refunded(orderID);
order.initiator.transfer(order.amount);  // ⚠️ Can fail with smart contracts
```

### 为什么 `.transfer()` 有问题 (Why `.transfer()` is Problematic)

**`.transfer()` Limitations**:
1. **2300 gas stipend**: Only provides 2300 gas, insufficient for smart contract wallets
2. **Fails with fallback logic**: Gnosis Safe, Argent, other smart wallets may fail
3. **Hard-coded gas**: Cannot be adjusted for future EVM changes

**State Update Order**:
- ✅ **Good**: State is updated BEFORE `.transfer()` (CEI pattern followed)
- ✅ **Good**: Reentrancy is prevented by `fulfilledAt` check
- ⚠️ **Problem**: If `.transfer()` fails, state is already updated but funds not sent

### 影响分析

#### Scenario 1: Smart Contract Redeemer/Initiator
**Setup**:
1. Redeemer is a Gnosis Safe multisig
2. Gnosis Safe fallback requires >2300 gas
3. User calls `redeem()`

**Flow**:
```solidity
order.fulfilledAt = block.number;  // ✅ State updated
emit Redeemed(...);                 // ✅ Event emitted
orderRedeemer.transfer(amount);     // ❌ FAILS - Gnosis Safe needs >2300 gas
```

**Result**:
- Transaction reverts
- State is rolled back (Solidity atomicity)
- **No fund loss**, but user cannot redeem

#### Scenario 2: Future EVM Changes
**Setup**:
1. EVM gas costs change (e.g., EIP-1884 increased SLOAD cost)
2. 2300 gas no longer sufficient for basic operations

**Result**:
- All `.transfer()` calls may fail
- Contract becomes unusable

### 证据链

**Code Evidence**:
```solidity
// NativeHTLC.sol:219
orderRedeemer.transfer(amount);

// NativeHTLC.sol:242
order.initiator.transfer(order.amount);

// NativeHTLC.sol:304
order.initiator.transfer(order.amount);
```

**Comparison with HTLC.sol**:
```solidity
// HTLC.sol uses SafeERC20.safeTransfer (better)
token.safeTransfer(redeemer, amount);
```

### 为什么这是 LOW 风险 (Why This is LOW Risk)

**Mitigating Factors**:
1. ✅ **CEI pattern followed**: State updated before external call
2. ✅ **Reentrancy protected**: `fulfilledAt` check prevents re-entry
3. ✅ **Transaction atomicity**: If `.transfer()` fails, entire transaction reverts (state rolled back)
4. ✅ **No fund loss**: Funds remain in contract, user can retry

**Why NOT Medium/High**:
- No fund loss possible
- User can work around by using EOA instead of smart contract
- State rollback prevents inconsistency

### 建议修复

#### Option 1: Use `.call{value: amount}("")` (Recommended)
```diff
- orderRedeemer.transfer(amount);
+ (bool success, ) = orderRedeemer.call{value: amount}("");
+ require(success, "NativeHTLC: ETH transfer failed");
```

**Pros**:
- Works with smart contract wallets
- No gas limit
- Future-proof

**Cons**:
- Slightly more gas
- Requires explicit success check

#### Option 2: Add Withdrawal Pattern
```solidity
mapping(address => uint256) public pendingWithdrawals;

function redeem(bytes32 orderID, bytes calldata secret) external {
    // ... existing checks ...
    order.fulfilledAt = block.number;
    emit Redeemed(orderID, secretHash, secret);
    
    pendingWithdrawals[orderRedeemer] += amount;
}

function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    require(amount > 0, "No pending withdrawal");
    pendingWithdrawals[msg.sender] = 0;
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Withdrawal failed");
}
```

**Pros**:
- Completely eliminates reentrancy risk
- User controls gas for withdrawal
- Most secure pattern

**Cons**:
- Requires two transactions
- More complex UX
- Higher total gas cost

### 风险评级理由

- **LOW**: 
  - No fund loss possible
  - Transaction atomicity prevents state inconsistency
  - Reentrancy is already prevented by CEI pattern
  - Only affects smart contract users (minority)
  - Workaround exists (use EOA)

**Not MEDIUM because**:
- No economic loss
- State remains consistent
- Easy workaround

---

## ✅ 验证完成 (Verification Complete)

1. ✅ Analyzed `.transfer()` usage in all functions
2. ✅ Verified CEI pattern is followed
3. ✅ Confirmed reentrancy is prevented
4. ✅ Identified smart contract wallet compatibility issue
5. ✅ Verified no fund loss possible due to transaction atomicity
6. ✅ Proposed safer alternatives
