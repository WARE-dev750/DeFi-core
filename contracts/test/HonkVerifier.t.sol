// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/core/HonkVerifier.sol";

contract HonkVerifierTest is Test {

    HonkVerifier verifier;

    function setUp() public {
        verifier = new HonkVerifier();
    }

    /// @notice Real UltraHonk proof must pass on-chain verification
    function test_realProofVerifies() public view {
        bytes memory proof = vm.readFileBinary(
            "/home/robelsocial750/DeFi-core/circuits/target/proof/proof"
        );

        bytes32[] memory pub = new bytes32[](4);
        pub[0] = bytes32(0x066f887cb761c6616ea5a9775bab244d526ae04e244e1b0291cd86c1fbda0330);
        pub[1] = bytes32(0x221b3171ae30f12ee672c13863c7bfea8a11ba43c27bba43b1887d5412e7f0fd);
        pub[2] = bytes32(uint256(1));
        pub[3] = bytes32(uint256(100_000_000));

        assertTrue(verifier.verify(proof, pub), "valid proof rejected");
    }

    /// @notice Corrupted public inputs must cause verifier to revert
    /// The HonkVerifier reverts (SumcheckFailed) rather than returning false
    function test_wrongPublicInputReverts() public {
        bytes memory proof = vm.readFileBinary(
            "/home/robelsocial750/DeFi-core/circuits/target/proof/proof"
        );

        bytes32[] memory pub = new bytes32[](4);
        pub[0] = bytes32(uint256(0xdeadbeef)); // corrupted nullifier_hash
        pub[1] = bytes32(0x221b3171ae30f12ee672c13863c7bfea8a11ba43c27bba43b1887d5412e7f0fd);
        pub[2] = bytes32(uint256(1));
        pub[3] = bytes32(uint256(100_000_000));

        // verifier reverts on invalid proof — catch it
        vm.expectRevert();
        verifier.verify(proof, pub);
    }
}
