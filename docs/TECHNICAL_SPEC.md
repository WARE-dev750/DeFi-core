# VielFi Technical Specification

## 1. Overview
VielFi is a Zero-Knowledge (ZK) privacy protocol built on Ethereum. It utilizes a shielded pool model (based on the UTXO/Note paradigm) to allow users to deposit, swap, and withdraw assets with privacy guarantees.

## 2. Cryptographic Primitives
- **Hash Function**: Poseidon2 over the BN254 curve.
- **Proof System**: PLONK-based UltraHonk (via Noir).
- **Commitment Scheme**: $C = \text{Poseidon2}(secret, nullifier, token, amount)$.
- **Nullifier**: $N = \text{Poseidon2}(nullifier, C)$.

## 3. System Components

### 3.1 Shielded Vault (`VeilCore.sol`)
The core state machine of the protocol. It maintains a Merkle Tree of commitments.
- **Deposit**: Users submit a commitment $C$ and transfer the required asset.
- **Withdraw**: Users submit a ZK-SNARK proof verifying:
    - Membership of $C$ in the Merkle Tree.
    - Ownership of the $nullifier$ secret.
    - Consistency of the $nullifier\_hash$.
    - Correctness of the $recipient$ and $fee$ binding.

### 3.2 Fee Management & Buybacks (`FeeManager.sol`)
Handles protocol revenue and sustainability.
- **Entry Fee**: 0.2% of deposits.
- **Exit Fee**: 0.1% of withdrawals.
- **Buyback Engine**: Accumulates fees and periodically executes swaps on Uniswap v4 to buy back and burn $VIEL tokens or distribute to stakers.

### 3.3 Integration Hooks
VielFi supports private interactions with external DeFi protocols (e.g., Uniswap v4) via "App Circuits" that are recursively verified within the Privacy Kernel.

## 4. Security Model
- **Privacy**: Achieved through an anonymity set (the Merkle Tree). The size of the set determines the level of privacy.
- **Soundness**: Guaranteed by the ZK-SNARK proof system. No assets can be withdrawn without a valid proof of a prior deposit.
- **Anti-Frontrunning**: All intents (recipient, fee, relayer) are cryptographically bound to the ZK proof.
