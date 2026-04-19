// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Interface matching NofaceVault.withdraw exactly.
interface INofaceVault {
    function withdraw(
        bytes calldata proof,
        bytes32 nullifierHash,
        bytes32 root,
        address recipient,
        uint256 denomination,
        address relayer,
        uint256 fee
    ) external;
}

/// @title BatchManager
/// @notice Solver-facing contract. Accepts a bundle of up to MAX_BATCH_SIZE
///         withdrawal intents and executes them in a single transaction.
///
/// Architecture:
/// - BatchManager has ZERO custody of funds. It only orchestrates calls to NofaceVault.
/// - Each withdrawal is wrapped in try/catch. One bad proof does not revert the bundle.
/// - Permissionless — any address can be a solver. No whitelist, no owner.
/// - Relayer is part of each intent and must match the proof public input.
///   This supports both permissionless proofs (relayer=0) and dedicated relayers.
/// - Solver collects all fees atomically in one transaction.
///
/// MEV note: individual proofs are still MEV-proof at the cryptographic layer.
/// A front-runner who copies a bundle cannot change relayer or fee without
/// invalidating each proof in the bundle.
contract BatchManager is ReentrancyGuard {

    uint256 public constant MAX_BATCH_SIZE = 10;

    address public immutable vault;

    // Emitted per successful withdrawal in a bundle.
    event BatchWithdrawal(
        bytes32 indexed nullifierHash,
        address indexed recipient,
        bool success,
        string reason
    );

    error EmptyBatch();
    error BatchTooLarge();

    struct Intent {
        bytes   proof;
        bytes32 nullifierHash;
        bytes32 root;
        address recipient;
        uint256 denomination;
        address relayer;
        uint256 fee;
    }

    constructor(address _vault) {
        vault = _vault;
    }

    /// @notice Execute a bundle of withdrawal intents.
    /// @dev    Each intent includes its relayer; value must match proof public inputs.
    /// @param  intents Array of withdrawal intents. Max MAX_BATCH_SIZE.
    function executeBatch(Intent[] calldata intents) external nonReentrant {
        if (intents.length == 0)                revert EmptyBatch();
        if (intents.length > MAX_BATCH_SIZE)    revert BatchTooLarge();

        for (uint256 i = 0; i < intents.length; i++) {
            Intent calldata intent = intents[i];

            // try/catch: a failed proof does not revert the entire bundle.
            // The vault will revert internally; we catch it and emit the reason.
            try INofaceVault(vault).withdraw(
                intent.proof,
                intent.nullifierHash,
                intent.root,
                intent.recipient,
                intent.denomination,
                intent.relayer,
                intent.fee
            ) {
                emit BatchWithdrawal(intent.nullifierHash, intent.recipient, true, "");
            } catch Error(string memory reason) {
                emit BatchWithdrawal(intent.nullifierHash, intent.recipient, false, reason);
            } catch {
                emit BatchWithdrawal(intent.nullifierHash, intent.recipient, false, "unknown");
            }
        }
    }
}
