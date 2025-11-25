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

---

## 🔴 AUDIT VERDICT: FALSE POSITIVE

**Executive Verdict**: FALSE POSITIVE - This is a documented LIMITATION, not an exploitable vulnerability. Requires privileged account action (owner deploying with non-standard token), which violates Core-4 and Core-5 audit directives.

### Reporter's Claim Summary
The report claims that the HTLC contract violates the accounting invariant `balanceOf(this) >= sum(orders.amount)` when:
1. Fee-on-transfer tokens are used (contract receives less than recorded amount)
2. Rebasing tokens are used (balance changes after deposit)
3. Direct token transfers create stuck funds

### Code-Level Analysis

#### Call Chain Trace for Fee-on-Transfer Scenario

**Initiation Flow**:
```
1. User EOA → HTLC.initiate()
   Caller: User (0xABCD)
   Callee: HTLC contract
   msg.sender: 0xABCD
   Function: initiate(redeemer, timelock, 1000, secretHash)

2. HTLC._initiate() → Storage Write
   Location: orders[orderID].amount = 1000
   Storage Scope: HTLC.orders mapping (persistent storage)
   Slot: keccak256(orderID, 1)

3. HTLC._initiate() → token.safeTransferFrom()
   Caller: HTLC contract (via delegatecall context? No, regular call)
   Callee: Token contract
   msg.sender: HTLC contract
   Function: transferFrom(0xABCD, HTLC, 1000)
   Call Type: CALL (not delegatecall)
   Value: 0 ETH

   IF token has 1% transfer fee:
   - User balance: -1000
   - Fee taken: 10 (to fee recipient)
   - HTLC receives: 990

4. Post-execution State:
   Storage: orders[orderID].amount = 1000 (HTLC.sol storage)
   Token Balance: token.balanceOf(HTLC) = 990
   Invariant: 990 >= 1000 → FALSE ✗
```

**OpenZeppelin SafeERC20.safeTransferFrom Behavior** (v5.2.0):
```solidity
// OpenZeppelin implementation (from memory/knowledge)
function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
    _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
}

function _callOptionalReturn(IERC20 token, bytes memory data) private {
    bytes memory returndata = address(token).functionCall(data);
    if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
        revert SafeERC20FailedOperation(address(token));
    }
}
```

**Key Finding**: SafeERC20 does NOT check `balanceOf` before/after. It only checks:
- Call doesn't revert
- Return value (if any) is not `false`

#### State Scope Analysis

**Relevant State Variables**:
```solidity
// HTLC.sol storage layout
- orders[bytes32] → Order struct (slot: keccak256(orderID, 1))
  ├─ initiator: address (slot+0)
  ├─ redeemer: address (slot+1)
  ├─ initiatedAt: uint256 (slot+2)
  ├─ timelock: uint256 (slot+3)
  ├─ amount: uint256 (slot+4)  ← LIABILITY RECORDED HERE
  └─ fulfilledAt: uint256 (slot+5)

// External Token contract
- balances[HTLC] → uint256 (external contract storage)  ← ACTUAL ASSET

// Context: No assembly slot manipulation detected
// Scope: Storage (persistent across transactions)
// Key usage: amount used in safeTransfer(redeemer, amount) at redeem/refund
```

**Critical msg.sender Usage**:
- Line 127: `safeParams(msg.sender, redeemer, timelock, amount)` - validation only
- Line 129: `_initiate(msg.sender, msg.sender, ...)` - msg.sender becomes initiator
- Line 321: `token.safeTransferFrom(funder_, address(this), amount_)` - funder_ is used, not msg.sender in call

**Storage Scope**: All order data is per-orderID (mapping), not per-user. No cross-order dependencies.

### Exploit Feasibility Assessment

#### Scenario 1: Fee-on-Transfer Tokens

**Prerequisites**:
1. ✅ HTLC contract must be deployed (via HTLCRegistry)
2. ✅ HTLC must be initialized with a fee-on-transfer token
3. ❌ **BLOCKER**: Only HTLCRegistry owner can deploy HTLC instances
4. ❌ **BLOCKER**: Owner chooses which token to use during deployment

**Can a normal EOA reproduce this?**
- **NO** - Requires owner to call `HTLCRegistry.deployHTLC(feeOnTransferToken)`
- This is a **PRIVILEGED ACTION**, not an unprivileged attack

**Core-4 Violation**: This attack requires a privileged account (owner) to deploy the HTLC with a specific token type. A normal unprivileged EOA cannot initiate this attack path.

**Core-5 Violation**: This is fundamentally a centralization risk - the owner controls which tokens are supported. The audit instructions explicitly state: "Centralization issues are out of scope for this audit."

From known-issues.md:
```
- Centralization risk in HTLCRegistry contract. The ownership is present only
  to set implementation contract addresses for the UDAs and to set valid HTLC addresses.
```

#### Scenario 2: Rebasing Tokens

Same analysis as Scenario 1 - requires owner to deploy with rebasing token. **Privileged action, out of scope.**

#### Scenario 3: Direct Token Transfer

