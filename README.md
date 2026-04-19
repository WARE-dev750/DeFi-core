## 1. What Is NOFACE?

NOFACE is licensed under the AGPL-3.0 license.

NOFACE is a private financial ecosystem built on Ethereum Layer-2.

Every major DeFi protocol today has one fatal flaw. Everything is public. Your wallet address, your trade size, your strategy, your identity — permanently visible to every bot, competitor, and adversary on the planet.

NOFACE fixes this at the infrastructure level.

Bring any asset. BTC, ETH, USDC, anything. It enters the NOFACE vault and disappears. Inside the protocol everything is private. You swap, trade, bet, earn, and transfer — completely invisibly. When you leave you take your assets back to any wallet with zero connection to where they came from.

**The outside world sees a vault. They see nothing inside.**

---

## 2. The Core Problem

Regular DeFi: Your wallet → Uniswap → blockchain explorer. Everyone sees exactly who you are, what you traded, how much, and when.

NOFACE: Your wallet → NOFACE vault → private economy → fresh wallet. The connection between entry and exit is mathematically impossible to trace.

This is not just a UX feature. It is a mathematical guarantee enforced by Zero-Knowledge proofs.

---

## 3. How It Works — Five Steps

### Step 1 — Shield (Enter)
<<<<<<< HEAD

Deposit any supported asset into the NOFACE Vault. The protocol issues you a private cryptographic note. Your asset disappears into the shielded pool. Nobody on-chain can see it is yours.

### Step 2 — Swap Privately

Tell NOFACE what you want to swap. Sign a gasless intent from your wallet. A Solver executes the trade on Uniswap v4 on your behalf. You pay zero gas. Your identity stays hidden. The swap happens. Nobody knows it was you.

### Step 3 — Transfer Privately

Send assets to anyone with zero on-chain link between sender and recipient. Perfect for payroll, payments, and confidential transactions. The recipient receives fresh assets with no history attached.

### Step 4 — Participate In The Private Economy

Inside the NOFACE ecosystem everything is denominated in $NOFACE. Betting markets, community tournaments, yield events, and financial games — all completely private, all powered by $NOFACE. The more activity inside the ecosystem the rarer $NOFACE becomes.

### Step 5 — Unshield (Exit)

=======
Deposit any supported asset into the NOFACE Vault. The protocol issues you a private cryptographic note. Your asset disappears into the shielded pool. Nobody on-chain can see it is yours.

### Step 2 — Swap Privately
Tell NOFACE what you want to swap. Sign a gasless intent from your wallet. A Solver executes the trade on Uniswap v4 on your behalf. You pay zero gas. Your identity stays hidden. The swap happens. Nobody knows it was you.

### Step 3 — Transfer Privately
Send assets to anyone with zero on-chain link between sender and recipient. Perfect for payroll, payments, and confidential transactions. The recipient receives fresh assets with no history attached.

### Step 4 — Participate In The Private Economy
Inside the NOFACE ecosystem everything is denominated in $NOFACE. Betting markets, community tournaments, yield events, and financial games — all completely private, all powered by $NOFACE. The more activity inside the ecosystem the rarer $NOFACE becomes.

### Step 5 — Unshield (Exit)
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
Withdraw to any fresh wallet at any time. Zero cryptographic connection between your deposit wallet and withdrawal wallet. Your financial history is clean.

---

## 4. The Universal Vault

NOFACE accepts any asset. Not just ERC-20 tokens.

<<<<<<< HEAD

| Asset              | Mechanism                  | Status |
| ------------------ | -------------------------- | ------ |
| USDC / USDT / DAI  | Native ERC-20              | Beta   |
| ETH / WETH         | Native + auto-wrap         | V1     |
| WBTC / tBTC        | Battle-tested BTC wrappers | V2     |
| Any ERC-20         | Permissionless vault       | V2     |
| Cross-chain assets | Chainlink CCIP             | V3     |

=======
| Asset | Mechanism | Status |
| :--- | :--- | :--- |
| USDC / USDT / DAI | Native ERC-20 | Beta |
| ETH / WETH | Native + auto-wrap | V1 |
| WBTC / tBTC | Battle-tested BTC wrappers | V2 |
| Any ERC-20 | Permissionless vault | V2 |
| Cross-chain assets | Chainlink CCIP | V3 |
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3

