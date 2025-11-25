# Global Audit Feedback & Meta-Knowledge

## 1. 🔄 Universal Patterns

### 1.1 Registry-Based Factory Pattern Risks

**🔁 Knowledge Reflection**
- **Context**: A central Registry contract holds the "Implementation Address" for Clones/Proxies.
- **Issue**: If the Implementation Address is mutable (owner-updatable), any pre-calculated `CREATE2` addresses become invalid after an update.
- **Impact**: Users following a "Deposit to Predicted Address -> Call Create" flow can lose funds if the implementation changes in between.

**🧠 Knowledge Update**
- **Pattern**: `Factory.predictAddress(...)` depends on `Factory.implementation`.
- **Invariant**: For safe "Deposit-then-Deploy" flows, `Factory.implementation` MUST NOT change between Deposit and Deploy.
- **Rule**: If `Factory.implementation` is mutable, the protocol MUST provide a way to atomicize "Deposit + Deploy" or verify the implementation hasn't changed.

**📍 Future Checkpoint**
- When auditing `CREATE2` factories with `predictAddress()`:
  1. Check if `predictAddress` uses a mutable storage variable (e.g., `impl`).
  2. Check if users are expected to send funds to the predicted address *before* the contract is deployed.
  3. If both are true, flag as a Centralization/Griefing risk (or High severity if unprivileged users can trigger the change).

---

### 1.2 False Positives & Scope

**🔁 Knowledge Reflection**
- **Insight**: Finding 009 (HTLCRegistry Fund Lock) was technically valid but out of scope.
- **Reason**: It required the **Owner** to attack the users.
- **Takeaway**: Centralization risks (Owner attacking users) are often out of scope unless explicitly included. Always check [Core-4] and [Core-5] type rules about privileged actors.

**🧠 Knowledge Update**
- **Heuristic**: "If the attack requires `onlyOwner` or similar privilege, it's likely invalid unless the protocol claims 'Trustless' or 'DAO-governed' without caveats."

---

### 1.3 Time-Based Boundary Semantics

**🔁 Knowledge Reflection**
- **Context**: HTLCs often use `require(now > timelock)` or `require(now < timelock)`.
- **Issue**: Strict inequality (`<` / `>`) creates an "Off-by-One" block behavior compared to inclusive inequality (`<=` / `>=`).
- **Correction**: "Refund after N blocks" usually implies `> N` or `>= N+1`. Code using `initiatedAt + timelock < block.number` correctly implements "after", meaning refund is available at `N+1`.
- **False Positive**: Flagging `<` as a bug because user expected `<=` is often wrong if the intent is "after expiry".

**🧠 Knowledge Update**
- **Pattern**: `lockTime < currentTime` vs `lockTime <= currentTime`.
- **Rule**: Check documentation for "at" vs "after".
  - "At block X" -> `<=`
  - "After block X" -> `<` (effective at X+1)

**📍 Future Checkpoint**
- When analyzing timelocks, compare strict vs inclusive inequality against specific wording in NatSpec ("at" vs "after").

---

### 1.4 Relayer/Proxy Pattern & Identity Hashing

**🔁 Knowledge Reflection**
- **Context**: Protocols supporting "Gasless" or "Relayed" transactions often separate `Funder` (msg.sender) from `Initiator` (beneficiary/controller).
- **Issue**: If `OrderID` hash includes `msg.sender`, relayers cannot create orders *on behalf of* users without changing the ID.
- **Design Choice**: Excluding `msg.sender` from identity hash is a FEATURE for relayers, not a collision bug.
- **Constraint**: This means two different funders cannot create the "same" order (same params) simultaneously, which is usually desirable (deduplication).

**🧠 Knowledge Update**
- **Pattern**: `initiateOnBehalf(user, ...)`
- **Invariant**: `OrderID` should depend on `User` (Initiator), not `Relayer` (Funder).
- **Rule**: If `msg.sender` is excluded from a hash, check if it's to support relayers. If so, it's likely valid.

---

### 1.5 Supported Token Types & Invariant Checks

**🔁 Knowledge Reflection**
- **Context**: General purpose DeFi protocols usually support standard ERC20s.
- **Issue**: Fee-on-transfer or Rebasing tokens break `balanceOf(this) == sum(deposits)`.
- **Verdict**: Unless the protocol explicitly claims support for these, this is a Limitation/Documentation issue, not a High/Critical vulnerability.

**🧠 Knowledge Update**
- **Heuristic**: "Does the protocol explicitly claim to support 'Any ERC20' including exotic ones?"
  - Yes -> Missing balance check is a Bug.
  - No -> Missing balance check is a Limitation (Informational).

---

### 1.6 .transfer() vs .call() Tradeoffs

**🔁 Knowledge Reflection**
- **Context**: Sending ETH via `.transfer(amount)`.
- **Issue**: Uses fixed 2300 gas. Breaks some smart wallets (Gnosis Safe fallback).
- **Tradeoff**: Prevents reentrancy (good) but hurts compatibility (bad).
- **Verdict**: Not a "Vulnerability" if Reentrancy is the concern. It's a "Compatibility Issue" (QA/Low).

**🧠 Knowledge Update**
- **Pattern**: `payable(addr).transfer(val)`
- **Rule**:
  - If used to prevent reentrancy: Valid security feature (with UX downsides).
  - If compatibility is paramount: Suggest `.call{value: val}("")` + CEI + ReentrancyGuard.

---

### 1.7 Permissionless Recovery Patterns

**🔁 Knowledge Reflection**
- **Context**: `recover()` function callable by anyone.
- **Issue**: Reporter fears "Griefing" or "Theft".
- **Reality**: If `recover()` *hardcodes* the destination to the `Owner` or `Beneficiary`, it is SAFE. Public access just allows anyone to help the owner.
- **Verdict**: Griefing (triggering recovery early) is usually Negative-EV for attacker and strictly helpful/neutral for owner.

**🧠 Knowledge Update**
- **Pattern**: `public recover() { send(hardcoded_owner); }`
- **Rule**: If destination is fixed/protected, public access is not a bug.

