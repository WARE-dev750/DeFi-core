// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {NofaceVault} from "../contracts/src/core/NofaceVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ── Mock USDC for testnet only ───────────────────────────────
contract TestUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000 * 1e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

// ── Mock Verifier for testnet only ───────────────────────────
// Always returns true — real HonkVerifier goes in after E2E proof
// NEVER deploy this to mainnet
contract TestVerifier {
    function verify(
        bytes calldata,
        bytes32[] calldata
    ) external pure returns (bool) {
        return true;
    }
}

contract DeployNoface is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console.log("Deploying from:", deployer);

        vm.startBroadcast(deployerKey);

        // 1. Deploy mock USDC
        TestUSDC usdc = new TestUSDC();
        console.log("MockUSDC deployed:   ", address(usdc));

        // 2. Deploy mock verifier
        TestVerifier verifier = new TestVerifier();
        console.log("TestVerifier deployed:", address(verifier));

        // 3. Deploy vault
        NofaceVault vault = new NofaceVault(
            address(usdc),
            address(verifier),
            deployer,   // treasury
            deployer    // owner
        );
        console.log("NofaceVault deployed: ", address(vault));

        vm.stopBroadcast();

        console.log("---");
        console.log("NOFACE Sepolia Deployment Complete");
        console.log("USDC:     ", address(usdc));
        console.log("Verifier: ", address(verifier));
        console.log("Vault:    ", address(vault));
    }
}