Every asset sits in a hardened smart contract forked from the most audited code in DeFi. Your BTC is secured by tBTC's battle-tested contracts. Your ETH by OpenZeppelin. Your position by mathematics.

---

## 5. Architecture — The Four Pillars

### Pillar A — The Shielded Vault (`NofaceVault.sol`)
<<<<<<< HEAD

The foundation of the protocol. A minimalist state machine that tracks private balances using a cryptographic Merkle Tree. Every deposit creates a commitment. Every withdrawal burns a nullifier. The vault never knows who owns what. Only the ZK proof does.

### Pillar B — The ZK Kernel (`circuits/src/kernel/main.nr`)

=======
The foundation of the protocol. A minimalist state machine that tracks private balances using a cryptographic Merkle Tree. Every deposit creates a commitment. Every withdrawal burns a nullifier. The vault never knows who owns what. Only the ZK proof does.

### Pillar B — The ZK Kernel (`circuits/src/kernel/main.nr`)
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
A Noir-based Zero-Knowledge circuit that validates every state transition. Built on UltraHonk. The kernel only cares about one thing — is this proof mathematically valid? If yes, the state updates. If no, the transaction reverts. No exceptions.

The circuit is compiled to a real verification key. `HonkVerifier.sol` is generated directly from that key by Barretenberg. There is no mock. There is no placeholder. The cryptography is live.

### Pillar C — The Intent Layer (Gasless Execution)
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
Users never submit transactions directly. They sign a gasless ZK-Intent authorizing a specific execution and relayer fee. Professional Solvers pick up the intent, pay the gas, execute the trade, and get reimbursed automatically. Users need zero ETH. Zero $NOFACE. Just a signature.

Solvers must stake $NOFACE to access the intent pool. If they front-run or manipulate — their stake gets slashed. The math enforces honesty.

### Pillar D — The Private Economy
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
Inside the NOFACE ecosystem $NOFACE is the only currency. Betting markets, community events, tournaments, and yield games all run on $NOFACE. Every event burns a percentage of $NOFACE permanently. Supply decreases. Activity increases. Value accrues.

---

## 6. The Clean Set — Why This Is Legal

Privacy without compliance gets protocols shut down.

NOFACE implements Proof-of-Inclusion. Before any transaction a user can prove their funds did not originate from sanctioned addresses — without revealing their identity.

**What you prove:** "My funds are clean."  
**What you hide:** Everything else.

This is the Privacy Pools approach co-authored by Vitalik Buterin. It is the legal framework that separates NOFACE from mixers. Institutions can use NOFACE. Regulators can verify compliance. Users keep their privacy.

---

## 7. $NOFACE Token

$NOFACE is not required to use the protocol. It is the engine that captures protocol value and distributes it to the people who secure and govern the ecosystem.

**Token Specification**
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
- Ticker: $NOFACE
- Total Supply: 1,000,000,000 (Fixed. Non-inflationary.)
- Standard: ERC-20 with Permit (EIP-2612)

**How Value Accrues**

Every transaction through NOFACE generates a 0.3% fee split three ways:

0.3% protocol fee
├── 0.1% → $NOFACE stakers (real yield paid in USDC)
├── 0.1% → Buyback and Burn (supply decreases permanently)
└── 0.1% → Protocol Treasury (audits, engineering, legal)

**Who Needs $NOFACE**

<<<<<<< HEAD

| Actor      | Why They Need It                                      |
| ---------- | ----------------------------------------------------- |
| Solvers    | Must stake to access the intent pool                  |
| Stakers    | Lock to earn real yield from protocol fees            |
| Community  | Required currency for all ecosystem events            |
| Governance | Voting power over fee structure and protocol upgrades |


**Token Allocation**


| Category          | Allocation | Vesting                      |
| ----------------- | ---------- | ---------------------------- |
| Liquidity Mining  | 40%        | 5-Year Linear                |
| Protocol Treasury | 20%        | 3-Year Linear                |
| Founders & Team   | 15%        | 1-Year Cliff, 4-Year Linear  |
| Private Investors | 15%        | 6-Month Cliff, 2-Year Linear |
| Community Airdrop | 10%        | 100% Unlocked at Launch      |

=======
| Actor | Why They Need It |
| :--- | :--- |
| Solvers | Must stake to access the intent pool |
| Stakers | Lock to earn real yield from protocol fees |
| Community | Required currency for all ecosystem events |
| Governance | Voting power over fee structure and protocol upgrades |

**Token Allocation**

