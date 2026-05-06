// SPDX-License-Identifier: MIT
// Forked from: https://github.com/tornadocash/tornado-core/blob/master/contracts/ERC20Tornado.sol
// Maximized for VielFi Protocol (CTO Spec V3)
pragma solidity ^0.8.23;

import {VeilCore} from "./VeilCore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IFeeManager {
    function collectEntryFee(address token, uint256 amount) external;
    function collectExitFee(address token, uint256 amount) external;
    function ENTRY_FEE_BPS() external view returns (uint256);
    function EXIT_FEE_BPS() external view returns (uint256);
    function FEE_DENOMINATOR() external view returns (uint256);
}


contract ERC20VeilCore is VeilCore {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    IFeeManager public feeManager;
    
    constructor(
        address _verifier, 
        address _token, 
        address _feeManager, 
        uint256 _denomination,
        uint256 _depositCap
    )
        VeilCore(_verifier, _denomination, _depositCap)
    {
        require(_token != address(0), "zero token");
        require(_denomination > 0, "zero denomination");
        token = IERC20(_token);
        feeManager = IFeeManager(_feeManager);
    }

    function _processDeposit(uint256 _denomination) internal override {
        require(msg.value == 0, "ETH not accepted");
        
        uint256 entryFee = 0;
        if (address(feeManager) != address(0)) {
            entryFee = (_denomination * feeManager.ENTRY_FEE_BPS()) / feeManager.FEE_DENOMINATOR();
        }

        uint256 totalAmount = _denomination + entryFee;
        token.safeTransferFrom(msg.sender, address(this), totalAmount);
        
        if (entryFee > 0) {
            token.safeTransfer(address(feeManager), entryFee);
            feeManager.collectEntryFee(address(token), entryFee);
        }
    }

    function _processWithdraw(
        address payable recipient,
        address payable relayer,
        uint256 _denomination,
        uint256 relayerFee
    ) internal override {
        uint256 exitFee = 0;
        if (address(feeManager) != address(0)) {
            exitFee = (_denomination * feeManager.EXIT_FEE_BPS()) / feeManager.FEE_DENOMINATOR();
            token.safeTransfer(address(feeManager), exitFee);
            feeManager.collectExitFee(address(token), exitFee);
        }
        
        uint256 netAmount = _denomination - exitFee;
        uint256 recipientAmount = netAmount - relayerFee;
        
        token.safeTransfer(recipient, recipientAmount);
        
        if (relayerFee > 0) {
            address feeRecipient = address(relayer) != address(0) ? address(relayer) : msg.sender;
            token.safeTransfer(feeRecipient, relayerFee);
        }
    }
}

