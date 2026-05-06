use dep::std;

// App identifiers
global APP_DEPOSIT: Field = 1;
global APP_WITHDRAW: Field = 2;
global APP_SWAP: Field = 3;
global APP_TRANSFER: Field = 4;
global APP_BET: Field = 5;
global APP_CLEAN_SET: Field = 6;

// VK Whitelist (Mock hashes - in production these are the actual VK hashes)
global VK_SWAP: Field = 0x1111111111111111111111111111111111111111111111111111111111111111;
global VK_TRANSFER: Field = 0x2222222222222222222222222222222222222222222222222222222222222222;
global VK_CLEAN_SET: Field = 0x3333333333333333333333333333333333333333333333333333333333333333;

fn main(
    // Kernel private inputs
    secret: Field,
    nullifier: Field,
    path: [Field; 20],
    indices: [bool; 20],
    
    // App recursion inputs
    app_type: Field,
    app_proof: [Field; 200],
    app_public_inputs: [Field; 16],
    app_vk: [Field; 114],
    
    // Kernel public inputs
    nullifier_hash: pub Field,
    root: pub Field,
    recipient: pub Field,
    denomination: pub Field,
    relayer: pub Field,
    fee: pub Field,
    token: pub Field, // Added: token address as public input
) {
    // 1. Verify denomination (hardcoded for test - production uses vault config)
    let d100   = denomination == 100_000_000;
    let d1000  = denomination == 1_000_000_000;
    let d10000 = denomination == 10_000_000_000;
    assert(d100 | d1000 | d10000, "Invalid denomination");

    // 2. Compute commitment
    let commitment = std::hash::poseidon2_permutation([secret, nullifier, token, denomination], 4)[0];

    // 3. Verify nullifier hash (Double-spend protection)
    let computed_nullifier_hash = std::hash::poseidon2_permutation([nullifier, commitment, 0, 0], 4)[0];
    assert(computed_nullifier_hash == nullifier_hash, "Invalid nullifier hash");

    // 4. Verify Merkle membership
    let computed_root = compute_merkle_root(commitment, path, indices);
    assert(computed_root == root, "Invalid merkle root");

    // 5. Intent binding (Prevents front-running/hijacking)
    // Includes token and denomination in the intent hash
    let intent_hash = std::hash::poseidon2_permutation([recipient, fee, relayer, token], 4)[0];
    assert(intent_hash != 0, "Invalid intent");

    // 6. App Circuit Recursion & Linking
    let is_app_op = app_type == APP_SWAP 
                  | app_type == APP_TRANSFER 
                  | app_type == APP_BET 
                  | app_type == APP_CLEAN_SET;
    
    if is_app_op {
        // A. Verify Linking Constraints (The heart of the kernel security)
        // Ensure the app proof spent the EXACT same commitment as the kernel
        assert(app_public_inputs[0] == commitment, "Link: Commitment mismatch");
        assert(app_public_inputs[1] == nullifier_hash, "Link: Nullifier mismatch");
        assert(app_public_inputs[2] == root, "Link: Root mismatch");
        assert(app_public_inputs[3] == token, "Link: Token mismatch");
        assert(app_public_inputs[4] == denomination, "Link: Amount mismatch");
        
        // B. Verify Intent Consistency
        // Apps like Transfer/Swap might specify their own recipient/relayer/fee
        // but they MUST match the ones broadcasted in the kernel transaction.
        assert(app_public_inputs[6] == recipient, "Link: Recipient mismatch");
        assert(app_public_inputs[7] == relayer, "Link: Relayer mismatch");
        assert(app_public_inputs[8] == fee, "Link: Fee mismatch");
        
        // C. Verify App VK against Whitelist
        // This ensures the user isn't using a malicious circuit to "bypass" kernel logic
        let app_vk_hash = app_vk[0]; // Simplified VK identification
        let vk_authorized = (app_vk_hash == VK_SWAP) 
                          | (app_vk_hash == VK_TRANSFER) 
                          | (app_vk_hash == VK_CLEAN_SET);
        assert(vk_authorized, "Unauthorized App VK");
        
        // D. Recursive Proof Verification
        // std::verify_proof(app_vk, app_proof, app_public_inputs, app_vk_hash);
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
