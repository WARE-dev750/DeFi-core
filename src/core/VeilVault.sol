// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleTreeWithHistory} from "./MerkleTreeWithHistory.sol";

interface IHonkVerifier {
    function verify(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns (bool);
}

contract VeilVault is MerkleTreeWithHistory, ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;

    uint256 public constant DENOM_SMALL  = 100   * 1e6;
    uint256 public constant DENOM_MEDIUM = 1_000 * 1e6;
    uint256 public constant DENOM_LARGE  = 10_000 * 1e6;

    uint256 public constant ENTRY_FEE_BPS = 20;
    uint256 public constant EXIT_FEE_BPS = 10;

    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    IERC20  public immutable token;
    address public immutable verifier;

    uint256 public accumulatedEntryFees;
    uint256 public accumulatedExitFees;

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
    error FeeTooHigh();
    error ArrayLengthMismatch();
    error EmptyBatch();

    struct BatchWithdrawArgs {
        bytes32[] nullifierHashes;
        bytes32[] roots;
        address[] recipients;
        uint256[] denominations;
        address[] relayers;
        uint256[] fees;
    }

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

        uint256 entryFee = (denomination * ENTRY_FEE_BPS) / 10_000;
        
        commitmentExists[commitment] = true;
        token.safeTransferFrom(msg.sender, address(this), denomination + entryFee);
        accumulatedEntryFees += entryFee;
        
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


        uint256 protocolFee = (denomination * EXIT_FEE_BPS) / 10_000;
        if (fee + protocolFee > denomination) revert FeeTooHigh();

        bytes32[] memory publicInputs = new bytes32[](6);
        publicInputs[0] = nullifierHash;
        publicInputs[1] = root;
        publicInputs[2] = bytes32(uint256(uint160(recipient)));
        publicInputs[3] = bytes32(denomination);
        publicInputs[4] = bytes32(uint256(uint160(relayer)));
        publicInputs[5] = bytes32(fee);

        bool ok;
        try IHonkVerifier(verifier).verify(proof, publicInputs) returns (bool result) {
            ok = result;
        } catch {
            revert ProofVerificationFailed();
        }
        if (!ok) revert ProofVerificationFailed();

        nullifierSpent[nullifierHash] = true;

        uint256 payout = denomination - protocolFee - fee;
        accumulatedExitFees += protocolFee;

        if (fee > 0) {
            address feeRecipient = relayer != address(0) ? relayer : msg.sender;
            token.safeTransfer(feeRecipient, fee);
        }

        token.safeTransfer(recipient, payout);
        emit Withdrawal(recipient, nullifierHash, payout);
    }

    function batchWithdraw(
        bytes[] calldata proofs,
        BatchWithdrawArgs calldata args
    ) external nonReentrant {
        uint256 length = args.nullifierHashes.length;
        if (
            proofs.length != length ||
            args.roots.length != length ||
            args.recipients.length != length ||
            args.denominations.length != length ||
            args.relayers.length != length ||
            args.fees.length != length
        ) revert ArrayLengthMismatch();
        if (length == 0) revert EmptyBatch();

        uint256 totalProtocolFee = 0;

        for (uint256 i = 0; i < length; i++) {
            if (!isKnownRoot(uint256(args.roots[i]))) revert InvalidRoot();
            if (nullifierSpent[args.nullifierHashes[i]]) revert NullifierAlreadySpent();
            if (args.denominations[i] != DENOM_SMALL &&
                args.denominations[i] != DENOM_MEDIUM &&
                args.denominations[i] != DENOM_LARGE) revert InvalidDenomination();

            uint256 protocolFee = (args.denominations[i] * EXIT_FEE_BPS) / 10_000;
            if (args.fees[i] + protocolFee > args.denominations[i]) revert FeeTooHigh();

            bytes32[] memory publicInputs = new bytes32[](6);
            publicInputs[0] = args.nullifierHashes[i];
            publicInputs[1] = args.roots[i];
            publicInputs[2] = bytes32(uint256(uint160(args.recipients[i])));
            publicInputs[3] = bytes32(args.denominations[i]);
            publicInputs[4] = bytes32(uint256(uint160(args.relayers[i])));
            publicInputs[5] = bytes32(args.fees[i]);

            bool ok;
            try IHonkVerifier(verifier).verify(proofs[i], publicInputs) returns (bool result) {
                ok = result;
            } catch {
                revert ProofVerificationFailed();
            }
            if (!ok) revert ProofVerificationFailed();

            nullifierSpent[args.nullifierHashes[i]] = true;
            totalProtocolFee += protocolFee;
            uint256 payout = args.denominations[i] - protocolFee - args.fees[i];

            if (args.fees[i] > 0) {
                address feeRecipient = args.relayers[i] != address(0) ? args.relayers[i] : msg.sender;
                token.safeTransfer(feeRecipient, args.fees[i]);
            }

            token.safeTransfer(args.recipients[i], payout);
            emit Withdrawal(args.recipients[i], args.nullifierHashes[i], payout);
        }

        accumulatedExitFees += totalProtocolFee;
    }

    function claimFees() external onlyOwner {
        uint256 exitAmount = accumulatedExitFees;
        accumulatedExitFees = 0;
        token.safeTransfer(owner(), exitAmount);
    }

    // Phase 3: Route entry fees to Burn and Stakers
    function distributeEntryFees() external {
        uint256 entryAmount = accumulatedEntryFees;
        accumulatedEntryFees = 0;
        // Temporary: simply send to owner until DEX router logic is implemented
        token.safeTransfer(owner(), entryAmount);
    }

    function getRoot() external view returns (bytes32) {
        return bytes32(getLastRoot());
    }

    function getLeafCount() external view returns (uint256) {
        return nextIndex;
    }
}
