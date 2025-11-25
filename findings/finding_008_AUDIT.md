# 🚨 Finding 008: UDA Griefing Attack - Unprotected `recover()` Allows Fund Theft Before Initialization

## 📝 检查总览

| 序号 | 错误类型 | 位置 / 函数 / 文件 | 发现依据 | 风险等级 |
|------|----------|-------------------|----------|----------|
| 008 | Implementation Bug | `UDA.sol::recover()` L61-64, L70-73 | Anyone can call `recover()` before `initialize()`, stealing deposited funds | **CRITICAL** |

---

## 🔍 详细说明

### 位置
- **File**: `evm/src/swap/UDA.sol`
- **Functions**: `recover(address _token)` L61-64, `recover()` L70-73
- **Same issue in**: `NativeUniqueDepositAddress` L127-130, L136-139

### 问题分析

#### Current Implementation
```solidity
// UniqueDepositAddress.sol:61-64
function recover(address _token) public {
    (, address refundAddress,,,,,) = getArgs();
    IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
}

// UniqueDepositAddress.sol:70-73
function recover() public {
    (, address _refundAddress,,,,,) = getArgs();
    payable(_refundAddress).transfer(address(this).balance);
}
```

**NO ACCESS CONTROL** - Anyone can call `recover()` at any time!

### 攻击场景 (Attack Scenario)

#### Scenario 1: Front-Running `initialize()`

**Setup**:
1. User creates UDA via `HTLCRegistry.createERC20SwapAddress()`
2. UDA address is deterministically computed
3. User deposits 1000 USDC to UDA address
4. User submits transaction to call `initialize()`

