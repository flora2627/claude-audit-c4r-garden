# 🚨 Finding 012: 未授权初始化 HTLC/ArbHTLC 可注入恶意 Token，导致空头订单与资金双向失衡

## 📝 检查总览

| 序号 | 错误类型 | 位置 / 函数 / 文件 | 发现依据 | 风险等级 |
|------|----------|---------------------|----------|----------|
| 012 | Access Control + Accounting Invariant Break | `HTLC.initialise`, `ArbHTLC.initialise`, `HTLCRegistry.createERC20SwapAddress`, `UDA.initialize` | 任意地址可将 HTLC 绑定到恶意 ERC20，Registry 会把该 Token 当作真实资产处理，从而生成没有真实资产支撑的订单 | **Critical** |

---

## 🔍 详细说明

**核心问题**：`HTLC` 与 `ArbHTLC` 的 `initialise()` 函数缺乏访问控制。部署完合约到`token`尚未设置之前，任意地址都能抢先调用并将合约永久绑定到攻击者控制的“假 Token”。之后：

1. Registry 会把这个恶意 Token 视为某个合法资产的官方 HTLC（`htlcs[token] = _htlc`）。  
2. `createERC20SwapAddress()` 在验证质押是否到位时，会调用恶意 Token 的 `balanceOf()`，攻击者可让它返回任意“大于等于 amount”的数字，即使实际并无任何资金。  
3. `UniqueDepositAddress.initialize()` 与 `HTLC._initiate()` 会继续信任这个 Token，通过 `safeTransferFrom`/`safeTransfer` 操作；恶意 Token 可以“成功返回 true”但不真正转账。  
4. 于是 `orders[orderId].amount` 被记为 >0，而合约真实资产余额为 0，直接打破 `token.balanceOf(this) ≥ ∑amount` 的复式记账不变量。  

在跨链业务场景中，攻击者扮演“发起方”即可制造“空头 HTLC”事件：

- 在 EVM 侧创建看似锁定了真实资产的订单（事件里 amount > 0），引导对手方在另一条链上锁仓。  
- 获取秘密后，攻击者在另一链提走对手方资产。  
- 受害者随后在 EVM 链 Redemption 时只能收到攻击者自定义的恶意 Token（甚至 transfer 直接返回 true 却不给资产），资金 100% 损失。  

### 触发条件 / 调用链

1. 观察到新部署的 `HTLC` / `ArbHTLC` 合约（尚未初始化）。  
2. 使用更高 gas 费用抢在官方 `initialise(realToken)` 交易之前，调用 `initialise(maliciousToken)`。  
3. Registry 继续使用该合约，并在 `createERC20SwapAddress()` 中拿恶意 Token 的 `balanceOf` 做充值校验。  
4. 通过 UDA 启动订单，`safeTransferFrom`/`safeTransfer` 由恶意 Token 返回 success，即刻生成“无资产支撑”的订单。  
5. 对手方在其它链履约后，Redeem 时无法收到真实资产，形成资金损失。  

### 证据链

- 无访问控制的初始化入口：`HTLC.initialise` / `ArbHTLC.initialise`
- Registry 信任 `token()` 结果：`HTLCRegistry.createERC20SwapAddress`
- UDA 直接调用 `HTLC.token().approve()`：`UDA.initialize`
- 订单写入后调用 `safeTransferFrom`：`HTLC._initiate`

详见：
```106:118:evm/src/swap/HTLC.sol
function initialise(address _token) public {
    require(isInitialized == 0, HTLC__HTLCAlreadyInitialized());
    token = IERC20(_token);
    unchecked { isInitialized++; }
}
```

```112:118:evm/src/swap/ArbHTLC.sol
function initialise(address _token) public {
    require(isInitialized == 0, ArbHTLC__HTLCAlreadyInitialized());
    token = IERC20(_token);
    unchecked { isInitialized++; }
}
```

```138:155:evm/src/swap/HTLCRegistry.sol
bytes memory encodedArgs = abi.encode(...);
address _implUDA = implUDA;
address addr = _implUDA.predictDeterministicAddressWithImmutableArgs(encodedArgs, salt);
require(IERC20(HTLC(htlc).token()).balanceOf(addr) >= amount, HTLCRegistry__InsufficientFundsDeposited());
if (addr.code.length == 0) {
    address uda = _implUDA.cloneDeterministicWithImmutableArgs(encodedArgs, salt);
    uda.functionCall(abi.encodeCall(UniqueDepositAddress.initialize, ()));
}
```

```28:40:evm/src/swap/UDA.sol
function initialize() public initializer {
    (address _addressHTLC, address refundAddress, address redeemer, uint256 timelock, bytes32 secretHash, uint256 amount, bytes memory destinationData) = getArgs();
    HTLC(_addressHTLC).token().approve(_addressHTLC, amount);
    HTLC(_addressHTLC).initiateOnBehalf(refundAddress, redeemer, timelock, amount, secretHash, destinationData);
}
```

```312:329:evm/src/swap/HTLC.sol
orders[orderID] = Order({... amount: amount_, ...});
token.safeTransferFrom(funder_, address(this), amount_);
```

### 影响

- **复式记账断裂**：`token.balanceOf(this)` 与 `orders[orderId].amount` 不再匹配。
- **跨链互换对手方资金全损**：对方在异链履约后，Redeem 得到的只是恶意 Token（或直接失败），现实资产无法追回。
- **治理面难以自动发现**：事件日志与订单状态看起来“正常”，需要额外稽核才发现资产缺失。

### 建议修复

> 遵守项目“仅报告问题、不提供修复方案”的约束，此处不提供修复建议。

---

## ✅ 验证完成

1. 确认 `HTLC` / `ArbHTLC` 的 `initialise` 无访问控制且一次写死。  
2. 推导部署 → 抢跑初始化 → 恶意 Token 注入 → Registry 信任 → 生成空头订单的完整调用链。  
3. 结合 `acc_modeling/account_ivar.md` 中的资产=负债不变量，验证该攻击直接破坏记账恒等式。  
4. 评估跨链实际业务：对手方按照事件履约后，在 Redeem 阶段遭遇 100% 资金损失。  
5. 确认攻击者不需要任何权限，仅需在初始化窗口内发送一笔交易即可。


