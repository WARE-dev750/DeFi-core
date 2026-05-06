// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {ERC20VeilCore} from "src/core/ERC20VeilCore.sol";
import {HonkVerifier}  from "src/core/HonkVerifier.sol";
import {FeeManager} from "src/core/FeeManager.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC for testnet only — replace with real USDC address on mainnet.
contract TestUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000 * 1e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract DeployVeilFi is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);
        console.log("Deploying from:", deployer);

        vm.startBroadcast(deployerKey);

        // Testnet only — swap for real USDC on mainnet.
        TestUSDC usdc = new TestUSDC();
        console.log("MockUSDC deployed:     ", address(usdc));

        // HonkVerifier: constants hardcoded via BaseZKHonkVerifier.
        // VK hash (circuit: circuits/src/kernel/main.nr):
        //   0x18fedb63ef8554a9d6a700bbd07a84266b9953b2d63a9f6f93d4521b16764689
        HonkVerifier verifier = new HonkVerifier();
        console.log("HonkVerifier deployed: ", address(verifier));

        // Deploy FeeManager FIRST (fix: was address(0))
        // Note: For production, deploy VeilFI token and staking first
        // For testnet, we use mock addresses that can be updated later
        address mockVeilToken = address(usdc); // Placeholder - replace with real $VielFI
        address mockStaking = deployer;        // Placeholder - replace with staking contract
        address vestingTreasury = deployer;    // Treasury for exit fees
        address burnAddress = address(0x000000000000000000000000000000000000dEaD); // Burn address
        
        // PoolManager address - Sepolia v4: 0xE8bD44a79E05cAf4A1F2C64845dB4953A5D5a6D
        // For local/testing, use a mock or skip swaps
        address poolManager = address(0); // Set to real v4 PoolManager for mainnet/testnet
        
        FeeManager feeManager = new FeeManager(
            mockVeilToken,
            address(usdc),
            poolManager,
            mockStaking,
            vestingTreasury,
            burnAddress
        );
        console.log("FeeManager deployed:   ", address(feeManager));
        
        uint256 depositCap = 500_000 * 1e6; // $500k USDC guarded launch cap
        
        // One vault instance. In production, deploy multiple instances
        // (one per denomination) to further anonymise the anonymity set.
        ERC20VeilCore vault = new ERC20VeilCore(address(verifier), address(usdc), address(feeManager), depositCap);
        console.log("ERC20VeilCore deployed:", address(vault));
        console.log("Deposit Cap:           ", depositCap / 1e6, "USDC");
        
        // Log FeeManager configuration
        console.log("Fee Config:");
        console.log("  Entry Fee: 0.2% (50% stake / 50% burn)");
        console.log("  Exit Fee:  0.1% (treasury)");

        vm.stopBroadcast();

        console.log("---");
        console.log("VeilFi Deployment Complete");
        console.log("USDC:        ", address(usdc));
        console.log("Verifier:    ", address(verifier));
        console.log("FeeManager:  ", address(feeManager));
        console.log("Vault:       ", address(vault));
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Update FeeManager with real $VielFI token address");
        console.log("2. Update FeeManager with real PoolManager for v4 swaps");
        console.log("3. Update staking contract address in FeeManager");
        console.log("4. Fund vault with initial liquidity");
        console.log("5. Set guardian multisig on vault");
    }
}
