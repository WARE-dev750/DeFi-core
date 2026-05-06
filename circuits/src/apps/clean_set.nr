// clean_set.nr - Privacy Pools Clean Set Verification Circuit
//
// Purpose: Proves that a commitment originates from a "clean" source
// without revealing which source. Used for regulatory compliance (AML/KYC).
//
// Pattern: Privacy Pools style verification - commitments are valid if they
// appear in the clean set Merkle tree. This allows users to prove their funds
// come from non-sanctioned sources without revealing transaction history.
//
// Forked from: Privacy Pools paper (Buterin et al.) + Tornado Cash pattern
// Uses: Poseidon2 for hashing, same Merkle tree depth as main.nr (20 levels)

use dep::std;

// Clean Set Merkle Tree depth - matches main.nr
global CLEAN_SET_TREE_DEPTH: Field = 20;

/// @notice Compute Merkle root from leaf and path
/// @param leaf The commitment being verified
/// @param path Array of sibling hashes (20 levels)
/// @param indices Array of left/right indicators (true = right, false = left)
/// @return The computed Merkle root
fn compute_clean_set_root(
    leaf: Field,
    path: [Field; CLEAN_SET_TREE_DEPTH],
    indices: [bool; CLEAN_SET_TREE_DEPTH]
) -> Field {
    let mut current = leaf;
    
    for i in 0..CLEAN_SET_TREE_DEPTH {
        let sibling = path[i];
        let is_right = indices[i];
        
        // Poseidon2 hash of [left, right, 0, 0]
        let left = if is_right { sibling } else { current };
        let right = if is_right { current } else { sibling };
        
        current = std::hash::poseidon2_permutation([left, right, 0, 0], 4)[0];
    }
    
    current
}

/// @notice Main circuit: Verify commitment is in clean set
/// @param secret Private secret for the commitment
/// @param nullifier Private nullifier (prevents double-spending)
/// @param source_tag Private identifier of the clean source
/// @param path Merkle path in clean set tree
/// @param indices Left/right indicators for path
/// 
/// @param commitment_hash Public: hash(secret, nullifier, source_tag)
/// @param clean_set_root Public: Root of clean set Merkle tree
/// @param nullifier_hash Public: hash(nullifier, commitment) - prevents replay
/// 
/// @dev The source_tag links the commitment to a specific whitelisted source
/// without revealing which source on-chain. Source registry is off-chain.
fn main(
    secret: Field,
    nullifier: Field,
    source_tag: Field,
    path: [Field; CLEAN_SET_TREE_DEPTH],
    indices: [bool; CLEAN_SET_TREE_DEPTH],
    
    commitment_hash: pub Field,
    clean_set_root: pub Field,
    nullifier_hash: pub Field,
) {
    // 1. Verify commitment matches private inputs
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, source_tag, 0], 4)[0];
    assert(commitment == commitment_hash, "Invalid commitment hash");
    
    // 2. Verify nullifier hash correctness
    let computed_nullifier_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier hash");
    
    // 3. Verify commitment is in clean set Merkle tree
    let computed_root = compute_clean_set_root(commitment, path, indices);
    assert(computed_root == clean_set_root, "Not in clean set");
    
    // 4. Source tag constraints (non-zero to prevent empty proofs)
    assert(source_tag != 0, "Empty source tag");
    
    // 5. Secret must be non-zero (valid commitment construction)
    assert(secret != 0, "Zero secret");
}

// ── Unit Tests ─────────────────────────────────────────────────────────────
#[test]
fn test_clean_set_membership() {
    // Test values
    let secret = 12345;
    let nullifier = 67890;
    let source_tag = 11111;
    
    // Compute commitment
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, source_tag, 0], 4)[0];
    
    // Mock path - in production this comes from clean set operator
    let path: [Field; 20] = [0; 20];
    let indices: [bool; 20] = [false; 20];
    
    // Compute expected root (simplified for test - would use actual path)
    let root = compute_clean_set_root(commitment, path, indices);
    
    // Compute nullifier hash
    let nf_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    
    // Circuit should pass with valid inputs
    main(secret, nullifier, source_tag, path, indices, commitment, root, nf_hash);
}

#[test(should_fail)]
fn test_wrong_commitment_fails() {
    let secret = 12345;
    let nullifier = 67890;
    let source_tag = 11111;
    
    // Wrong commitment hash
    let wrong_commitment = 99999;
    
    let path: [Field; 20] = [0; 20];
    let indices: [bool; 20] = [false; 20];
    let root = compute_clean_set_root(wrong_commitment, path, indices);
    let nf_hash = std::hash::poseidon2_permutation([nullifier, wrong_commitment, 0, 0], 4)[0];
    
    // Should fail - commitment doesn't match private inputs
    main(secret, nullifier, source_tag, path, indices, wrong_commitment, root, nf_hash);
}

#[test(should_fail)]
fn test_zero_source_tag_fails() {
    let secret = 12345;
    let nullifier = 67890;
    let source_tag = 0; // Invalid - zero source tag
    
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, source_tag, 0], 4)[0];
    let path: [Field; 20] = [0; 20];
    let indices: [bool; 20] = [false; 20];
    let root = compute_clean_set_root(commitment, path, indices);
    let nf_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    
    // Should fail - source tag must be non-zero
    main(secret, nullifier, source_tag, path, indices, commitment, root, nf_hash);
}
