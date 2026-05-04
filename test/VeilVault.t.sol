// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {VeilVault} from "src/core/VeilVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// MockVerifier accepts any non-empty proof — used for vault logic tests only.
// ZK correctness is proven separately in HonkVerifier.t.sol with a real proof.
contract MockVerifier {
    function verify(bytes calldata proof, bytes32[] calldata) external pure returns (bool) {
        return proof.length > 0;
    }
}

contract VeilVaultTest is Test {

    VeilVault  vault;
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
        vault    = new VeilVault(address(token), address(verifier));

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
        vm.expectRevert(VeilVault.InvalidDenomination.selector);
        vault.deposit(_c(1), 999 * 1e6);
    }

    function test_DuplicateCommitmentReverts() public {
        bytes32 c = _c(42);
        vm.prank(alice);
        vault.deposit(c, SMALL);
        vm.prank(alice);
        vm.expectRevert(VeilVault.CommitmentAlreadyExists.selector);
        vault.deposit(c, SMALL);
    }

    function test_CommitmentOutOfFieldReverts() public {
        vm.prank(alice);
        vm.expectRevert(VeilVault.CommitmentOutOfField.selector);
        vault.deposit(bytes32(SNARK_FIELD), SMALL); // exactly at boundary — invalid
    }

    // ── Withdraw tests ────────────────────────────────────────────────────────

    function test_BatchWithdraw() public {
        // Deposit twice
        _deposit(alice, _c(1), SMALL);
        _deposit(alice, _c(2), MEDIUM);

        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = keccak256("n1");
        nullifiers[1] = keccak256("n2");

        bytes32[] memory roots = new bytes32[](2);
        roots[0] = vault.getRoot();
        roots[1] = vault.getRoot();

        address[] memory recipients = new address[](2);
        recipients[0] = bob;
        recipients[1] = bob;

        uint256[] memory denoms = new uint256[](2);
        denoms[0] = SMALL;
        denoms[1] = MEDIUM;

        address[] memory relayers = new address[](2);
        relayers[0] = address(0);
        relayers[1] = address(0);

        uint256[] memory fees = new uint256[](2);
        fees[0] = 0;
        fees[1] = 0;

        uint256 bobBefore = token.balanceOf(bob);
        
        bytes[] memory proofs = new bytes[](2);
        proofs[0] = bytes("proof");
        proofs[1] = bytes("proof");

        vm.prank(bob);
        vault.batchWithdraw(
            proofs,
            VeilVault.BatchWithdrawArgs(
                nullifiers,
                roots,
                recipients,
                denoms,
                relayers,
                fees
            )
        );

        uint256 fee1 = (SMALL * vault.EXIT_FEE_BPS()) / 10_000;
        uint256 fee2 = (MEDIUM * vault.EXIT_FEE_BPS()) / 10_000;

        assertEq(token.balanceOf(bob), bobBefore + SMALL - fee1 + MEDIUM - fee2);
    }

    function testFuzz_BatchWithdraw(uint256 count) public {
        count = bound(count, 1, 10); // bound count between 1 and 10

        bytes32[] memory nullifiers = new bytes32[](count);
        bytes32[] memory roots = new bytes32[](count);
        address[] memory recipients = new address[](count);
        uint256[] memory denoms = new uint256[](count);
        address[] memory relayers = new address[](count);
        uint256[] memory fees = new uint256[](count);

        uint256 expectedPayout = 0;

        for(uint256 i = 0; i < count; i++) {
            _deposit(alice, _c(i + 100), SMALL);
            nullifiers[i] = keccak256(abi.encodePacked("n", i));
            roots[i] = vault.getRoot();
            recipients[i] = bob;
            denoms[i] = SMALL;
            relayers[i] = address(0);
            fees[i] = 0;
            
            uint256 fee = (SMALL * vault.EXIT_FEE_BPS()) / 10_000;
            expectedPayout += (SMALL - fee);
        }

        uint256 bobBefore = token.balanceOf(bob);
        
        bytes[] memory proofs = new bytes[](count);
        for(uint256 i = 0; i < count; i++) {
            proofs[i] = bytes("proof");
        }

        vm.prank(bob);
        vault.batchWithdraw(
            proofs,
            VeilVault.BatchWithdrawArgs(
                nullifiers,
                roots,
                recipients,
                denoms,
                relayers,
                fees
            )
        );

        assertEq(token.balanceOf(bob), bobBefore + expectedPayout);
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

        uint256 protocolFee = (SMALL * vault.EXIT_FEE_BPS()) / 10_000;
        uint256 bobBefore   = token.balanceOf(bob);

        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        assertEq(token.balanceOf(bob), bobBefore + SMALL - protocolFee);
    }

    function test_DoubleWithdrawReverts() public {
        _deposit(alice, _c(1), SMALL);
        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        bytes32 root = vault.getRoot();
        vm.prank(bob);
        vm.expectRevert(VeilVault.NullifierAlreadySpent.selector);
        vault.withdraw(bytes("proof"), keccak256("n1"), root, bob, SMALL, address(0), 0);
    }

    function test_InvalidRootReverts() public {
        _deposit(alice, _c(1), SMALL);

        vm.prank(bob);
        vm.expectRevert(VeilVault.InvalidRoot.selector);
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
        vm.expectRevert(VeilVault.FeeTooHigh.selector);
        // fee alone exceeds denomination
        vault.withdraw(bytes("proof"), keccak256("n1"), root, bob, SMALL, address(0), SMALL);
    }

    function test_VaultSolvencyAfterWithdraw() public {
        _deposit(alice, _c(1), SMALL);
        uint256 entryFee = (SMALL * vault.ENTRY_FEE_BPS()) / 10_000;
        assertEq(token.balanceOf(address(vault)), SMALL + entryFee);

        uint256 exitFee = (SMALL * vault.EXIT_FEE_BPS()) / 10_000;
        _withdraw(bob, keccak256("n1"), bob, SMALL, address(0), 0);

        // Pull pattern: protocol fees stay in vault until owner claims
        assertEq(token.balanceOf(address(vault)), entryFee + exitFee);
        assertEq(vault.accumulatedExitFees(), exitFee);
        assertEq(vault.accumulatedEntryFees(), entryFee);
    }
}
