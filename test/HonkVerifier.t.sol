// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "src/core/HonkVerifier.sol";

contract HonkVerifierTest is Test {
    HonkVerifier verifier;

    // 6 public inputs matching Prover.toml:
    // secret=1, nullifier=2, denomination=100_000_000, relayer=0, fee=0
    bytes32 constant NULLIFIER_HASH =
        0x066f887cb761c6616ea5a9775bab244d526ae04e244e1b0291cd86c1fbda0330;
    bytes32 constant ROOT =
        0x221b3171ae30f12ee672c13863c7bfea8a11ba43c27bba43b1887d5412e7f0fd;
    bytes32 constant RECIPIENT    = bytes32(uint256(1));
    bytes32 constant DENOMINATION = bytes32(uint256(100_000_000));
    bytes32 constant RELAYER      = bytes32(uint256(0));
    bytes32 constant FEE          = bytes32(uint256(0));

    function _proofPath() internal view returns (string memory) {
        string memory fromEnv = vm.envOr("NOFACE_PROOF_PATH", string(""));
        if (bytes(fromEnv).length != 0) return fromEnv;
        return string.concat(vm.projectRoot(), "/circuits/target/proof/proof/proof");
    }

    function setUp() public {
        verifier = new HonkVerifier();
    }

    function _buildPublicInputs() internal pure returns (bytes32[] memory) {
        bytes32[] memory pi = new bytes32[](6);
        pi[0] = NULLIFIER_HASH;
        pi[1] = ROOT;
        pi[2] = RECIPIENT;
        pi[3] = DENOMINATION;
        pi[4] = RELAYER;
        pi[5] = FEE;
        return pi;
    }

    function _requireProofFixture() internal view returns (bool) {
        return vm.isFile(_proofPath());
    }

    function test_realProofVerifies() public {
        if (!_requireProofFixture()) return;
        bytes memory proof = vm.readFileBinary(_proofPath());
        bytes32[] memory pi = _buildPublicInputs();
        bool ok = verifier.verify(proof, pi);
        assertTrue(ok, "Real proof must verify");
    }

    function test_wrongPublicInputReverts() public {
        if (!_requireProofFixture()) return;
        bytes memory proof = vm.readFileBinary(_proofPath());
        bytes32[] memory pi = _buildPublicInputs();
        // Corrupt nullifier_hash
        pi[0] = bytes32(uint256(pi[0]) ^ 1);
        vm.expectRevert();
        verifier.verify(proof, pi);
    }

    function test_wrongRelayerReverts() public {
        if (!_requireProofFixture()) return;
        bytes memory proof = vm.readFileBinary(_proofPath());
        bytes32[] memory pi = _buildPublicInputs();
        // Swap relayer to non-zero — proof was generated with relayer=0
        pi[4] = bytes32(uint256(uint160(address(0xDEAD))));
        vm.expectRevert();
        verifier.verify(proof, pi);
    }

    function test_wrongFeeReverts() public {
        if (!_requireProofFixture()) return;
        bytes memory proof = vm.readFileBinary(_proofPath());
        bytes32[] memory pi = _buildPublicInputs();
        // Change fee from 0 to 1 — proof was generated with fee=0
        pi[5] = bytes32(uint256(1));
        vm.expectRevert();
        verifier.verify(proof, pi);
    }
}
