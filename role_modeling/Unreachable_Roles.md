# Unreachable Roles (Non-EOA)

## Owner (HTLCRegistry)

### Function-Level Capabilities
- **`setImplNativeUDA(address)`**: Update the Native UDA implementation contract.
- **`setImplUDA(address)`**: Update the ERC20 UDA implementation contract.
- **`addHTLC(address)`**: Add a new HTLC contract to the registry.

### Business-Level Capabilities
- **Protocol Governance**: Controls which HTLC contracts are "official" and which UDA implementations are used.
- **Upgrade Path**: Can change the UDA implementation, effectively changing the behavior of future deployments.

### Financial-Level Capabilities
- **Indirect Risk**: If the Owner sets a malicious UDA implementation, future users who deploy UDAs could have their funds stolen.
- **No Direct Custody**: The Owner does not hold user funds directly.

### Effective Capability Summary
The Owner is a **trusted role** in the system.

- **Can**:
    - Update critical infrastructure (UDA implementations).
    - Add new HTLC contracts to the registry.
- **Cannot**:
    - Steal funds from existing orders (HTLCs are immutable once deployed).
    - Pause or freeze the system (no emergency stop).
- **Influence**:
    - High trust assumption: Users must trust the Owner not to deploy malicious UDA implementations.
    - Centralization vector: If the Owner is compromised, future UDA deployments are at risk.

---

## Notes on Privilege Model

- **No Admin in HTLC Contracts**: The core `HTLC`, `NativeHTLC`, `ArbHTLC` contracts have no admin functions. Once deployed, they are immutable.
- **Registry Owner is the Only Privileged Role**: The `HTLCRegistry` Owner is the only privileged role in the system.
- **Solana/Starknet/Sui**: No privileged roles detected in the scope (all functions are user-callable or internal).
