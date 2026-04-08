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
    let d100 = denomination == 100_000_000;
    let d1000 = denomination == 1_000_000_000;
    let d10000 = denomination == 10_000_000_000;
    assert(d100 | d1000 | d10000, "Invalid denomination");
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0])[0];
    let computed_nullifier_hash = std::hash::poseidon2_permutation([nullifier, secret, 0, 0])[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier");
    let computed_root = compute_merkle_root(commitment, path, indices);
    assert(computed_root == root, "Invalid merkle root");
    assert(recipient != 0, "Zero recipient");
}
fn compute_merkle_root(leaf: Field, path: [Field; 20], indices: [bool; 20]) -> Field {
    let mut current = leaf;
    for i in 0..20 {
        let sibling = path[i];
        current = if indices[i] == false {
            std::hash::poseidon2_permutation([current, sibling, 0, 0])[0]
        } else {
            std::hash::poseidon2_permutation([sibling, current, 0, 0])[0]
        };
    }
    current
}


#[test]
fn test_print_hashes() {
    let nh = std::hash::poseidon2_permutation([2,1,0,0])[0];
    let commitment = std::hash::poseidon2_permutation([1,2,100000000,0])[0];
    let root = std::hash::poseidon2_permutation([commitment,0,0,0])[0];
    assert(nh != 0);
    assert(commitment != 0);
    assert(root != 0);
    println(nh);
    println(commitment);
    println(root);
}


#[test]
fn test_real_root() {
    let commitment = std::hash::poseidon2_permutation([1,2,100000000,0])[0];
    let mut current = commitment;
    for _i in 0..20 {
        current = std::hash::poseidon2_permutation([current,0,0,0])[0];
    }
    println(current);
}
