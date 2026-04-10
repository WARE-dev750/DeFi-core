fn main(
    secret: Field,
    nullifier: Field,
    path: [Field; 20],
    indices: [bool; 20],
    nullifier_hash: pub Field,
    root: pub Field,
    recipient: pub Field,
    denomination: pub Field,
) {
    let d100   = denomination == 100_000_000;
    let d1000  = denomination == 1_000_000_000;
    let d10000 = denomination == 10_000_000_000;
    assert(d100 | d1000 | d10000, "Invalid denomination");

    // commitment = Poseidon2([secret, nullifier, denomination, 0])
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0], 4)[0];

    // nullifier_hash binds nullifier to commitment - prevents cross-denomination reuse
    let computed_nullifier_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier");

    // merkle inclusion proof
    let computed_root = compute_merkle_root(commitment, path, indices);
    assert(computed_root == root, "Invalid merkle root");

    assert(recipient != 0, "Zero recipient");
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

#[test]
fn test_nullifier_binding() {
    let secret: Field = 1;
    let nullifier: Field = 2;
    let denomination: Field = 100_000_000;

    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0], 4)[0];
    let nh = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];

    assert(commitment != 0);
    assert(nh != 0);
    // different inputs must produce different outputs
    assert(commitment != nh);
}

#[test]
fn test_merkle_two_levels() {
    let leaf: Field = 42;
    let sibling: Field = 99;
    let parent = std::hash::poseidon2_permutation([leaf, sibling, 0, 0], 4)[0];
    assert(parent != 0);
}
