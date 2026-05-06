// SPDX-License-Identifier: MIT
// Forked from: https://github.com/tornadocash/tornado-core/blob/master/contracts/ERC20Tornado.sol
// Changes from original:
//   1. Solidity ^0.7.0 -> ^0.8.23
//   2. SafeERC20 from OZ v4 -> OZ v5 import path
//   3. MiMC hasher removed (handled in MerkleTreeWithHistory.sol via Poseidon2)
//   4. Inherits VeilCore (our Honk-compatible abstract) instead of original Tornado
//   5. No ETH refund mechanism (ERC20 only; simplifies attack surface)
//   6. Fee integration: 0.2% entry fee, 0.1% exit fee (CTO Spec V2)
//      Entry fees fund buyback engine (50% stake / 50% burn)
//      Exit fees fund vesting treasury for development
pragma solidity ^0.8.23;

import {VeilCore} from "./VeilCore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Minimal FeeManager interface
interface IFeeManager {
    function collectEntryFee(address token, uint256 amount) external returns (uint256 netAmount);
    function collectExitFee(address token, uint256 amount) external returns (uint256 netAmount);
}

/// @title  ERC20VeilCore
/// @notice Concrete ERC20 instance of the VeilCore privacy pool with fee integration.
///         One deployed instance per token/denomination combination.
///         Entry Fee: 0.2% (50% staked, 50% burned). Exit Fee: 0.1% (to treasury).
contract ERC20VeilCore is VeilCore {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    IFeeManager public feeManager;
    
    // Fee configuration (basis points)
    uint256 public constant ENTRY_FEE_BPS = 20;  // 0.2%
    uint256 public constant EXIT_FEE_BPS = 10;   // 0.1%
    uint256 public constant FEE_DENOMINATOR = 10000;

    constructor(address _verifier, address _token, address _feeManager, uint256 _depositCap)
        VeilCore(_verifier, _depositCap)
    {
        require(_token != address(0), "zero token");
        token = IERC20(_token);
        feeManager = IFeeManager(_feeManager);
    }

    /// @inheritdoc VeilCore
    /// @dev Pull `denomination` tokens from depositor, collect 0.2% entry fee.
    ///      User receives shielded commitment for (denomination - fee).
    function _processDeposit(uint256 denomination) internal override {
        require(msg.value == 0, "ETH not accepted");
        
        // Calculate entry fee: 0.2%
        uint256 fee = (denomination * ENTRY_FEE_BPS) / FEE_DENOMINATOR;
        uint256 netAmount = denomination - fee;
        
        // Pull full amount from depositor
        token.safeTransferFrom(msg.sender, address(this), denomination);
        
        // Send fee to FeeManager for buyback engine
        if (fee > 0 && address(feeManager) != address(0)) {
            token.safeTransfer(address(feeManager), fee);
        }
    }

    /// @inheritdoc VeilCore
    /// @dev Push `denomination - exitFee - relayerFee` to recipient.
    ///      Exit fee (0.1%) goes to FeeManager treasury.
    function _processWithdraw(
        address payable recipient,
        address payable relayer,
        uint256 denomination,
        uint256 relayerFee
    ) internal override {
        // Calculate exit fee: 0.1%
        uint256 exitFee = (denomination * EXIT_FEE_BPS) / FEE_DENOMINATOR;
        uint256 remainingAfterExitFee = denomination - exitFee;
        
        // Calculate what recipient gets after both fees
        uint256 recipientAmount = remainingAfterExitFee - relayerFee;
        
        // Transfer to recipient
        token.safeTransfer(recipient, recipientAmount);
        
        // Transfer relayer fee
        if (relayerFee > 0) {
            address feeRecipient = address(relayer) != address(0) ? address(relayer) : msg.sender;
            token.safeTransfer(feeRecipient, relayerFee);
        }
        
        // Send exit fee to FeeManager (accumulates for treasury)
        if (exitFee > 0 && address(feeManager) != address(0)) {
            token.safeTransfer(address(feeManager), exitFee);
        }
    }
}
