## 标题
HTLCRegistry 允许所有已预存资金的 UDA 被所有者随时“换锁”，导致资产永久卡死

## 严重等级
High

## 描述
- `HTLCRegistry.setImplUDA()` / `setImplNativeUDA()` 允许合约所有者随时替换 `implUDA`/`implNativeUDA`（`HTLCRegistry.sol` 88-100 行）。
- `getERC20Address()` / `getNativeAddress()` 在计算用户要预先充值的 UDA 地址时，会把当前实现地址作为 CREATE2 输入的一部分（同文件 170-190、244-263 行）。
- 用户必须 **先** 把资产充到该预测地址，再调用 `create*SwapAddress()` 启动克隆；否则余额检查 `IERC20(...).balanceOf(addr) >= amount` / `address(addr).balance >= amount` 不通过（同文件 148-226 行）。
- 一旦所有者在“充值”与“创建”之间修改实现地址，`create*SwapAddress()` 会改用新的实现地址重新计算 `addr`，余额检查永远失败，而旧地址上的资产没有私钥、无法转出。

结果：所有者只需在看到大额充值后更新实现地址，就能把这笔资产永久卡死。由于用户无法在交易里锁定实现地址，也没有任何取回入口，这是一个确定可实现的“借贷不平”——资产已经记入 UDA 地址（资产方），但对应的 HTLC 负债永远建立不了。

## 影响
- 任何在“充值→创建”流程中的用户都要 **完全信任** 所有者在他们调用 `create*SwapAddress()` 之前不会更新实现地址。
- 所有者（或被攻破的所有者密钥）可以先观察充值，再瞬间调用 `setImpl{Native}UDA()`，从而永久冻结所有尚未完成的充值资产（ERC20 与原生代币均可），造成 100% 的资金损失。

## 复现（ERC20 流）
1. 所有者设置 `implUDA = Impl_A`，用户通过 `getERC20Address()` 得到地址 `addr_A` 并向其转入 `amount` 代币。
2. 在用户调用 `createERC20SwapAddress()` 之前，所有者把实现替换为 `Impl_B`。
3. 用户沿用原参数调用 `createERC20SwapAddress()`：
   - 函数此时用 `Impl_B` 计算 `addr_B` 并检查 `balanceOf(addr_B) >= amount`，由于资产在 `addr_A`，检查失败并 revert。
4. `addr_A` 没有私钥、也不再会有合约部署（实现已切换），资金永久卡死。

同样流程对 `createNativeSwapAddress()` / `getNativeAddress()` 也成立。

## 证据
```148:156:evm/src/swap/HTLCRegistry.sol
        address addr = _implUDA.predictDeterministicAddressWithImmutableArgs(encodedArgs, salt);
        require(IERC20(HTLC(htlc).token()).balanceOf(addr) >= amount, HTLCRegistry__InsufficientFundsDeposited());
        if (addr.code.length == 0) {
            address uda = _implUDA.cloneDeterministicWithImmutableArgs(encodedArgs, salt);
            emit UDACreated(address(uda), address(refundAddress), htlc);
            uda.functionCall(abi.encodeCall(UniqueDepositAddress.initialize, ()));
        }
```

```85:100:evm/src/swap/HTLCRegistry.sol
    function setImplNativeUDA(address _impl) external onlyOwner validContractAddress(_impl) {
        implNativeUDA = _impl;
        emit NativeUDAImplUpdated(_impl);
    }
    function setImplUDA(address _impl) external onlyOwner validContractAddress(_impl) {
        implUDA = _impl;
        emit UDAImplUpdated(_impl);
    }
```

```170:190:evm/src/swap/HTLCRegistry.sol
        return implUDA.predictDeterministicAddressWithImmutableArgs(
            abi.encode(htlc, refundAddress, redeemer, timelock, secretHash, amount, destinationData),
            keccak256(abi.encodePacked(refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData)))
        );
```

```244:263:evm/src/swap/HTLCRegistry.sol
        return implNativeUDA.predictDeterministicAddressWithImmutableArgs(
            abi.encode(nativeHTLC, refundAddress, redeemer, timelock, secretHash, amount, destinationData),
            keccak256(abi.encodePacked(refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData)))
        );
```

## 建议
（遵守「不提供修复建议」约束，此处留空）

---

# AUDIT ADJUDICATION REPORT

## 1) Executive Verdict
**FALSE POSITIVE - Out of Scope (Centralization Risk)**

This report describes a logically valid attack path but requires privileged owner action to execute. Per audit directive [Core-4] ("Only accept attacks that a normal, unprivileged account can initiate") and [Core-5] ("Centralization issues are out of scope"), this falls outside the audit scope.

## 2) Reporter's Claim Summary
The reporter claims that the HTLCRegistry owner can permanently freeze user funds by changing the UDA implementation address (`implUDA` or `implNativeUDA`) between when users deposit funds and when they call `createERC20SwapAddress()`/`createNativeSwapAddress()`. This causes an address computation mismatch, making the balance check fail while leaving funds stranded at an address with no private key or deployed contract.

