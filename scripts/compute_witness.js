const { buildPoseidon } = require("circomlibjs");

async function main() {
    const poseidon = await buildPoseidon();
    const F = poseidon.F;

    const secret      = BigInt(1);
    const nullifier   = BigInt(2);
    const denomination = BigInt(100_000_000);
    const ZERO        = BigInt(0);

    // commitment = Poseidon2([secret, nullifier, denomination, 0])[0]
    const commitment = F.toObject(poseidon([secret, nullifier, denomination, ZERO]));

    // nullifier_hash = Poseidon2([nullifier, commitment, 0, 0])[0]
    const nullifier_hash = F.toObject(poseidon([nullifier, commitment, ZERO, ZERO]));

    // root: simulate 20-level path with all zero siblings, all left indices
    // each level: current = Poseidon2([current, 0, 0, 0])[0]
    let current = commitment;
    for (let i = 0; i < 20; i++) {
        current = F.toObject(poseidon([current, ZERO, ZERO, ZERO]));
    }
    const root = current;

    console.log("=== Prover.toml values ===");
    console.log(`secret = "${secret}"`);
    console.log(`nullifier = "${nullifier}"`);
    console.log(`denomination = "${denomination}"`);
    console.log(`nullifier_hash = "0x${nullifier_hash.toString(16).padStart(64, '0')}"`);
    console.log(`root = "0x${root.toString(16).padStart(64, '0')}"`);
    console.log(`commitment = "0x${commitment.toString(16).padStart(64, '0')}"`);
}

main().catch(console.error);
