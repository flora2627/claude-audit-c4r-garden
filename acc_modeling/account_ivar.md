# Garden Finance Multi-Entity Accounting Model

## 1. Core Accounting Entities

*   **Entity A**: `HTLC.sol` / `NativeHTLC.sol` (EVM) - Core Escrow
*   **Entity B**: `UDA.sol` (EVM) - Transient Deposit Proxy
*   **Entity C**: `SolanaNativeSwap` (Solana) - Core Escrow
*   **Entity D**: `SolanaSPLSwap` (Solana) - Core Escrow
*   **Entity E**: `StarknetHTLC` (Starknet) - Core Escrow
*   **Entity F**: `SuiAtomicSwap` (Sui) - Core Escrow

## 2. Intra-Entity Accounting Models

### 2.1 Entity A: `HTLC.sol` (EVM)
*   **Assets**: `token.balanceOf(address(this))`
*   **Liabilities**: `Sum(orders[i].amount)`
*   **[!] Intra-Entity Invariant**: `token.balanceOf(address(this)) >= Sum(active_orders.amount)`

### 2.2 Entity B: `UDA.sol` (EVM)
*   **Assets**: `token.balanceOf(address(this))` (Transient)
*   **Liabilities**: Implicit obligation to forward to HTLC.
*   **[!] Intra-Entity Invariant**: `token.balanceOf(address(this)) >= required_amount` (Before init)

### 2.3 Entity C/D/E/F (Non-EVM)
*   **Assets**: Vault Balance / PDA Balance / Coin Object
*   **Liabilities**: `Sum(Order.amount)`
*   **[!] Intra-Entity Invariant**: `Total_Assets >= Sum(active_orders.amount)`

## 3. Cross-Entity Accounting Invariants (Core Risk Points)

### 3.1 Interaction Pair: (UDA <> HTLC)
*   **Dependency Description**: Users deposit into UDA, which then approves and calls `initiateOnBehalf` on HTLC.
*   **[!!] Cross-Entity Invariant 1**: `HTLC.orders[id].amount == UDA.initial_deposit` (assuming full deposit used).
*   **Risk Scenario**: If UDA fails to forward the full amount or if `initiateOnBehalf` takes less than deposited (remainder stuck), funds are lost or accounting mismatches occur.
*   **[!!] Cross-Entity Invariant 2**: `HTLC.orders[id].initiator == UDA.refundAddress` (or UDA itself, but UDA sets initiator to user).
*   **Risk Scenario**: If UDA sets initiator to itself but has no refund logic for that path, funds are stuck if refunded. (Current logic: UDA sets initiator to `refundAddress` passed in args).

## 4. Key Operations Double-Entry Analysis

### 4.1 Operation: `createERC20SwapAddress` -> `UDA.initialize` -> `HTLC.initiateOnBehalf`
*   **Business Description**: User creates a UDA, deposits funds, and the registry initializes it, triggering the swap on HTLC.
*   **Accounting Entries**:
    *   **User Ledger**:
        *   Credit: Token Balance
        *   Debit: Receivable (from Protocol)
    *   **UDA Ledger**:
        *   Debit: Token Balance (Asset)
        *   Credit: Implicit Liability (to User)
        *   *Then immediately:*
        *   Credit: Token Balance (Asset)
        *   Debit: Implicit Liability (to User)
    *   **HTLC Ledger**:
        *   Debit: Token Balance (Asset)
        *   Credit: Order Liability (to Redeemer/Initiator)
*   **Reconciliation Check**: `User.Debit` should match `HTLC.Credit` (Order Liability). The UDA is a pass-through.

---

## 5. Defense-in-Depth Trust Model (From finding_012 Analysis)

### 🔁 Knowledge Reflection

Finding_012 alleged that unprotected `initialise()` in HTLC/ArbHTLC could allow front-running to inject malicious tokens, breaking accounting invariants. Initial analysis suggested this was a critical vulnerability. However, deeper analysis revealed:

**Misunderstanding revealed**: The attack path requires multiple operational failures by trusted parties (owner + users), not just a protocol logic flaw. The accounting invariant break is conditional on trust model violations, not unconditional protocol failures.

**Blind spot**: Failed to initially recognize that centralization-dependent attacks fall outside scope when centralization is explicitly documented and trusted parties are assumed competent.

### 🧠 Knowledge Update

**Defense Layer Model for Accounting Invariant Protection:**

The invariant `token.balanceOf(HTLC) >= Sum(orders[i].amount)` relies on a multi-layer defense model:

1. **Layer 1 (Deployment)**: HTLC deployer calls `initialise(REAL_TOKEN)` immediately after deployment
   - Risk: Front-running by attacker calling `initialise(MALICIOUS_TOKEN)`
   - Mitigation: Use atomic deployment + initialization OR use CREATE2 with initialization in constructor

2. **Layer 2 (Registry Integration)**: HTLCRegistry owner calls `addHTLC()`
   - **Critical Trust Assumption**: Owner MUST verify `HTLC.token()` returns expected address before calling `addHTLC()`
   - If Layer 1 failed (front-run), Layer 2 MUST catch it
   - Current code: No on-chain enforcement, relies on off-chain verification

3. **Layer 3 (User Verification)**: Users verify token address before locking counterparty funds
   - **User Competence Assumption** (per Core-9): Technically competent users performing atomic swaps will verify token addresses
   - This is standard practice in cross-chain atomic swaps
   - If Layers 1 and 2 both failed, Layer 3 MUST catch it

**Accounting Invariant Conditional Truth:**

```
IF token is honest (verified by Layers 2 & 3)
  THEN token.balanceOf(HTLC) >= Sum(orders[i].amount) [HOLDS]
ELSE
  Accounting invariant can be broken BUT:
  - Requires Layer 2 failure (owner doesn't verify - centralization issue, out of scope)
  - Requires Layer 3 failure (user doesn't verify - user error, not protocol bug)
```

**SafeERC20 Limitation (Universal Across All EVM Projects):**

OpenZeppelin's `SafeERC20.safeTransferFrom()`:
- ✅ Checks return value (handles non-standard tokens that don't return bool)
- ❌ Does NOT verify actual balance changes
- ❌ Cannot prevent malicious tokens from returning `true` without transferring

This is a documented limitation. Projects using SafeERC20 must trust that tokens are honest OR implement additional balance-checking logic.

### 📍 Future Checkpoint

**When auditing similar unprotected initialization patterns:**

1. **First check**: Is the system explicitly centralized with trusted owner?
   - If YES: Check known-issues.md / docs for centralization acknowledgment
   - If centralization is in scope: Verify whether owner verification is required/expected

2. **Second check**: What layers of defense exist?
   - Deployment-time protection?
   - Integration-time verification (manual or automatic)?
   - User-level verification expectations?

3. **Third check**: Under what trust model does the accounting invariant hold?
   - Unconditional (always holds regardless of token)?
   - Conditional (holds if token is honest + trusted parties verify)?

4. **Classification decision**:
   - If requires only attacker on-chain actions → Valid vulnerability
   - If requires trusted party operational failures → Centralization issue (check if in scope)
   - If requires user verification failures → User error (check user competence assumptions)

5. **Economic viability**:
   - Compute P(success) = P(layer1_fail) × P(layer2_fail) × P(layer3_fail)
   - If P(success) < 0.1% with competent parties → Not economically viable
   - If EV negative → False positive

---
