# PRC-369

**Programmable Economic Rights Standard for Locked Capital**

PRC-369 is a next-generation protocol standard designed to separate **capital ownership** from **economic rights**, enabling programmable, transferable and composable rights over locked on-chain assets without moving the underlying capital.

Unlike traditional token standards that represent ownership of an asset, PRC-369 introduces a new primitive for decentralized finance: **Programmable Economic Rights (PERs)**.

## Vision

Modern DeFi has successfully tokenized assets, liquidity and debt.

However, capital locked inside long-term positions remains economically rigid. Users must often choose between maintaining conviction and preserving liquidity.

PRC-369 solves this problem by allowing the economic rights associated with a locked position to evolve independently while the underlying capital remains safely secured in its native protocol.

**Capital remains. Rights evolve. Conviction compounds.**

---

## Core Principles

* **Capital is immutable.** The underlying asset never leaves its native reserve protocol except through its original redemption process.

* **Economic rights are programmable.** Rights may be transferred, split, merged, composed or exchanged without compromising the underlying reserve.

* **Time has measurable value.** Locked duration is treated as an economic resource rather than a restriction.

* **Economic conservation is mandatory.** Every transformation preserves value according to deterministic settlement rules.

* **History is immutable.** Every state transition is traceable and auditable.

* **Kernel-first architecture.** The protocol core remains minimal, deterministic and independent of application logic.

---

## Architecture

PRC-369 is built as a layered protocol.

```text
Applications
    │
MINTer Vault
Marketplace
Lending
Explorer
SDK
    │
Settlement Engine
Evolution Engine
Rights Engine
Ledger
Vault
    │
Asset Adapters
    │
PRC-369 Kernel
    │
Native Reserve Protocols
```

The Kernel defines the language of the protocol.

Applications implement business logic.

Asset Adapters connect external reserve protocols without modifying the Kernel.

---

## Initial Reference Implementation

The first implementation of PRC-369 is **MINTer Vault**.

MINTer Vault demonstrates how programmable economic rights can be created from native reserve positions while preserving capital security.

The first supported reserve family is:

* MCReserve

Future reserve families include:

* DCReserve
* HCReserve
* PCReserve
* PCXReserve
* PRCReserve
* ICReserve
* CCReserve
* MTCReserve

All future integrations are expected to be implemented through dedicated Asset Adapters without requiring changes to the PRC-369 Kernel.

---

## Design Goals

* Modular architecture
* Deterministic execution
* Audit-friendly codebase
* Minimal Kernel
* Extensible Asset Adapter framework
* Long-term protocol stability

---

## Repository Structure

```text
contracts/
docs/
audits/
examples/
```

Additional modules, SDKs and tooling will be added as the standard evolves.

---

## Development Status

Current Phase:

**Genesis — Kernel Development**

The project is currently focused on defining and implementing the immutable Kernel that will serve as the foundation for future protocol modules.

---

## License

MIT License

