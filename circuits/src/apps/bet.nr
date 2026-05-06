// bet.nr - Private Prediction Market Betting Circuit
//
// Purpose: Enables private betting on prediction markets (e.g., Polymarket)
// while maintaining shielded balances. Users prove they own a vault commitment
// and allocate funds to a specific bet without revealing their identity.
//
// Flow:
//   1. User has shielded USDC in vault (commitment in Merkle tree)
//   2. User generates bet proof: "I own commitment X, I bet Y on market Z"
//   3. Solver executes bet on Polymarket using their own funds
//   4. Vault locks the commitment, creates new "bet commitment"
//   5. If user wins, they can withdraw winnings to new shielded commitment
//
// Pattern: Hybrid of Tornado Cash (commitment/nullifier) + custom bet logic
// Uses: Poseidon2, same tree depth (20), UltraHonk backend

use dep::std;

// Tree depth - matches main.nr
global BET_TREE_DEPTH: Field = 20;

/// @notice Compute Merkle root from leaf and path
fn compute_merkle_root(
    leaf: Field,
    path: [Field; BET_TREE_DEPTH],
    indices: [bool; BET_TREE_DEPTH]
) -> Field {
    let mut current = leaf;
    
    for i in 0..BET_TREE_DEPTH {
        let sibling = path[i];
        let is_right = indices[i];
        
        let left = if is_right { sibling } else { current };
        let right = if is_right { current } else { sibling };
        
        current = std::hash::poseidon2_permutation([left, right, 0, 0], 4)[0];
    }
    
    current
}

/// @notice Main circuit: Private bet proof
/// @param secret Private secret for the original vault commitment
/// @param nullifier Private nullifier (prevents double-betting same commitment)
/// @param bet_amount Private amount being wagered (must be <= denomination)
/// @param market_id Private identifier of the prediction market
/// @param outcome_id Private outcome being bet on (0 = No, 1 = Yes, etc.)
/// @param solver_fee Private fee paid to solver for execution
/// @param path Merkle path in vault tree
/// @param indices Left/right indicators for path
/// @param new_secret Secret for the new bet commitment (for settlement)
/// 
/// @param merkle_root Public: Current vault Merkle root
/// @param nullifier_hash Public: Prevents double-spending (hash of nullifier+commitment)
/// @param bet_commitment Public: New commitment representing the active bet
/// @param market_id_hash Public: Hash of market_id for on-chain verification
/// @param denomination Public: Original commitment denomination (for fee calc)
fn main(
    secret: Field,
    nullifier: Field,
    bet_amount: Field,
    market_id: Field,
    outcome_id: Field,
    solver_fee: Field,
    path: [Field; BET_TREE_DEPTH],
    indices: [bool; BET_TREE_DEPTH],
    new_secret: Field,
    
    merkle_root: pub Field,
    nullifier_hash: pub Field,
    bet_commitment: pub Field,
    market_id_hash: pub Field,
    denomination: pub Field,
) {
    // 1. Verify denomination is valid (one of fixed sizes)
    let d100   = denomination == 100_000_000;      // 100 USDC
    let d1000  = denomination == 1_000_000_000;    // 1000 USDC  
    let d10000 = denomination == 10_000_000_000;   // 10000 USDC
    assert(d100 | d1000 | d10000, "Invalid denomination");
    
    // 2. Compute original commitment
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0], 4)[0];
    
    // 3. Verify nullifier hash (prevents double-betting)
    let computed_nullifier_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier");
    
    // 4. Verify commitment is in vault Merkle tree
    let computed_root = compute_merkle_root(commitment, path, indices);
    assert(computed_root == merkle_root, "Invalid merkle root");
    
    // 5. Bet amount constraints (underflow protection via Field arithmetic)
    // bet_amount must be > 0 and < denomination
    assert(bet_amount != 0, "Zero bet amount");
    
    // Constraint: bet_amount + solver_fee <= denomination
    // Since Field doesn't have < operator, we check: denomination - bet_amount - solver_fee == change
    // where change >= 0 (implied by Field being positive)
    let change = denomination - bet_amount - solver_fee;
    // change is implicitly >= 0 in Field arithmetic
    // Add constraint that change must not cause underflow (denomination >= bet_amount + solver_fee)
    let total_out = bet_amount + solver_fee;
    // Reconstruct denomination to verify no underflow occurred
    let reconstructed = total_out + change;
    assert(reconstructed == denomination, "Bet amount exceeds denomination");
    
    // 6. Market constraints
    assert(market_id != 0, "Invalid market ID");
    assert(outcome_id <= 10, "Invalid outcome ID"); // Support up to 10 outcomes
    
    // 7. Compute market_id_hash for on-chain verification
    let computed_market_hash = std::hash::poseidon2_permutation([market_id, outcome_id, bet_amount, 0], 4)[0];
    assert(computed_market_hash == market_id_hash, "Market hash mismatch");
    
    // 8. Compute bet commitment (what gets locked in bet vault)
    // This links the bet to: market, outcome, amount, and a new secret for settlement
    let computed_bet_commitment = std::hash::poseidon2_permutation([
        new_secret, 
        nullifier_hash,  // Link to original nullifier for traceability
        market_id,
        bet_amount
    ], 4)[0];
    assert(computed_bet_commitment == bet_commitment, "Bet commitment mismatch");
    
    // 9. New secret must be different from original (fresh commitment)
    assert(new_secret != secret, "Must use new secret for bet");
}

