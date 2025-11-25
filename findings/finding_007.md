# 🚨 Finding 007: OrderID Collision in NativeHTLC - Missing Funder in Hash (Same as Finding 003)

## 📝 检查总览

| 序号 | 错误类型 | 位置 / 函数 / 文件 | 发现依据 | 风险等级 |
|------|----------|-------------------|----------|----------|
| 007 | Implementation Bug | `NativeHTLC.sol::_initiate()` L261-262 | OrderID does not include funder, allowing collision in `initiateOnBehalf` | **HIGH** |

---

## 🔍 详细说明

### 位置
- **File**: `evm/src/swap/NativeHTLC.sol`
- **Function**: `_initiate()`
- **Lines**: 261-262

### 问题分析

**This is the SAME vulnerability as Finding 003 in HTLC.sol**

#### Current OrderID Generation
```solidity
// Line 261-262
orderID = sha256(abi.encode(
    block.chainid, 
    secretHash_, 
    initiator_,      // ❌ Uses initiator, NOT funder (msg.sender)
    redeemer_, 
    timelock_, 
    msg.value,       // ✅ Uses msg.value (amount from funder)
    address(this)
));
```

**Collision Scenario**:
1. Alice calls `initiateOnBehalf(Bob, Charlie, 100, secretHash)` with 1 ETH
   - `funder = Alice (msg.sender)`
   - `initiator = Bob`
   - `orderID = sha256(chainid, secretHash, Bob, Charlie, 100, 1 ETH, this)`

2. Bob calls `initiate(Charlie, 100, secretHash)` with 1 ETH
   - `funder = Bob (msg.sender)`
   - `initiator = Bob`
   - `orderID = sha256(chainid, secretHash, Bob, Charlie, 100, 1 ETH, this)` ← **SAME!**

3. **Result**: Bob's transaction reverts with `NativeHTLC__DuplicateOrder()`

### 证据链

```solidity
// NativeHTLC.sol:148-158
function initiateOnBehalf(
    address payable initiator,
    address payable redeemer,
    uint256 timelock,
    uint256 amount,
    bytes32 secretHash
) external payable safeParams(initiator, redeemer, timelock, amount) {
    require(msg.sender != redeemer, NativeHTLC__SameFunderAndRedeemer());
    require(initiator != address(0), NativeHTLC__ZeroAddressInitiator());
    _initiate(initiator, redeemer, timelock, secretHash);
    //        ^^^^^^^^^
    //        initiator (NOT msg.sender)
}

// NativeHTLC.sol:257-276
function _initiate(
    address payable initiator_,
    address payable redeemer_,
    uint256 timelock_,
    bytes32 secretHash_
) internal returns (bytes32 orderID) {
    orderID = sha256(abi.encode(
        block.chainid, 
        secretHash_, 
        initiator_,  // ❌ Only initiator, NOT msg.sender (funder)
        redeemer_, 
        timelock_, 
        msg.value,   // ✅ But uses msg.value from funder
        address(this)
    ));
    
    require(orders[orderID].timelock == 0, NativeHTLC__DuplicateOrder());
    
    orders[orderID] = Order({
        initiator: initiator_,
        redeemer: redeemer_,
        initiatedAt: block.number,
        timelock: timelock_,
        amount: msg.value,  // ✅ Stores msg.value
        fulfilledAt: 0
    });
    
    emit Initiated(orderID, secretHash_, msg.value);
}
```

### 影响分析

**Same as Finding 003**:
- Front-running attacks
- Griefing/DoS
- Malicious relayer exploitation

### 建议修复

**Same as Finding 003** - Include `msg.sender` (funder) in orderID:

```diff
  orderID = sha256(abi.encode(
      block.chainid, 
      secretHash_, 
+     msg.sender,   // ✅ Add funder to prevent collision
      initiator_,
      redeemer_, 
      timelock_, 
      msg.value, 
      address(this)
  ));
```

### 风险评级理由

- **HIGH**: Same reasoning as Finding 003
  - Allows front-running attacks
  - Enables griefing/DoS
  - Affects core protocol functionality

---

## ✅ 验证完成 (Verification Complete)

1. ✅ Confirmed same vulnerability as HTLC.sol (Finding 003)
2. ✅ Verified orderID does not include funder
3. ✅ Confirmed collision possible between `initiate()` and `initiateOnBehalf()`
4. ✅ Same fix applies: include `msg.sender` in orderID hash
