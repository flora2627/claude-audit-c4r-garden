# Role: Swapper / Trader

## 1. Function-Level Capabilities

The "Swapper" is a specialization of the Normal User who actively engages in cross-chain atomic swaps. They utilize the same entry points but in a specific sequence to achieve a value exchange.

- **`initiate(...)`**: Locks the "Sell" asset.
- **`redeem(...)`**: Unlocks the "Buy" asset using the preimage.
- **`refund(...)`**: Recovers the "Sell" asset if the trade fails (timeout).
- **`instantRefund(...)`**: Fast cancellation if the counterparty agrees.
- **`createERC20SwapAddress(...)`**: (Optional) Uses a deterministic address to fund the swap (CEX-like flow).

## 2. Business-Level Capabilities

- **Atomic Exchange**: Can exchange Asset A on Chain X for Asset B on Chain Y without trusting the counterparty (trustless via HTLC).
- **Price Discovery**: implicitly agrees to a price by the ratio of `amount` locked on Chain X vs Chain Y.
- **Optionality**:
    - The Swapper (Initiator) effectively writes a "call option" to the Counterparty. The Counterparty can choose to proceed (lock their side) or not.
    - If the Counterparty locks, the Swapper (Redeemer on destination) has the "option" to reveal the secret and claim.
    - **Crucial**: Once the secret is revealed on one chain, the atomicity is enforced *cryptographically* but requires *liveness* to claim on the other chain.
- **Counterparty Selection**: Can choose a specific `redeemer` or leave it open (if protocol allows `address(0)` - check code, usually HTLC requires specific redeemer).
    - *Code Check*: `safeParams` requires `redeemer != address(0)`. So Swapper *must* select a counterparty upfront.

## 3. Financial-Level Capabilities

- **Capital Efficiency**: Capital is locked for `timelock` duration.
- **Slippage**: Defined by the difference between the agreed amounts and market rates at the time of settlement.
- **Cross-Chain Arbitrage**: Can exploit price differences between chains.
- **Refund Risk**:
    - If Swapper initiates but Counterparty never responds: Swapper loses liquidity for `timelock`.
    - If Swapper reveals secret on Chain Y but fails to redeem on Chain X (e.g., gas spike, censorship): Swapper might lose funds if Chain X timelock expires (though usually Chain X timelock > Chain Y timelock to prevent this).
- **Fee Payment**: Pays gas fees for `initiate` and `redeem` (unless using a Relayer/Meta-tx).

## 4. Effective Capability Summary

The Swapper is the primary value-driver of the protocol.

- **Can**:
    - Execute trustless cross-chain trades.
    - Cancel trades (eventually) if the other side defaults.
    - Use "Deposit Addresses" (UDA) for easier funding flows.
- **Cannot**:
    - Force the counterparty to proceed.
    - Recover funds immediately without counterparty consent.
    - Change the terms of the trade once initiated (immutable).
- **Influence**:
    - Generates volume and TVL.
    - Emits events (`Initiated`, `Redeemed`) that indexers/market makers rely on.
