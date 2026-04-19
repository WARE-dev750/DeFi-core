// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
<<<<<<< HEAD
import {NofaceVault} from "src/core/NofaceVault.sol";
import {HonkVerifier} from "src/core/HonkVerifier.sol";
=======
import {NofaceVault} from "../contracts/src/core/NofaceVault.sol";
import {HonkVerifier} from "../contracts/src/core/HonkVerifier.sol";
>>>>>>> 2186b1053832043c62ad4dc595db74e813e68ca3
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC for testnet only -- replace with real USDC address on mainnet
contract TestUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000 * 1e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract DeployNoface is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console.log("Deploying from:", deployer);

        vm.startBroadcast(deployerKey);

        // Testnet only -- swap for real USDC on mainnet
        TestUSDC usdc = new TestUSDC();
        console.log("MockUSDC deployed:    ", address(usdc));

        // HonkVerifier has no constructor args -- constants are hardcoded
        // via BaseZKHonkVerifier(N, LOG_N, VK_HASH, NUMBER_OF_PUBLIC_INPUTS)
        // VK_HASH: 0x18fedb63ef8554a9d6a700bbd07a84266b9953b2d63a9f6f93d4521b16764689
        // Circuit: circuits/src/kernel/main.nr
        HonkVerifier verifier = new HonkVerifier();
        console.log("HonkVerifier deployed:", address(verifier));

        NofaceVault vault = new NofaceVault(
            address(usdc),
            address(verifier)
        );
        console.log("NofaceVault deployed: ", address(vault));

        vm.stopBroadcast();

        console.log("---");
        console.log("NOFACE Deployment Complete");
        console.log("USDC:     ", address(usdc));
        console.log("Verifier: ", address(verifier));
        console.log("Vault:    ", address(vault));
    }
}
