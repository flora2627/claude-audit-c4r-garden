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

---

# 🔴 STRICT SECURITY AUDIT REPORT

## Executive Verdict

**FALSE POSITIVE** - This is intentional protocol design, not a vulnerability. Zero economic risk.

## Reporter's Claim Summary

Collision in orderID generation allows front-running attack where Alice calls `initiateOnBehalf(Bob, ...)` to block Bob's `initiate(...)` transaction, causing DoS/griefing.

## Code-Level Analysis

### Verified Code Behavior

**File**: `evm/src/swap/NativeHTLC.sol`

**L261-262** - OrderID generation:
```solidity
orderID = sha256(abi.encode(block.chainid, secretHash_, initiator_, redeemer_, timelock_, msg.value, address(this)));
// Does NOT include msg.sender (funder)
```

**L229-243** - Refund mechanism (CRITICAL):
```solidity
function refund(bytes32 orderID) external {
    Order storage order = orders[orderID];
    // ... validation ...
    order.initiator.transfer(order.amount);  // ← Sends to INITIATOR, not funder
}
```

**L194-220** - Redeem mechanism:
```solidity
function redeem(bytes32 orderID, bytes calldata secret) external {
    // ... validation ...
    orderRedeemer.transfer(amount);  // ← Sends to REDEEMER
}
```

**CONFIRMED**: Collision CAN occur. OrderID identical when all parameters match.

## Call Chain Trace

### Attack Scenario: Alice Front-Runs Bob

**Call 1: `initiateOnBehalf()` by Alice**
```
1. Entry: NativeHTLC::initiateOnBehalf(Bob, Charlie, 100, 1ETH, hash) @ L148
   ├─ Caller: Alice (EOA)
   ├─ msg.sender: Alice
   ├─ msg.value: 1 ETH
   └─ Call type: external payable

2. Internal: _initiate(Bob, Charlie, 100, hash) @ L257
   ├─ msg.sender: Alice (preserved)
   ├─ msg.value: 1 ETH (preserved)
   ├─ orderID = sha256(chainid, hash, Bob, Charlie, 100, 1ETH, this)
   ├─ Creates Order{ initiator: Bob, redeemer: Charlie, amount: 1ETH }
   └─ ETH locked in contract (from Alice)

Result: Order created. Alice paid 1 ETH. Bob is initiator.
```

**Call 2: `initiate()` by Bob**
```
1. Entry: NativeHTLC::initiate(Charlie, 100, 1ETH, hash) @ L107
   ├─ Caller: Bob (EOA)
   ├─ msg.sender: Bob
   ├─ msg.value: 1 ETH
   └─ Call type: external payable

2. Internal: _initiate(Bob, Charlie, 100, hash) @ L257
   ├─ msg.sender: Bob (preserved)
   ├─ msg.value: 1 ETH (preserved)
   ├─ orderID = sha256(chainid, hash, Bob, Charlie, 100, 1ETH, this)
   ├─ orderID MATCHES existing order
   ├─ Check: orders[orderID].timelock == 0  → FALSE (timelock=100)
   └─ REVERT: NativeHTLC__DuplicateOrder()

Result: Transaction reverts. Bob's 1 ETH never leaves wallet.
```

## State Scope & Context Audit

### Storage Variables

**Global Storage:**
- `orders` mapping (L35): `mapping(bytes32 => Order)` - contract storage, global scope

**Order Struct (L22-29):**
```solidity
struct Order {
    address payable initiator;  // storage - CONTROLS REFUND
    address payable redeemer;   // storage - CONTROLS REDEEM
    uint256 initiatedAt;        // storage
    uint256 timelock;          // storage - used for duplicate check
    uint256 amount;            // storage
    uint256 fulfilledAt;       // storage
}
```

**Context Variables:**
- `msg.sender`: Used in checks (L155), NOT in orderID or Order struct
- `msg.value`: Used in orderID (L262), stored in Order.amount (L271)
- `block.number`: Used in initiatedAt (L269), refund check (L236)
- `block.chainid`: Used in orderID (L262)

