use dep::std;

fn main(
    sender_secret: Field,
    sender_nullifier: Field,
    merkle_path: [Field; 20],
    merkle_indices: [bool; 20],
    transfer_amount: Field,
    recipient_output_secret: Field,
    recipient_output_nullifier: Field,
    has_change: bool,
    change_secret: Field,
    change_nullifier: Field,
    
    input_commitment: pub Field,
    sender_nullifier_hash: pub Field,
    merkle_root: pub Field,
    token: pub Field,
    input_amount: pub Field,
    recipient_commitment: pub Field,
    change_commitment: pub Field,
) {
    let computed_input_commitment = std::hash::poseidon2_permutation(
        [sender_secret, sender_nullifier, token, input_amount], 4
    )[0];
    assert(computed_input_commitment == input_commitment, "Invalid input commitment");
    
    let computed_nullifier_hash = std::hash::poseidon2_permutation(
        [sender_nullifier, input_commitment, 0, 0], 4
    )[0];
    assert(computed_nullifier_hash == sender_nullifier_hash, "Invalid nullifier");
    
    let computed_root = compute_merkle_root(input_commitment, merkle_path, merkle_indices);
    assert(computed_root == merkle_root, "Invalid merkle root");
    
    if has_change {
        let change_amount = input_amount - transfer_amount;
        let reconstructed_input = transfer_amount + change_amount;
        assert(reconstructed_input == input_amount, "Amount conservation violated");
        assert(change_amount != 0, "Change amount cannot be zero when has_change is true");
    } else {
        assert(transfer_amount == input_amount, "Transfer must equal input when no change");
    }
    
    let computed_recipient_commitment = std::hash::poseidon2_permutation(
        [recipient_output_secret, recipient_output_nullifier, token, transfer_amount], 4
    )[0];
    assert(computed_recipient_commitment == recipient_commitment, "Recipient commitment mismatch");
    
    if has_change {
        let change_amount = input_amount - transfer_amount;
        let computed_change_commitment = std::hash::poseidon2_permutation(
            [change_secret, change_nullifier, token, change_amount], 4
        )[0];
        assert(computed_change_commitment == change_commitment, "Change commitment mismatch");
    } else {
        assert(change_commitment == 0, "Change must be zero when has_change is false");
    }
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