**Attack**:
1. Attacker monitors mempool
2. Attacker sees user's `initialize()` transaction
3. Attacker front-runs with `UDA.recover(USDC)` with higher gas
4. **Result**: 1000 USDC sent to `refundAddress` (which is the user's intended initiator)
5. User's `initialize()` transaction executes but with 0 balance
6. `initiateOnBehalf()` fails because UDA has no tokens to approve/transfer

**Impact**:
- User's funds are sent to `refundAddress` prematurely
- Atomic swap is not initiated
- User must manually recover and retry

#### Scenario 2: Malicious `refundAddress`

**Setup**:
1. Attacker creates UDA with `refundAddress = attacker.address`
2. Victim accidentally sends tokens to UDA address (wrong address)
3. Attacker calls `recover()` to steal victim's tokens

**Impact**:
- Victim loses funds
- No recourse

### 证据链

**Code Evidence**:
```solidity
// UDA.sol:61-64
function recover(address _token) public {  // ❌ No access control!
    (, address refundAddress,,,,,) = getArgs();
    IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
}

// UDA.sol:28-40
function initialize() public initializer {  // ✅ Protected by `initializer`
    // ... get args ...
    HTLC(_addressHTLC).token().approve(_addressHTLC, amount);
    HTLC(_addressHTLC).initiateOnBehalf(refundAddress, redeemer, timelock, amount, secretHash, destinationData);
}
```

**Expected Flow**:
1. User deposits tokens to UDA
2. User calls `initialize()`
3. UDA approves and calls `HTLC.initiateOnBehalf()`
4. Tokens transferred from UDA to HTLC

**Actual Vulnerable Flow**:
1. User deposits tokens to UDA
2. **Attacker calls `recover()`** ← Griefing attack
3. Tokens sent to `refundAddress`
4. User calls `initialize()`
5. `initiateOnBehalf()` fails (no tokens)

### 影响分析

#### 1. **Implementation Bug (编码层)**
- **Missing Access Control**: `recover()` should only be callable after failed initialization or by authorized party
- **Race Condition**: Front-running window between deposit and initialization

#### 2. **Financial Model Flaw (金融层)**
- **Griefing Attack**: Attacker can prevent atomic swap initiation
- **Fund Misdirection**: Funds sent to `refundAddress` before swap is created
- **UX Degradation**: User must manually handle refunded tokens and retry

### 建议修复

#### Option 1: Restrict `recover()` to Post-Initialization (Recommended)
```diff
+ bool private initialized;

  function initialize() public initializer {
      // ... existing code ...
      HTLC(_addressHTLC).initiateOnBehalf(refundAddress, redeemer, timelock, amount, secretHash, destinationData);
+     initialized = true;
  }

  function recover(address _token) public {
+     require(initialized, "UDA: not yet initialized");
      (, address refundAddress,,,,,) = getArgs();
      IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
  }
```

**Pros**:
- Prevents front-running
- Allows recovery after initialization
- Minimal code change

**Cons**:
- Adds storage variable (gas cost)
- Doesn't help if initialization fails

#### Option 2: Add Access Control to `recover()`
```diff
  function recover(address _token) public {
      (, address refundAddress,,,,,) = getArgs();
+     require(msg.sender == refundAddress, "UDA: only refund address");
      IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
  }
```

**Pros**:
- Simple fix
- Allows `refundAddress` to recover at any time
- No additional storage

**Cons**:
- Still allows `refundAddress` to grief themselves
- Doesn't prevent front-running if `refundAddress` is attacker

#### Option 3: Remove `recover()` Entirely
```diff
- function recover(address _token) public { ... }
- function recover() public { ... }
```

**Pros**:
- Eliminates attack vector
- Simplifies contract

**Cons**:
- No way to recover accidentally sent tokens
- Reduces flexibility

#### Option 4: Combine Initialization and Deposit (Best)
```solidity
function initializeWithDeposit(address _token, uint256 amount) public initializer {
    // Transfer tokens in same transaction as initialization
    IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);
    
    // ... rest of initialization ...
    HTLC(_addressHTLC).token().approve(_addressHTLC, amount);
    HTLC(_addressHTLC).initiateOnBehalf(refundAddress, redeemer, timelock, amount, secretHash, destinationData);
}
```

**Pros**:
- Atomic operation (no front-running window)
- No griefing possible
- Most secure

**Cons**:
- Changes UX flow
- Requires user to approve UDA instead of depositing directly

### 风险评级理由

- **CRITICAL**: 
  - Allows fund theft/griefing
  - No access control on critical function
  - Exploitable by any attacker
  - Breaks intended atomic swap flow
  - Affects ALL UDA instances

**Why CRITICAL**:
- Direct fund loss possible (if `refundAddress` is malicious)
- Griefing attack always possible (front-run `initialize()`)
- No user action can prevent attack
- Affects core protocol functionality

---

## ✅ 验证完成 (Verification Complete)

1. ✅ Analyzed `recover()` access control
2. ✅ Identified missing protection against front-running
3. ✅ Confirmed attack scenario is exploitable
4. ✅ Verified same issue in both `UniqueDepositAddress` and `NativeUniqueDepositAddress`
5. ✅ Proposed multiple mitigation strategies

---

# 🔴 STRICT AUDIT REPORT - FINDING 008

## Executive Verdict: **FALSE POSITIVE (Informational)**

**One-sentence rationale:** The `recover()` function intentionally sends funds to the user's own `refundAddress` in all scenarios, making this a griefing attack with zero economic incentive rather than fund theft; both claimed scenarios fail economic viability tests.

---

## Reporter's Claim Summary

The report alleges two critical attack vectors:
1. **Front-running attack**: Attacker can front-run `initialize()` to grief user's swap
2. **Malicious refundAddress**: Attacker can steal accidentally sent tokens

Claimed severity: CRITICAL (fund theft possible)

---

## Code-Level Analysis

### Call Chain Trace - Normal Flow

**Step 1: User gets UDA address**
- Caller: User EOA
- Callee: `HTLCRegistry.getERC20Address()`
- Function: View function, returns deterministic address
- Returns: UDA address (not yet deployed)

**Step 2: User deposits tokens**
- User sends tokens directly to UDA address (no contract code yet)
- On-chain state: Tokens at address with no code

**Step 3: User initiates swap**
- Caller: User EOA
- Callee: `HTLCRegistry.createERC20SwapAddress()`
- msg.sender: User EOA

**HTLCRegistry.createERC20SwapAddress() L149:**
```solidity
require(IERC20(HTLC(htlc).token()).balanceOf(addr) >= amount, HTLCRegistry__InsufficientFundsDeposited());
```
- Check: Balance >= amount BEFORE deployment
- State read: ERC20 balance of UDA address

**HTLCRegistry.createERC20SwapAddress() L151-154:**
```solidity
if (addr.code.length == 0) {
    address uda = _implUDA.cloneDeterministicWithImmutableArgs(encodedArgs, salt);
    emit UDACreated(address(uda), address(refundAddress), htlc);
    uda.functionCall(abi.encodeCall(UniqueDepositAddress.initialize, ()));
}
```
- Conditional: Only if UDA not deployed
- Deploy + Initialize in SAME transaction (atomic)
- Call type: functionCall (library wrapper around low-level call)

**UniqueDepositAddress.initialize() L28-40:**
- msg.sender: HTLCRegistry contract
- Modifier: `initializer` (OpenZeppelin protection)
- Line 38: `HTLC(_addressHTLC).token().approve(_addressHTLC, amount)`
- Line 39: Calls `HTLC.initiateOnBehalf()`

**HTLC.initiateOnBehalf() L186-197:**
- msg.sender: UDA contract address
- Callee: `_initiate()`
- Parameters: funder=UDA, initiator=refundAddress, redeemer, timelock, amount, secretHash

**HTLC._initiate() L321:**
```solidity
token.safeTransferFrom(funder_, address(this), amount_);
```
- Call type: ERC20 transferFrom via SafeERC20
- From: UDA contract
- To: HTLC contract
- Amount: Specified amount
- Prerequisite: UDA must have approved HTLC (done in line 38 above)

---

### Call Chain Trace - Claimed Attack Scenario 1

**Attacker attempts to deploy UDA and call recover():**

**Step 1: Attacker deploys UDA**
- Attacker could theoretically call Clones library directly
- Deploy UDA with user's parameters (including user's refundAddress)
- UDA now exists at deterministic address

