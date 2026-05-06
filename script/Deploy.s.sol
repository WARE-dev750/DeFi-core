// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {ERC20VeilCore} from "../src/core/ERC20VeilCore.sol";
import {FeeManager} from "../src/core/FeeManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock Verifier for deployment (replace with real verifier in production)
contract MockVerifier {
    function verify(bytes calldata, bytes32[] calldata) external pure returns (bool) {
        return true;
    }
}

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.startBroadcast(deployerPrivateKey);

        // Parameters
        address token = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (Sepolia)
        address poolManager = 0xE8bD44a79E05cAf4A1F2C64845dB4953A5D5a6D; // Uni v4 Sepolia
        uint256 denomination = 100 * 1e6; // 100 USDC
        uint256 depositCap = 500_000 * 1e6; // 500k USDC

        // 1. Deploy Verifier
        MockVerifier verifier = new MockVerifier();
        console.log("Verifier deployed:", address(verifier));

        // 2. Deploy FeeManager
        FeeManager feeManager = new FeeManager(
            token, // Using USDC as VeilFI placeholder for now
            poolManager,
            address(0), // staking
            address(0), // treasury
            address(0)  // burn
        );
        console.log("FeeManager deployed:", address(feeManager));

        // 3. Deploy Vault
        ERC20VeilCore vault = new ERC20VeilCore(
            address(verifier),
            token,
            address(feeManager),
            denomination,
            depositCap
        );
        console.log("ERC20VeilCore deployed:", address(vault));

        // 4. Post-deployment config
        feeManager.authorizeVault(address(vault), true);
        console.log("Vault authorized in FeeManager");

        vm.stopBroadcast();
    }
}
