# 🚨 记账金额与实际到账金额不符导致资金池亏空 (Fee-on-Transfer Token Accounting Mismatch)

## 1. 发现 (Discovery)

在审计 EVM、Starknet 和 Solana (SPL) 的代币交换实现时，发现协议在处理代币转账时存在**记账金额与实际到账金额不一致**的风险。

具体表现为：在 `initiate` 过程中，合约/程序按照用户输入的 `amount` 进行记账，但未检查实际转入合约/Vault 的代币数量。对于 **Fee-on-Transfer**（转账收费）或 **Deflationary**（通缩）代币，合约实际收到的金额将少于账面记录的金额。

### 涉及位置 (Locations)

*   **EVM**: `evm/src/swap/HTLC.sol` (Line 328)
*   **Starknet**: `starknet/src/htlc.cairo` (Line 435)
*   **Solana SPL**: `solana/solana-spl-swaps/programs/solana-spl-swaps/src/lib.rs` (Line 49)

## 2. 详细说明 (Details)

### EVM (`HTLC.sol`)
```solidity
// evm/src/swap/HTLC.sol
function _initiate(...) internal returns (bytes32 orderID) {
    // ... 记账 ...
    orders[orderID] = Order({
        ...,
        amount: amount_, // 记账金额
        ...
    });

    // ... 转账 ...
    token.safeTransferFrom(funder_, address(this), amount_); // 未检查实际到账
}
```
`safeTransferFrom` 仅保证转账调用成功，但不保证接收到的金额等于 `amount_`。

### Solana SPL (`solana-spl-swaps`)
```rust
// solana/solana-spl-swaps/programs/solana-spl-swaps/src/lib.rs
pub fn initiate(...) -> Result<()> {
    // ...
    token::transfer(token_transfer_context, swap_amount)?; // 转移 swap_amount
    
    // ... 记账 ...
    *ctx.accounts.swap_data = SwapAccount {
        ...,
        swap_amount, // 记账金额
        ...,
    };
}
```
Solana 实现中，`token_vault` 是根据 Mint 派生的 PDA (`seeds = [mint.key().as_ref()]`)。这意味着**所有针对该代币的订单共享同一个 Vault**。

## 3. 影响 (Impact)

这是一个 **High (高危)** 级别的会计漏洞，因为它直接破坏了**借贷平衡**（Accounting Equation）并导致**资金丢失**。

1.  **共享资金池污染**: 由于合约（EVM/Starknet）或 Vault（Solana）是所有订单共享的，一个 Fee-on-Transfer 订单会导致整个资金池出现亏空。
2.  **资金窃取**: 攻击者可以发起一个 Fee-on-Transfer 代币的交换，存入 `X` (实际到账 `X - fee`)，但账面记录 `X`。随后攻击者（作为 Redeemer）赎回 `X`。这多出的 `fee` 部分实际上是从其他诚实用户的存款中抽取的。
3.  **最后一人受损**: 在一系列交易后，资金池的余额将不足以支付最后一个尝试赎回的用户，导致其资金被锁或丢失。

尽管代码注释中提到 "This contract does not support fee-on-transfer or rebasing tokens"，但由于缺乏链上强制检查或白名单机制，用户（无论是恶意还是无意）的使用仍会破坏系统的偿付能力。

## 4. 建议 (Recommendation)

在执行转账前后检查余额变化，并以实际收到的金额进行记账。

**EVM/Starknet 伪代码**:
```solidity
uint256 balanceBefore = token.balanceOf(address(this));
token.safeTransferFrom(msg.sender, address(this), amount);
uint256 actualAmount = token.balanceOf(address(this)) - balanceBefore;
// 使用 actualAmount 进行记账
```

**Solana SPL**:
由于 Solana 的 CPI 调用无法直接返回余额变化，建议在 `initiate` 指令中增加对 Vault 余额的检查（`token_vault.amount`），确保其增加量 >= `swap_amount`，或者仅支持在 Token Program 层面强制 1:1 转账的标准代币（通过白名单 Mint）。


---

# ADJUDICATION REPORT

## 1. Executive Verdict

**FALSE POSITIVE / INFORMATIONAL**

