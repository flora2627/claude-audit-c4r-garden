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

---

### 1.8 Unprotected Initialization Front-Running (from finding_012)

**🔁 Knowledge Reflection**

**Context**: `initialise(address _token) public` with no access control in HTLC/ArbHTLC contracts.

**Issue initially identified**:
- Attacker can front-run deployment → inject malicious token → Registry owner adds it without verification → users lock real funds on counterparty chain → attacker redeems with malicious tokens → fund loss

**Misunderstanding revealed**:
- Attack path requires MULTIPLE operational failures by trusted parties:
  1. Owner failing to monitor initialization transaction
  2. Owner failing to verify token address before calling `addHTLC()`
  3. Users failing to verify token address before locking counterparty funds
- Not a pure protocol logic flaw - requires off-chain social engineering

**Blind spot**:
- Failed to distinguish between "exploitable on-chain" vs "requires operational failures"
- Centralization-dependent attacks should be classified differently when system is explicitly centralized and trusted parties are assumed competent

**🧠 Knowledge Update**

**Pattern**: Unprotected `initialize()` / `initialise()` functions in contracts that will be integrated into centralized registries

**Rule - When to classify as FALSE POSITIVE**:

A "front-running initialization → inject malicious parameters" vulnerability should be classified as **FALSE POSITIVE** when ALL of the following are true:

1. **Centralization acknowledged**: System documentation explicitly states owner is trusted (check known-issues.md, README, or audit scope)
2. **Defense-in-depth exists**: Multiple verification layers protect against the attack:
   - Owner verification before integration
   - User verification before committing value
3. **Audit rules exclude centralization**: Audit directive [Core-5] or similar states "Centralization issues are out of scope"
4. **Requires privileged failures**: Attack requires trusted privileged party to make operational mistakes (violates [Core-4]: "Only accept attacks that a normal, unprivileged account can initiate")
5. **Not 100% attacker-controlled**: Attack path requires social engineering, governance mistakes, or probabilistic events (violates [Core-6])
6. **User competence assumption**: Audit assumes technically competent users who verify configurations (e.g., [Core-9]: "用户会严格检查自己的操作和协议配置")
7. **Negative EV**: Economic analysis shows P(success) < 0.1% when competent parties are involved

**Rule - When to classify as VALID**:

Classify as VALID vulnerability if ANY of the following:

1. **System claims trustless**: Protocol documentation claims "trustless", "decentralized", or "no admin keys" but has unprotected initialization
2. **No defense layers**: No owner verification step exists before integration, or automatic integration without human review
3. **Centralization in scope**: Audit explicitly includes centralization risks
4. **High probability**: P(success) > 10% under realistic operational assumptions
5. **Positive EV**: Attacker expected value is positive even accounting for low probability

**Computation Template for Economic Viability**:

```
P(success) = P(deploy_frontrun) × P(owner_no_verify) × P(user_no_verify)

For Garden Finance case:
P(success) ≈ 0.95 × 0.01 × 0.05 = 0.000475 = 0.0475% (< 0.1% threshold)

EV = P(success) × victim_funds - attack_cost
EV = 0.000475 × $100,000 - $100 = $47.50 - $100 = -$52.50 (NEGATIVE)
```

**SafeERC20 Universal Limitation**:

OpenZeppelin's `SafeERC20.safeTransferFrom()` (applies to ALL EVM projects using it):
- ✅ Checks return value (handles non-standard ERC20s)
- ❌ Does NOT verify balance changes before/after
- ❌ Cannot prevent intentionally malicious tokens from returning `true` without transferring

This is a **documented limitation**, not a bug. Any EVM project using SafeERC20 has this constraint.

**Defense-in-Depth Model for Token Trust**:

Projects using external tokens should implement defense layers:

1. **Token Whitelisting**: Owner maintains list of approved tokens (centralized but explicit)
2. **Owner Verification**: Manual verification of token addresses before integration (Garden Finance model)
3. **Balance Checking**: Code-level balance checks before/after transfers (trustless but gas-heavy)
4. **User Education**: Document that users must verify token addresses (education layer)

Absence of Layer 3 (balance checking) is NOT a vulnerability if Layers 1, 2, and 4 exist and are documented.

**📍 Future Checkpoint**

**When auditing unprotected initialization patterns:**

1. **Check centralization model** (in order):
   - Read known-issues.md / README / audit scope for centralization statements
   - Check if owner/admin is explicitly trusted
   - Verify if centralization risks are in/out of scope per audit rules

2. **Map defense layers**:
   - Deployment: Atomic init? Constructor init? Front-run protection?
   - Integration: Owner verification step? Automatic or manual?
   - Usage: User verification expected? Standard practice in this domain?

3. **Compute attack economics**:
   - Probability: P(layer1_fail) × P(layer2_fail) × P(layer3_fail)
   - Cost: Gas + infrastructure + opportunity cost
   - Gain: Expected value of successful attack
   - EV: P × Gain - Cost
   - Threshold: If EV < 0 or P < 0.1%, likely false positive

4. **Apply audit directive filters**:
   - [Core-4]: Does attack require privileged party failure? → If YES, check if in scope
   - [Core-5]: Is this centralization issue? → If YES and out of scope → FALSE POSITIVE
   - [Core-6]: Is attack 100% attacker-controlled? → If NO (requires social engineering) → FALSE POSITIVE
   - [Core-9]: Does attack assume users don't verify? → If YES and users assumed competent → FALSE POSITIVE

5. **Classification decision tree**:
   ```
   Is system centralized & documented?
     ├─ NO → Check if defense layers exist → Classify based on exploitability
     └─ YES → Is centralization in scope?
          ├─ NO → FALSE POSITIVE (out of scope)
          └─ YES → Does attack require owner operational failure?
               ├─ NO → VALID (attacker-only exploit)
               └─ YES → Compute EV → If negative or P<0.1% → FALSE POSITIVE
   ```

**Key Insight**: "Unprotected initialization" is a **design weakness** but becomes a **vulnerability** only under specific conditions. The conditions must be evaluated in context of:
- Trust model (centralized vs trustless)
- Audit scope (centralization in/out)
- Defense layers (single point of failure vs defense-in-depth)
- Economics (positive EV vs negative EV)
- User assumptions (naive vs competent)

---
