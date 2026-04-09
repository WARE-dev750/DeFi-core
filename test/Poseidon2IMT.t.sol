// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Poseidon2} from "../contracts/src/core/Poseidon2.sol";
import {Poseidon2IMT} from "../contracts/src/core/Poseidon2IMT.sol";

contract Poseidon2IMTTest is Test {
    using Poseidon2IMT for Poseidon2IMT.IMTData;

    Poseidon2IMT.IMTData private tree;

    function setUp() public {
        tree._init();
    }

    // Empty tree root must equal zeros[20]
    function test_EmptyRoot() public view {
        assertEq(
            tree._root(),
            0x3039bcb20f03fd9c8650138ef2cfe643edeed152f9c20999f43aeed54d79e387
        );
    }

    // After inserting leaf=1 at index 0 (left child all the way up),
    // root = Poseidon2.hash(Poseidon2.hash(...hash(1, zeros[0])..., zeros[i])..., zeros[19])
    function test_InsertOneLeaf() public {
        tree._insert(1);
        uint256 root = tree._root();
        // Compute expected root manually
        uint256 current = 1;
        for (uint256 i = 0; i < 20; i++) {
            current = Poseidon2.hash(current, Poseidon2IMT._zeros(i));
        }
        assertEq(root, current);
    }

    // After inserting two leaves, root = Poseidon2.hash(leaf0, leaf1) hashed up with zeros
    function test_InsertTwoLeaves() public {
        tree._insert(1);
        tree._insert(2);
        uint256 root = tree._root();
        // level 0: hash(1, 2)
        uint256 current = Poseidon2.hash(1, 2);
        // levels 1-19: hash(current, zeros[i])
        for (uint256 i = 1; i < 20; i++) {
            current = Poseidon2.hash(current, Poseidon2IMT._zeros(i));
        }
        assertEq(root, current);
    }

    // Root history: isKnownRoot returns true for recent roots
    function test_RootHistory() public {
        uint256 emptyRoot = tree._root();
        tree._insert(1);
        uint256 root1 = tree._root();
        // Both roots should be known
        assertTrue(tree._isKnownRoot(emptyRoot));
        assertTrue(tree._isKnownRoot(root1));
    }

    // Size increments correctly
    function test_SizeIncrements() public {
        assertEq(tree.size, 0);
        tree._insert(1);
        assertEq(tree.size, 1);
        tree._insert(2);
        assertEq(tree.size, 2);
    }

    // Print zero values for reference
    function test_PrintZeroValues() public {
        uint256[21] memory z;
        z[0] = 0;
        for (uint256 i = 1; i <= 20; i++) {
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
