// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20VeilCore} from "src/core/ERC20VeilCore.sol";
import {VeilCore} from "src/core/VeilCore.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// ── MockVerifier ──────────────────────────────────────────────────────────────
// Accepts any proof with length > 0. Used exclusively for vault-logic tests.
// ZK correctness is tested separately in HonkVerifier.t.sol with a real proof.
// This mirrors the tornado-core test pattern of mocking the verifier.
contract MockVerifier {
    function verify(bytes calldata proof, bytes32[] calldata) external pure returns (bool) {
        return proof.length > 0;
    }
}

contract ERC20VeilCoreTest is Test {

    ERC20VeilCore vault;
    MockERC20      token;
    MockVerifier   verifier;

    address alice  = address(0xA11CE);
    address bob    = address(0xB0B);
    address solver = address(0x50100);

    uint256 constant SNARK_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 SMALL;
    uint256 MEDIUM;
    uint256 LARGE;

    // ── Setup ─────────────────────────────────────────────────────────────────
    function setUp() public {
        token    = new MockERC20("USDC", "USDC", 6);
        verifier = new MockVerifier();
        vault    = new ERC20VeilCore(address(verifier), address(token));

        SMALL  = vault.DENOM_SMALL();
        MEDIUM = vault.DENOM_MEDIUM();
        LARGE  = vault.DENOM_LARGE();

        // Fund actors
        token.mint(alice,  100 * LARGE);
        token.mint(bob,    100 * LARGE);
        token.mint(solver, 100 * LARGE);

        // Approvals
        vm.prank(alice);  token.approve(address(vault), type(uint256).max);
        vm.prank(bob);    token.approve(address(vault), type(uint256).max);
        vm.prank(solver); token.approve(address(vault), type(uint256).max);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _c(uint256 seed) internal pure returns (bytes32) {
        // Must be < SNARK_FIELD. Simple: hash and mask to field.
        return bytes32(uint256(keccak256(abi.encodePacked(seed))) % (SNARK_FIELD - 1) + 1);
    }

    function _deposit(address who, bytes32 commitment, uint256 denom) internal {
        vm.prank(who);
        vault.deposit(commitment, denom);
    }

    function _withdraw(
        address caller,
        bytes32 nullifier,
        address recipient,
        uint256 denom,
        address relayer,
        uint256 fee
    ) internal {
        bytes32 root = vault.getRoot();
        vm.prank(caller);
        vault.withdraw(bytes("proof"), root, nullifier, recipient, denom, relayer, fee);
    }

    // ── Deposit tests ─────────────────────────────────────────────────────────

    function test_DepositRecordsCommitment() public {
        bytes32 c = _c(1);
        _deposit(alice, c, SMALL);
        assertTrue(vault.commitments(c));
    }

    function test_DepositTransfersExactDenomination() public {
        uint256 before = token.balanceOf(address(vault));
        _deposit(alice, _c(1), SMALL);
        // No fees: vault receives exactly denomination
        assertEq(token.balanceOf(address(vault)), before + SMALL);
    }

    function test_RootChangesAfterDeposit() public {
        bytes32 before = vault.getRoot();
        _deposit(alice, _c(1), SMALL);
        assertTrue(vault.getRoot() != before);
    }

    function test_InvalidDenominationReverts() public {
        vm.prank(alice);
        vm.expectRevert(VeilCore.InvalidDenomination.selector);
        vault.deposit(_c(1), 999 * 1e6);
    }

    function test_DuplicateCommitmentReverts() public {
        bytes32 c = _c(42);
        _deposit(alice, c, SMALL);
        vm.prank(alice);
        vm.expectRevert(VeilCore.CommitmentAlreadyExists.selector);
        vault.deposit(c, SMALL);
    }

    function test_CommitmentOutOfFieldReverts() public {
        vm.prank(alice);
        vm.expectRevert(VeilCore.CommitmentOutOfField.selector);
        vault.deposit(bytes32(SNARK_FIELD), SMALL); // boundary — invalid
    }

    // ── Withdraw tests ────────────────────────────────────────────────────────

    function test_WithdrawReleasesFundsNoFee() public {
        _deposit(alice, _c(1), SMALL);

        uint256 bobBefore = token.balanceOf(bob);
        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        // No protocol fee — bob receives full denomination
        assertEq(token.balanceOf(bob), bobBefore + SMALL);
    }

    function test_WithdrawRelayerReceivesFee() public {
        _deposit(alice, _c(1), SMALL);

        uint256 fee = 1_000; // 0.001 USDC
        uint256 solverBefore = token.balanceOf(solver);
        uint256 bobBefore    = token.balanceOf(bob);

        bytes32 root = vault.getRoot();
        vm.prank(solver);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), bob, SMALL, solver, fee);

        assertEq(token.balanceOf(solver), solverBefore + fee);
        assertEq(token.balanceOf(bob),    bobBefore + SMALL - fee);
    }

    function test_PermissionlessSelfRelayFee() public {
        // relayer == address(0): msg.sender gets the fee
        _deposit(alice, _c(1), SMALL);

        uint256 fee = 500;
        uint256 solverBefore = token.balanceOf(solver);

        bytes32 root = vault.getRoot();
        vm.prank(solver);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), bob, SMALL, address(0), fee);

        assertEq(token.balanceOf(solver), solverBefore + fee);
    }

    function test_DoubleWithdrawReverts() public {
        _deposit(alice, _c(1), SMALL);
        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(VeilCore.NullifierAlreadySpent.selector);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), bob, SMALL, address(0), 0);
    }

    function test_InvalidRootReverts() public {
        _deposit(alice, _c(1), SMALL);

        vm.prank(bob);
        vm.expectRevert(VeilCore.InvalidRoot.selector);
        vault.withdraw(bytes("proof"), bytes32(uint256(0xdead)), keccak256("n1"), bob, SMALL, address(0), 0);
    }

    function test_FeeTooHighReverts() public {
        _deposit(alice, _c(1), SMALL);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(VeilCore.FeeTooHigh.selector);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), bob, SMALL, address(0), SMALL); // fee == denom
    }

    function test_ZeroRecipientReverts() public {
        _deposit(alice, _c(1), SMALL);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(VeilCore.ZeroRecipient.selector);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), address(0), SMALL, address(0), 0);
    }

    function test_EmptyProofReverts() public {
        _deposit(alice, _c(1), SMALL);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(VeilCore.ProofVerificationFailed.selector);
        vault.withdraw(bytes(""), root, keccak256("n1"), bob, SMALL, address(0), 0);
    }

    // ── Solvency invariant ────────────────────────────────────────────────────

    function test_VaultSolvencyAfterWithdraw() public {
        _deposit(alice, _c(1), SMALL);
        assertEq(token.balanceOf(address(vault)), SMALL);

        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);
        // No protocol fee — vault is empty after withdrawal (no locked fees)
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_MultipleDepositsAndWithdraws() public {
        _deposit(alice, _c(1), SMALL);
        _deposit(alice, _c(2), MEDIUM);
        _deposit(alice, _c(3), LARGE);

        assertEq(token.balanceOf(address(vault)), SMALL + MEDIUM + LARGE);

        _withdraw(bob, keccak256("n1"), bob, SMALL,  address(0), 0);
        _withdraw(bob, keccak256("n2"), bob, MEDIUM, address(0), 0);
        _withdraw(bob, keccak256("n3"), bob, LARGE,  address(0), 0);

        assertEq(token.balanceOf(address(vault)), 0);
    }

    // ── Fuzz tests ────────────────────────────────────────────────────────────

    function testFuzz_DepositWithdrawSolvency(uint8 depositCount) public {
        depositCount = uint8(bound(depositCount, 1, 20));

        uint256 totalDeposited = 0;
        for (uint256 i = 0; i < depositCount; i++) {
            _deposit(alice, _c(i + 1000), SMALL);
            totalDeposited += SMALL;
        }
        assertEq(token.balanceOf(address(vault)), totalDeposited);

        uint256 bobBefore = token.balanceOf(bob);
        for (uint256 i = 0; i < depositCount; i++) {
            _withdraw(bob, keccak256(abi.encodePacked("nf", i)), bob, SMALL, address(0), 0);
        }

        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(bob), bobBefore + totalDeposited);
    }

    function testFuzz_FeeNeverExceedsDenomination(uint256 fee) public {
        fee = bound(fee, 0, SMALL - 1); // valid range: [0, denom)

        _deposit(alice, _c(99), SMALL);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        // Must NOT revert — any fee < denomination is valid
        vault.withdraw(bytes("proof"), root, keccak256("nfuzz"), bob, SMALL, address(0), fee);
    }

    function testFuzz_DoubleSpendPrevented(uint256 seed) public {
        seed = bound(seed, 1, type(uint128).max);
        bytes32 c = _c(seed);
        bytes32 n = keccak256(abi.encodePacked("null", seed));

        _deposit(alice, c, SMALL);
        _withdraw(bob, n, bob, SMALL, address(0), 0);

        bytes32 root = vault.getRoot();
        vm.expectRevert(VeilCore.NullifierAlreadySpent.selector);
        vm.prank(bob);
        vault.withdraw(bytes("proof"), root, n, bob, SMALL, address(0), 0);
    }
}
