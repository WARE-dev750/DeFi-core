// NOFACE Protocol — ZK Withdrawal Kernel
// Forked structure from Aztec noir-examples/token
// Poseidon2 over BN254, UltraHonk backend
//
// Private inputs:
//   secret      — the depositor's secret scalar
//   nullifier   — unique per-note scalar
//   path        — Merkle sibling path (depth 20)
//   indices     — left/right flags for each level
//
// Public inputs:
//   nullifier_hash  — burned on-chain to prevent double spend
//   root            — must match a known vault root
//   recipient       — withdrawal destination address
//   denomination    — must be 100, 1000, or 10000 USDC (6 decimals)

fn main(
    // --- private ---
    secret:      Field,
    nullifier:   Field,
    path:        [Field; 20],
    indices:     [u1; 20],

    // --- public ---
    nullifier_hash: pub Field,
    root:           pub Field,
    recipient:      pub Field,
    denomination:   pub Field,
) {
    // ── 1. Denomination whitelist ────────────────────────────
    // Allowed: 100 USDC, 1000 USDC, 10000 USDC (6 decimals)
    // Prevents zero-value or arbitrary-amount proofs
    let d100   = denomination == 100_000_000;
    let d1000  = denomination == 1_000_000_000;
    let d10000 = denomination == 10_000_000_000;
    assert(d100 | d1000 | d10000, "Invalid denomination");

    // ── 2. Commitment ────────────────────────────────────────
    // commitment = Poseidon2(secret, nullifier, denomination, 0)
    // Denomination is baked in — you cannot withdraw a different
    // amount than you deposited
    let commitment = std::hash::poseidon2_permutation(
        [secret, nullifier, denomination, 0], 4
    )[0];

    // ── 3. Nullifier hash ────────────────────────────────────
    // nullifier_hash = Poseidon2(nullifier, secret, 0, 0)
    // Revealed on-chain — burns the note so it cannot be reused
    let computed_nullifier_hash = std::hash::poseidon2_permutation(
        [nullifier, secret, 0, 0], 4
    )[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier");

    // ── 4. Merkle root ───────────────────────────────────────
    // Proves commitment exists in the vault tree
    // without revealing which leaf it is
    let computed_root = compute_merkle_root(commitment, path, indices);
    assert(computed_root == root, "Invalid merkle root");

    // ── 5. Recipient sanity ──────────────────────────────────
    // Prevents burning funds to zero address
    assert(recipient != 0, "Zero recipient");
}

// Incremental Merkle root recomputation
// Mirrors the LeanIMT Poseidon2 logic in NofaceVault.sol
fn compute_merkle_root(
    leaf:    Field,
    path:    [Field; 20],
    indices: [u1; 20]
) -> Field {
    let mut current = leaf;

    for i in 0..20 {
        let sibling = path[i];
        current = if indices[i] == 0 {
            // current is left child
            std::hash::poseidon2_permutation([current, sibling, 0, 0], 4)[0]
        } else {
            // current is right child
            std::hash::poseidon2_permutation([sibling, current, 0, 0], 4)[0]
        };
    }

    current
}
