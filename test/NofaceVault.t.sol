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

    function setUp() public {
        usdc  = new MockUSDC();
        vault = new NofaceVault(address(usdc), treasury, address(this));
        usdc.transfer(user, 10_000 * 1e6);
    }

    function test_DepositIncreasesLeafCount() public {
        vm.startPrank(user);
        usdc.approve(address(vault), vault.DENOM_SMALL());
        vault.deposit(keccak256("note_1"), vault.DENOM_SMALL());
        vm.stopPrank();
        assertEq(vault.totalDeposits(), 1);
    }

    function test_RootChangesAfterDeposit() public {
        bytes32 rootBefore = vault.currentRoot();
        vm.startPrank(user);
        usdc.approve(address(vault), vault.DENOM_SMALL());
        vault.deposit(keccak256("note_2"), vault.DENOM_SMALL());
        vm.stopPrank();
        assertTrue(vault.currentRoot() != rootBefore);
    }

    function test_WithdrawReleasesFunds() public {
        bytes32 commitment    = keccak256("note_3");
        bytes32 nullifierHash = keccak256("null_3");
        vm.startPrank(user);
        usdc.approve(address(vault), vault.DENOM_SMALL());
        vault.deposit(commitment, vault.DENOM_SMALL());
        vm.stopPrank();
        bytes32 root = vault.currentRoot();
        vault.withdraw(nullifierHash, root, fresh, vault.DENOM_SMALL(), "");
        assertTrue(vault.isSpent(nullifierHash));
        uint256 fee = (vault.DENOM_SMALL() * vault.FEE_BPS()) / vault.BPS_DENOM();
        assertEq(usdc.balanceOf(fresh), vault.DENOM_SMALL() - fee);
    }

    function test_DoubleSpendReverts() public {
        bytes32 commitment    = keccak256("note_4");
        bytes32 nullifierHash = keccak256("null_4");
        vm.startPrank(user);
        usdc.approve(address(vault), vault.DENOM_SMALL());
        vault.deposit(commitment, vault.DENOM_SMALL());
        vm.stopPrank();
        bytes32 root = vault.currentRoot();
        uint256 denom = vault.DENOM_SMALL();
        vault.withdraw(nullifierHash, root, fresh, denom, "");
        assertTrue(vault.isSpent(nullifierHash));
        vm.expectRevert(NofaceVault.NullifierAlreadySpent.selector);
        vault.withdraw(nullifierHash, root, fresh, denom, "");
    }
}
