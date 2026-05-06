use dep::std;

global SWAP_EXACT_IN: Field = 0;
global SWAP_EXACT_OUT: Field = 1;

fn main(
    input_secret: Field,
    input_nullifier: Field,
    merkle_path: [Field; 20],
    merkle_indices: [bool; 20],
    output_secret: Field,
    output_nullifier: Field,
    swap_direction: Field,
    amount_in: Field,
    amount_out: Field,
    min_out: Field,
    
    // Standard App Interface V2
    input_commitment: pub Field,      // 0
    input_nullifier_hash: pub Field,  // 1
    merkle_root: pub Field,           // 2
    token_in: pub Field,              // 3
    input_amount: pub Field,          // 4
    output_commitment: pub Field,     // 5
    recipient: pub Field,             // 6
    relayer: pub Field,               // 7
    fee: pub Field,                   // 8
    
    // Swap Specific
    token_out: pub Field,             // 9
    amount_out_pub: pub Field,        // 10
) {
    // 1. Consistency checks
    assert(amount_in == input_amount, "Amount mismatch");
    assert(amount_out == amount_out_pub, "Output mismatch");
    
    // 2. Input commitment binding
    let computed_input_commitment = std::hash::poseidon2_permutation(
        [input_secret, input_nullifier, token_in, amount_in], 4
    )[0];
    assert(computed_input_commitment == input_commitment, "Invalid input commitment");
    
    // 3. Nullifier binding
    let computed_nullifier_hash = std::hash::poseidon2_permutation(
        [input_nullifier, input_commitment, 0, 0], 4
    )[0];
    assert(computed_nullifier_hash == input_nullifier_hash, "Invalid nullifier");
    
    // 4. Merkle proof
    let computed_root = compute_merkle_root(input_commitment, merkle_path, merkle_indices);
    assert(computed_root == merkle_root, "Invalid merkle root");
    
    // 5. Swap logic & Slippage
    assert(amount_out >= min_out, "Slippage exceeded");
    let valid_direction = (swap_direction == SWAP_EXACT_IN) | (swap_direction == SWAP_EXACT_OUT);
    assert(valid_direction, "Invalid swap direction");
    
    // 6. Output commitment binding
    let computed_output_commitment = std::hash::poseidon2_permutation(
        [output_secret, output_nullifier, token_out, amount_out], 4
    )[0];
    assert(computed_output_commitment == output_commitment, "Output commitment mismatch");
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
