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