**CRITICAL FINDING**:
- Funder (msg.sender in `initiateOnBehalf`) is NEVER stored
- Initiator has refund rights, NOT funder
- This is BY DESIGN for relayer pattern

## Exploit Feasibility

### Prerequisites (100% Attacker-Controlled)

✅ **Attacker can execute**: Any EOA can call `initiateOnBehalf()` - no permissions required

✅ **Attacker needs to know**:
- Victim's exact parameters (redeemer, timelock, amount, secretHash)
- Obtainable via mempool monitoring

✅ **Attacker must pay**:
- Full swap amount upfront (e.g., 1 ETH)

### Attack Execution

**Step 1**: Alice monitors mempool, sees Bob's pending `initiate(Charlie, 100, 1ETH, hash)`

**Step 2**: Alice extracts parameters, submits `initiateOnBehalf(Bob, Charlie, 100, 1ETH, hash)` with higher gas

**Step 3**: Alice's tx mines first, Bob's tx reverts

**Step 4**: Alice has now...
- Paid 1 ETH
- Created order where Bob is initiator
- Bob can refund Alice's 1 ETH after timelock
- Charlie can redeem Alice's 1 ETH if has secret

**Step 5**: Alice waits... and loses money

### Who Controls What?

| Actor | Paid | Can Refund | Can Redeem | Gains | Loses |
|-------|------|------------|------------|-------|-------|
| Alice (attacker) | 1 ETH | ❌ NO | ❌ NO | Nothing | 1 ETH |
| Bob (victim) | 0 ETH | ✅ YES | ❌ NO | 1 ETH | Nothing |
| Charlie (redeemer) | 0 ETH | ❌ NO | ✅ YES (if secret) | 1 ETH | Nothing |

## Economic Analysis

### Attack Cost-Benefit

**Attacker (Alice) P&L:**
```
Costs:
- 1 ETH (locked, unrecoverable by Alice)
- ~50,000 gas (~$10 at 50 gwei, $2000 ETH)
- Total: ~1.005 ETH

Gains:
- Bob's transaction reverted (temporary inconvenience)
- Bob can retry with different parameters
- Alice controls: NOTHING

Recovery Options:
- Refund to Alice? NO (goes to Bob)
- Redeem as Alice? NO (only Charlie can redeem)
- Front-run refund? NO (any EOA can call, sends to Bob)

Net P&L: -1.005 ETH (-100%)
```

**Victim (Bob) P&L:**
```
Costs:
- Failed gas (~$5)
- Must change ONE parameter to retry

Gains:
- Can refund Alice's 1 ETH after timelock (block.number + 100)
- Net gain: +1 ETH (Alice's money)

Alternative:
- Wait for Alice's order to expire
- Call refund(orderID)
- Receive 1 ETH from Alice
```

### Economic Viability: NEGATIVE EV

**ROI Calculation:**
```
Expected Value = P(profit) × Gain - P(loss) × Cost
               = 0% × $0 - 100% × $2000
               = -$2000

Expected Return: -100%
Breakeven Condition: NONE (impossible to profit)
```

**Sensitivity Analysis:**

| Scenario | Alice's Outcome | Bob's Outcome | Economically Viable? |
|----------|----------------|---------------|---------------------|
| Charlie redeems | Loses 1 ETH to Charlie | Unaffected | ❌ NO |
| Bob refunds | Loses 1 ETH to Bob | Gains 1 ETH | ❌ NO (for Alice) |
| Timeout forever | 1 ETH locked forever | Can unlock anytime | ❌ NO |
| Alice "extorts" Bob | Bob ignores, refunds | Gains 1 ETH | ❌ NO |

**Conclusion**: NO scenario where attacker profits. ALL scenarios result in attacker loss.

### Real-World Attack Likelihood

**Griefing Attack Cost:**
- To block Bob's 1 ETH swap: Pay 1 ETH
- To block Bob's 10 ETH swap: Pay 10 ETH
- To block Bob's 100 ETH swap: Pay 100 ETH

**Griefing Efficiency:** 100% cost to inflict 0% loss (victim actually gains)

**Comparison to Standard Griefing:**
- Gas-only griefing: ~$10 to block transaction (temporary)
- This "attack": $2000 to block transaction AND give victim $2000

