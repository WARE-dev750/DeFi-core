// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {NofaceVault} from "../contracts/src/core/NofaceVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ── Mock USDC ────────────────────────────────────────────────
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000 * 1e6);
    }
}

// ── Mock Verifier ────────────────────────────────────────────
// Always returns true — lets us test vault logic without
// needing a real ZK proof in Foundry
contract MockVerifier {
    function verify(
        bytes calldata,
        bytes32[] calldata
    ) external pure returns (bool) {
        return true;
    }
}

// ── Tests ────────────────────────────────────────────────────
contract NofaceVaultTest is Test {

    NofaceVault   vault;
    MockUSDC      usdc;
    MockVerifier  verifier;

    address user     = address(0xA11CE);
    address fresh    = address(0xBEEF);
    address treasury = address(0xFEE5);

    // BN254 scalar field modulus
    // All commitments must be below this value
    uint256 internal constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function _toField(bytes32 h) internal pure returns (bytes32) {
        return bytes32(uint256(h) % SNARK_SCALAR_FIELD);
    }

    function setUp() public {
        usdc     = new MockUSDC();
        verifier = new MockVerifier();
        vault    = new NofaceVault(
            address(usdc),
            address(verifier),
            treasury,
            address(this)
        );
        usdc.transfer(user, 10_000 * 1e6);
    }

    // ── Deposit Tests ────────────────────────────────────────

    function test_DepositIncreasesLeafCount() public {
        vm.startPrank(user);
        usdc.approve(address(vault), vault.DENOM_SMALL());
        vault.deposit(_toField(keccak256("note_1")), vault.DENOM_SMALL());
        vm.stopPrank();

        assertEq(vault.totalDeposits(), 1);
    }

    function test_RootChangesAfterDeposit() public {
        bytes32 rootBefore = vault.currentRoot();

        vm.startPrank(user);
        usdc.approve(address(vault), vault.DENOM_SMALL());
        vault.deposit(_toField(keccak256("note_2")), vault.DENOM_SMALL());
        vm.stopPrank();

        assertTrue(rootBefore != vault.currentRoot());
    }

    // ── Withdrawal Tests ─────────────────────────────────────

    function test_WithdrawReleasesFunds() public {
        bytes32 commitment    = _toField(keccak256("note_3"));
        bytes32 nullifierHash = keccak256("null_3");
        uint256 denom         = vault.DENOM_SMALL();

        vm.startPrank(user);
        usdc.approve(address(vault), denom);
        vault.deposit(commitment, denom);
        vm.stopPrank();

        bytes32 root      = vault.currentRoot();
        uint256 balBefore = usdc.balanceOf(fresh);

        vault.withdraw(nullifierHash, root, fresh, denom, "");

        uint256 fee = (denom * 30) / 10_000;
        assertEq(usdc.balanceOf(fresh) - balBefore, denom - fee);
    }

    // ── Security Tests ───────────────────────────────────────

    function test_DoubleSpendReverts() public {
        bytes32 commitment    = _toField(keccak256("note_4"));
        bytes32 nullifierHash = keccak256("null_4");
        uint256 denom         = vault.DENOM_SMALL();

        vm.startPrank(user);
        usdc.approve(address(vault), denom);
        vault.deposit(commitment, denom);
        vm.stopPrank();

        bytes32 root = vault.currentRoot();

        // First withdrawal — must succeed
        vault.withdraw(nullifierHash, root, fresh, denom, "");
        assertTrue(vault.isSpent(nullifierHash));

        // Second withdrawal — must revert
        vm.expectRevert(NofaceVault.NullifierAlreadySpent.selector);
        vault.withdraw(nullifierHash, root, fresh, denom, "");
    }

    function test_InvalidRootReverts() public {
        bytes32 commitment    = _toField(keccak256("note_5"));
        bytes32 nullifierHash = keccak256("null_5");
        uint256 denom         = vault.DENOM_SMALL();

        vm.startPrank(user);
        usdc.approve(address(vault), denom);
        vault.deposit(commitment, denom);
        vm.stopPrank();

        bytes32 fakeRoot = bytes32(uint256(0xDEAD));

        vm.expectRevert(NofaceVault.InvalidRoot.selector);
        vault.withdraw(nullifierHash, fakeRoot, fresh, denom, "");
    }

    function test_InvalidDenominationReverts() public {
        bytes32 commitment = _toField(keccak256("note_6"));

        vm.startPrank(user);
        usdc.approve(address(vault), 50 * 1e6);
        vm.expectRevert(NofaceVault.InvalidDenomination.selector);
        vault.deposit(commitment, 50 * 1e6);
        vm.stopPrank();
    }

    // ── Solvency Invariant ───────────────────────────────────

    function test_VaultSolvencyAfterWithdraw() public {
        bytes32 commitment    = _toField(keccak256("note_7"));
        bytes32 nullifierHash = keccak256("null_7");
        uint256 denom         = vault.DENOM_SMALL();

        vm.startPrank(user);
        usdc.approve(address(vault), denom);
        vault.deposit(commitment, denom);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(vault)), denom);

        bytes32 root = vault.currentRoot();
        vault.withdraw(nullifierHash, root, fresh, denom, "");

        // Vault must be empty — all funds went to recipient + treasury
        assertEq(usdc.balanceOf(address(vault)), 0);
    }
}
