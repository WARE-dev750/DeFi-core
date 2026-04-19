// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// Fork: OpenZeppelin ReentrancyGuard — audited, no custom primitives.
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleTreeWithHistory} from "./MerkleTreeWithHistory.sol";

interface IHonkVerifier {
    function verify(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns (bool);
}

// NofaceVault — core privacy vault.
// Architectural pattern: identical to Tornado Cash ETHTornado.sol.
// Forked primitives: MerkleTreeWithHistory (Tornado Cash), SafeERC20 + Ownable +
// ReentrancyGuard (OpenZeppelin), HonkVerifier (Aztec/Barretenberg generated).
// Custom glue: deposit/withdraw business logic, solver fee routing, protocol fee accumulation.
contract NofaceVault is MerkleTreeWithHistory, ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;

    // Fixed denominations — variable amounts leak depositor identity.
    uint256 public constant DENOM_SMALL  = 100   * 1e6; // 100  USDC
    uint256 public constant DENOM_MEDIUM = 1_000 * 1e6; // 1000 USDC
    uint256 public constant DENOM_LARGE  = 10_000 * 1e6; // 10000 USDC

    // 30 bps = 0.3% protocol fee.
    uint256 public constant FEE_BPS = 30;

    // BN254 scalar field upper bound. Commitments must be valid field elements.
    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    IERC20  public immutable token;
    address public immutable verifier;

    // Protocol fees accumulate here. Owner pulls on their own schedule.
    // Pull pattern prevents DoS if owner address is token-blacklisted.
    // TODO Phase 3: replace claimFees with permissionless FeeDistributor.sol
    // that routes to staking pool, buyback-burn, and DAO treasury automatically.
    uint256 public accumulatedFees;

    mapping(bytes32 => bool) public commitmentExists;
    mapping(bytes32 => bool) public nullifierSpent;

    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 denomination);
    event Withdrawal(address indexed recipient, bytes32 nullifierHash, uint256 amount);

    error InvalidDenomination();
    error CommitmentAlreadyExists();
    error CommitmentOutOfField();
    error InvalidRoot();
    error NullifierAlreadySpent();
    error ProofVerificationFailed();
    error UnauthorizedRelayer();
    error FeeTooHigh();

    // Tree depth 20 = 2^20 = 1,048,576 max deposits. Matches Tornado Cash.
    constructor(address _token, address _verifier)
        MerkleTreeWithHistory(20)
        Ownable(msg.sender)
    {
        token    = IERC20(_token);
        verifier = _verifier;
    }

    function deposit(bytes32 commitment, uint256 denomination) external nonReentrant {
        if (denomination != DENOM_SMALL &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE)   revert InvalidDenomination();
        if (uint256(commitment) >= SNARK_SCALAR_FIELD) revert CommitmentOutOfField();
        if (commitmentExists[commitment])              revert CommitmentAlreadyExists();

        commitmentExists[commitment] = true;
        token.safeTransferFrom(msg.sender, address(this), denomination);
        uint32 leafIndex = _insert(uint256(commitment));
        emit Deposit(commitment, leafIndex, denomination);
    }

    function withdraw(
        bytes calldata proof,
        bytes32 nullifierHash,
        bytes32 root,
        address recipient,
        uint256 denomination,
        address relayer,
        uint256 fee
    ) external nonReentrant {
        if (!isKnownRoot(uint256(root)))   revert InvalidRoot();
        if (nullifierSpent[nullifierHash]) revert NullifierAlreadySpent();
        if (denomination != DENOM_SMALL &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE)   revert InvalidDenomination();

        // Relayer exclusivity:
        // - relayer == address(0): permissionless, msg.sender gets the fee.
        // - relayer != address(0): only that exact address may submit.
        //   When BatchManager calls this, user sets relayer = BatchManager address.
        //   msg.sender == BatchManager == relayer. Passes without any whitelist.
        if (relayer != address(0) && msg.sender != relayer) revert UnauthorizedRelayer();

        // Guard against fee + protocolFee consuming entire denomination.
        uint256 protocolFee = (denomination * FEE_BPS) / 10_000;
        if (fee + protocolFee > denomination) revert FeeTooHigh();

        // Public inputs — order must match circuit main.nr exactly:
        // nullifier_hash, root, recipient, denomination, relayer, fee
        bytes32[] memory publicInputs = new bytes32[](6);
        publicInputs[0] = nullifierHash;
        publicInputs[1] = root;
        publicInputs[2] = bytes32(uint256(uint160(recipient)));
        publicInputs[3] = bytes32(denomination);
        publicInputs[4] = bytes32(uint256(uint160(relayer)));
        publicInputs[5] = bytes32(fee);

        // HonkVerifier reverts on invalid proof internally.
        // try/catch ensures vault surfaces its own clean error in all cases.
        bool ok;
        try IHonkVerifier(verifier).verify(proof, publicInputs) returns (bool result) {
            ok = result;
        } catch {
            revert ProofVerificationFailed();
        }
        if (!ok) revert ProofVerificationFailed();

        // CEI: mark nullifier spent before any external calls.
        nullifierSpent[nullifierHash] = true;

        uint256 payout = denomination - protocolFee - fee;
        accumulatedFees += protocolFee;

        // FIX (Flaw 3): if relayer is address(0), fee goes to msg.sender —
        // the actual solver who paid gas. Fee is never trapped.
        if (fee > 0) {
            address feeRecipient = relayer != address(0) ? relayer : msg.sender;
            token.safeTransfer(feeRecipient, fee);
        }

        token.safeTransfer(recipient, payout);
        emit Withdrawal(recipient, nullifierHash, payout);
    }

    // Owner pulls accumulated protocol fees.
    // Phase 3: this becomes a permissionless FeeDistributor.sol call.
    function claimFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        token.safeTransfer(owner(), amount);
    }

    function getRoot() external view returns (bytes32) {
        return bytes32(getLastRoot());
    }

    function getLeafCount() external view returns (uint256) {
        return nextIndex;
    }
}
