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

    uint256 constant DENOM = 100 * 1e6;

    // ── Setup ─────────────────────────────────────────────────────────────────
    function setUp() public {
        token    = new MockERC20("USDC", "USDC", 6);
        verifier = new MockVerifier();
        
        address feeManager = address(0); 
        uint256 depositCap = 1_000_000 * 1e6;
        vault    = new ERC20VeilCore(address(verifier), address(token), feeManager, DENOM, depositCap);

        // Fund actors
        token.mint(alice,  1000 * DENOM);
        token.mint(bob,    1000 * DENOM);
        token.mint(solver, 1000 * DENOM);

        // Approvals
        vm.prank(alice);  token.approve(address(vault), type(uint256).max);
        vm.prank(bob);    token.approve(address(vault), type(uint256).max);
        vm.prank(solver); token.approve(address(vault), type(uint256).max);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _c(uint256 seed) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encodePacked(seed))) % (SNARK_FIELD - 1) + 1);
    }

    function _deposit(address who, bytes32 commitment) internal {
        vm.prank(who);
        vault.deposit(commitment);
    }

    function _withdraw(
        address caller,
        bytes32 nullifier,
        address recipient,
        address relayer,
        uint256 fee
    ) internal {
        bytes32 root = vault.getRoot();
        vm.prank(caller);
        vault.withdraw(bytes("proof"), root, nullifier, recipient, relayer, fee, address(token));
    }

    // ── Deposit tests ─────────────────────────────────────────────────────────

    function test_DepositRecordsCommitment() public {
        bytes32 c = _c(1);
        _deposit(alice, c);
        assertTrue(vault.commitments(c));
    }

    function test_DepositTransfersExactDenomination() public {
        uint256 before = token.balanceOf(address(vault));
        _deposit(alice, _c(1));
        assertEq(token.balanceOf(address(vault)), before + DENOM);
    }

    function test_RootChangesAfterDeposit() public {
        bytes32 before = vault.getRoot();
        _deposit(alice, _c(1));
        assertTrue(vault.getRoot() != before);
    }

    function test_DuplicateCommitmentReverts() public {
        bytes32 c = _c(42);
        _deposit(alice, c);
        vm.prank(alice);
        vm.expectRevert(VeilCore.CommitmentAlreadyExists.selector);
        vault.deposit(c);
    }

    function test_CommitmentOutOfFieldReverts() public {
        vm.prank(alice);
        vm.expectRevert(VeilCore.CommitmentOutOfField.selector);
        vault.deposit(bytes32(SNARK_FIELD)); 
    }

    // ── Withdraw tests ────────────────────────────────────────────────────────

    function test_WithdrawReleasesFundsNoFee() public {
        _deposit(alice, _c(1));

        uint256 bobBefore = token.balanceOf(bob);
        _withdraw(bob, keccak256("n1"), bob, address(0), 0);

        assertEq(token.balanceOf(bob), bobBefore + DENOM);
    }

    function test_WithdrawRelayerReceivesFee() public {
        _deposit(alice, _c(1));

        uint256 fee = 1_000; 
        uint256 solverBefore = token.balanceOf(solver);
        uint256 bobBefore    = token.balanceOf(bob);

        bytes32 root = vault.getRoot();
        vm.prank(solver);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), bob, solver, fee, address(token));

        assertEq(token.balanceOf(solver), solverBefore + fee);
        assertEq(token.balanceOf(bob),    bobBefore + DENOM - fee);
    }

    function test_DoubleWithdrawReverts() public {
        _deposit(alice, _c(1));
        _withdraw(bob, keccak256("n1"), bob, address(0), 0);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(VeilCore.NullifierAlreadySpent.selector);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), bob, address(0), 0, address(token));
    }

    function test_InvalidRootReverts() public {
        _deposit(alice, _c(1));

        vm.prank(bob);
        vm.expectRevert(VeilCore.InvalidRoot.selector);
        vault.withdraw(bytes("proof"), bytes32(uint256(0xdead)), keccak256("n1"), bob, address(0), 0, address(token));
    }

    function test_FeeTooHighReverts() public {
        _deposit(alice, _c(1));

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(VeilCore.FeeTooHigh.selector);
        vault.withdraw(bytes("proof"), root, keccak256("n1"), bob, address(0), DENOM, address(token)); 
    }

    // ── Solvency invariant ────────────────────────────────────────────────────

    function test_VaultSolvencyAfterWithdraw() public {
        _deposit(alice, _c(1));
        assertEq(token.balanceOf(address(vault)), DENOM);

        _withdraw(bob, keccak256("n1"), bob, address(0), 0);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    // ── Fuzz tests ────────────────────────────────────────────────────────────

    function testFuzz_DepositWithdrawSolvency(uint8 depositCount) public {
        depositCount = uint8(bound(depositCount, 1, 20));

        uint256 totalDeposited = 0;
        for (uint256 i = 0; i < depositCount; i++) {
            _deposit(alice, _c(i + 1000));
            totalDeposited += DENOM;
        }
        assertEq(token.balanceOf(address(vault)), totalDeposited);

        uint256 bobBefore = token.balanceOf(bob);
        for (uint256 i = 0; i < depositCount; i++) {
            _withdraw(bob, keccak256(abi.encodePacked("nf", i)), bob, address(0), 0);
        }

        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(bob), bobBefore + totalDeposited);
    }
}
