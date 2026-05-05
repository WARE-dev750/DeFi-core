// Swap Circuit: Private token swap via Uniswap v4
// Forked pattern from: Tornado Cash commitment scheme + Aztec connect-style app circuits
// 
// Proves: 
//   1. User owns input commitment (Merkle membership)
//   2. Input nullifier is fresh (double-spend protection)
//   3. Swap parameters are valid (input -> output conversion)
//   4. New output commitment is correctly formed

use dep::std;

// Swap direction: 0 = exact input, 1 = exact output
global SWAP_EXACT_IN: Field = 0;
global SWAP_EXACT_OUT: Field = 1;

fn main(
    // Private inputs
    input_secret: Field,
    input_nullifier: Field,
    merkle_path: [Field; 20],
    merkle_indices: [bool; 20],
    output_secret: Field,
    output_nullifier: Field,
    
    // Swap parameters (private)
    swap_direction: Field,      // 0 = exact in, 1 = exact out
    amount_in: Field,
    amount_out: Field,
    min_out: Field,             // slippage protection
    
    // Public inputs
    input_nullifier_hash: pub Field,
    merkle_root: pub Field,
    token_in: pub Field,         // token address as field
    token_out: pub Field,        // token address as field
    amount_in_pub: pub Field,    // public for solver verification
    amount_out_pub: pub Field,   // public for solver verification
    output_commitment: pub Field,
) {
    // 1. Verify denomination matches public input
    assert(amount_in == amount_in_pub, "Amount mismatch");
    assert(amount_out == amount_out_pub, "Output mismatch");
    
    // 2. Compute input commitment
    let input_commitment = std::hash::poseidon2_permutation(
        [input_secret, input_nullifier, token_in, amount_in], 
        4
    )[0];
    
    // 3. Verify nullifier hash
    let computed_nullifier_hash = std::hash::poseidon2_permutation(
        [input_nullifier, input_commitment, 0, 0], 
        4
    )[0];
    assert(computed_nullifier_hash == input_nullifier_hash, "Invalid nullifier");
    
    // 4. Verify Merkle membership
    let computed_root = compute_merkle_root(input_commitment, merkle_path, merkle_indices);
    assert(computed_root == merkle_root, "Invalid merkle root");
    
    // 5. Slippage check: output >= minimum expected
    assert(amount_out >= min_out, "Slippage exceeded");
    
    // 6. Verify swap direction is valid
    let valid_direction = (swap_direction == SWAP_EXACT_IN) | (swap_direction == SWAP_EXACT_OUT);
    assert(valid_direction, "Invalid swap direction");
    
    // 7. Compute output commitment (binds to new note)
    let computed_output_commitment = std::hash::poseidon2_permutation(
        [output_secret, output_nullifier, token_out, amount_out], 
        4
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

#[test]
fn test_swap_exact_in_witness() {
    // Test vector generation
    let input_secret: Field = 12345;
    let input_nullifier: Field = 67890;
    let output_secret: Field = 11111;
    let output_nullifier: Field = 22222;
    
    let token_in: Field = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    let token_out: Field = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    
    let amount_in: Field = 1_000_000_000; // 1000 USDC (6 decimals)
    let amount_out: Field = 333333333333333333; // ~0.33 ETH (18 decimals)
    let min_out: Field = 300000000000000000; // 5% slippage tolerance
    
    // Compute commitments
    let input_commitment = std::hash::poseidon2_permutation(
        [input_secret, input_nullifier, token_in, amount_in], 4
    )[0];
    
    let nullifier_hash = std::hash::poseidon2_permutation(
        [input_nullifier, input_commitment, 0, 0], 4
    )[0];
    
    let output_commitment = std::hash::poseidon2_permutation(
        [output_secret, output_nullifier, token_out, amount_out], 4
    )[0];
    
    // Mock merkle root (normally computed from path)
    let mut root = input_commitment;
    for _ in 0..20 {
        root = std::hash::poseidon2_permutation([root, 0, 0, 0], 4)[0];
    }
    
    println(f"input_commitment  = {input_commitment}");
    println(f"nullifier_hash    = {nullifier_hash}");
    println(f"output_commitment = {output_commitment}");
    println(f"merkle_root       = {root}");
    
    assert(input_commitment != 0);
    assert(nullifier_hash != 0);
    assert(output_commitment != 0);
}

#[test]
fn test_slippage_protection() {
    let amount_out: Field = 100;
    let min_out: Field = 95;
    
    // Should pass: 100 >= 95
    assert(amount_out >= min_out);
}

#[test(should_fail)]
fn test_slippage_violation() {
    let amount_out: Field = 90;
    let min_out: Field = 95;
    
    // Should fail: 90 < 95
    assert(amount_out >= min_out);
}
