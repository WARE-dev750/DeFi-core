use dep::std;

global CLEAN_SET_TREE_DEPTH: Field = 20;

fn main(
    secret: Field,
    nullifier: Field,
    source_tag: Field,
    path: [Field; 20],
    indices: [bool; 20],
    
    commitment_hash: pub Field,
    nullifier_hash: pub Field,
    clean_set_root: pub Field,
) {
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, source_tag, 0], 4)[0];
    assert(commitment == commitment_hash, "Invalid commitment hash");
    
    let computed_nullifier_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier hash");
    
    let computed_root = compute_clean_set_root(commitment, path, indices);
    assert(computed_root == clean_set_root, "Not in clean set");
    
    assert(source_tag != 0, "Empty source tag");
    assert(secret != 0, "Zero secret");
}

fn compute_clean_set_root(
    leaf: Field,
    path: [Field; 20],
    indices: [bool; 20]
) -> Field {
    let mut current = leaf;
    for i in 0..20 {
        let sibling = path[i];
        let is_right = indices[i];
        let left = if is_right { sibling } else { current };
        let right = if is_right { current } else { sibling };
        current = std::hash::poseidon2_permutation([left, right, 0, 0], 4)[0];
    }
    current
}