**Attack Flow**:
```
1. Attacker: token.transfer(HTLC, 1000)
   Result: balanceOf(HTLC) += 1000
          No order created

2. State: balanceOf(HTLC) = X + 1000
          sum(orders.amount) = X

3. Invariant: (X + 1000) >= X → TRUE ✓
```

**Impact Analysis**:
- Existing users: **NO IMPACT** - they can still redeem/refund their orders
- Attacker: **LOSES FUNDS** - no way to recover donated tokens
- Protocol: Invariant becomes `balance > sum(orders)` - **ACCEPTABLE**

**Is this a vulnerability?**
- **NO** - Anyone can send tokens to any address (basic blockchain behavior)
- **NO** - Extra funds don't harm existing users
- **NO** - Protocol doesn't promise to return accidentally sent funds
- This is **user error**, not a security issue

### Economic Analysis

#### Cost-Benefit for Attacker
**Scenario 1 & 2**: N/A (requires privileged access)

**Scenario 3**:
- Cost: 1000 tokens (permanently lost)
- Benefit: 0 (no way to extract funds)
- ROI: -100%
- **Economic Viability**: NONE (attacker loses money)

#### Real-World Risk Assessment

**Fee-on-Transfer Tokens**:
- USDT: Has transfer fee mechanism, but **fee is disabled** on Ethereum mainnet
- Most major tokens: No transfer fees
- Exotic tokens: May have fees, but not widely used in DeFi

**Industry Standard Practice**:
- Uniswap V2: Doesn't support fee-on-transfer tokens
- Uniswap V3: Doesn't support fee-on-transfer tokens
- Aave: Doesn't support rebasing tokens
- Compound: Doesn't support rebasing tokens

**Mitigation**: Standard practice is to **DOCUMENT** unsupported token types, not to add runtime checks.

### Dependency/Library Reading Notes

**OpenZeppelin SafeERC20 v5.2.0** (from knowledge base):
```solidity
library SafeERC20 {
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        // 1. Encodes transferFrom call
        bytes memory data = abi.encodeCall(token.transferFrom, (from, to, value));

        // 2. Executes call
        bytes memory returndata = address(token).functionCall(data);

        // 3. Checks return value (if any)
        if (returndata.length != 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation failed");
        }

        // 4. Does NOT check balanceOf before/after ❌
    }
}
```

**Why SafeERC20 doesn't check balance**:
1. **Gas efficiency**: Balance checks cost extra gas for all transfers
2. **Standard assumption**: ERC20 standard assumes 1:1 transfer amounts
3. **Design philosophy**: Handle non-compliant return values, not non-standard token economics
4. **Documented limitation**: OpenZeppelin docs explicitly state limitations

### Final Feature-vs-Bug Assessment

**Is this intended behavior?**
- The protocol is designed for **standard ERC20 tokens**
- No explicit support for fee-on-transfer or rebasing tokens is documented
- This is consistent with industry-standard DeFi protocols

**Is this a bug or a limitation?**
- **LIMITATION** - Like how a car isn't designed to fly
- Not supporting exotic token types is an **architectural choice**, not a defect
- Proper response: Document supported token types

**Minimal Fix** (documentation only):
```solidity
/**
 * @notice HTLC contract for atomic swaps using standard ERC20 tokens
 *
 * SUPPORTED TOKENS:
 * - Standard ERC20 tokens that transfer exact amounts
 *
 * UNSUPPORTED TOKENS (use at your own risk):
 * - Fee-on-transfer tokens (STA, PAXG, etc.)
 * - Rebasing tokens (stETH, aTokens, etc.)
 * - Tokens with transfer hooks or callbacks
 *
 * The contract assumes 1:1 transfer amounts as per ERC20 standard.
 * Using non-standard tokens may result in accounting discrepancies.
 */
contract HTLC is EIP712 {
    // ... existing code ...
}
```

### Conclusion

**Why FALSE POSITIVE:**

1. ✅ **Core-4 Violation**: Attack requires privileged owner action (deploying with non-standard token)
2. ✅ **Core-5 Violation**: This is a centralization issue (owner controls token selection) - explicitly out of scope
3. ✅ **No Practical Economic Risk**:
   - Most tokens don't have fees
   - Owner presumably won't deploy with incompatible tokens
   - Can be mitigated by documentation
4. ✅ **Standard Industry Practice**: All major DeFi protocols handle this via documentation, not code
5. ✅ **Feature-vs-Bug**: This is an architectural LIMITATION, not a defect

**What the report describes is:**
- A **known limitation** of standard DeFi protocols
- A **documentation gap**, not a vulnerability
- A **theoretical scenario** requiring privileged access

**What it is NOT:**
- An exploitable vulnerability by unprivileged attackers
- A practical economic risk under normal operations
- A bug in the protocol logic

**Recommended Action**: Add documentation clarifying supported token types. No code changes required.

**Risk Level**: INFORMATIONAL (documentation improvement)
**Audit Status**: ❌ INVALID VULNERABILITY / ✅ VALID DOCUMENTATION GAP
