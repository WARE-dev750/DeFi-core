// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {ERC20VeilCore} from "src/core/ERC20VeilCore.sol";
import {HonkVerifier}  from "src/core/HonkVerifier.sol";
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

        // FeeManager placeholder - deploy FeeManager first then update
        address feeManager = address(0); // TODO: Deploy FeeManager first
        uint256 depositCap = 500_000 * 1e6; // $500k USDC guarded launch cap
        
        // One vault instance. In production, deploy multiple instances
        // (one per denomination) to further anonymise the anonymity set.
        ERC20VeilCore vault = new ERC20VeilCore(address(verifier), address(usdc), feeManager, depositCap);
        console.log("ERC20VeilCore deployed:", address(vault));
        console.log("Deposit Cap:           ", depositCap / 1e6, "USDC");

        vm.stopBroadcast();

        console.log("---");
        console.log("VeilFi Deployment Complete");
        console.log("USDC:     ", address(usdc));
        console.log("Verifier: ", address(verifier));
        console.log("Vault:    ", address(vault));
    }
}