**Rational Attacker Decision:** NEVER execute this attack

## Dependency/Library Reading

### OpenZeppelin EIP712 (v5.2.0)

**Import** (L4): `@openzeppelin/contracts/utils/cryptography/EIP712.sol`

**Usage** (L95, L315):
```solidity
constructor() EIP712(name, version) {}
function instantRefundDigest(bytes32 orderID) public view returns (bytes32) {
    return _hashTypedDataV4(keccak256(abi.encode(_REFUND_TYPEHASH, orderID)));
}
```

**Verified Behavior**: Standard EIP712 domain separator. No impact on orderID collision logic.

### No External Token Calls

NativeHTLC handles native ETH only. No `safeTransferFrom()` calls that could affect state.

**ETH Transfers**:
- L219: `orderRedeemer.transfer(amount)` - push pattern, no reentrancy risk in state update
- L242: `order.initiator.transfer(order.amount)` - push pattern, state already updated (L238)

**Reentrancy Protection**: fulfilledAt set BEFORE transfer (checks-effects-interactions pattern)

## Final Feature-vs-Bug Assessment

### Evidence This Is INTENTIONAL DESIGN

**1. Function Naming**
- `initiateOnBehalf` - explicitly indicates proxy action
- Separate `funder` vs `initiator` parameters in HTLC.sol (L171)

**2. Refund Logic**
```solidity
// NativeHTLC.sol:242
order.initiator.transfer(order.amount);
// Does NOT send to msg.sender or original funder
```
**Intent**: Initiator has control rights, not funder

**3. Order Struct Design**
```solidity
struct Order {
    address payable initiator;  // ← Stored
    address payable redeemer;   // ← Stored
    // NO funder field          // ← Funder never tracked
    // ...
}
```
**Intent**: Protocol doesn't care WHO funded, only WHO controls

**4. OrderID Semantics**
- OrderID represents SWAP PARAMETERS (initiator, redeemer, amount, timelock, secret)
- NOT funding transaction metadata
- Prevents duplicate swaps with identical parameters
- **This is correct**: Two swaps with identical parameters should have identical IDs

**5. Use Case: Relayer Service Pattern**

**Intended Flow:**
```
User (Alice): "I want atomic swap BTC→ETH"
Relayer (Bob): "I'll pay gas and fund ETH HTLC on your behalf"
              "You retain control and refund rights"
              "We have off-chain service agreement"

Bob calls: initiateOnBehalf(Alice, redeemer, timelock, amount, hash)
- Bob pays ETH
- Alice is initiator (has refund control)
- If swap fails, Alice refunds Bob's ETH back to... Alice (per their agreement)
```

**Why this makes sense:**
- Relayer provides liquidity service
- User maintains trustless control
- Off-chain payment for service (fee deducted before refund, etc.)
- Protocol is neutral to funding source

**6. Duplicate Prevention is CORRECT**

If order with parameters `(Bob, Charlie, 100, 1ETH, hash)` exists:
- Someone already created this exact swap
- Creating identical swap makes NO SENSE
- Rejecting duplicate is CORRECT BEHAVIOR

### Why Reporter's Proposed "Fix" Would BREAK Protocol

**Reporter suggests**: Include `msg.sender` in orderID

**Consequence:**
- Same swap parameters, different funders = different orderIDs
- User (Bob) and Relayer (Alice on behalf of Bob) create "different" swaps
- But both have initiator=Bob, redeemer=Charlie, same secretHash
- When secret revealed, which orderID to use for cross-chain verification?
- **BREAKS** cross-chain atomic swap verification

**Cross-Chain Scenario:**
```
Chain A: Alice calls initiateOnBehalf(Bob, Charlie, hash)
         orderID_A = hash(..., Alice, Bob, Charlie, ...)  // includes Alice

Chain B: Bob calls initiate(Charlie, hash)
         orderID_B = hash(..., Bob, Bob, Charlie, ...)    // includes Bob

Problem: orderID_A ≠ orderID_B
- But they're the SAME atomic swap (same secret, same parties)
- Cross-chain verification FAILS
- Atomic swap protocol BROKEN
```

