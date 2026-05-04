// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Poseidon2} from "../contracts/src/core/Poseidon2.sol";

/// @notice Validates Poseidon2.sol against ground truth vectors produced by Noir.
/// @dev If ANY of these tests fail, the Solidity implementation is wrong.
///      DO NOT modify expected values — regenerate from Noir if needed.
///      Ground truth: nargo test --show-output (nargo nightly 2026-04-08)
///      All vectors: poseidon2_permutation([a, b, 0, 0], 4)[0]
contract Poseidon2Test is Test {

    function test_vector_hash_0_0() public pure {
        uint256 result = Poseidon2.hash(0, 0);
        assertEq(result, 0x18dfb8dc9b82229cff974efefc8df78b1ce96d9d844236b496785c698bc6732e);
    }

    function test_vector_hash_1_0() public pure {
        uint256 result = Poseidon2.hash(1, 0);
        assertEq(result, 0x02a04ea402711ced2d4bc39608cc5350a7db4af98ec2950d4d1ec30334d6c2b4);
    }

    function test_vector_hash_0_1() public pure {
        uint256 result = Poseidon2.hash(0, 1);
        assertEq(result, 0x2ce0b6fcd20887e7855e149803d635bdb8cde2ea352a880a3d935124fd780f73);
    }

    function test_vector_hash_1_2() public pure {
        uint256 result = Poseidon2.hash(1, 2);
        assertEq(result, 0x299bfccd7daf3c917e51291383929049ec0eaed800af245056cbf135f7dea636);
    }

    function test_vector_hash_3_7() public pure {
        uint256 result = Poseidon2.hash(3, 7);
        assertEq(result, 0x221b2915d0d8d629c22266fd504844907afc67cf4dca2be39e6f8088eea8c0d6);
    }

    function test_vector_hash_2_1() public pure {
        uint256 result = Poseidon2.hash(2, 1);
        assertEq(result, 0x0dff6bc75a0964018049d6f7d67e6f07b7facff2d8639aa825e8b8208aacbbbd);
    }
}
