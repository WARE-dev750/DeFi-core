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
 *   3. Verifies ZK proofs on withdrawal via UltraHonk verifier
 *   4. Burns nullifiers to prevent double-spend
 *   5. Releases funds to any fresh address
 *
 * SECURITY INVARIANT:
 *   Total assets in vault == sum of all unspent commitments
 * ─────────────────────────────────────────────────────────────
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {InternalLeanIMT, LeanIMTData} from "@zk-kit/lean-imt.sol/InternalLeanIMT.sol";

/// @dev Interface matching the auto-generated HonkVerifier.sol
interface IHonkVerifier {
    function verify(
        bytes calldata _proof,
        bytes32[] calldata _publicInputs
    ) external view returns (bool);
}

contract NofaceVault is Ownable {

    // ─────────────────────────────────────────────────────────
    // REENTRANCY GUARD
    // ─────────────────────────────────────────────────────────
    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED     = 2;

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
    uint256 public constant DENOM_SMALL  = 100   * 1e6;
    uint256 public constant DENOM_MEDIUM = 1_000 * 1e6;
    uint256 public constant DENOM_LARGE  = 10_000 * 1e6;

    uint256 public constant FEE_BPS   = 30;
    uint256 public constant BPS_DENOM = 10_000;

    // UltraHonk circuit declares 4 user public inputs.
    // NUMBER_OF_PUBLIC_INPUTS in HonkVerifier.sol = 12
    // (4 user inputs + 8 UltraHonk protocol inputs)
    // The 4 user inputs occupy indices 0..3 in the publicInputs array.
    uint256 private constant PUBLIC_INPUTS_COUNT = 12;

    // ─────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────
    IERC20           public immutable token;
    IHonkVerifier    public immutable verifier;

    LeanIMTData      private _tree;

    mapping(bytes32 => bool) public nullifierSpent;
    mapping(bytes32 => bool) public knownRoots;

    address public treasury;
    bool    public depositsPaused;

    // ─────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────
    event Deposit(
        bytes32 indexed commitment,
        uint256 leafIndex,
        uint256 denomination,
        uint256 timestamp
    );

    event Withdrawal(
        bytes32 indexed nullifierHash,
        address indexed recipient,
        uint256 denomination,
        uint256 fee,
        uint256 timestamp
    );

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

    // ─────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────
    constructor(
        address _token,
        address _verifier,
        address _treasury,
        address _owner
    ) Ownable(_owner) {
        if (_token    == address(0)) revert ZeroAddress();
        if (_verifier == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_owner    == address(0)) revert ZeroAddress();

        _reentrancyStatus = _NOT_ENTERED;

        token    = IERC20(_token);
        verifier = IHonkVerifier(_verifier);
        treasury = _treasury;

        _recordRoot();
    }

    // ─────────────────────────────────────────────────────────
    // DEPOSIT
    // ─────────────────────────────────────────────────────────
    /**
     * @notice Deposit tokens into the shielded vault.
     * @param commitment  Poseidon2([secret, nullifier, denomination, 0])[0]
     *                    computed off-chain by the SDK.
     * @param denomination Fixed amount: SMALL / MEDIUM / LARGE.
     */
    function deposit(
        bytes32 commitment,
        uint256 denomination
    ) external nonReentrant {
        if (depositsPaused) revert DepositsArePaused();

        if (
            denomination != DENOM_SMALL  &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE
        ) revert InvalidDenomination();

        if (_tree._has(uint256(commitment))) revert CommitmentAlreadyExists();

        // Checks-Effects-Interactions
        token.safeTransferFrom(msg.sender, address(this), denomination);

        uint256 leafIndex = _tree.size;
        _tree._insert(uint256(commitment));
        _recordRoot();

        emit Deposit(commitment, leafIndex, denomination, block.timestamp);
    }

    // ─────────────────────────────────────────────────────────
    // WITHDRAW
    // ─────────────────────────────────────────────────────────
    /**
     * @notice Withdraw tokens to a fresh address using a ZK proof.
     *
     * @dev Public inputs layout (matches Noir circuit declaration order):
     *      Index 0: nullifier_hash
     *      Index 1: root
     *      Index 2: recipient  (address cast to bytes32)
     *      Index 3: denomination
     *      Index 4..11: UltraHonk protocol inputs (zero-filled by SDK)
     *
     * @param nullifierHash  Poseidon2([nullifier, secret, 0, 0])[0]
     * @param root           Known historical Merkle root.
     * @param recipient      Fresh wallet to receive funds.
     * @param denomination   Amount to withdraw.
     * @param proof          UltraHonk proof bytes from Noir SDK.
     */
    function withdraw(
        bytes32 nullifierHash,
        bytes32 root,
        address recipient,
        uint256 denomination,
        bytes calldata proof
    ) external nonReentrant {
        if (recipient == address(0))    revert ZeroAddress();
        if (!knownRoots[root])          revert InvalidRoot();
        if (nullifierSpent[nullifierHash]) revert NullifierAlreadySpent();

        if (
            denomination != DENOM_SMALL  &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE
        ) revert InvalidDenomination();

        // Build public inputs array for the verifier
        // Must match the order declared in main.nr `pub` params
        bytes32[] memory publicInputs = new bytes32[](PUBLIC_INPUTS_COUNT);
        publicInputs[0] = nullifierHash;
        publicInputs[1] = root;
        publicInputs[2] = bytes32(uint256(uint160(recipient)));
        publicInputs[3] = bytes32(denomination);
        // indices 4..11 remain bytes32(0) — UltraHonk protocol inputs

        if (!verifier.verify(proof, publicInputs)) revert InvalidProof();

        // Burn nullifier BEFORE transfer — reentrancy protection
        nullifierSpent[nullifierHash] = true;

        uint256 fee             = (denomination * FEE_BPS) / BPS_DENOM;
        uint256 recipientAmount = denomination - fee;

        if (fee > 0) token.safeTransfer(treasury, fee);
        token.safeTransfer(recipient, recipientAmount);

        emit Withdrawal(nullifierHash, recipient, denomination, fee, block.timestamp);
    }

    // ─────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────
    function currentRoot() external view returns (bytes32) {
        return bytes32(_tree._root());
    }

    function totalDeposits() external view returns (uint256) {
        return _tree.size;
    }

    function commitmentExists(bytes32 commitment) external view returns (bool) {
        return _tree._has(uint256(commitment));
    }

    function isSpent(bytes32 nullifierHash) external view returns (bool) {
        return nullifierSpent[nullifierHash];
    }

    function isKnownRoot(bytes32 root) external view returns (bool) {
        return knownRoots[root];
    }

    // ─────────────────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────────────────
    function pauseDeposits() external onlyOwner {
        depositsPaused = true;
    }

    function unpauseDeposits() external onlyOwner {
        depositsPaused = false;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    // ─────────────────────────────────────────────────────────
    // INTERNAL
    // ─────────────────────────────────────────────────────────
    function _recordRoot() internal {
        bytes32 root = bytes32(_tree._root());
        knownRoots[root] = true;
        emit RootAdded(root);
    }
}