The reported accounting mismatch is a **documented design limitation, not an exploitable vulnerability**. Users are explicitly warned; the economic attack is not viable; the protocol operates correctly within its documented constraints.

## 2. Reporter's Claim Summary

The report alleges that HTLC contracts across EVM, Starknet, and Solana fail to verify actual token receipt amounts, enabling fee-on-transfer tokens to create accounting mismatches that lead to pool insolvency and fund theft.

## 3. Code-Level Analysis

### 3.1 Logic Existence: CONFIRMED

**EVM** (`evm/src/swap/HTLC.sol:328`):
```solidity
token.safeTransferFrom(funder_, address(this), amount_);
```
Records `amount_` without balance verification.

**Starknet** (`starknet/src/htlc.cairo:435`):
```cairo
.transfer_from(funder_, get_contract_address(), amount_);
```
Records `amount_` without balance verification.

**Solana SPL** (`solana/solana-spl-swaps/src/lib.rs:49`):
```rust
token::transfer(token_transfer_context, swap_amount)?;
```
Records `swap_amount` without balance verification.

**Verdict**: Code pattern exists as claimed.

### 3.2 Documentation Check: EXPLICITLY WARNED

**EVM** (`HTLC.sol:119`):
```solidity
* NOTE: This contract does not support fee-on-transfer or rebasing tokens.
```

This appears in BOTH `initiate()` function docs (lines 119 and 138). The contract DOCUMENTS its limitation.

## 4. Dependency Library Verification

**OpenZeppelin SafeERC20.safeTransferFrom**:
- Performs `transferFrom` call
- Validates return value (handles non-compliant ERC20s)
- Reverts on failure
- **Does NOT verify balance delta**

This is standard behavior. SafeERC20 ensures the call succeeds, not that amounts match.

## 5. Exploit Feasibility Analysis

### 5.1 Attack Prerequisites

1. ✅ **Fee-on-transfer token exists** (many do: SafeMoon, Reflect, etc.)
2. ✅ **User ignores documented limitation**
3. ✅ **Multiple concurrent orders in same HTLC instance**
4. ❌ **Economic rationality**

### 5.2 Attack Scenarios Analyzed

**Scenario A: Single Malicious User**
```
Order 1: Attacker deposits 100 FeeToken (receives 95, records 100)
Redeem:  Contract attempts to transfer 100, has only 95 → FAILS
```
**Result**: Attack fails immediately; attacker's own funds are stuck.

**Scenario B: Multi-Order Race**
```
Order 1: Attacker deposits 100 FeeToken (receives 95, records 100)
Order 2: Victim deposits 100 FeeToken (receives 95, records 100)
Total:   Contract has 190, recorded 200
Redeem:  Order 1 redeems 100 (leaving 90)
         Order 2 redeems 100 → FAILS (only 90 left)
```
**Result**: Both users paid fees; no differential advantage.

**Scenario C: Asymmetric Fee Manipulation**
```
Attacker controls FeeToken with whitelist:
1. Attacker (whitelisted): deposits 100, receives 100, records 100
2. Victim (not whitelisted): deposits 100, receives 90, records 100
3. Attacker redeems: 100 (leaving 90)
4. Victim redeems: FAILS
```
**Result**: Victim is harmed by the token's malicious design, not the HTLC contract.

### 5.3 Architecture Constraint

**HTLCRegistry.sol:38**:
```solidity
mapping(address token => address HTLC) public htlcs;
```

Each token has ONE HTLC instance. All orders for USDT share one contract; all orders for DAI share another.

**Implication**: For the attack to work, MULTIPLE users must choose to use the SAME fee-on-transfer token, ignoring the documented warning.

## 6. Economic Analysis

### 6.1 Attacker Input-Output

**Costs**:
- Lock funds in HTLC
- Gas for initiate + redeem/refund
- Counterparty risk in cross-chain swap

**Gains**:
- ❌ **Attacker receives ZERO direct benefit**
- The "stolen" fee goes to the token contract (burned/redistributed per token design)
- The attacker's counterparty receives the recorded amount from the shared pool
- Net effect: Griefing other users, not profit

