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

