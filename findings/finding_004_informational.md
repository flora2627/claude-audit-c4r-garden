# ⚠️ Finding 004: Signature Replay Protection Analysis - No Nonce, Relies on Duplicate Order Check

## 📝 检查总览

| 序号 | 错误类型 | 位置 / 函数 / 文件 | 发现依据 | 风险等级 |
|------|----------|-------------------|----------|----------|
| 004 | Design Analysis | `HTLC.sol::initiateWithSignature()` L212-224 | No explicit nonce, signature replay prevented by orderID uniqueness | **INFORMATIONAL** |

---

## 🔍 详细说明

### 位置
- **File**: `evm/src/swap/HTLC.sol`
- **Function**: `initiateWithSignature()`
- **Lines**: 212-224

### 问题分析

#### Current Implementation
```solidity
function initiateWithSignature(
    address initiator,
    address redeemer,
    uint256 timelock,
    uint256 amount,
    bytes32 secretHash,
    bytes calldata signature
) external safeParams(initiator, redeemer, timelock, amount) {
    bytes32 hash = _hashTypedDataV4(keccak256(abi.encode(
        _INITIATE_TYPEHASH, 
        redeemer, 
        timelock, 
        amount, 
        secretHash
    )));
    require(SignatureChecker.isValidSignatureNow(initiator, hash, signature), HTLC__InvalidInitiatorSignature());
    _initiate(initiator, initiator, redeemer, timelock, amount, secretHash);
}
```

#### Signature Replay Protection Mechanism

**No Explicit Nonce**, but protected by:
1. **OrderID Uniqueness**: `_initiate()` generates orderID from `(chainid, secretHash, initiator, redeemer, timelock, amount, address(this))`
2. **Duplicate Check**: Line 308 in `_initiate()` checks `orders[orderID].timelock == 0`
3. **SecretHash Uniqueness**: Each signature includes `secretHash`, which should be unique per order

**Replay Attack Attempt**:
1. Attacker captures valid signature for `(redeemer, timelock, amount, secretHash)`
2. Attacker tries to replay signature
3. `_initiate()` generates same orderID
4. **FAIL**: Line 308 check `orders[orderID].timelock == 0` fails
5. Transaction reverts with `HTLC__DuplicateOrder()`

### 为什么这是安全的 (Why This is Secure)

**Good Design**:
1. ✅ **Signature includes all order parameters**: `(redeemer, timelock, amount, secretHash)`
2. ✅ **SecretHash acts as implicit nonce**: Should be unique per order
3. ✅ **Duplicate order check prevents replay**: Same signature → same orderID → duplicate check fails
4. ✅ **EIP712 domain separation**: Includes contract address and chain ID

**Why Replay is Not Possible**:
- Same signature → same orderID → duplicate check fails
- Different secretHash → different signature required
- Different chain → different domain separator → signature invalid

### 潜在边界情况 (Edge Cases)

#### Case 1: Cross-Chain Replay
**Scenario**: Attacker replays signature on different chain
- **Protection**: EIP712 includes `block.chainid` in domain separator
- **Result**: Signature invalid on different chain ✅

#### Case 2: After Order Fulfillment
**Scenario**: Order is fulfilled (redeemed/refunded), attacker tries to replay signature
- **Current Behavior**: 
  - `orders[orderID].timelock != 0` (order exists)
  - Line 308 check fails with `HTLC__DuplicateOrder()`
  - **Result**: Replay blocked ✅

#### Case 3: User Wants to Create Identical Order
**Scenario**: User legitimately wants to create another order with same parameters
- **Problem**: Cannot reuse same signature (duplicate check fails)
- **Solution**: User must generate new `secretHash` → new signature required
- **Impact**: User experience issue, but not a security vulnerability

### 建议改进 (Suggested Improvements)

#### Option 1: Add Explicit Nonce (More Explicit)
```diff
+ mapping(address => uint256) public nonces;

  function initiateWithSignature(...) external {
      bytes32 hash = _hashTypedDataV4(keccak256(abi.encode(
          _INITIATE_TYPEHASH, 
          redeemer, 
          timelock, 
          amount, 
          secretHash,
+         nonces[initiator]++  // ✅ Explicit nonce
      )));
      // ... rest of function
  }
```

**Pros**:
- More explicit replay protection
- Allows identical orders with different nonces
- Standard EIP712 pattern

**Cons**:
- Increases gas cost (SSTORE)
- Breaks existing signatures
- Adds complexity

#### Option 2: Keep Current Design (Recommended)
**Rationale**:
- SecretHash already acts as implicit nonce
- Duplicate order check is sufficient
- Simpler implementation
- Lower gas cost

### 风险评级理由

- **INFORMATIONAL**: 
  - No security vulnerability
  - Signature replay is properly prevented
  - Design is intentional and secure
  - Edge cases are handled correctly

**This is NOT a vulnerability**, just a design analysis for documentation purposes.

---

## ✅ 验证完成 (Verification Complete)

1. ✅ Analyzed `initiateWithSignature()` signature scheme
2. ✅ Verified EIP712 implementation is correct
3. ✅ Confirmed signature replay is prevented by orderID uniqueness
4. ✅ Tested edge cases (cross-chain, post-fulfillment, identical orders)
5. ✅ **Conclusion**: Design is secure, no vulnerability found