**ROI**: **Negative** (gas costs + locked capital + zero gain)

### 6.2 Victim Loss Analysis

The report claims "last user loses funds." Let's verify:

```
HTLC for FeeToken (1% transfer fee)
Order 1: Alice deposits 100 → receives 99
Order 2: Bob deposits 100 → receives 99
Total: 198 in contract, 200 recorded

Redeem sequence:
1st redeem: 100 out, 98 left
2nd redeem: tries 100, has only 98 → FAILS (2 tokens short)
```

**Victim loss**: 2% of deposit (the cumulative fees)
**Root cause**: Using fee-on-transfer token despite documented limitation

## 7. Call Chain Trace

### EVM Initiate Flow

```
User → HTLC.initiate(redeemer, timelock, amount, secretHash)
  ↓
  HTLC._initiate(msg.sender, msg.sender, redeemer, timelock, amount, secretHash)
    msg.sender: User
    ↓
    SafeERC20.safeTransferFrom(funder=User, to=HTLC, amount)
      → FeeToken.transferFrom(User, HTLC, amount)
          [Fee deducted here: HTLC receives amount * (1 - fee%)]
      → Returns true (success)
    ↓
    orders[orderID].amount = amount [MISMATCH: records amount, received less]
```

**Call Type**: `call` (via SafeERC20)
**State Change**: `orders[orderID]` storage write
**Reentrancy**: None (follows Checks-Effects-Interactions)

### EVM Redeem Flow

```
Redeemer → HTLC.redeem(orderID, secret)
  msg.sender: Redeemer
  ↓
  Validates secret & orderID
  ↓
  SafeERC20.safeTransfer(redeemer, order.amount)
    → Attempts to transfer recorded amount
    → If balance insufficient → REVERTS
```

**Failure Point**: If accumulated fees create deficit, later redeems fail.

## 8. State Scope Analysis

### Storage Layout (HTLC.sol)

```solidity
Line 35: IERC20 public token;              // Single token per HTLC instance
Line 41: mapping(bytes32 => Order) orders; // Per-orderID storage

struct Order {
    address initiator;    // Per-order
    address redeemer;     // Per-order
    uint256 amount;       // ⚠️ RECORDED amount (not actual)
    ...
}
```

**Token Balance**: `token.balanceOf(address(this))` is SHARED across all orders
**Accounting**: Per-order amounts are recorded independently
**Invariant**: `Σ(orders[*].amount) ≤ token.balanceOf(this)` should hold, but doesn't with fee-on-transfer

### State Scope Summary

| Variable | Scope | Key Derivation | Issue |
|----------|-------|----------------|-------|
| `token` | Global (per HTLC) | Immutable after init | N/A |
| `orders[orderID]` | Per-order | SHA256 hash of params | Records nominal amount |
| Token balance | Shared pool | N/A | Actual balance < sum of recorded amounts |

## 9. Feature vs Bug Assessment

### Protocol Design Intent

The HTLC contract is designed for **standard ERC20 tokens** that:
- Transfer exactly the specified amount
- Follow transfer(from, to, amount) semantics
- Do not modify amounts in flight

**Evidence**:
1. Line 119 comment: "This contract does not support fee-on-transfer or rebasing tokens"
2. No balance verification code (intentional omission for gas efficiency)
3. Architecture assumes 1:1 transfers

### Is This a Bug?

**NO. This is documented expected behavior.**