**Step 2: Attacker calls recover()**
- Caller: Attacker EOA
- Callee: `UDA.recover(address _token)`
- msg.sender: Attacker EOA (not validated - function is public)

**UDA.recover() L61-64:**
```solidity
function recover(address _token) public {
    (, address refundAddress,,,,,) = getArgs();
    IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
}
```
- Line 62: Reads refundAddress from immutable args (baked into UDA bytecode)
- Line 63: Transfers ALL tokens to refundAddress
- **CRITICAL**: refundAddress is USER'S address, NOT attacker's address!

**Step 3: User calls createERC20SwapAddress()**
- HTLCRegistry L151: `addr.code.length > 0` (UDA already deployed)
- Skips deployment and initialization
- Returns UDA address
- Swap not initiated

**Result:**
- Tokens sent to USER'S refundAddress (user still owns them)
- Swap not initiated (user must retry)
- Attacker spent gas, gained NOTHING

---

### State Scope & Context Audit

**Critical State: `refundAddress`**

**Storage Location:** NOT in storage - stored in contract bytecode via Clones immutable args pattern

**How it's set:**
```solidity
// HTLCRegistry.sol L140-141
bytes memory encodedArgs = abi.encode(htlc, refundAddress, redeemer, timelock, secretHash, amount, destinationData);
address uda = _implUDA.cloneDeterministicWithImmutableArgs(encodedArgs, salt);
```

**How it's read:**
```solidity
// UDA.sol L51-54
function getArgs() internal view returns (address, address, address, uint256, bytes32, uint256, bytes memory) {
    bytes memory args = address(this).fetchCloneArgs();
    return abi.decode(args, (address, address, address, uint256, bytes32, uint256, bytes));
}
```

**Key insight:** The refundAddress is IMMUTABLE and baked into the UDA bytecode during deployment. It cannot be changed after deployment.

**Who controls refundAddress:** The caller of `createERC20SwapAddress()` / `getERC20Address()` - i.e., the USER.

**Deterministic address calculation (L142-144):**
```solidity
bytes32 salt = keccak256(
    abi.encodePacked(refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData))
);
```

**Critical point:** Salt INCLUDES refundAddress. Therefore:
- Different refundAddress → Different salt → Different UDA address
- IMPOSSIBLE to create same UDA address with different refundAddress

