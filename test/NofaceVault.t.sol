// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {NofaceVault} from "src/core/NofaceVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// MockVerifier accepts any non-empty proof — used for vault logic tests only.
// ZK correctness is proven separately in HonkVerifier.t.sol with a real proof.
contract MockVerifier {
    function verify(bytes calldata proof, bytes32[] calldata) external pure returns (bool) {
        return proof.length > 0;
    }
}

contract NofaceVaultTest is Test {

    NofaceVault  vault;
    MockERC20    token;
    MockVerifier verifier;

    address alice   = address(0xA11CE);
    address bob     = address(0xB0B);
    address solver  = address(0x50100);

    uint256 constant SNARK_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 SMALL;
    uint256 MEDIUM;
    uint256 LARGE;

    function setUp() public {
        token    = new MockERC20("USDC", "USDC", 6);
        verifier = new MockVerifier();
        vault    = new NofaceVault(address(token), address(verifier));

        SMALL  = vault.DENOM_SMALL();
        MEDIUM = vault.DENOM_MEDIUM();
        LARGE  = vault.DENOM_LARGE();

        token.mint(alice, 1_000_000 * 1e6);
        token.mint(bob,   1_000_000 * 1e6);

        vm.startPrank(alice);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    // Valid field element commitment
    function _c(uint256 n) internal pure returns (bytes32) {
        return bytes32(n % SNARK_FIELD);
    }

    // ── Deposit tests ─────────────────────────────────────────────────────────

    function test_DepositIncreasesLeafCount() public {
        vm.prank(alice);
        vault.deposit(_c(1), SMALL);
        assertEq(vault.getLeafCount(), 1);
    }

    function test_RootChangesAfterDeposit() public {
        bytes32 before = vault.getRoot();
        vm.prank(alice);
        vault.deposit(_c(1), SMALL);
        assertTrue(vault.getRoot() != before);
    }

    function test_InvalidDenominationReverts() public {
        vm.prank(alice);
        vm.expectRevert(NofaceVault.InvalidDenomination.selector);
        vault.deposit(_c(1), 999 * 1e6);
    }

    function test_DuplicateCommitmentReverts() public {
        bytes32 c = _c(42);
        vm.prank(alice);
        vault.deposit(c, SMALL);
        vm.prank(alice);
        vm.expectRevert(NofaceVault.CommitmentAlreadyExists.selector);
        vault.deposit(c, SMALL);
    }

    function test_CommitmentOutOfFieldReverts() public {
        vm.prank(alice);
        vm.expectRevert(NofaceVault.CommitmentOutOfField.selector);
        vault.deposit(bytes32(SNARK_FIELD), SMALL); // exactly at boundary — invalid
    }

    // ── Withdraw tests ────────────────────────────────────────────────────────

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
        vault.withdraw(
            bytes("proof"),
            nullifier,
            root,
            recipient,
            denom,
            relayer,
            fee
        );
    }

    function test_WithdrawReleasesFunds() public {
        _deposit(alice, _c(1), SMALL);

        uint256 protocolFee = (SMALL * vault.FEE_BPS()) / 10_000;
        uint256 bobBefore   = token.balanceOf(bob);

        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        assertEq(token.balanceOf(bob), bobBefore + SMALL - protocolFee);
    }

    function test_DoubleWithdrawReverts() public {
        _deposit(alice, _c(1), SMALL);
        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(NofaceVault.NullifierAlreadySpent.selector);
        vault.withdraw(bytes("proof"), keccak256("n1"), root, bob, SMALL, address(0), 0);
    }

    function test_InvalidRootReverts() public {
        _deposit(alice, _c(1), SMALL);

        vm.prank(bob);
        vm.expectRevert(NofaceVault.InvalidRoot.selector);
        vault.withdraw(
            bytes("proof"),
            keccak256("n1"),
            bytes32(uint256(0xdead)), // bad root
            bob,
            SMALL,
            address(0),
            0
        );
    }

    function test_UnauthorizedRelayerReverts() public {
        _deposit(alice, _c(1), SMALL);

        bytes32 root = vault.getRoot();
        // proof says relayer=solver, but msg.sender=bob
        vm.prank(bob);
        vm.expectRevert(NofaceVault.UnauthorizedRelayer.selector);
        vault.withdraw(bytes("proof"), keccak256("n1"), root, bob, SMALL, solver, 0);
    }

    function test_SolverReceivesFee() public {
        _deposit(alice, _c(1), SMALL);

        uint256 solverFee     = 1_000; // 0.001 USDC
        uint256 solverBefore  = token.balanceOf(solver);

        // solver calls directly — relayer == msg.sender == solver
        bytes32 root = vault.getRoot();
        vm.prank(solver);
        vault.withdraw(bytes("proof"), keccak256("n1"), root, bob, SMALL, solver, solverFee);

        assertEq(token.balanceOf(solver), solverBefore + solverFee);
    }

    function test_PermissionlessSolverGetsFee() public {
        // relayer=address(0): anyone can submit, msg.sender gets fee
        _deposit(alice, _c(1), SMALL);

        uint256 solverFee    = 500;
        uint256 solverBefore = token.balanceOf(solver);

        bytes32 root = vault.getRoot();
        vm.prank(solver);
        vault.withdraw(bytes("proof"), keccak256("n1"), root, bob, SMALL, address(0), solverFee);

        assertEq(token.balanceOf(solver), solverBefore + solverFee);
    }

    function test_FeeTooHighReverts() public {
        _deposit(alice, _c(1), SMALL);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(NofaceVault.FeeTooHigh.selector);
        // fee alone exceeds denomination
        vault.withdraw(bytes("proof"), keccak256("n1"), root, bob, SMALL, address(0), SMALL);
    }

    function test_VaultSolvencyAfterWithdraw() public {
        _deposit(alice, _c(1), SMALL);
        assertEq(token.balanceOf(address(vault)), SMALL);

        uint256 protocolFee = (SMALL * vault.FEE_BPS()) / 10_000;
        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        // Pull pattern: protocol fees stay in vault until owner claims
        assertEq(token.balanceOf(address(vault)), protocolFee);
        assertEq(vault.accumulatedFees(), protocolFee);
    }
}
