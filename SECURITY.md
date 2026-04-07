# SECURITY.md: NOFACE Protocol Technical Security Specifications

## 1. System Invariants
The protocol is designed to maintain the following mathematical and logical conditions at all times:
*   **Solvency Invariant:** The total value of assets in the vault must always equal the sum of unspent Merkle Tree commitments.
*   **Nullifier Uniqueness:** A cryptographic nullifier can only be recorded as "spent" once. Any attempt to reuse a nullifier must result in a transaction revert.
*   **Non-Custodial Design:** User private keys and withdrawal notes are never transmitted to the protocol. Control of assets is governed strictly by the cryptographic ownership of valid nullifiers.

## 2. Zero-Knowledge Proof Integrity (Circuit Soundness)
The security of the privacy layer depends on the mathematical soundness of the ZK-circuits (Noir/Circom).
*   **Soundness Risk:** A bug in the circuit logic could allow an attacker to generate a "fake" proof to withdraw assets they do not own.
*   **Mitigation:** All circuits must undergo **Formal Verification** to prove that the constraints correctly enforce nullifier uniqueness and Merkle Tree root validity.
*   **Double-Constraint Pattern:** Every circuit is designed with redundant constraints to ensure that "witness generation" cannot be manipulated.

## 3. Smart Contract Security Standards
To mitigate Ethereum Virtual Machine (EVM) level exploits, NOFACE utilizes the following industry-standard patterns:

### A. Execution Logic
*   **Checks-Effects-Interactions (CEI):** All state changes occur before external contract calls to prevent recursive exploitation.
*   **Reentrancy Protection:** Implementation of the `nonReentrant` modifier (OpenZeppelin) on all functions involving asset transfers.

### B. Economic Security
*   **Oracle Manipulation:** NOFACE does not rely on internal pool liquidity for pricing. It utilizes **Chainlink TWAP (Time-Weighted Average Price)** oracles to prevent price distortion during single-block Flash Loan attacks.
*   **SafeMath:** Use of Solidity 0.8.x native overflow protection and the `SafeERC20` library for all standardized token interactions.

## 4. Governance & Risk Management (The Guardrail Phase)
Given the complexity of ZK-circuits, the protocol utilizes a **Temporary Proxy Architecture** during the initial 12–24 months of operation.

*   **3-of-5 Multi-Signature Wallet:** Administrative actions (e.g., triggering a pause or upgrading code) require approval from three out of five independent security guardians.
*   **The Circuit Breaker (Emergency Pause):** The Multi-Sig can trigger a `pause()` function.
    *   **Scope:** Deposits are paused.
    *   **Exit Sovereignty:** The `withdraw()` function remains active, ensuring users can always redeem their nullifiers and exit the protocol.
*   **48-Hour Timelock:** All non-emergency upgrades are subject to a public 48-hour delay, allowing the community to verify the code change before execution.

## 5. Audit & Disclosure Requirements
Deployment to an Ethereum Layer-2 Mainnet requires a two-stage security validation:
1.  **Technical Logic Audit:** A line-by-line review of the Solidity contracts focusing on state transitions and access control.
2.  **ZK-Circuit Audit:** A specialized review of mathematical constraints, "trusted setup" (if applicable), and circuit soundness.
3.  **Public Bug Bounty:** Integration with **Immunefi**, offering rewards of up to $5,000,000 USD for critical (fund-loss) vulnerabilities.

***