---

## Exploit Feasibility Analysis

### Scenario 1: Front-running Attack

**Prerequisites:**
1. User deposits tokens to UDA address
2. UDA not yet deployed
3. Attacker can deploy UDA via direct Clones library call

**Attack steps:**
1. Monitor mempool for deposits to predicted UDA addresses
2. Front-run with UDA deployment (no initialization)
3. Call `recover()` before user's `createERC20SwapAddress()`

**Analysis:**
✅ Technically feasible (no privileged account required)
❌ Funds sent to user's own refundAddress, NOT attacker
❌ User retains full control of funds
❌ Zero economic gain for attacker

**Blocker:** This is griefing, not theft. Funds always go to the address specified by the user in the UDA parameters.

### Scenario 2: Malicious refundAddress

**Claim:** "Attacker creates UDA with refundAddress = attacker.address, victim accidentally sends tokens"

**Analysis:**
- If attacker creates UDA with their own refundAddress, they get a DIFFERENT UDA address (salt includes refundAddress)
- Victim would need to specifically send to attacker's UDA address
- This is equivalent to "victim sends funds to wrong address" - user error, not protocol vulnerability
- Attacker could simply call `initialize()` instead of `recover()` to initiate their own swap

**Verdict:** Not a protocol vulnerability. This is user error (sending to wrong address).

---

## Economic Analysis

### Attacker P&L - Scenario 1 (Front-running)

**Inputs:**
- Gas cost for deploying UDA: ~100k gas
- Gas cost for calling recover(): ~50k gas
- Total gas: ~150k gas
- At 50 gwei and $3000 ETH: ~$22.50

**Outputs:**
- Funds sent to: User's refundAddress (NOT attacker)
- Attacker receives: $0
- User impact: Must retry swap (inconvenience)

**Net EV:** -$22.50 (purely negative for attacker)

**Sensitivity Analysis:**
- Even at 1 gwei gas price: Still negative EV (attacker gains nothing)
- Even if victim deposits $1M: Attacker still gains $0
- No price scenario makes this profitable

**Conclusion:** Economically irrational attack. Pure griefing with guaranteed loss.

### Attacker P&L - Scenario 2 (Malicious refundAddress)

**This scenario is logically incoherent:**
- Attacker controls their own UDA parameters
- Attacker gets deterministic address based on THEIR parameters
- For victim to "accidentally" send to this exact address requires victim error
- If attacker wanted these funds in an HTLC, they'd call `initialize()`, not `recover()`

**Conclusion:** Not a protocol vulnerability. Equivalent to victim sending to wrong address.

---

## Dependency/Library Reading

### OpenZeppelin Initializable.sol

**`initializer` modifier behavior:**
- Prevents function from being called more than once
- Sets internal flag `_initialized`
- If function reverts, flag may or may not be set (version dependent)
- In constructor, `_disableInitializers()` prevents initialization of implementation

**`_disableInitializers()` in UDA.sol L21:**
```solidity
constructor() {
    _disableInitializers();
}
```
- Prevents initialization of implementation contract
- Only clones can be initialized

### OpenZeppelin SafeERC20.sol

**`safeTransfer` in recover() L63:**
```solidity
IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
```
- Wrapper around ERC20 transfer
- Handles non-standard ERC20 implementations
- Reverts on failure
- No reentrancy vector (checks-effects-interactions pattern)

### Clones Library

**`cloneDeterministicWithImmutableArgs`:**
- Creates minimal proxy (EIP-1167 + immutable args pattern)
- Anyone can call on public implementation
- Deterministic address based on implementation + salt + args
- No access control in library itself

**Security implication:** Anyone can deploy UDA if they know the parameters. This enables the griefing attack but not fund theft.

---

## Feature vs. Bug Assessment

### Intended Behavior Analysis

**From UDA.sol NatSpec L57-59:**
```solidity
/**
 * @notice  Allows the owner to recover any tokens accidentally sent to this contract
 * @dev     Always sends the funds to the owner (refundAddress) of the contract
 * @param   _token  The ERC20 token to recover
 */
```

**Key observation:** Comment says "Allows the owner" but function has no `onlyOwner` modifier.

