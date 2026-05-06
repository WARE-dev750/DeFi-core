use dep::std;

fn main(
    secret: Field,
    nullifier: Field,
    token: Field,
    amount: Field,
    path: [Field; 20],
    indices: [bool; 20],
    
    // Standard App Interface V2
    input_commitment: pub Field,      // 0
    input_nullifier_hash: pub Field,  // 1
    merkle_root: pub Field,           // 2
    token_pub: pub Field,             // 3
    amount_pub: pub Field,            // 4
    output_commitment: pub Field,     // 5 (unused)
    recipient: pub Field,             // 6 (unused)
    relayer: pub Field,               // 7 (unused)
    fee: pub Field,                   // 8 (unused)
    
    // Clean Set Specific
    clean_set_root: pub Field,        // 9
    clean_path: [Field; 20],
    clean_indices: [bool; 20],
) {
    // 1. Commitment binding (Must match Vault formula)
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, token, amount], 4)[0];
    assert(commitment == input_commitment, "Invalid commitment hash");
    assert(token == token_pub, "Token mismatch");
    assert(amount == amount_pub, "Amount mismatch");
    
    // 2. Nullifier binding
    let computed_nullifier_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    assert(computed_nullifier_hash == input_nullifier_hash, "Invalid nullifier hash");
    
    // 3. Vault Merkle proof
    let computed_vault_root = compute_merkle_root(commitment, path, indices);
    assert(computed_vault_root == merkle_root, "Invalid vault root");
    
    // 4. Clean set membership proof
    let computed_clean_root = compute_merkle_root(commitment, clean_path, clean_indices);
    assert(computed_clean_root == clean_set_root, "Not in clean set");
}

fn compute_merkle_root(leaf: Field, path: [Field; 20], indices: [bool; 20]) -> Field {
    let mut current = leaf;
    for i in 0..20 {
        let sibling = path[i];
        current = if indices[i] == false {
            std::hash::poseidon2_permutation([current, sibling, 0, 0], 4)[0]
        } else {
            std::hash::poseidon2_permutation([sibling, current, 0, 0], 4)[0]
        };
    }
    current
}
