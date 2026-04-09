// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {NofaceVault} from "../contracts/src/core/NofaceVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC for testnet only
contract TestUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000 * 1e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

// Mock Verifier for testnet only — NEVER deploy to mainnet
contract TestVerifier {
    function verify(bytes calldata, bytes32[] calldata) external pure returns (bool) {
        return true;
    }
}

contract DeployNoface is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);
        console.log("Deploying from:", deployer);

        vm.startBroadcast(deployerKey);

        TestUSDC usdc = new TestUSDC();
        console.log("MockUSDC deployed:   ", address(usdc));

        TestVerifier verifier = new TestVerifier();
        console.log("TestVerifier deployed:", address(verifier));

        // Constructor: (address _token, address _verifier)
        // Ownable sets owner = msg.sender = deployer
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
