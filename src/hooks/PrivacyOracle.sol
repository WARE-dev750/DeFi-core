// SPDX-License-Identifier: MIT
// PrivacyOracle: Clean Set Verification for Compliance
//
// Forked concept from: Privacy Pools (Vitalik Buterin, Jacob Illum, et al.)
// Reference: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4503965
//
// Validates that a commitment's associated funds originate from "clean" sources
// by proving membership in a Merkle tree of approved deposit sources.

pragma solidity ^0.8.23;

import {MerkleTreeWithHistory} from "../core/MerkleTreeWithHistory.sol";

/// @title PrivacyOracle
/// @notice Validates that commitments come from approved source sets
/// @dev Maintains a separate Merkle tree of "clean" source addresses
contract PrivacyOracle is MerkleTreeWithHistory {
    
    // ── Roles ────────────────────────────────────────────────────────────────
    address public governance;
    mapping(address => bool) public validators;
    
    // ── State ─────────────────────────────────────────────────────────────────
    // Source address -> is whitelisted
    mapping(address => bool) public cleanSources;
    // Commitment -> has been validated through oracle
    mapping(bytes32 => bool) public validatedCommitments;
    
    // ── Events ───────────────────────────────────────────────────────────────
    event SourceAdded(address indexed source, uint256 timestamp);
    event SourceRemoved(address indexed source, uint256 timestamp);
    event CommitmentValidated(bytes32 indexed commitment, uint256 indexed leafIndex);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    
    // ── Errors ───────────────────────────────────────────────────────────────
    error Unauthorized();
    error AlreadyClean();
    error NotClean();
    error CommitmentAlreadyValidated();
    error InvalidSource();
    
    // ── Modifiers ────────────────────────────────────────────────────────────
    modifier onlyGovernance() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }
    
    modifier onlyValidator() {
        if (!validators[msg.sender] && msg.sender != governance) revert Unauthorized();
        _;
    }
    
    // ── Constructor ─────────────────────────────────────────────────────────
    constructor() MerkleTreeWithHistory(20) {
        governance = msg.sender;
        validators[msg.sender] = true;
    }
    
    // ── Governance ───────────────────────────────────────────────────────────
    function transferGovernance(address newGovernance) external onlyGovernance {
        governance = newGovernance;
    }
    
    function addValidator(address validator) external onlyGovernance {
        validators[validator] = true;
        emit ValidatorAdded(validator);
    }
    
    function removeValidator(address validator) external onlyGovernance {
        validators[validator] = false;
        emit ValidatorRemoved(validator);
    }
    
    // ── Source Management ───────────────────────────────────────────────────
    /// @notice Add a source address to the clean set
    /// @dev Only governance can add sources
    function addCleanSource(address source) external onlyGovernance {
        if (source == address(0)) revert InvalidSource();
        if (cleanSources[source]) revert AlreadyClean();
        
        cleanSources[source] = true;
        
        // Insert source hash into Merkle tree
        bytes32 leaf = keccak256(abi.encodePacked(source));
        uint32 leafIndex = _insert(uint256(leaf));
        
        emit SourceAdded(source, block.timestamp);
    }
    
    /// @notice Remove a source address from the clean set
    /// @dev Only governance can remove sources
    function removeCleanSource(address source) external onlyGovernance {
        if (!cleanSources[source]) revert NotClean();
        
        cleanSources[source] = false;
        
        // Note: Removing from Merkle tree is complex; we use nullifier-style approach
        // In practice, sources remain in tree but are marked invalid off-chain
        emit SourceRemoved(source, block.timestamp);
    }
    
    /// @notice Batch add multiple clean sources
    function batchAddCleanSources(address[] calldata sources) external onlyGovernance {
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i] == address(0)) continue;
            if (cleanSources[sources[i]]) continue;
            
            cleanSources[sources[i]] = true;
            bytes32 leaf = keccak256(abi.encodePacked(sources[i]));
            _insert(uint256(leaf));
            emit SourceAdded(sources[i], block.timestamp);
        }
    }
    
    // ── Validation ────────────────────────────────────────────────────────────
    /// @notice Mark a commitment as validated against the clean set
    /// @dev Validators can validate that a commitment was created from clean sources
    /// This is called after off-chain verification of the commitment's origin
    function validateCommitment(bytes32 commitment) external onlyValidator {
        if (validatedCommitments[commitment]) revert CommitmentAlreadyValidated();
        
        validatedCommitments[commitment] = true;
        
        emit CommitmentValidated(commitment, 0); // 0 = oracle validation, not tree index
    }
    
    /// @notice Batch validate commitments
    function batchValidateCommitments(bytes32[] calldata commitments) external onlyValidator {
        for (uint256 i = 0; i < commitments.length; i++) {
            if (validatedCommitments[commitments[i]]) continue;
            validatedCommitments[commitments[i]] = true;
            emit CommitmentValidated(commitments[i], 0);
        }
    }
    
    // ── View Functions ─────────────────────────────────────────────────────────
    function isCleanSource(address source) external view returns (bool) {
        return cleanSources[source];
    }
    
    function isCommitmentValidated(bytes32 commitment) external view returns (bool) {
        return validatedCommitments[commitment];
    }
    
    function getCleanSetRoot() external view returns (bytes32) {
        return bytes32(getLastRoot());
    }
    
    /// @notice Verify that a source is in the clean set Merkle tree
    function verifyCleanSource(
        address source,
        uint256[20] calldata path,
        bool[20] calldata indices
    ) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(source));
        uint256 computedRoot = uint256(leaf);
        
        for (uint256 i = 0; i < 20; i++) {
            uint256 sibling = path[i];
            if (indices[i]) {
                computedRoot = uint256(keccak256(abi.encodePacked(sibling, computedRoot)));
            } else {
                computedRoot = uint256(keccak256(abi.encodePacked(computedRoot, sibling)));
            }
        }
        
        return isKnownRoot(computedRoot);
    }
}
