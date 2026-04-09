// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {NofaceVault} from "../contracts/src/core/NofaceVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract MockVerifier {
    function verify(bytes calldata proof, bytes32[] calldata) external pure returns (bool) {
        return proof.length > 0;
    }
}

contract NofaceVaultTest is Test {
    NofaceVault  vault;
    MockERC20    token;
    MockVerifier verifier;

    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    uint256 constant SNARK_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // Cache denominations to avoid consuming vm.prank with static calls
    uint256 SMALL;
    uint256 MEDIUM;
    uint256 LARGE;

    function setUp() public {
        token    = new MockERC20("USDC", "USDC", 6);
        verifier = new MockVerifier();
        vault    = new NofaceVault(address(token), address(verifier));

        // Cache before any pranks
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

    function _c(uint256 n) internal pure returns (bytes32) {
        return bytes32(n % SNARK_FIELD);
    }

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

    function test_DoubleSpendReverts() public {
        bytes32 c = _c(42);
        vm.prank(alice);
        vault.deposit(c, SMALL);
        vm.prank(alice);
        vm.expectRevert(NofaceVault.CommitmentAlreadyExists.selector);
        vault.deposit(c, SMALL);
    }

    function test_WithdrawReleasesFunds() public {
        vm.prank(alice);
        vault.deposit(_c(1), SMALL);
        bytes32 root      = vault.getRoot();
        bytes32 nullifier = keccak256("nullifier_1");
        uint256 fee       = (SMALL * vault.FEE_BPS()) / 10_000;
        uint256 bobBefore = token.balanceOf(bob);
        vm.prank(bob);
        vault.withdraw(bytes("proof"), nullifier, root, bob, SMALL);
        assertEq(token.balanceOf(bob), bobBefore + SMALL - fee);
    }

    function test_DoubleWithdrawReverts() public {
        vm.prank(alice);
        vault.deposit(_c(1), SMALL);
        bytes32 root      = vault.getRoot();
        bytes32 nullifier = keccak256("nullifier_1");
        vm.prank(bob);
        vault.withdraw(bytes("proof"), nullifier, root, bob, SMALL);
        vm.prank(bob);
        vm.expectRevert(NofaceVault.NullifierAlreadySpent.selector);
        vault.withdraw(bytes("proof"), nullifier, root, bob, SMALL);
    }

    function test_InvalidRootReverts() public {
        vm.prank(alice);
        vault.deposit(_c(1), SMALL);
        vm.prank(bob);
        vm.expectRevert(NofaceVault.InvalidRoot.selector);
        vault.withdraw(
            bytes("proof"),
            keccak256("n"),
            bytes32(uint256(0xdead)),
            bob,
            SMALL
        );
    }

    function test_VaultSolvencyAfterWithdraw() public {
        vm.prank(alice);
        vault.deposit(_c(1), SMALL);
        assertEq(token.balanceOf(address(vault)), SMALL);
        bytes32 root      = vault.getRoot();
        bytes32 nullifier = keccak256("nullifier_1");
        uint256 fee       = (SMALL * vault.FEE_BPS()) / 10_000;
        vm.prank(bob);
        vault.withdraw(bytes("proof"), nullifier, root, bob, SMALL);
        // Fee goes to owner() (test contract), vault should be empty
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(address(this)), fee);
    }
}
