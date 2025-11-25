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

