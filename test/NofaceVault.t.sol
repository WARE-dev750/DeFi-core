// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {NofaceVault} from "../contracts/src/core/NofaceVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000 * 1e6);
    }
}

contract NofaceVaultTest is Test {
    NofaceVault vault;
    MockUSDC    usdc;

    address user     = address(0xA11CE);
    address fresh    = address(0xBEEF);
    address treasury = address(0xFEE5);

    // BN254 scalar field modulus — all leaves must be below this
    // The real NOFACE SDK reduces commitments into this field before deposit
    uint256 internal constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // Reduces a keccak256 hash into a valid BN254 field element
    function _toField(bytes32 h) internal pure returns (bytes32) {
        return bytes32(uint256(h) % SNARK_SCALAR_FIELD);
    }

    function setUp() public {
        usdc  = new MockUSDC();
        vault = new NofaceVault(address(usdc), treasury, address(this));
        usdc.transfer(user, 10_000 * 1e6);
    }

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
        bytes32 rootAfter = vault.currentRoot();
        assertTrue(rootBefore != rootAfter);
    }

    function test_WithdrawReleasesFunds() public {
        bytes32 commitment    = _toField(keccak256("note_3"));
        bytes32 nullifierHash = keccak256("null_3");
        uint256 denom         = vault.DENOM_SMALL();

        vm.startPrank(user);
        usdc.approve(address(vault), denom);
        vault.deposit(commitment, denom);
        vm.stopPrank();

        bytes32 root          = vault.currentRoot();
        uint256 balBefore     = usdc.balanceOf(fresh);
        vault.withdraw(nullifierHash, root, fresh, denom, "");
        uint256 balAfter      = usdc.balanceOf(fresh);

        uint256 fee           = (denom * 30) / 10_000;
        assertEq(balAfter - balBefore, denom - fee);
    }

    function test_DoubleSpendReverts() public {
        bytes32 commitment    = _toField(keccak256("note_4"));
        bytes32 nullifierHash = keccak256("null_4");
        uint256 denom         = vault.DENOM_SMALL();

        vm.startPrank(user);
        usdc.approve(address(vault), denom);
        vault.deposit(commitment, denom);
        vm.stopPrank();

        bytes32 root = vault.currentRoot();
        vault.withdraw(nullifierHash, root, fresh, denom, "");
        assertTrue(vault.isSpent(nullifierHash));

        vm.expectRevert(NofaceVault.NullifierAlreadySpent.selector);
        vault.withdraw(nullifierHash, root, fresh, denom, "");
    }
}
