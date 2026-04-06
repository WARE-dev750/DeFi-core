# SECURITY.md: ROby Protocol Security Architecture

## 1. The Hierarchy of Trust
In a decentralized system, security is a zero-sum game between **Agility** (fixing bugs) and **Sovereignty** (protecting users from the developer).

| Security Model | Risk Factor | Logic |
| :--- | :--- | :--- |
| **Admin Keys** | **Highest** | A single point of failure (Phishing, Extortion, Insider Threat). |
| **Multi-Sig** | **Medium** | Collusion risk. If 3 of 5 signers are compromised, the protocol is lost. |
| **Immutability** | **Lowest** | Math is constant. Risk shifts entirely to the initial code audit. |

**Logic Conclusion:** For a 10-digit target, the core logic must be **Immutable.** Humans are the weakest link in any encryption or security chain.

---

## 2. Attack Vector Mitigation

### A. Economic Attacks (Flash Loans)
*   **Vulnerability:** Attackers use massive temporary liquidity to manipulate price oracles and drain pools.
*   **Mathematical Defense:** Use **Time-Weighted Average Prices (TWAP)** and decentralized oracles (Chainlink).
*   **Constraint:** No single transaction should be able to move the internal price of an asset by more than 2% without triggering a high-slippage penalty.

### B. Logical Attacks (Reentrancy)
*   **Vulnerability:** Calling an external contract before updating the internal balance.
*   **Mathematical Defense:** Strict adherence to the **Checks-Effects-Interactions (CEI)** pattern.
*   **Constraint:** Mandatory use of `ReentrancyGuard` on all state-changing functions.

### C. Privacy Attacks (Heuristics)
*   **Vulnerability:** Eavesdropping on metadata (timing, gas amounts, IP addresses) to de-anonymize users.
*   **Mathematical Defense:** **zk-SNARKs (Zero-Knowledge Succinct Non-Interactive Arguments of Knowledge).**
*   **Constraint:** Transactions are only valid if they include a mathematically verifiable proof that the sender has the balance, without revealing the balance or the sender's address.

---

## 3. Governance & "The Kill Switch"

To balance the "Immutable" risk (if a bug is found), ROby Protocol utilizes a **Decentralized Circuit Breaker.**

1.  **The Sentinel Role:** An automated bot monitors the Total Value Locked (TVL).
2.  **The Trigger:** If more than 10% of TVL leaves the protocol in a single block (mathematically impossible in normal trading), the protocol enters **"Safe Mode."**
3.  **Safe Mode:** Withdrawals are paused for 24 hours. This provides the only window for a **Multi-Sig** of audited security experts to review the code. 
4.  **The Expiry:** If no action is taken in 24 hours, Safe Mode expires automatically. This prevents "Founder Hostage" scenarios.

---

## 4. Disclosure Policy (Bug Bounty)

*   **Logic:** It is mathematically more profitable for a hacker to report a bug for $2M than to steal $100M and be hunted by global law enforcement for life (decreasing the utility of the stolen funds).
*   **The Bounty:** 10% of the "at-risk" funds, capped at $5,000,000 USD.
*   **Immunity:** ROby Protocol guarantees legal "Safe Harbor" for any researcher who discovers a vulnerability and discloses it privately without exploiting it.

---
