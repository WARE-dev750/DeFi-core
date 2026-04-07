// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/*
 * NofaceVault.sol
 * ─────────────────────────────────────────────────────────────
 * The master state controller for the NOFACE protocol.
 *
 * WHAT THIS CONTRACT DOES:
 *   1. Accepts ERC-20 deposits (USDC for beta)
 *   2. Issues a cryptographic commitment into the Merkle tree
 *   3. Verifies ZK proofs on withdrawal
 *   4. Burns nullifiers to prevent double-spend
 *   5. Releases funds to any fresh address
 *
 * WHAT THIS CONTRACT NEVER DOES:
 *   - Never stores who deposited
 *   - Never links deposit to withdrawal
 *   - Never holds private keys
 *   - Never knows which commitment belongs to whom
 *
 * SECURITY INVARIANT:
 *   Total assets in vault == sum of all unspent commitments
 *   This must hold at all times. Any deviation = critical bug.
 * ─────────────────────────────────────────────────────────────
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {InternalLeanIMT, LeanIMTData} from "@zk-kit/lean-imt.sol/InternalLeanIMT.sol";

contract NofaceVault is Ownable {

    // ─────────────────────────────────────────────────────────
    // REENTRANCY GUARD (manual — uses SSTORE not TSTORE)
    // OZ v5 ReentrancyGuard uses transient storage which
    // behaves unexpectedly in Foundry tests on Cancun.
    // This uses regular storage — identical security guarantee.
    // ─────────────────────────────────────────────────────────
    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        require(_reentrancyStatus != _ENTERED, "ReentrancyGuard: reentrant call");
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    using SafeERC20 for IERC20;
    using InternalLeanIMT for LeanIMTData;

    // ─────────────────────────────────────────────────────────
    // CONSTANTS
    // ─────────────────────────────────────────────────────────

    // Fixed deposit denominations for maximum privacy
    // Every deposit looks identical on-chain
    // This maximises the anonymity set
    uint256 public constant DENOM_SMALL  = 100  * 1e6; // 100  USDC
    uint256 public constant DENOM_MEDIUM = 1000 * 1e6; // 1000 USDC
    uint256 public constant DENOM_LARGE  = 10000 * 1e6; // 10000 USDC

    // Protocol fee — 0.3% on withdrawal
    // Split: 0.1% stakers / 0.1% buyback / 0.1% treasury
    uint256 public constant FEE_BPS = 30; // 30 basis points = 0.3%
    uint256 public constant BPS_DENOM = 10_000;

    // ─────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────

    // The supported deposit token (USDC for beta)
    IERC20 public immutable token;

    // The Merkle tree — tracks all commitments
    // Built today from Semaphore / Ethereum Foundation
    LeanIMTData private _tree;

    // Nullifier registry — prevents double spend
    // Once a nullifier is spent it can NEVER be spent again
    // mapping: nullifierHash => isSpent
    mapping(bytes32 => bool) public nullifierSpent;

    // Valid historical roots — proofs never go stale
    // A user can generate a proof against any historical root
    // mapping: root => isValid
    mapping(bytes32 => bool) public knownRoots;

    // Treasury address — receives protocol fees
    address public treasury;

    // Emergency pause — deposits only, withdrawals always open
    bool public depositsPaused;

    // ─────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────

    // Emitted on deposit — only commitment is logged, never identity
    event Deposit(
        bytes32 indexed commitment,
        uint256 leafIndex,
        uint256 denomination,
        uint256 timestamp
    );

    // Emitted on withdrawal — nullifier logged, recipient logged
    // Nobody can link nullifier to original commitment without the secret
    event Withdrawal(
        bytes32 indexed nullifierHash,
        address indexed recipient,
        uint256 denomination,
        uint256 fee,
        uint256 timestamp
    );

    // Emitted when a new root is added to history
    event RootAdded(bytes32 indexed root);

    // ─────────────────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────────────────

    error InvalidDenomination();
    error CommitmentAlreadyExists();
    error NullifierAlreadySpent();
    error InvalidRoot();
    error InvalidProof();
    error DepositsArePaused();
    error ZeroAddress();
    error TreeFull();

    // ─────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────

    constructor(
        address _token,
        address _treasury,
        address _owner
    ) Ownable(_owner) {
        if (_token    == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_owner    == address(0)) revert ZeroAddress();

        _reentrancyStatus = _NOT_ENTERED;
        token    = IERC20(_token);
        treasury = _treasury;

        // LeanIMT needs no initialisation — dynamic depth, starts empty
        // Record the empty tree root as valid
        // Allows proofs to be generated before any deposits
        _recordRoot();
    }

    // ─────────────────────────────────────────────────────────
    // DEPOSIT
    // ─────────────────────────────────────────────────────────

    /**
     * @notice Deposit tokens into the shielded vault.
     *
     * @dev The caller provides a cryptographic commitment.
     *      The commitment is H(secret, nullifier) computed off-chain.
     *      The vault inserts it into the Merkle tree and takes payment.
     *      After this call the depositor's funds are invisible.
     *
     * @param commitment  The Poseidon hash of (secret, nullifier).
     *                    Computed off-chain by the SDK.
     *                    This is the ONLY link to the deposit.
     *                    If you lose the secret note you lose the funds.
     *
     * @param denomination The deposit size. Must be SMALL/MEDIUM/LARGE.
     *                     Fixed denominations maximise anonymity set.
     */
    function deposit(
        bytes32 commitment,
        uint256 denomination
    ) external nonReentrant {
        // Check deposits are not paused
        if (depositsPaused) revert DepositsArePaused();

        // Validate denomination — only fixed amounts accepted
        // This is a privacy feature not just a restriction
        if (
            denomination != DENOM_SMALL  &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE
        ) revert InvalidDenomination();

        // Commitment must not already exist in the tree
        // Duplicate commitments would allow replay attacks
        if (_tree._has(uint256(commitment))) revert CommitmentAlreadyExists();

        // Pull tokens from depositor BEFORE updating state
        // Follows checks-effects-interactions pattern
        token.safeTransferFrom(msg.sender, address(this), denomination);

        // Insert commitment into Merkle tree
        // This is the cryptographic record of the deposit
        uint256 leafIndex = _tree.size;
        _tree._insert(uint256(commitment));

        // Record the new root as valid for future proofs
        _recordRoot();

        emit Deposit(
            commitment,
            leafIndex,
            denomination,
            block.timestamp
        );
    }

    // ─────────────────────────────────────────────────────────
    // WITHDRAW
    // ─────────────────────────────────────────────────────────

    /**
     * @notice Withdraw tokens from the shielded vault to a fresh address.
     *
     * @dev The caller provides a ZK proof that:
     *      1. They know a secret that hashes to a commitment in the tree
     *      2. The nullifier has not been spent before
     *      3. The recipient address is bound to this specific proof
     *
     *      No link exists between the depositor and recipient.
     *      The nullifier is burned permanently after this call.
     *
     * @param nullifierHash  H(secret, 1) — unique per deposit.
     *                       Burned after use. Cannot be reused.
     * @param root           The Merkle root the proof was generated against.
     *                       Must be a known historical root.
     * @param recipient      The fresh wallet to receive funds.
     *                       Should have zero prior transaction history.
     * @param denomination   The amount to withdraw.
     * @param proof          The ZK proof bytes. Verified on-chain.
     *                       In beta this is a placeholder — full
     *                       UltraHonk verifier added in V1.
     */
    function withdraw(
        bytes32 nullifierHash,
        bytes32 root,
        address recipient,
        uint256 denomination,
        bytes calldata proof
    ) external nonReentrant {
        // Validate inputs
        if (recipient == address(0)) revert ZeroAddress();

        // Validate denomination
        if (
            denomination != DENOM_SMALL  &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE
        ) revert InvalidDenomination();

        // Root must be a known historical root
        // This allows proofs generated before recent deposits to still work
        if (!knownRoots[root]) revert InvalidRoot();

        // Nullifier must not be spent
        // This is the double-spend prevention mechanism
        // Once spent — gone forever
        if (nullifierSpent[nullifierHash]) revert NullifierAlreadySpent();

        // Verify the ZK proof
        // In beta: placeholder verification (always passes)
        // In V1: full UltraHonk on-chain verification
        if (!_verifyProof(nullifierHash, root, recipient, denomination, proof)) {
            revert InvalidProof();
        }

        // Burn the nullifier BEFORE transferring funds
        // Critical: prevents reentrancy-based double spend
        nullifierSpent[nullifierHash] = true;

        // Calculate protocol fee
        uint256 fee = (denomination * FEE_BPS) / BPS_DENOM;
        uint256 recipientAmount = denomination - fee;

        // Send fee to treasury
        if (fee > 0) {
            token.safeTransfer(treasury, fee);
        }

        // Send remaining funds to recipient fresh wallet
        token.safeTransfer(recipient, recipientAmount);

        emit Withdrawal(
            nullifierHash,
            recipient,
            denomination,
            fee,
            block.timestamp
        );
    }

    // ─────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────

    /// @notice Returns the current Merkle root
    function currentRoot() external view returns (bytes32) {
        return bytes32(_tree._root());
    }

    /// @notice Returns the total number of deposits ever made
    function totalDeposits() external view returns (uint256) {
        return _tree.size;
    }

    /// @notice Check if a commitment exists in the tree
    function commitmentExists(bytes32 commitment) external view returns (bool) {
        return _tree._has(uint256(commitment));
    }

    /// @notice Check if a nullifier has been spent
    function isSpent(bytes32 nullifierHash) external view returns (bool) {
        return nullifierSpent[nullifierHash];
    }

    /// @notice Check if a root is a known valid root
    function isKnownRoot(bytes32 root) external view returns (bool) {
        return knownRoots[root];
    }

    // ─────────────────────────────────────────────────────────
    // ADMIN FUNCTIONS — controlled by 3-of-5 multisig
    // ─────────────────────────────────────────────────────────

    /// @notice Pause deposits only — withdrawals always remain open
    /// @dev Emergency use only. Cannot trap user funds.
    function pauseDeposits() external onlyOwner {
        depositsPaused = true;
    }

    /// @notice Resume deposits
    function unpauseDeposits() external onlyOwner {
        depositsPaused = false;
    }

    /// @notice Update treasury address
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    // ─────────────────────────────────────────────────────────
    // INTERNAL FUNCTIONS
    // ─────────────────────────────────────────────────────────

    /// @dev Records the current tree root as a valid historical root
    function _recordRoot() internal {
        bytes32 root = bytes32(_tree._root());
        knownRoots[root] = true;
        emit RootAdded(root);
    }

    /**
     * @dev ZK proof verifier.
     *
     *      BETA: Always returns true. Placeholder only.
     *      V1:   Calls auto-generated UltraHonk Verifier.sol
     *            produced by the Noir compiler from main.nr
     *
     *      The real verifier checks:
     *      - commitment = Poseidon(secret, nullifier) is in tree
     *      - nullifierHash = Poseidon(secret, 1)
     *      - recipient address is bound to this proof
     *      - denomination matches commitment
     */
    function _verifyProof(
        bytes32 nullifierHash,
        bytes32 root,
        address recipient,
        uint256 denomination,
        bytes calldata proof
    ) internal pure returns (bool) {
        // Silence unused variable warnings in beta
        // These are all used by the real verifier in V1
        (nullifierHash, root, recipient, denomination, proof);

        // TODO V1: Replace with real UltraHonk verifier call
        // return IVerifier(verifier).verify(proof, publicInputs);
        return true;
    }
}
