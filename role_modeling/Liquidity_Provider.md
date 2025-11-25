# Role: Liquidity Provider (Market Maker)

## 1. Function-Level Capabilities

In this HTLC-based system, there is no passive "Liquidity Provider" who deposits into a pool. Instead, the "Liquidity Provider" is an active **Market Maker (MM)** who acts as the counterparty to Normal Users (Swappers).

- **`initiate(...)`**: The MM calls this on the *destination* chain to lock the asset the User wants to buy.
- **`redeem(...)`**: The MM calls this on the *source* chain to claim the asset the User sold, using the secret revealed by the User.
- **`refund(...)`**: The MM calls this on the destination chain if the User fails to reveal the secret in time.
- **`instantRefund(...)`**: The MM signs this to allow the User to exit early if the trade is aborted off-chain.

## 2. Business-Level Capabilities

- **Order Fulfillment**: The MM is the primary enabler of liquidity. Without MMs, users would have to find peer-to-peer matches manually.
- **Spread Capture**: The MM profits from the price difference between the source asset and the destination asset (minus fees).
- **Inventory Management**: The MM must balance assets across multiple chains (EVM, Solana, Starknet, Sui) to ensure they can fulfill orders.
- **Risk Management**:
    - **Liveness Risk**: The MM *must* be online to `redeem` on the source chain after the User reveals the secret on the destination chain. If they miss the window, they lose the funds (User refunds source, MM already paid destination).
    - **Reorg Risk**: If the destination chain reorgs after the MM sees the secret, the MM might have already revealed the secret on the source chain.

## 3. Financial-Level Capabilities

- **Capital Deployment**: The MM locks large amounts of capital in `HTLC` contracts across chains.
- **Asset Custody**: The MM retains custody of their assets until the swap is atomic. They do not trust the protocol with pooled funds.
- **Solvency**: The MM's solvency is their own concern. The protocol does not insure them.
- **Fee Optimization**: MMs likely batch transactions or use optimized routing to minimize gas costs.

## 4. Effective Capability Summary

The Market Maker is a "Super User" with high availability and capital.

- **Can**:
    - Facilitate trades for any user.
    - Censor trades (by refusing to act as counterparty), though users can find other MMs.
    - Arbitrage price discrepancies.
- **Cannot**:
    - Steal user funds (cryptographically prevented by HTLC).
    - Mint/Burn tokens (unless they are the token issuer, which is outside protocol scope).
- **Influence**:
    - Determines the effective "price" and "spread" for users.
    - Critical for system liveness and usability.
