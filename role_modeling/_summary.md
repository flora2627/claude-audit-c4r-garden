# Global EOA Capability Summary

## Role Comparison Matrix

| Capability | Normal User | Swapper | Market Maker | Relayer |
|------------|-------------|---------|--------------|---------|
| **Initiate Orders** | ✅ | ✅ | ✅ | ✅ (on behalf) |
| **Redeem Orders** | ✅ | ✅ | ✅ | ❌ |
| **Refund Orders** | ✅ | ✅ | ✅ | ❌ |
| **Deploy UDAs** | ✅ | ✅ | ✅ | ✅ |
| **Lock Capital** | ✅ | ✅ | ✅ | ⚠️ (optional) |
| **Reveal Secrets** | ✅ | ✅ | ✅ | ❌ |
| **Sign for Others** | ❌ | ❌ | ❌ | ⚠️ (signature relay) |
| **Influence Price** | ❌ | ⚠️ (implicit) | ✅ | ❌ |
| **Censorship Power** | ❌ | ❌ | ⚠️ (refuse orders) | ⚠️ (refuse relay) |
| **Liveness Dependency** | Low | Medium | **High** | Low |
| **Capital Requirement** | Low | Medium | **High** | Low (gas only) |

---

## Role Definitions

### 1. Normal User
- **Who**: Any EOA interacting with the protocol.
- **Primary Use Case**: Testing, one-off swaps, or acting as a counterparty in a peer-to-peer trade.
- **Risk Profile**: Low. Can only lose their own funds if they make mistakes (e.g., wrong `secretHash`).

### 2. Swapper / Trader
- **Who**: An EOA actively executing cross-chain atomic swaps.
- **Primary Use Case**: Trading Asset A on Chain X for Asset B on Chain Y.
- **Risk Profile**: Medium. Exposed to timelock risk, counterparty default, and liveness requirements.

### 3. Market Maker (Liquidity Provider)
- **Who**: A professional or automated service providing liquidity.
- **Primary Use Case**: Fulfilling user orders by acting as the counterparty.
- **Risk Profile**: High. Must maintain capital across chains, monitor for secret reveals, and ensure liveness.

### 4. Relayer
- **Who**: A service provider submitting transactions on behalf of users.
- **Primary Use Case**: Gas abstraction, UX improvement.
- **Risk Profile**: Low (if only relaying signatures). Medium (if funding orders on behalf of users).

---

## Overlapping Capabilities

- **All roles can `initiate`**: The protocol is permissionless. Any EOA can create orders.
- **Swapper ≈ Normal User + Intent**: A Swapper is just a Normal User with a specific goal (cross-chain trade).
- **Market Maker ≈ Swapper + Scale**: A Market Maker is a Swapper operating at scale with professional infrastructure.
- **Relayer ≠ Swapper**: A Relayer does not participate in the swap itself, only facilitates it.

---

## Unique High-Risk Capabilities

### Market Maker: Liveness Requirement
- **Risk**: If the MM fails to `redeem` on the source chain after the User reveals the secret on the destination chain, the MM loses funds.
- **Mitigation**: Automated monitoring, redundant infrastructure.

### Relayer: Trust in Off-Chain Compensation
- **Risk**: If the Relayer funds an order via `initiateOnBehalf` and the user doesn't pay them back, the Relayer loses funds.
- **Mitigation**: Only relay signed transactions (`initiateWithSignature`), or require upfront payment.

### Owner (HTLCRegistry): Malicious UDA Implementation
- **Risk**: If the Owner deploys a malicious UDA implementation, future users who deploy UDAs could have their funds stolen.
- **Mitigation**: Multi-sig, timelock, or immutable registry (not currently implemented).

---

## Roles That Can Influence Financial Invariants

### HTLC System Invariants
1. **Order Solvency**: `contract.balance(token) >= sum(active_orders[i].amount)`
2. **Mutual Exclusion**: An order can only be fulfilled once (either `redeem` or `refund`, not both).
3. **Atomicity**: If the secret is revealed on one chain, it can be used on the other chain.

### Roles That Can Break Invariants
- **None (by design)**: The HTLC contracts enforce invariants cryptographically. No EOA role can break them.
- **Owner (indirect)**: Can deploy a malicious UDA that bypasses `safeTransferFrom` checks, but this only affects future UDA deployments, not existing HTLCs.

---

## Cross-Role Attack Vectors

### 1. Swapper → Market Maker: Free Option Attack
- **Attack**: Swapper initiates on Chain X, waits to see if the market moves favorably, then decides whether to complete the swap on Chain Y.
- **Impact**: MM loses the "option premium" (opportunity cost of locked capital).
- **Mitigation**: Short timelocks, or require upfront fees.

### 2. Relayer → User: Front-Running
- **Attack**: Relayer sees a user's signed transaction, extracts the `secretHash`, and initiates their own order with better terms.
- **Impact**: User's order is "stolen" by the Relayer.
- **Mitigation**: Use unique `secretHash` per user, or encrypt off-chain communication.

### 3. Market Maker → Swapper: Censorship
- **Attack**: MM refuses to act as counterparty for specific users (e.g., based on address blacklist).
- **Impact**: User cannot complete the swap (unless they find another MM).
- **Mitigation**: Decentralized MM network, or fallback to peer-to-peer matching.

---

## Conclusion

The Garden HTLC system is **highly permissionless** with minimal privilege escalation vectors. The only privileged role (Owner) has limited scope (UDA implementations). All financial invariants are enforced cryptographically, not by access control.

**Key Audit Focus**:
- Verify that `redeem` and `refund` are mutually exclusive.
- Verify that `secretHash` uniqueness prevents order collisions.
- Verify that `timelock` logic prevents premature refunds.
- Verify that UDA implementations cannot bypass HTLC security.
