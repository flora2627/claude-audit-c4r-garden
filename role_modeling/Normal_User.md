# Role: Normal User

## 1. Function-Level Capabilities

A "Normal User" is an EOA with no special privileges or prior state in the system. They can access all public, permissionless entry points.

### EVM (ArbHTLC, HTLC, NativeHTLC, UDA)
- **`initiate(...)`**: Create a new swap order by locking assets (ERC20 or ETH).
- **`initiateOnBehalf(...)`**: Create a swap order on behalf of another address (specifying `initiator` in params).
- **`initiateWithSignature(...)`**: Create a swap order using a signature (if supported).
- **`redeem(...)`**: Claim assets from an existing order using the correct preimage (`secret`).
- **`refund(...)`**: Reclaim assets from an expired order.
- **`instantRefund(...)`**: Reclaim assets immediately if possessing a valid signature from the counterparty (`redeemer`).
- **`initialise(...)`**: Initialize a proxy/UDA if applicable (e.g., in `UDA.sol` or `ArbHTLC`).
- **`createERC20SwapAddress(...)` / `createNativeSwapAddress(...)`**: Deploy new swap contracts via `HTLCRegistry`.

### Solana (Native & SPL Swaps)
- **`initiate`**: Create a swap account and fund it.
- **`redeem`**: Claim funds from a swap account with the secret.
- **`refund`**: Reclaim funds from a swap account after expiry.
- **`instant_refund`**: Reclaim funds immediately with counterparty signature.

### Starknet (HTLC)
- **`initiate` / `initiate_with_destination_data`**: Lock assets.
- **`initiate_on_behalf`**: Lock assets for another.
- **`redeem`**: Claim assets.
- **`refund`**: Reclaim expired assets.
- **`instant_refund`**: Reclaim with signature.

### Sui (Main)
- **`initiate`**: Create shared object order.
- **`redeem`**: Claim coin object.
- **`refund`**: Reclaim coin object.
- **`instant_refund`**: Reclaim with signature.

## 2. Business-Level Capabilities

- **Order Creation**: Can unilaterally create new financial obligations (swaps) by locking their own assets.
- **Order Finalization**: Can finalize any order (theirs or others') *if* they possess the correct cryptographic secret (preimage).
- **Order Cancellation**: Can cancel their own orders and recover funds *after* the timelock expires.
- **Cooperative Cancellation**: Can cancel orders immediately *if* the counterparty agrees (signs).
- **Delegation**: Can act as a relayer/broker by initiating orders on behalf of others (`initiateOnBehalf`), potentially charging fees or facilitating UX (gas abstraction).
- **Registry Interaction**: Can deploy new persistent swap addresses/contracts via the Registry.

## 3. Financial-Level Capabilities

- **Asset Locking**: Can move assets from their wallet into the protocol's custody (Contract/PDA/SharedObject).
- **Asset Unlocking**: Can trigger the release of assets from the protocol to themselves (as redeemer or refundee).
- **Solvency Impact**:
    - **Positive**: Adds TVL (temporarily) during `initiate`.
    - **Neutral**: Swaps are generally peer-to-peer; no global debt pool is modified, but local contract balances change.
    - **Risk**: If a user can `refund` before expiry or `redeem` without the secret, they cause a solvency deficit (theft).
- **Fee Generation**: If the protocol charges fees on initiate/redeem (not explicitly seen in `scope.txt` summaries but possible), they trigger fee accrual.

## 4. Effective Capability Summary

The Normal User is the primary actor in this system. Their power is defined by **cryptographic knowledge** (secrets/signatures) and **time** (expiry).

- **Can**:
    - Lock arbitrary amounts of capital (up to their own balance).
    - Unlock capital they have a right to (via secret or timeout).
    - Facilitate trades for others (relayer).
    - Deploy new infrastructure (via Registry).
- **Cannot**:
    - Access funds locked by others without the secret.
    - Refund their own funds before expiry without counterparty consent.
    - Modify global protocol parameters (fees, governance).
    - Pause or freeze the system.
- **Influence**:
    - Direct control over the "Active Orders" state.
    - Indirect influence on network congestion and event emission logs.
