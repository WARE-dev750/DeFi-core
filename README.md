## 1. Protocol Security Model
The NOFACE security model is built on the principle of **Minimizing Human Intervention.** The protocol relies on mathematical proofs to verify transactions rather than administrative oversight.

*   **Immutability:** The core logic of the smart contracts is non-upgradeable. Once deployed, the bytecode cannot be modified.
*   **Non-Custodial Design:** At no point does the protocol, its developers, or its administrative keys have custody of user assets. Control is strictly governed by the cryptographic ownership of nullifiers.
*   **Zero-Knowledge Proofs:** Transaction validity is enforced by ZK-circuits. These circuits verify that a user has the right to spend an asset without revealing the asset's history or the user's identity.

## 2. Smart Contract Architecture
To protect against common decentralized finance (DeFi) exploits, the following technical standards are implemented:

### A. Reentrancy Protection
*   **Mechanism:** All state-changing functions follow the **Checks-Effects-Interactions (CEI)** pattern.
*   **Guard:** Implementation of the `nonReentrant` modifier from OpenZeppelin to prevent recursive call attacks during asset transfers.

### B. Oracle Integrity (Price Feeds)
*   **Mechanism:** To prevent price manipulation via Flash Loans, the protocol does not rely on internal liquidity for pricing.
*   **Implementation:** Use of decentralized oracles (e.g., Chainlink) providing **Time-Weighted Average Prices (TWAP)** to ensure price stability across blocks.

### C. Integer Safety
*   **Implementation:** Use of Solidity 0.8.x native overflow/underflow checks. Standard interactions with ERC-20 tokens are handled via the `SafeERC20` library to manage non-standard token behaviors.

## 3. Privacy Engine (Zero-Knowledge Layer)
The privacy engine utilizes a **Nullifier-based Shielded Pool**. 

*   **Merkle Tree Root Verification:** Each withdrawal must provide a ZK-proof showing that their commitment exists in the protocol's Merkle Tree.
*   **Nullifier Uniqueness:** To prevent "Double-Spending," every successful withdrawal marks a unique nullifier as "spent" on the blockchain. 
*   **Circuit Soundness:** All ZK-circuits (Noir/Circom) must undergo **Formal Verification** to prove that no mathematical edge-case allows for the creation of unauthorized assets.

## 4. Incident Response & Risk Management

### A. Administrative Access (Multi-Sig vs. Master Key)
To prevent a single point of failure (a "Master Key" being stolen), the protocol utilizes a **3-of-5 Multi-Signature wallet** for administrative actions.
*   **Scope:** Administrative powers are limited to triggering the "Circuit Breaker" and adjusting protocol parameters (e.g., fee rates).
*   **Time-Lock:** All non-emergency administrative actions are subject to a **48-hour time-lock**, allowing the community to verify the change before it goes live.

### B. Circuit Breaker (Emergency Pause)
*   **Action:** In the event of a detected exploit, the Multi-Sig can trigger a `pause()` function.
*   **Restriction:** The pause only affects new deposits. The withdrawal function remains accessible at all times to ensure users can exit the protocol.

### C. Bug Bounty Program
*   **Platform:** Hosted on **Immunefi**.
*   **Incentive:** Rewards are tiered based on the severity of the vulnerability. The maximum payout for a "Critical" (fund-loss) bug is $5,000,000 USD, funded by the protocol treasury.

## 5. Audit & Disclosure Requirements
Before any Mainnet deployment, NOFACE requires:
1.  **Contract Logic Audit:** Focus on state transitions and EVM-level security.
2.  **ZK-Circuit Audit:** Mathematical review of circuit constraints and soundness.
3.  **Public Disclosure:** All audit reports must be published in full on the project’s GitHub repository.

---
