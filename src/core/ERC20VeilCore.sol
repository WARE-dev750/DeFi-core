// SPDX-License-Identifier: MIT
// Forked from: https://github.com/tornadocash/tornado-core/blob/master/contracts/ERC20Tornado.sol
// Changes from original:
//   1. Solidity ^0.7.0 -> ^0.8.23
//   2. SafeERC20 from OZ v4 -> OZ v5 import path
//   3. MiMC hasher removed (handled in MerkleTreeWithHistory.sol via Poseidon2)
//   4. Inherits VeilCore (our Honk-compatible abstract) instead of original Tornado
//   5. No ETH refund mechanism (ERC20 only; simplifies attack surface)
//   6. No fees, no tokenomics — pure, auditable privacy primitive
pragma solidity ^0.8.23;

import {VeilCore} from "./VeilCore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  ERC20VeilCore
/// @notice Concrete ERC20 instance of the VeilCore privacy pool.
///         One deployed instance per token/denomination combination.
///         Keeps the same single-denomination invariant as tornado-core for
///         maximum anonymity-set homogeneity.
contract ERC20VeilCore is VeilCore {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    constructor(address _verifier, address _token)
        VeilCore(_verifier)
    {
        require(_token != address(0), "zero token");
        token = IERC20(_token);
    }

    /// @inheritdoc VeilCore
    /// @dev Pull `denomination` tokens from depositor. No protocol cut.
    function _processDeposit(uint256 denomination) internal override {
        require(msg.value == 0, "ETH not accepted");
        token.safeTransferFrom(msg.sender, address(this), denomination);
    }

    /// @inheritdoc VeilCore
    /// @dev Push `denomination - fee` to recipient, `fee` to relayer (if nonzero).
    function _processWithdraw(
        address payable recipient,
        address payable relayer,
        uint256 denomination,
        uint256 fee
    ) internal override {
        token.safeTransfer(recipient, denomination - fee);
        if (fee > 0) {
            // If relayer is zero-address, msg.sender (the self-relayer) gets the fee.
            address feeRecipient = address(relayer) != address(0) ? address(relayer) : msg.sender;
            token.safeTransfer(feeRecipient, fee);
        }
    }
}
