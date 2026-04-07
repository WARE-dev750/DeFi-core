NOFACE-Protocol/
├── circuits/               # MODULAR ZK-STACK (Noir)
│   ├── src/
│   │   ├── kernel/         # THE STATE KERNEL: Validates SMT & Nullifiers ONLY
│   │   │   └── main.nr     
│   │   ├── apps/           # TRANSACTION LOGIC: Swap/Spend (Decoupled from Kernel)
│   │   │   ├── swap.nr     
│   │   │   └── transfer.nr 
│   │   └── middleware/     # COMPLIANCE: Proof-of-Inclusion (Async from Core)
│   │       └── clean_set.nr
│   ├── Nargo.toml          # UltraHonk + Recursion (Aggregates Apps into Kernel)
│   └── tests/              # Extensive Circuit Unit Tests (Required for Pass)
├── contracts/              # THE MINIMALIST ENGINE
│   ├── src/
│   │   ├── core/
│   │   │   ├── NofaceVault.sol   # Pure Storage: Root history & Nullifier bitmaps
│   │   │   └── Verifier.sol      # Auto-generated UltraHonk Verifier
│   │   ├── sequencer/      # THE INTENT LAYER
│   │   │   ├── IntentPool.sol    # [FIX 3] Collects user intents, prevents on-chain reverts
│   │   │   └── BatchManager.sol  # Handles the atomic transition of the State Tree
│   │   ├── hooks/          # UNISWAP V4 INTEGRATION
│   │   │   ├── NofaceHook.sol    # TSTORE-based shielded swaps
│   │   │   └── PrivacyOracle.sol # Feeds compliance/policy updates to the hook
│   │   └── libraries/
│   │       └── IncrementalTree.sol # Gas-optimized Merkle Tree (32 levels)
│   └── test/               # Foundry + Halmos (Formal verification of state logic)
├── infra/                  # THE COORDINATION LAYER
│   ├── solver/             # [FIX 3] Replaces "Relayer": Matches Intents to avoid collisions
│   │   └── bundle-builder/ 
│   ├── indexer/            # [FIX 2] PRACTICAL PRIVACY
│   │   └── ohttp-gateway/  # Oblivious HTTP for note discovery (FHE is too slow, move on)
│   └── prover/             
│       └── coordination/   # Decentralized Proof Generation (Succinct/Gevulot)
├── sdk/                    # THE INTEGRATION LAYER
│   ├── intent-gen/         # Constructs the ZK-Intents + Ephemeral Keys
│   ├── discovery/          # OHTTP-based note scanning
│   └── index.ts            
├── specs/                  # THE BIBLE
│   ├── state-machine.tla   # TLA+ model of the Sequencer (Ensures no deadlocks)
│   └── compliance.md       # ASP standards for Clean Set inclusion
└── README.md