| Category | Allocation | Vesting |
| :--- | :--- | :--- |
| Liquidity Mining | 40% | 5-Year Linear |
| Protocol Treasury | 20% | 3-Year Linear |
| Founders & Team | 15% | 1-Year Cliff, 4-Year Linear |
| Private Investors | 15% | 6-Month Cliff, 2-Year Linear |
| Community Airdrop | 10% | 100% Unlocked at Launch |
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3

---

## 8. The Flywheel

More users enter the private economy 
│
▼
More volume generates more fees 
│
▼
More fees fund buyback and burn 
│
▼
$NOFACE supply decreases 
│
▼
Solvers compete harder to stake 
│
▼
Better execution attracts more users 
│
▼
More users enter the private economy ◄──┘

Each loop makes the next loop stronger.

---

## 9. Technical Stack

<<<<<<< HEAD

| Layer             | Technology                                                              |
| ----------------- | ----------------------------------------------------------------------- |
| ZK Circuits       | Noir — UltraHonk proof system                                           |
| On-Chain Verifier | Barretenberg — auto-generated `HonkVerifier.sol` from real VK           |
| Smart Contracts   | Solidity 0.8.27 — Foundry                                               |
| Merkle Tree       | Fixed-Depth IncrementalTree (Tornado Cash Fork) — Native Poseidon2 Hash |
| BTC Layer         | tBTC — Threshold Network, decentralized BTC wrapper                     |
| Hooks             | Uniswap v4 — TSTORE-based shielded swaps                                |
| Intent Settlement | CoW Protocol — MEV-resistant solver architecture                        |
| Metadata Privacy  | OHTTP — Oblivious HTTP, hides user IP during note discovery             |
| Proof Generation  | Succinct / Gevulot — Decentralized prover networks                      |
| Cross-Chain       | Chainlink CCIP — V3 cross-chain asset support                           |

=======
| Layer | Technology |
| :--- | :--- |
| ZK Circuits | Noir — UltraHonk proof system |
| On-Chain Verifier | Barretenberg — auto-generated `HonkVerifier.sol` from real VK |
| Smart Contracts | Solidity 0.8.27 — Foundry |
| Merkle Tree | Fixed-Depth IncrementalTree (Tornado Cash Fork) — Native Poseidon2 Hash |
| BTC Layer | tBTC — Threshold Network, decentralized BTC wrapper |
| Hooks | Uniswap v4 — TSTORE-based shielded swaps |
| Intent Settlement | CoW Protocol — MEV-resistant solver architecture |
| Metadata Privacy | OHTTP — Oblivious HTTP, hides user IP during note discovery |
| Proof Generation | Succinct / Gevulot — Decentralized prover networks |
| Cross-Chain | Chainlink CCIP — V3 cross-chain asset support |
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3

---

## 10. Dependency Map

<<<<<<< HEAD

| Component                 | Source                        | Purpose                            |
| ------------------------- | ----------------------------- | ---------------------------------- |
| MerkleTreeWithHistory     | Tornado Cash / Aztec Protocol | Fixed-Depth Commitment Merkle Tree |
| HonkVerifier              | Barretenberg — Aztec          | UltraHonk proof verification       |
| ReentrancyGuard / Ownable | OpenZeppelin                  | Vault security primitives          |
| Uniswap v4 Hook           | Uniswap Periphery             | Private swap execution             |
| Intent Settlement         | CoW Protocol                  | MEV-resistant execution            |
| BTC Wrapper               | tBTC — Threshold Network      | Decentralized BTC support          |
| Token Contract            | Solady ERC-20                 | Gas-optimized $NOFACE              |
| OHTTP Gateway             | Cloudflare / IETF             | Metadata privacy                   |

=======
| Component | Source | Purpose |
| :--- | :--- | :--- |
| MerkleTreeWithHistory | Tornado Cash / Aztec Protocol | Fixed-Depth Commitment Merkle Tree |
| HonkVerifier | Barretenberg — Aztec | UltraHonk proof verification |
| ReentrancyGuard / Ownable | OpenZeppelin | Vault security primitives |
| Uniswap v4 Hook | Uniswap Periphery | Private swap execution |
| Intent Settlement | CoW Protocol | MEV-resistant execution |
| BTC Wrapper | tBTC — Threshold Network | Decentralized BTC support |
| Token Contract | Solady ERC-20 | Gas-optimized $NOFACE |
| OHTTP Gateway | Cloudflare / IETF | Metadata privacy |
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3

