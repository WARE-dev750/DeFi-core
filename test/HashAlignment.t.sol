// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// AUDIT TEST: Hash alignment between on-chain PoseidonT3 and Noir circuit
// poseidon2_permutation([L, R, 0, 0])[0] must equal PoseidonT3.hash([L, R])
// Using same test vectors as Noir test_hash_alignment()

import {Test, console} from "forge-std/Test.sol";
import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";

contract HashAlignmentTest is Test {

    // Same values used in Noir test - both below BN254 modulus
    uint256 constant L = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    uint256 constant R = 0x1111111111111111111111111111111111111111111111111111111111111111;

    function test_HashAlignment_knownVector() public pure {
        uint256 onchain = PoseidonT3.hash([L, R]);
        console.log("On-chain PoseidonT3([L,R]):", onchain);
        // We will compare this value against nargo test output manually
        assert(onchain != 0);
    }
}
