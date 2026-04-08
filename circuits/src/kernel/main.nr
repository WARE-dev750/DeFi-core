fn main(
    secret: Field,
    nullifier: Field,
    path: [Field; 20],
    indices: [u1; 20],
    nullifier_hash: pub Field,
    root: pub Field,
    recipient: pub Field,
    denomination: pub Field,
) {
    // Poseidon2 requires inputs padded to 4 elements (t=4 state width)
    let commitment = std::hash::poseidon2_permutation(
        [secret, nullifier, denomination, 0], 4
    )[0];
    let computed_nullifier_hash = std::hash::poseidon2_permutation(
        [nullifier, secret, 0, 0], 4
    )[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier");
    let computed_root = compute_merkle_root(commitment, path, indices);
    assert(computed_root == root, "Invalid merkle root");
    assert(recipient != 0, "Zero recipient");
}

fn compute_merkle_root(
    leaf: Field,
    path: [Field; 20],
    indices: [u1; 20]
) -> Field {
    let mut current = leaf;
    for i in 0..20 {
        let sibling = path[i];
        current = if indices[i] == 0 {
            std::hash::poseidon2_permutation([current, sibling, 0, 0], 4)[0]
        } else {
            std::hash::poseidon2_permutation([sibling, current, 0, 0], 4)[0]
        };
    }
    current
}