Every dependency is forked from battle-tested, multiply-audited production code. No component was written from scratch when a proven alternative existed.

---

## 11. Roadmap

### Phase 1 — Beta
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
- USDC shielded vault on Arbitrum Sepolia testnet
- Real UltraHonk ZK proof generation and on-chain verification ✅
- Basic shield and unshield functionality
- First security audit
- ETHGlobal / Ethereum Foundation grant application

### Phase 2 — V1 Mainnet
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
- Arbitrum mainnet deployment
- Private swaps via Uniswap v4
- $NOFACE token launch via LBP
- Solver network live
- WETH support added
- $1M TVL cap during gated beta

### Phase 3 — V2 Expansion
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
- Multi-asset vault (WBTC / tBTC added)
- Private economy launch (betting, tournaments, community events)
- Multi-chain deployment (Base, Optimism)
- Second audit complete
- $100M TVL target

### Phase 4 — V3 Maturity
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
- Cross-chain asset support via Chainlink CCIP
- Full DAO governance transition
- Permissionless vault (any ERC-20)
- $1B TVL target
- Protocol legacy as standard privacy primitive for Ethereum

---

## 12. Security

NOFACE treats security as an existential requirement, not a feature.

**System Invariants**
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
- **Solvency:** Total vault assets always equal sum of unspent commitments
- **Nullifier Uniqueness:** Every nullifier can only be spent once. Ever.
- **Non-Custodial:** User private keys never leave their device

**Audit Requirements Before Mainnet**
<<<<<<< HEAD

=======
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
1. Crowdsourced bug bounty via Code4rena
2. Formal verification of all ZK circuits
3. Tier-1 institutional audit (OpenZeppelin / Spearbit / Trail of Bits)
4. Public Immunefi bounty up to $5,000,000 for critical vulnerabilities

**Guardrail Phase**

Administrative powers are held by a 3-of-5 Security Multisig until all audits complete. 48-hour timelock on all non-emergency upgrades. Emergency pause covers deposits only — withdrawals always remain open.

---

## 13. Current Build Status

<<<<<<< HEAD

| Component                            | Status                                            |
| ------------------------------------ | ------------------------------------------------- |
| Fixed-Depth MerkleTree + Poseidon2   | ✅ Complete — Native BB Translation                |
| `NofaceVault.sol`                    | ✅ Complete — 8/8 tests passing                    |
| `main.nr` ZK Kernel                  | ✅ Complete — real UltraHonk circuit               |
| `HonkVerifier.sol`                   | ✅ Complete — generated from real verification key |
| Hash alignment (Poseidon2 ↔ circuit) | ✅ Complete — Test vectors passing                 |
| Deploy script                        | ✅ Complete — Uses real HonkVerifier               |
| End-to-end proof integration test    | 🟡 In progress                                    |
| `swap.nr` / `transfer.nr`            | ⏳ Pending kernel finalization                     |
| `IntentPool.sol`                     | ⏳ Pending vault                                   |
| `BatchManager.sol`                   | ⏳ Pending vault                                   |
| `NofaceHook.sol`                     | ⏳ Pending V1                                      |
| $NOFACE Token                        | ⏳ Pending mainnet                                 |
| SDK                                  | ⏳ Pending contracts                               |


---

*Built by a 15-year-old. Seriously.*
=======
| Component | Status |
| :--- | :--- |
| Fixed-Depth MerkleTree + Poseidon2 | ✅ Complete — Native BB Translation |
| `NofaceVault.sol` | ✅ Complete — 8/8 tests passing |
| `main.nr` ZK Kernel | ✅ Complete — real UltraHonk circuit |
| `HonkVerifier.sol` | ✅ Complete — generated from real verification key |
| Hash alignment (Poseidon2 ↔ circuit) | ✅ Complete — Test vectors passing |
| Deploy script | ✅ Complete — Uses real HonkVerifier |
| End-to-end proof integration test | 🟡 In progress |
| `swap.nr` / `transfer.nr` | ⏳ Pending kernel finalization |
| `IntentPool.sol` | ⏳ Pending vault |
| `BatchManager.sol` | ⏳ Pending vault |
| `NofaceHook.sol` | ⏳ Pending V1 |
| $NOFACE Token | ⏳ Pending mainnet |
| SDK | ⏳ Pending contracts |

---

*Built by a 15-year-old. Seriously.*
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
