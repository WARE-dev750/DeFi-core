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
    
    input_commitment: pub Field,
    input_nullifier_hash: pub Field,
    merkle_root: pub Field,
    token_in: pub Field,
    token_out: pub Field,
    amount_in_pub: pub Field,
    amount_out_pub: pub Field,
    output_commitment: pub Field,
) {
    assert(amount_in == amount_in_pub, "Amount mismatch");
    assert(amount_out == amount_out_pub, "Output mismatch");
    
    let computed_input_commitment = std::hash::poseidon2_permutation(
        [input_secret, input_nullifier, token_in, amount_in], 4
    )[0];
    assert(computed_input_commitment == input_commitment, "Invalid input commitment");
    
    let computed_nullifier_hash = std::hash::poseidon2_permutation(
        [input_nullifier, input_commitment, 0, 0], 4
    )[0];
    assert(computed_nullifier_hash == input_nullifier_hash, "Invalid nullifier");
    
    let computed_root = compute_merkle_root(input_commitment, merkle_path, merkle_indices);
    assert(computed_root == merkle_root, "Invalid merkle root");
    
    assert(amount_out >= min_out, "Slippage exceeded");
    
    let valid_direction = (swap_direction == SWAP_EXACT_IN) | (swap_direction == SWAP_EXACT_OUT);
    assert(valid_direction, "Invalid swap direction");
    
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