## 3) Code-Level Analysis

### 3.1 Logic Existence: CONFIRMED
The reported attack path is logically valid:

**File: evm/src/swap/HTLCRegistry.sol**

- **Lines 97-100**: Owner can change `implUDA` at any time
  ```solidity
  function setImplUDA(address _impl) external onlyOwner validContractAddress(_impl) {
      implUDA = _impl;
      emit UDAImplUpdated(_impl);
  }
  ```

- **Lines 182-189 (`getERC20Address`)**: Computes address using CURRENT `implUDA`
  ```solidity
  return implUDA.predictDeterministicAddressWithImmutableArgs(
      abi.encode(htlc, refundAddress, redeemer, timelock, secretHash, amount, destinationData),
      keccak256(abi.encodePacked(refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData)))
  );
  ```

- **Lines 145-149 (`createERC20SwapAddress`)**: Loads CURRENT `implUDA` and computes address
  ```solidity
  address _implUDA = implUDA; // loads from storage
  address addr = _implUDA.predictDeterministicAddressWithImmutableArgs(encodedArgs, salt);
  require(IERC20(HTLC(htlc).token()).balanceOf(addr) >= amount, HTLCRegistry__InsufficientFundsDeposited());
  ```

### 3.2 Address Computation Dependency
CREATE2 address computation includes the implementation address in the bytecode hash. Changing `implUDA` from `Impl_A` to `Impl_B` produces:
- `addr_A = CREATE2(HTLCRegistry, salt, bytecode_with_Impl_A)`
- `addr_B = CREATE2(HTLCRegistry, salt, bytecode_with_Impl_B)`
- `addr_A ≠ addr_B`

### 3.3 Recovery Analysis
The UDA contracts (evm/src/swap/UDA.sol:61-73) contain `recover()` functions to retrieve stuck funds. However:
- Recovery functions only exist if the contract is deployed
- If implementation changes before deployment, no contract is ever deployed to `addr_A`
- `addr_A` is a CREATE2-predicted address with no private key
- **Conclusion**: Funds are permanently unrecoverable

## 4) Call Chain Trace

### Normal Flow (No Attack):
```
1. User → HTLCRegistry.getERC20Address() [view call]
   - msg.sender: User
   - Returns: addr_A (computed with Impl_A)

2. User → ERC20.transfer(addr_A, amount) [external call to token contract]
   - msg.sender: User
   - Transfers tokens to addr_A

3. User → HTLCRegistry.createERC20SwapAddress(...) [call]
   - msg.sender: User
   - Internally:
     a) Loads implUDA = Impl_A (still)
     b) Computes addr = addr_A (same as step 1)
     c) Checks balanceOf(addr_A) >= amount ✓
     d) Deploys clone to addr_A
     e) addr_A.initialize() → HTLC.initiateOnBehalf()
```

### Attack Flow:
```
1. User → HTLCRegistry.getERC20Address() [view call]
   - msg.sender: User
   - implUDA = Impl_A
   - Returns: addr_A

2. User → ERC20.transfer(addr_A, amount)
   - msg.sender: User
   - Tokens now at addr_A

2.5. Owner → HTLCRegistry.setImplUDA(Impl_B) [privileged call]
   - msg.sender: Owner
   - Changes: implUDA = Impl_B (storage write)

3. User → HTLCRegistry.createERC20SwapAddress(...) [call]
   - msg.sender: User
   - Internally:
     a) Loads implUDA = Impl_B (NEW)
     b) Computes addr = addr_B (DIFFERENT from addr_A)
     c) Checks balanceOf(addr_B) >= amount ✗
   - Transaction reverts

4. Funds stuck at addr_A:
   - No private key exists
   - No contract will ever be deployed (impl changed to Impl_B)
   - No recovery path
```

## 5) State Scope Analysis

### Storage Variables:
- `implUDA` (HTLCRegistry.sol:42): **Storage** - globally shared, owner-controlled
- `implNativeUDA` (HTLCRegistry.sol:43): **Storage** - globally shared, owner-controlled

### Local Variables:
- `_implUDA` (HTLCRegistry.sol:145): **Memory** - loaded from storage at execution time
- `addr` (HTLCRegistry.sol:148): **Memory** - computed based on `_implUDA`

### Critical Finding:
- `getERC20Address()` (view function) reads `implUDA` from storage at time T1
- User deposits funds based on address computed at T1
- `createERC20SwapAddress()` reads `implUDA` from storage at time T2
- If `implUDA[T1] ≠ implUDA[T2]`, computed addresses differ
- No transaction-level locking mechanism exists to prevent this race condition

## 6) Exploit Feasibility

### Prerequisites:
1. ❌ **Requires privileged account**: Owner must call `setImplUDA()`
2. ✓ Timing window exists (deposit → create must be separate transactions)
3. ✓ No user-side mitigation possible (cannot lock implementation in create call)

