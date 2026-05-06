// SPDX-License-Identifier: MIT
// Forked from: https://github.com/tornadocash/tornado-core/blob/master/contracts/Tornado.sol
// Maximized for VielFi Protocol (CTO Spec V3)
pragma solidity ^0.8.23;

import {MerkleTreeWithHistory} from "./MerkleTreeWithHistory.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IHonkVerifier {
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external view returns (bool);
}

abstract contract VeilCore is MerkleTreeWithHistory, ReentrancyGuard, Ownable {

    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    IHonkVerifier public immutable verifier;

    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullifierHashes;
    
    // Configurable denominations
    uint256 public immutable denomination;
    
    uint256 public depositCap;
    uint256 public currentTVL;
    uint256 public launchStartTime;
    uint256 public constant GUARDED_PERIOD = 90 days;
    
    bool public paused;
    bool public withdrawPaused;
    address public guardian;
    
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);
    event DepositCapUpdated(uint256 newCap);
    event GuardianUpdated(address newGuardian);
    event EmergencyPause(bool depositsPaused, bool withdrawsPaused);

    error InvalidDenomination();
    error CommitmentAlreadyExists();
    error CommitmentOutOfField();
    error InvalidRoot();
    error NullifierAlreadySpent();
    error ProofVerificationFailed();
    error FeeTooHigh();
    error ZeroRecipient();
    error DepositCapExceeded();
    error Paused();
    error WithdrawPaused();
    error InvalidGuardian();
    error Unauthorized();
    
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }
    
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert WithdrawPaused();
        _;
    }
    
    modifier onlyGuardian() {
        if (msg.sender != guardian && msg.sender != owner()) revert InvalidGuardian();
        _;
    }
    
    modifier checkDepositCap(uint256 amount) {
        if (block.timestamp < launchStartTime + GUARDED_PERIOD) {
            if (currentTVL + amount > depositCap) revert DepositCapExceeded();
        }
        _;
    }

    constructor(address _verifier, uint256 _denomination, uint256 _depositCap) 
        MerkleTreeWithHistory(20) 
        Ownable(msg.sender) 
    {
        verifier = IHonkVerifier(_verifier);
        denomination = _denomination;
        depositCap = _depositCap;
        launchStartTime = block.timestamp;
        guardian = msg.sender;
    }

    function deposit(bytes32 commitment) 
        external 
        nonReentrant 
        whenNotPaused
        checkDepositCap(denomination)
    {
        if (uint256(commitment) >= SNARK_SCALAR_FIELD) revert CommitmentOutOfField();
        if (commitments[commitment]) revert CommitmentAlreadyExists();

        commitments[commitment] = true;
        uint32 leafIndex = _insert(uint256(commitment));
        currentTVL += denomination;
        
        _processDeposit(denomination);
        emit Deposit(commitment, leafIndex, block.timestamp);
    }

    function _processDeposit(uint256 _denomination) internal virtual;

    function withdraw(
        bytes calldata proof,
        bytes32 root,
        bytes32 nullifierHash,
        address recipient,
        address relayer,
        uint256 fee,
        address token
    ) external nonReentrant whenWithdrawNotPaused {
        if (recipient == address(0)) revert ZeroRecipient();
        if (!isKnownRoot(uint256(root))) revert InvalidRoot();
        if (nullifierHashes[nullifierHash]) revert NullifierAlreadySpent();
        if (fee >= denomination) revert FeeTooHigh();

        // Standard App Interface V2 Public Inputs (must match kernel/main.nr)
        // [0] nullifierHash
        // [1] root
        // [2] recipient
        // [3] denomination
        // [4] relayer
        // [5] fee
        // [6] token
        bytes32[] memory publicInputs = new bytes32[](7);
        publicInputs[0] = nullifierHash;
        publicInputs[1] = root;
        publicInputs[2] = bytes32(uint256(uint160(recipient)));
        publicInputs[3] = bytes32(denomination);
        publicInputs[4] = bytes32(uint256(uint160(relayer)));
        publicInputs[5] = bytes32(fee);
        publicInputs[6] = bytes32(uint256(uint160(token)));

        bool ok;
        try verifier.verify(proof, publicInputs) returns (bool result) {
            ok = result;
        } catch {
            revert ProofVerificationFailed();
        }
        if (!ok) revert ProofVerificationFailed();

        nullifierHashes[nullifierHash] = true;
        currentTVL -= denomination;
        
        _processWithdraw(payable(recipient), payable(relayer), denomination, fee);
        emit Withdrawal(recipient, nullifierHash, relayer, fee);
    }

    function _processWithdraw(
        address payable recipient,
        address payable relayer,
        uint256 _denomination,
        uint256 fee
    ) internal virtual;

    function isSpent(bytes32 _nullifierHash) external view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    function getRoot() external view returns (bytes32) {
        return bytes32(getLastRoot());
    }

    function updateDepositCap(uint256 _newCap) external onlyOwner {
        depositCap = _newCap;
        emit DepositCapUpdated(_newCap);
    }
    
    function setGuardian(address _guardian) external onlyOwner {
        if (_guardian == address(0)) revert InvalidGuardian();
        guardian = _guardian;
        emit GuardianUpdated(_guardian);
    }
    
    function pause() external onlyGuardian {
        paused = true;
        withdrawPaused = true;
        emit EmergencyPause(true, true);
    }
    
    function unpause() external onlyOwner {
        paused = false;
        withdrawPaused = false;
        emit EmergencyPause(false, false);
    }
}
