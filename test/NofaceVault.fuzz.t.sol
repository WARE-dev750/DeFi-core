// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NofaceVaultFuzzTest {
    // Initialize the NofaceVault contract instance
    NofaceVault vault;

    function beforeEach() public {
        vault = new NofaceVault();
    }

    function testFuzzDeposit(uint256 amount) public {
        // Test deposit with randomized amount
        assume(amount > 0); // Assumption, since deposits cannot be zero
        vault.deposit(amount);
        assert(vault.balanceOf(msg.sender) == amount);
    }

    function testFuzzWithdraw(uint256 amount) public {
        // Prepare the state
        vault.deposit(1000);
        assume(amount <= 1000); // Ensure we can only withdraw what is deposited
        vault.withdraw(amount);
        assert(vault.balanceOf(msg.sender) == 1000 - amount);
    }

    function testFuzzFeeCalculation(uint256 amount) public {
        // Test variable fees on deposit
        vault.deposit(amount);
        uint256 fee = vault.calculateFee(amount);
        assert(fee <= amount); // Fees should never exceed the amount
    }

    function testFuzzInvariants() public {
        // Check invariants after various operations
        uint256 initialBalance = vault.totalBalance();
        vault.deposit(500);
        assert(vault.totalBalance() == initialBalance + 500);
        vault.withdraw(200);
        assert(vault.totalBalance() == initialBalance + 500 - 200);
    }
}