**Two interpretations:**
1. **Bug:** Missing access control (documentation says "owner", code allows anyone)
2. **Feature:** Intentionally public so anyone can help recover stuck funds to rightful owner

**Evidence for "Feature":**
- Function ALWAYS sends to refundAddress (hardcoded beneficiary)
- No way to redirect funds to caller
- Permissionless design reduces dependency on user action
- Common pattern in rescue/recovery functions

**Evidence for "Bug":**
- Documentation mentions "owner" without enforcement
- Could enable griefing (but not theft)

**Verdict:** This is a **documentation inconsistency** rather than a security vulnerability. The actual behavior (funds always to refundAddress) is safe, even if callable by anyone.

---

## Known Issues Cross-Reference

Checking `/known-issues.md`:
- No mention of UDA recover() griefing
- No mention of front-running UDA deployment

**However**, the impact is purely griefing, which is typically out of scope for most audits unless it can lock funds permanently.

---

## Final Severity Assessment

### Original Claim: CRITICAL
**Justification given:**
- "Allows fund theft/griefing"
- "No access control on critical function"
- "Exploitable by any attacker"

### Actual Severity: **INFORMATIONAL / LOW**

**Correct classification:**

**Not Critical/High because:**
- ❌ No fund theft possible
- ❌ No fund loss possible
- ❌ Funds always go to legitimate user's address
- ❌ User retains full custody at all times

**Not Medium because:**
- ❌ Protocol doesn't break (user can retry)
- ❌ Funds are immediately recoverable (already at user's address)
- ❌ No economic damage to user (except gas for retry)

**Why Informational:**
- ✅ Griefing attack possible but economically irrational
- ✅ Documentation inconsistency ("owner" vs public function)
- ✅ UX degradation only (user must retry)
- ✅ No privileged exploit required
- ✅ Working as designed (funds to refundAddress)

---

## Corrected Attack Analysis

### What the attack ACTUALLY does:

1. Attacker spends gas to grief user
2. User's funds sent to user's own address
3. User experiences delay/inconvenience
4. User retries swap with same funds
5. Attacker gains nothing, loses gas

### What the attack DOES NOT do:

- ❌ Steal funds
- ❌ Lock funds permanently
- ❌ Redirect funds to attacker
- ❌ Cause economic loss to user
- ❌ Break protocol invariants

---

## Recommended Actions

### For Protocol Team:

**Option 1: Document as intended behavior**
- Update NatSpec to clarify function is intentionally public
- Add comment explaining permissionless recovery design
- No code changes needed

**Option 2: Add access control (if griefing is concern)**
```diff
function recover(address _token) public {
    (, address refundAddress,,,,,) = getArgs();
+   require(msg.sender == refundAddress, "UDA: only refund address");
    IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
}
```

**Option 3: Add initialization check (reduces griefing window)**
```diff
+   bool private _udaInitialized;

    function initialize() public initializer {
        // ... existing code ...
+       _udaInitialized = true;
    }

    function recover(address _token) public {
+       require(_udaInitialized, "UDA: not initialized");
        (, address refundAddress,,,,,) = getArgs();
        IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
    }
```

**Recommendation:** Option 1 or 2. Option 3 doesn't fully solve griefing and adds gas cost.

### For Auditors:

- Classify as **QA/Informational**
- Not eligible for critical/high/medium bounty
- Document as griefing vector with no economic impact

---

## Conclusion

**Executive Summary:**

The reported "UDA griefing attack" is a **false positive** when evaluated for fund theft. While technically possible to grief users, the attack:
- Has zero economic incentive (negative EV)
- Sends funds to user's own address (no theft)
- Causes only temporary inconvenience (user retries)
- May be intentional design (permissionless recovery)

**Final Verdict:** **FALSE POSITIVE** (downgrade to Informational/QA)

**Core principle violated by original report:** Failed to verify economic viability and actual fund flow. The claim of "fund theft" is demonstrably false through code analysis showing funds ALWAYS go to user-specified refundAddress.

**One-sentence summary:** A griefing attack that sends user funds back to the user is an inconvenience, not a critical vulnerability.
