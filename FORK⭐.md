# FORK.md: NOFACE Protocol Dependency & Fork Strategy

## 1. The Core Privacy Math (The "Brain")
*   **Source:** [**Privacy Pools v1 (Ameen Soleimani / Noir Implementation)**](https://github.com/privacy-pools/privacy-pools-optimism)
*   **What it's for:** The Zero-Knowledge (ZK) circuits for deposit and withdrawal logic.
*   **Why:** It is the industry standard for "Compliant Privacy." It includes the **Association Set (Clean Set)** logic, which allows the protocol to remain legal in the USA.
*   **When:** Integrated during **Phase 1 (Month 0-6)**.
*   **Where:** `circuits/src/kernel/main.nr` and `specs/compliance.md`.
*   **How to connect:** The output of these circuits (the Proof) is sent to the `Verifier.sol` contract to authorize vault releases.

## 2. The Membership Logic (The "Memory")
*   **Source:** [**Semaphore (Privacy Scaling Explorations / Ethereum Foundation)**](https://github.com/semaphore-protocol/semaphore)
*   **What it's for:** Incremental Merkle Tree implementation.
*   **Why:** Semaphore is the gold standard for "proving you belong to a group without revealing who you are." Being built by the **Ethereum Foundation** gives us 100% mathematical trust.
*   **When:** Integrated during **Phase 1**.
*   **Where:** `contracts/src/libraries/IncrementalTree.sol`.
*   **How to connect:** Every deposit into the `NofaceVault.sol` updates this tree to create a new "Commitment" for the user.

## 3. The Asset Vault (The "Safe")
*   **Source:** [**OpenZeppelin (ERC-4626 Tokenized Vault Standard)**](https://github.com/OpenZeppelin/openzeppelin-contracts)
*   **What it's for:** Secure handling of USDC, ETH, and other assets.
*   **Why:** OpenZeppelin is the most audited code in DeFi. Using the **ERC-4626 standard** ensures NOFACE is compatible with yield-bearing protocols like Yearn and Aave.
*   **When:** Integrated during **Phase 1**.
*   **Where:** `contracts/src/core/NofaceVault.sol`.
*   **How to connect:** Users deposit into the ERC-4626 vault, which then triggers the ZK-circuit to "Shield" the deposit.

## 4. The Trading Engine (The "Hook")
*   **Source:** [**Uniswap v4 Periphery (Hooks)**](https://github.com/Uniswap/v4-periphery)
*   **What it's for:** Shielded Swaps and Private Liquidity.
*   **Why:** To avoid building a new DEX. We "fork" the hook logic to allow NOFACE users to trade directly against Uniswap’s $5B+ liquidity pools without leaving the privacy layer.
*   **When:** Integrated during **Phase 2 (Month 12-18)**.
*   **Where:** `contracts/src/hooks/NofaceHook.sol`.
*   **How to connect:** The hook calls `NofaceVault.sol` to verify a user has the funds (via ZK-proof) before executing a swap on the Uniswap Singleton.

## 5. The Intent Settlement (The "Driver")
*   **Source:** [**CoW Protocol (CoWSwap Settler Contracts)**](https://github.com/cowprotocol/contracts)
*   **What it's for:** Off-chain matching of user "Intents."
*   **Why:** CoWSwap has the best logic for preventing MEV (Front-running). By forking their **Solver/Settlement** logic, we ensure that shielded trades cannot be sniped by bots.
*   **When:** Integrated during **Phase 2**.
*   **Where:** `contracts/src/sequencer/BatchManager.sol` and `infra/solver/`.
*   **How to connect:** Solvers collect ZK-Intents from the `IntentPool.sol` and bundle them into a single transaction to the `BatchManager`.

## 6. The Metadata Shield (The "Cloak")
*   **Source:** [**OHTTP (Cloudflare / IETF Standard)**](https://github.com/cloudflare/ohttp-go)
*   **What it's for:** Hiding User IP Addresses.
*   **Why:** Even if the ZK-math is perfect, an RPC provider can see a user's IP. OHTTP is the internet standard for "Oblivious" requests.
*   **When:** Integrated during **Phase 1**.
*   **Where:** `infra/indexer/ohttp-gateway/`.
*   **How to connect:** The NOFACE SDK routes all "Note Discovery" requests through this gateway before they hit the blockchain indexer.

## 7. The Token Logic (The "Utility")
*   **Source:** [**Solady (Vectorized ERC-20)**](https://github.com/Vectorized/solady)
*   **What it's for:** The $NOFACE Governance Token.
*   **Why:** Solady is the most gas-efficient implementation of ERC-20. It reduces the cost for users to transfer and stake $NOFACE.
*   **When:** Integrated during **Phase 3 (TGE)**.
*   **Where:** `contracts/src/governance/NofaceToken.sol`.
*   **How to connect:** $NOFACE is used to pay the "Shielding Fee" within the `NofaceVault.sol`.

---
