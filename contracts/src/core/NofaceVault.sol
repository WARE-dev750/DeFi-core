// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Poseidon2IMT} from "./Poseidon2IMT.sol";

interface IHonkVerifier {
    function verify(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns (bool);
}

contract NofaceVault is Ownable {
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
    using Poseidon2IMT for Poseidon2IMT.IMTData;

    uint256 public constant DENOM_SMALL  = 100   * 1e6;
    uint256 public constant DENOM_MEDIUM = 1_000 * 1e6;
    uint256 public constant DENOM_LARGE  = 10_000 * 1e6;
    uint256 public constant FEE_BPS      = 30;
    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    IERC20  public immutable token;
    address public immutable verifier;

    Poseidon2IMT.IMTData private _tree;
    mapping(bytes32 => bool) public commitmentExists;
    mapping(bytes32 => bool) public nullifierSpent;

    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 denomination);
    event Withdrawal(address indexed recipient, bytes32 nullifierHash, uint256 amount);
    event RootAdded(bytes32 indexed root);

    error InvalidDenomination();
    error CommitmentAlreadyExists();
    error CommitmentOutOfField();
    error InvalidRoot();
    error NullifierAlreadySpent();
    error ProofVerificationFailed();

    constructor(address _token, address _verifier) Ownable(msg.sender) {
        token    = IERC20(_token);
        verifier = _verifier;
        _reentrancyStatus = _NOT_ENTERED;
        _tree._init();
    }

    function deposit(bytes32 commitment, uint256 denomination) external nonReentrant {
        if (denomination != DENOM_SMALL &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE) revert InvalidDenomination();
        if (uint256(commitment) >= SNARK_SCALAR_FIELD) revert CommitmentOutOfField();
        if (commitmentExists[commitment])              revert CommitmentAlreadyExists();

        commitmentExists[commitment] = true;
        token.safeTransferFrom(msg.sender, address(this), denomination);

        uint256 leafIndex = _tree._insert(uint256(commitment));
        bytes32 root = bytes32(_tree._root());
        emit RootAdded(root);
        emit Deposit(commitment, leafIndex, denomination);
    }

    function withdraw(
        bytes calldata proof,
        bytes32 nullifierHash,
        bytes32 root,
        address recipient,
        uint256 denomination
    ) external nonReentrant {
        if (!_tree._isKnownRoot(uint256(root))) revert InvalidRoot();
        if (nullifierSpent[nullifierHash])       revert NullifierAlreadySpent();
        if (denomination != DENOM_SMALL &&
            denomination != DENOM_MEDIUM &&
            denomination != DENOM_LARGE) revert InvalidDenomination();

        bytes32[] memory publicInputs = new bytes32[](4);
        publicInputs[0] = nullifierHash;
        publicInputs[1] = root;
        publicInputs[2] = bytes32(uint256(uint160(recipient)));
        publicInputs[3] = bytes32(denomination);

        if (!IHonkVerifier(verifier).verify(proof, publicInputs))
            revert ProofVerificationFailed();

        nullifierSpent[nullifierHash] = true;

        uint256 fee    = (denomination * FEE_BPS) / 10_000;
        uint256 payout = denomination - fee;

        token.safeTransfer(recipient, payout);
        if (fee > 0) token.safeTransfer(owner(), fee);

        emit Withdrawal(recipient, nullifierHash, payout);
    }

    function getRoot() external view returns (bytes32) {
        return bytes32(_tree._root());
    }

    function getLeafCount() external view returns (uint256) {
        return _tree.size;
    }

    function isKnownRoot(bytes32 root) external view returns (bool) {
        return _tree._isKnownRoot(uint256(root));
    }
}