### Attack Execution:
- **Attacker**: Must be contract owner (privileged)
- **Victim**: Any user in deposit→create flow
- **Cost**: Single `setImplUDA()` transaction (~50k gas)
- **Gain**: None direct (purely griefing/malicious)
- **Detection**: Owner can monitor mempool for large deposits, front-run with `setImplUDA()`

### Verdict on Exploitability:
**REQUIRES PRIVILEGED ACCOUNT** - Violates audit directive [Core-4]:
> "Check whether the attack requires any privileged account (including phishing/compromise). Only accept attacks that a normal, unprivileged account can initiate."

A normal, unprivileged EOA **CANNOT** execute this attack. Only the contract owner can call `setImplUDA()`.

## 7) Economic Analysis

### Not Applicable - Centralization Risk
This is not an economic exploit by an external attacker. It is a governance/centralization risk where:
- **Owner**: Trusted party with broad system control
- **Motivation**: Would need to be malicious or compromised
- **User defense**: Must trust owner OR avoid protocol during deployment phase

### Known Issues Acknowledgment:
From known-issues.md:5:
> "Centralization risk in `HTLCRegistry` contract. The ownership is present only to set implementation contract addresses for the UDAs and to set valid HTLC addresses."

The project explicitly acknowledges owner control over implementation addresses.

## 8) Dependency/Library Reading Notes

### Clones Library Analysis:
- Uses OpenZeppelin Clones pattern with immutable args variant
- `predictDeterministicAddressWithImmutableArgs(args, salt)` computes CREATE2 address
- CREATE2 formula: `keccak256(0xFF, deployer, salt, keccak256(bytecode))`
- Bytecode includes both implementation address and immutable args
- **Confirmed**: Changing implementation address changes computed CREATE2 address

### UDA Recovery Mechanism (evm/src/swap/UDA.sol):
- Lines 61-73: `recover()` and `recover(address _token)` functions exist
- These send funds to `refundAddress` extracted from clone args
- **Critical limitation**: Recovery only works if contract is deployed
- If implementation changes pre-deployment, contract never exists at predicted address
- **Conclusion**: No recovery path for this attack scenario

## 9) Final Feature-vs-Bug Assessment

### This is NOT a Valid Finding Because:

**Reason 1: Requires Privileged Account (Core-4 Violation)**
The attack requires the contract owner to maliciously call `setImplUDA()`. Per [Core-4]:
> "Only accept attacks that a normal, unprivileged account can initiate."

**Reason 2: Centralization Risk (Core-5 Exclusion)**
Per [Core-5]:
> "Centralization issues are out of scope for this audit."

The owner already has broad control over the system:
- Can set HTLC implementation addresses (via `addHTLC()`)
- Can set UDA implementation addresses (via `setImplUDA()`/`setImplNativeUDA()`)
- Can potentially deploy malicious implementations

This specific attack is one manifestation of general owner trust assumptions.

**Reason 3: Known Issue**
The project documentation (known-issues.md) explicitly acknowledges centralization risks in HTLCRegistry, including owner control over implementation addresses.

### Design Considerations (Educational):
While out of scope, the two-step process (deposit → create) does create a trust dependency that could be mitigated by:
1. Including implementation address as a parameter in `createERC20SwapAddress()` for user verification
2. Timelock on implementation changes
3. Atomic deposit+create in single transaction (though CREATE2 mechanics make this difficult)

However, these are design trade-offs, not vulnerabilities, given the stated trust model.

## 10) Supplementary Notes

### User Behavior Assumption (Core-9):
Per [Core-9], users are "技术背景的普通用户，会严格遵守规则，但是会严格检查自己的操作和协议配置" (technical users who strictly follow rules and carefully check their operations and protocol configuration).

Even careful technical users **cannot protect themselves** from this attack because:
- They cannot atomically lock the implementation address in their transaction
- They cannot verify the implementation hasn't changed between query and create
- The protocol provides no on-chain mechanism for implementation verification

**However**, this does not change the verdict because:
1. Attack still requires privileged owner action (Core-4)
2. Still falls under centralization risk (Core-5)
3. Users' primary "check" is trusting the protocol owner (documented trust assumption)

### Comparison to Standard Centralization Risks:
- **Typical centralization**: "Owner can upgrade to steal funds" → Known, accepted risk
- **This finding**: "Owner can front-run deposits to lock funds via implementation swap" → More specific attack vector, but fundamentally same trust dependency

The specificity and severity don't override the core requirement that attacks must be executable by unprivileged accounts.

---

## FINAL VERDICT: FALSE POSITIVE (Out of Scope)

**Classification**: Centralization Risk
**Severity if in scope**: Would be High (permanent fund loss)
**Actual status**: Out of scope per Core-4 and Core-5
**Recommendation**: Document this specific attack vector in known-issues.md for transparency, but treat as accepted trust assumption rather than vulnerability