### Is "Collision" a Bug?

**NO** - It's preventing duplicates:

**Analogy**: Two people trying to create identical database records with same primary key
- System rejects second insert
- This is CORRECT behavior, not a bug
- Primary key ensures uniqueness

**In HTLC:**
- OrderID is primary key for swaps
- Identical swap parameters = identical orderID
- Second creation attempt correctly rejected
- **This prevents actual bugs** (duplicate orders, double-spending risk, etc.)

### What About the "Front-Running Attack"?

**Reporter's Scenario:** Alice front-runs Bob to grief him

**Reality Check:**
1. Alice must pay full swap amount (1 ETH)
2. Bob becomes initiator (has refund rights)
3. After timelock, Bob calls `refund(orderID)` and receives Alice's 1 ETH
4. **Bob profits 1 ETH, Alice loses 1 ETH**

**This is not an attack.** This is Alice donating money to Bob.

**Why would Alice do this?**
- **Malice**: Irrational economic behavior (costs her 1 ETH to minorly inconvenience Bob)
- **Service**: She's a relayer with off-chain agreement
- **Mistake**: She accidentally used Bob as initiator

**Rational actors:** Never execute this "attack"

## Conclusion

### VERDICT: FALSE POSITIVE

This report confuses:
- ✅ **Technical capability** (collision can occur)
- ❌ **Security vulnerability** (causes exploitable harm)

### Why This Is NOT a Vulnerability

1. **Zero Economic Risk**
   - "Attacker" loses 100% of funds
   - "Victim" gains 100% of attacker's funds
   - Expected value: -100% for attacker

2. **Intentional Protocol Design**
   - Relayer service provider pattern
   - Separation of funder vs. initiator roles
   - Correct duplicate prevention

3. **No Fund Loss**
   - No party loses money involuntarily
   - Worst case: Temporary inconvenience (change one parameter)
   - Attacker voluntarily donates money to "victim"

4. **Breaks Protocol If "Fixed"**
   - Including funder in orderID breaks cross-chain verification
   - Prevents legitimate relayer use cases
   - Allows actual duplicates

### Corrected Risk Assessment

- **Severity**: INFORMATIONAL (design documentation)
- **Likelihood**: N/A (not exploitable for profit)
- **Impact**: None (anti-profitable)
- **Risk**: NONE

### Recommendation

**No code change required.**

**Optional**: Add NatSpec documentation explaining relayer pattern:

```solidity
/**
 * @notice Creates HTLC order on behalf of another address (relayer pattern)
 * @dev Caller (msg.sender) provides funds, but `initiator` has refund control.
 *      Intended for relayer services that fund orders on behalf of users.
 *      WARNING: Do not call this with initiator != msg.sender unless you have
 *      off-chain agreement, as initiator can refund your funds after timelock.
 * @param initiator Address that will have refund rights (NOT msg.sender)
 * ...
 */
function initiateOnBehalf(...) external payable { ... }
```

### Related Findings

**Finding 003 (HTLC.sol)**: SAME ANALYSIS - Also FALSE POSITIVE

Both findings demonstrate misunderstanding of:
- Economic threat modeling (ignoring attacker ROI)
- Protocol design patterns (relayer service model)
- Duplicate prevention semantics (orderID as unique swap identifier)

---

## Audit Methodology Applied

✅ Independently read all source code (NativeHTLC.sol, HTLC.sol)
✅ Traced complete call chains with msg.sender context
✅ Analyzed state scope (storage vs memory, mapping keys)
✅ Verified refund/redeem destination addresses
✅ Calculated attacker P&L under realistic conditions
✅ Checked OpenZeppelin dependencies (EIP712)
✅ Evaluated economic viability (ROI = -100%)
✅ Confirmed no privileged account requirements
✅ Assessed feature vs bug (intentional design)
✅ Verified cross-chain implications

**Auditor's Note**: This finding demonstrates the importance of economic analysis in security audits. Technical capability to trigger code path ≠ exploitable vulnerability. Always calculate attacker ROI and verify who controls funds at each step.
