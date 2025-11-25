# Role: Relayer

## 1. Function-Level Capabilities

The Relayer is an EOA that facilitates transactions for other users, typically to abstract gas costs or simplify the UX.

- **`initiateOnBehalf(...)`**: Creates an order where `msg.sender` (Relayer) pays the gas/funds, but `initiator` is set to another address.
- **`initiateWithSignature(...)`**: Submits a user's EIP-712 signature to create an order. The Relayer pays the gas.
- **`createERC20SwapAddress(...)`**: Can deploy UDAs for users.

## 2. Business-Level Capabilities

- **Gas Abstraction**: Allows users to initiate swaps without holding native gas tokens (ETH/SOL/MATIC) on the source chain, provided the Relayer is compensated (off-chain or via the swap mechanism).
- **Order Routing**: Can act as a gateway, choosing which orders to submit.
- **Censorship (Weak)**: Can refuse to relay a specific user's transaction, but cannot prevent the user from submitting it themselves (since `initiate` is permissionless).
- **Front-running**: Can see a user's intent (via mempool or off-chain channel) and potentially front-run, though in HTLCs, the `secretHash` protects the trade uniqueness.

## 3. Financial-Level Capabilities

- **Fee Collection**: Can charge a fee for the service (likely built into the exchange rate or paid separately).
- **Capital Requirement**: Needs native gas tokens to submit transactions.
- **Risk**:
    - If relaying `initiateOnBehalf` with their own funds: High risk if the user doesn't pay them back.
    - If relaying `initiateWithSignature`: Low risk, just gas cost.

## 4. Effective Capability Summary

The Relayer is a service provider.

- **Can**:
    - Submit transactions for others.
    - Deploy infrastructure (UDAs).
- **Cannot**:
    - Alter the trade parameters (signed by user).
    - Steal funds (user is the `initiator` and `refundAddress`).
- **Influence**:
    - Improves UX and onboarding.
    - Centralization vector if users rely solely on specific relayers.