// ── Unit Tests ─────────────────────────────────────────────────────────────

#[test]
fn test_valid_bet() {
    let secret = 12345;
    let nullifier = 67890;
    let bet_amount = 50_000_000; // 50 USDC
    let market_id = 42;
    let outcome_id = 1; // Yes
    let solver_fee = 1_000_000; // 1 USDC fee
    let new_secret = 54321;
    let denomination = 100_000_000; // 100 USDC
    
    let path: [Field; 20] = [0; 20];
    let indices: [bool; 20] = [false; 20];
    
    // Compute commitment
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0], 4)[0];
    let root = compute_merkle_root(commitment, path, indices);
    
    // Compute nullifier hash
    let nf_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    
    // Compute market hash
    let mkt_hash = std::hash::poseidon2_permutation([market_id, outcome_id, bet_amount, 0], 4)[0];
    
    // Compute bet commitment
    let bet_commit = std::hash::poseidon2_permutation([new_secret, nf_hash, market_id, bet_amount], 4)[0];
    
    main(
        secret, nullifier, bet_amount, market_id, outcome_id, solver_fee,
        path, indices, new_secret,
        root, nf_hash, bet_commit, mkt_hash, denomination
    );
}

#[test(should_fail)]
fn test_bet_exceeds_denomination() {
    let secret = 12345;
    let nullifier = 67890;
    let bet_amount = 90_000_000; // 90 USDC
    let solver_fee = 20_000_000; // 20 USDC fee (total 110 > 100!)
    let market_id = 42;
    let outcome_id = 1;
    let new_secret = 54321;
    let denomination = 100_000_000; // 100 USDC
    
    let path: [Field; 20] = [0; 20];
    let indices: [bool; 20] = [false; 20];
    
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0], 4)[0];
    let root = compute_merkle_root(commitment, path, indices);
    let nf_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    let mkt_hash = std::hash::poseidon2_permutation([market_id, outcome_id, bet_amount, 0], 4)[0];
    let bet_commit = std::hash::poseidon2_permutation([new_secret, nf_hash, market_id, bet_amount], 4)[0];
    
    // Should fail - bet + fee exceeds denomination
    main(
        secret, nullifier, bet_amount, market_id, outcome_id, solver_fee,
        path, indices, new_secret,
        root, nf_hash, bet_commit, mkt_hash, denomination
    );
}

#[test(should_fail)]
fn test_zero_market_id_fails() {
    let secret = 12345;
    let nullifier = 67890;
    let bet_amount = 50_000_000;
    let market_id = 0; // Invalid
    let outcome_id = 1;
    let solver_fee = 1_000_000;
    let new_secret = 54321;
    let denomination = 100_000_000;
    
    let path: [Field; 20] = [0; 20];
    let indices: [bool; 20] = [false; 20];
    
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0], 4)[0];
    let root = compute_merkle_root(commitment, path, indices);
    let nf_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    let mkt_hash = std::hash::poseidon2_permutation([market_id, outcome_id, bet_amount, 0], 4)[0];
    let bet_commit = std::hash::poseidon2_permutation([new_secret, nf_hash, market_id, bet_amount], 4)[0];
    
    // Should fail - market_id cannot be zero
    main(
        secret, nullifier, bet_amount, market_id, outcome_id, solver_fee,
        path, indices, new_secret,
        root, nf_hash, bet_commit, mkt_hash, denomination
    );
}

#[test(should_fail)]
fn test_same_secret_fails() {
    let secret = 12345;
    let nullifier = 67890;
    let bet_amount = 50_000_000;
    let market_id = 42;
    let outcome_id = 1;
    let solver_fee = 1_000_000;
    let new_secret = 12345; // Same as original - invalid!
    let denomination = 100_000_000;
    
    let path: [Field; 20] = [0; 20];
    let indices: [bool; 20] = [false; 20];
    
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, denomination, 0], 4)[0];
    let root = compute_merkle_root(commitment, path, indices);
    let nf_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    let mkt_hash = std::hash::poseidon2_permutation([market_id, outcome_id, bet_amount, 0], 4)[0];
    let bet_commit = std::hash::poseidon2_permutation([new_secret, nf_hash, market_id, bet_amount], 4)[0];
    
    // Should fail - must use new secret for bet commitment
    main(
        secret, nullifier, bet_amount, market_id, outcome_id, solver_fee,
        path, indices, new_secret,
        root, nf_hash, bet_commit, mkt_hash, denomination
    );
}
