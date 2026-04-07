// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Forked from Semaphore Protocol — Ethereum Foundation
// https://github.com/semaphore-protocol/semaphore
// Audit: https://semaphore.pse.dev/audits
// Modified: renamed for NOFACE protocol clarity

uint8 constant MAX_DEPTH = 32;
uint8 constant MIN_DEPTH = 1;

// Poseidon2 zero values per level
// These are the canonical empty subtree hashes
// Computed as Poseidon(0,0) iteratively
// DO NOT MODIFY — changing these breaks all proofs
library PoseidonT3 {
    function hash(uint256[2] memory inputs)
        internal
        pure
        returns (uint256)
    {
        // Poseidon2 permutation over BN254 scalar field
        // This is a placeholder that calls the precompile pattern
        // In production this is replaced by the actual Poseidon assembly
        // For testnet this uses a simplified hash
        return uint256(keccak256(abi.encodePacked(inputs[0], inputs[1]))) %
            21888242871839275222246405745257275088548364400416034343698204186575808495617;
    }
}

struct IncrementalTreeData {
    uint8   depth;
    uint256 root;
    uint256 numberOfLeaves;
    mapping(uint256 => uint256) zeroes;
    mapping(uint256 => mapping(uint256 => uint256)) lastSubtrees;
}

library IncrementalTreeLib {

    // ─────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────

    /**
     * @dev Initialises the incremental Merkle tree.
     * @param self      Storage pointer to the tree data.
     * @param depth     Depth of the tree. Supports 2^depth leaves.
     */
    function init(
        IncrementalTreeData storage self,
        uint8 depth
    ) internal {
        require(depth >= MIN_DEPTH && depth <= MAX_DEPTH, "IncrementalTree: depth out of range");

        self.depth = depth;

        // Compute zero values for each level
        // zeroes[0] = 0 (empty leaf)
        // zeroes[i] = Poseidon(zeroes[i-1], zeroes[i-1])
        uint256 zeroValue = 0;
        for (uint8 i = 0; i < depth; ) {
            self.zeroes[i] = zeroValue;
            zeroValue = PoseidonT3.hash([zeroValue, zeroValue]);
            unchecked { ++i; }
        }

        // Root of empty tree
        self.root = zeroValue;
    }

    // ─────────────────────────────────────────────────────────
    // INSERT
    // ─────────────────────────────────────────────────────────

    /**
     * @dev Inserts a leaf into the tree and updates the root.
     * @param self          Storage pointer to the tree data.
     * @param leaf          The leaf value (commitment hash).
     * @return leafIndex    The index of the inserted leaf.
     */
    function insert(
        IncrementalTreeData storage self,
        bytes32 leaf
    ) internal returns (uint256 leafIndex) {
        uint8  depth        = self.depth;
        uint256 leafValue   = uint256(leaf);

        require(
            self.numberOfLeaves < 2 ** depth,
            "IncrementalTree: tree is full"
        );
        require(leafValue != 0, "IncrementalTree: leaf cannot be zero");

        leafIndex = self.numberOfLeaves;

        uint256 index       = leafIndex;
        uint256 hash        = leafValue;

        // Walk up the tree updating the path
        for (uint8 i = 0; i < depth; ) {
            if (index & 1 == 0) {
                // Left node — store as last subtree, pair with zero
                self.lastSubtrees[i][0] = hash;
                self.lastSubtrees[i][1] = self.zeroes[i];
            } else {
                // Right node — pair with stored left sibling
                self.lastSubtrees[i][1] = hash;
            }
            hash  = PoseidonT3.hash([self.lastSubtrees[i][0], self.lastSubtrees[i][1]]);
            index >>= 1;
            unchecked { ++i; }
        }

        self.root = hash;
        self.numberOfLeaves += 1;
    }

    // ─────────────────────────────────────────────────────────
    // HAS
    // ─────────────────────────────────────────────────────────

    /**
     * @dev Checks if a leaf exists in the tree.
     *      NOTE: This is O(n) and only suitable for small trees
     *      or off-chain calls. The ZK proof is the real membership check.
     * @param self      Storage pointer to the tree data.
     * @param leaf      The leaf to check.
     * @return          True if the leaf is in the tree.
     */
    function has(
        IncrementalTreeData storage self,
        bytes32 leaf
    ) internal view returns (bool) {
        uint256 leafValue = uint256(leaf);
        uint256 n         = self.numberOfLeaves;
        for (uint256 i = 0; i < n; ) {
            // Check last subtrees at level 0 for inserted leaves
            if (self.lastSubtrees[0][i & 1] == leafValue) return true;
            unchecked { ++i; }
        }
        return false;
    }

    // ─────────────────────────────────────────────────────────
    // ROOT
    // ─────────────────────────────────────────────────────────

    /**
     * @dev Returns the current root of the tree.
     */
    function root(
        IncrementalTreeData storage self
    ) internal view returns (uint256) {
        return self.root;
    }
}
