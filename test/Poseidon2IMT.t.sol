// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Poseidon2} from "../contracts/src/core/Poseidon2.sol";
import {MerkleTreeWithHistory} from "../contracts/src/core/MerkleTreeWithHistory.sol";


// Harness exposes internal _insert for testing
contract MerkleTreeHarness is MerkleTreeWithHistory {
    constructor() MerkleTreeWithHistory(20) {}
    function insert(uint256 leaf) external returns (uint32) {
        return _insert(leaf);
    }
}


// Harness exposes internal _insert for testing
contract MerkleTreeWithHistoryTest is Test {

    MerkleTreeHarness private tree;

    function setUp() public {
        tree = new MerkleTreeHarness();
    }

    // Empty tree root must equal zeros[20]
    function test_EmptyRoot() public view {
        assertEq(
            tree.getLastRoot(),
            0x276ff13fde3afa1adb26149ddc3aa67240d603b6a91da5e494c8e58706381a38
        );
    }

    // After inserting leaf=1 at index 0 (left child all the way up),
    // root = Poseidon2.hash(Poseidon2.hash(...hash(1, zeros[0])..., zeros[i])..., zeros[19])
    function test_InsertOneLeaf() public {
        tree.insert(1);
        uint256 root = tree.getLastRoot();
        // Compute expected root manually
        uint256 current = 1;
        for (uint256 i = 0; i < 20; i++) {
            current = Poseidon2.hash(current, tree.zeros(i));
        }
        assertEq(root, current);
    }

    // After inserting two leaves, root = Poseidon2.hash(leaf0, leaf1) hashed up with zeros
    function test_InsertTwoLeaves() public {
        tree.insert(1);
        tree.insert(2);
        uint256 root = tree.getLastRoot();
        // level 0: hash(1, 2)
        uint256 current = Poseidon2.hash(1, 2);
        // levels 1-19: hash(current, zeros[i])
        for (uint256 i = 1; i < 20; i++) {
            current = Poseidon2.hash(current, tree.zeros(i));
        }
        assertEq(root, current);
    }

    // Root history: isKnownRoot returns true for recent roots
    function test_RootHistory() public {
        uint256 emptyRoot = tree.getLastRoot();
        tree.insert(1);
        uint256 root1 = tree.getLastRoot();
        // Both roots should be known
        assertTrue(tree.isKnownRoot(emptyRoot));
        assertTrue(tree.isKnownRoot(root1));
    }

    // Size increments correctly
    function test_SizeIncrements() public {
        assertEq(uint256(tree.nextIndex()), 0);
        tree.insert(1);
        assertEq(uint256(tree.nextIndex()), 1);
        tree.insert(2);
        assertEq(uint256(tree.nextIndex()), 2);
    }

    // Print zero values for reference
    function test_PrintZeroValues() public {
        uint256[32] memory z;
        z[0] = 0;
        for (uint256 i = 1; i <= 31; i++) {
            z[i] = Poseidon2.hash(z[i-1], z[i-1]);
            emit log_named_bytes32(
                string(abi.encodePacked("zeros[", _toString(i), "]")),
                bytes32(z[i])
            );
        }
    }

    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 tmp = v; uint256 len;
        while (tmp != 0) { len++; tmp /= 10; }
        bytes memory buf = new bytes(len);
        while (v != 0) { buf[--len] = bytes1(uint8(48 + v % 10)); v /= 10; }
        return string(buf);
    }
}
