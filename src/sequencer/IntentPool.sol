// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title IntentPool
/// @notice Stores signed withdrawal intents for solver discovery and claiming.
/// @dev Intent execution remains in solver infrastructure (BatchManager/VeilVault).
contract IntentPool is EIP712, ReentrancyGuard {
    bytes32 internal constant WITHDRAWAL_INTENT_TYPEHASH =
        keccak256(
            "WithdrawalIntent(address user,bytes32 nullifierHash,bytes32 root,address recipient,uint256 denomination,address relayer,uint256 fee,bytes32 proofHash,uint256 nonce,uint64 deadline)"
        );

    enum IntentStatus {
        None,
        Open,
        Claimed,
        Cancelled
    }

    struct WithdrawalIntent {
        address user;
        bytes32 nullifierHash;
        bytes32 root;
        address recipient;
        uint256 denomination;
        address relayer;
        uint256 fee;
        bytes32 proofHash;
        uint256 nonce;
        uint64 deadline;
    }

    struct IntentRecord {
        address user;
        address relayer;
        address claimer;
        uint64 deadline;
        IntentStatus status;
    }

    mapping(bytes32 => IntentRecord) public intents;
    mapping(address => uint256) public nonces;

    event WithdrawalIntentOpened(bytes32 indexed intentId, address indexed user, address indexed relayer, uint64 deadline);
    event WithdrawalIntentClaimed(bytes32 indexed intentId, address indexed solver);
    event WithdrawalIntentCancelled(bytes32 indexed intentId, address indexed user);

    error InvalidSigner();
    error InvalidDeadline();
    error InvalidNonce();
    error IntentAlreadyExists();
    error IntentNotOpen();
    error IntentExpired();
    error UnauthorizedSolver();
    error UnauthorizedUser();

    constructor() EIP712("VeilFi IntentPool", "1") {}

    function submitWithdrawalIntent(WithdrawalIntent calldata intent, bytes calldata signature)
        external
        nonReentrant
        returns (bytes32 intentKey)
    {
        if (intent.deadline < block.timestamp) revert InvalidDeadline();

        uint256 expectedNonce = nonces[intent.user];
        if (intent.nonce != expectedNonce) revert InvalidNonce();

        bytes32 digest = _hashTypedDataV4(_intentStructHash(intent));
        address signer = ECDSA.recover(digest, signature);
        if (signer != intent.user) revert InvalidSigner();

        intentKey = _intentKey(intent);
        if (intents[intentKey].status != IntentStatus.None) revert IntentAlreadyExists();

        nonces[intent.user] = expectedNonce + 1;
        intents[intentKey] = IntentRecord({
            user: intent.user,
            relayer: intent.relayer,
            claimer: address(0),
            deadline: intent.deadline,
            status: IntentStatus.Open
        });

        emit WithdrawalIntentOpened(intentKey, intent.user, intent.relayer, intent.deadline);
    }

    function claimIntent(bytes32 intentKey) external nonReentrant {
        IntentRecord storage record = intents[intentKey];
        if (record.status != IntentStatus.Open) revert IntentNotOpen();
        if (record.deadline < block.timestamp) revert IntentExpired();
        if (record.relayer != address(0) && record.relayer != msg.sender) revert UnauthorizedSolver();

        record.status = IntentStatus.Claimed;
        record.claimer = msg.sender;

        emit WithdrawalIntentClaimed(intentKey, msg.sender);
    }

    function cancelIntent(bytes32 intentKey) external nonReentrant {
        IntentRecord storage record = intents[intentKey];
        if (record.status != IntentStatus.Open) revert IntentNotOpen();
        if (record.user != msg.sender) revert UnauthorizedUser();

        record.status = IntentStatus.Cancelled;
        emit WithdrawalIntentCancelled(intentKey, msg.sender);
    }

    function intentKey(WithdrawalIntent calldata intent) external pure returns (bytes32) {
        return _intentKey(intent);
    }

    function _intentKey(WithdrawalIntent calldata intent) internal pure returns (bytes32) {
        return keccak256(abi.encode(_intentStructHash(intent)));
    }

    function _intentStructHash(WithdrawalIntent calldata intent) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                WITHDRAWAL_INTENT_TYPEHASH,
                intent.user,
                intent.nullifierHash,
                intent.root,
                intent.recipient,
                intent.denomination,
                intent.relayer,
                intent.fee,
                intent.proofHash,
                intent.nonce,
                intent.deadline
            )
        );
    }
}

