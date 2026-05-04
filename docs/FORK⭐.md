# Fork Credits & Integrations

In adherence to the core mandate: *Always fork the best of the best.*

This project minimizes novel cryptographic and smart contract implementations by leveraging battle-tested code:

- **Tornado Cash**: `MerkleTreeWithHistory` logic for fixed-depth incremental Merkle trees.
- **OpenZeppelin**: `ReentrancyGuard`, `Ownable`, and `SafeERC20` primitives for vault security and token interactions.
- **Aztec / Barretenberg**: `HonkVerifier` and UltraHonk zero-knowledge proof generation and verification.
- **Foundry**: Utilizing `forge-std` for rigorous unit and aggressive fuzz testing.
- **Poseidon-Solidity**: For gas-efficient on-chain Poseidon hash calculations compatible with Noir circuits.