**Reasoning**:
1. ✅ **Explicit warning** in natspec docs
2. ✅ **Standard industry pattern** (Uniswap V2, Sushiswap, etc. also don't support fee-on-transfer by default)
3. ✅ **Intentional design** for gas efficiency
4. ✅ **User responsibility** to select compatible tokens

**Analogy**: A car manual says "Do not use diesel in a gasoline engine." Using diesel anyway and blaming the car manufacturer is not a valid vulnerability report.

## 10. User Behavior Analysis (按 Core-9 指令)

**假设**: 用户是技术背景的普通用户，会严格遵守规则，但会严格检查自己的操作和协议配置。

**Expected User Behavior**:
1. ✅ Read contract documentation / UI warnings
2. ✅ Verify token compatibility before use
3. ✅ Check if token has transfer fees
4. ✅ Select standard ERC20 tokens (USDT, USDC, DAI, etc.)

**Actual Requirement for Vulnerability**:
- ❌ User ignores documented limitation
- ❌ User selects exotic fee-on-transfer token
- ❌ Multiple users make same mistake simultaneously

**Conclusion**: Under Core-9 assumptions, this vulnerability **CANNOT occur** because competent users follow protocol specifications.

## 11. Comparison to Known Issues

Checked `known-issues.md`:
- ❌ Fee-on-transfer tokens NOT mentioned in known issues
- ✅ But explicitly mentioned in code comments (HTLC.sol:119, 138)

**Assessment**: This is a **documented limitation**, not a hidden flaw. The absence from known-issues.md is an oversight in documentation consolidation, not evidence of a vulnerability.

## 12. Real-World Precedent

**Standard DeFi Practice**:
- **Uniswap V2**: Doesn't support fee-on-transfer (requires V2 pairs with special handling)
- **Compound**: Doesn't support fee-on-transfer collateral
- **Aave**: Explicitly blocks fee-on-transfer tokens

**Garden Finance**: Follows industry standard by documenting the limitation.

## 13. Proposed "Fix" Analysis

The report suggests:
```solidity
uint256 balanceBefore = token.balanceOf(address(this));
token.safeTransferFrom(msg.sender, address(this), amount);
uint256 actualAmount = token.balanceOf(address(this)) - balanceBefore;
```

**Issues with this approach**:
1. **Gas cost**: +2 SLOAD operations per initiate (~4,200 gas)
2. **Reentrancy risk**: Balance checks create read-after-write patterns
3. **Complexity**: Requires updating all 3 chains' implementations
4. **Breaks existing integrations**: Changes order amount semantics
5. **Doesn't solve root issue**: Rebasing tokens still break (as documented)

**Better solution**: Maintain current design, enforce limitation via:
- UI warnings
- Token whitelist in HTLCRegistry (owner-controlled)
- Off-chain validation

## 14. Final Determination

### Why This is NOT a Valid High/Medium Vulnerability

| Criterion | Assessment |
|-----------|------------|
| **Documented** | ✅ YES - Explicit warning in code |
| **Enforceable by users** | ✅ YES - Users control token selection |
| **Requires user error** | ✅ YES - Ignoring warnings |
| **Economic incentive** | ❌ NO - Attacker gains nothing |
| **Practical exploitability** | ❌ NO - Requires coordinated user mistakes |
| **Breaks stated guarantees** | ❌ NO - Protocol never claimed to support fee-on-transfer |

### Classification

**INFORMATIONAL / QA**:
- Recommend adding fee-on-transfer detection to HTLCRegistry
- Consider token whitelist feature
- Consolidate warnings in README/known-issues.md

**NOT HIGH/MEDIUM** because:
1. Protocol operates correctly within documented constraints
2. No economic attack vector exists
3. Requires user error (ignoring explicit warnings)
4. Standard industry practice to exclude fee-on-transfer tokens
5. "Documentation is not enforcement" argument fails when users are explicitly warned

## 15. Severity Rationale

Per Code4rena severity definitions:

**HIGH**: "Assets can be stolen/lost/compromised directly"
- ❌ No direct theft mechanism
- ❌ Requires user selecting incompatible token
- ❌ No attacker profit

**MEDIUM**: "Assets not at direct risk, but function of protocol could be impacted"
- ❌ Function works as designed for supported tokens
- ❌ Documented limitation, not a bug

**QA/INFORMATIONAL**: "Best practices, code quality"
- ✅ Could improve documentation
- ✅ Could add enforcement mechanism
- ✅ User education needed

---

## 16. Recommended Actions (Non-Security)

1. **Documentation**: Add fee-on-transfer limitation to README.md known issues
2. **Registry Enhancement**: Optional token whitelist in HTLCRegistry
3. **UI/Frontend**: Warning when detecting fee-on-transfer tokens (off-chain)
4. **No Code Changes Needed**: Current implementation is correct for supported tokens

---

**VERDICT**: FALSE POSITIVE - Documented design limitation, not exploitable vulnerability.
