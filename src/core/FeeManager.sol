// SPDX-License-Identifier: MIT
// FeeManager: The Buyback Engine for VielFi Protocol
// Maximized for Security (CTO Spec V3)
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";

contract FeeManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;

    uint256 public constant ENTRY_FEE_BPS = 20;
    uint256 public constant EXIT_FEE_BPS = 10;
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    uint256 public buybackThreshold = 1000 * 1e6;
    uint256 public constant MAX_SWAP_PER_HOUR = 10;
    
    IERC20 public immutable veilToken;
    IPoolManager public immutable poolManager;
    
    address public stakingContract;
    address public vestingTreasury;
    address public burnAddress;
    
    mapping(address => bool) public isAuthorizedVault;
    mapping(address => bool) public isKeeper;
    
    mapping(address => uint256) public entryFeeBalance;
    mapping(address => uint256) public exitFeeBalance;
    
    uint256 public swapCountThisHour;
    uint256 public currentHourStart;
    bool public paused;
    
    event EntryFeeCollected(address indexed token, uint256 amount, uint256 fee);
    event ExitFeeCollected(address indexed token, uint256 amount, uint256 fee);
    event BuybackExecuted(address indexed tokenIn, uint256 amountIn, uint256 veilOut);
    event TreasuryFunded(uint256 amount);
    event VaultAuthorized(address indexed vault, bool status);
    event KeeperAuthorized(address indexed keeper, bool status);
    
    error InvalidAddress();
    error RateLimitExceeded();
    error BelowThreshold();
    error Unauthorized();
    error SwapFailed();
    error Paused();
    
    modifier whenNotPaused() { if (paused) revert Paused(); _; }
    modifier onlyVault() { if (!isAuthorizedVault[msg.sender]) revert Unauthorized(); _; }
    modifier onlyKeeper() { if (!isKeeper[msg.sender] && msg.sender != owner()) revert Unauthorized(); _; }
    
    constructor(
        address _veilToken,
        address _poolManager,
        address _stakingContract,
        address _vestingTreasury,
        address _burnAddress
    ) Ownable(msg.sender) {
        if (_veilToken == address(0) || _poolManager == address(0)) revert InvalidAddress();
        veilToken = IERC20(_veilToken);
        poolManager = IPoolManager(_poolManager);
        stakingContract = _stakingContract;
        vestingTreasury = _vestingTreasury;
        burnAddress = _burnAddress;
        currentHourStart = block.timestamp / 1 hours;
        isKeeper[msg.sender] = true;
    }
    
    function collectEntryFee(address token, uint256 amount) 
        external whenNotPaused onlyVault returns (uint256 netAmount) 
    {
        uint256 fee = (amount * ENTRY_FEE_BPS) / FEE_DENOMINATOR;
        netAmount = amount - fee;
        IERC20(token).safeTransferFrom(msg.sender, address(this), fee);
        entryFeeBalance[token] += fee;
        emit EntryFeeCollected(token, amount, fee);
    }
    
    function collectExitFee(address token, uint256 amount)
        external whenNotPaused onlyVault returns (uint256 netAmount)
    {
        uint256 fee = (amount * EXIT_FEE_BPS) / FEE_DENOMINATOR;
        netAmount = amount - fee;
        exitFeeBalance[token] += fee;
        emit ExitFeeCollected(token, amount, fee);
    }
    
    function executeBuyback(
        address token,
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint160 sqrtPriceLimitX96
    ) external whenNotPaused onlyKeeper nonReentrant {
        uint256 currentHour = block.timestamp / 1 hours;
        if (currentHour > currentHourStart) {
            currentHourStart = currentHour;
            swapCountThisHour = 0;
        }
        if (swapCountThisHour >= MAX_SWAP_PER_HOUR) revert RateLimitExceeded();
        
        uint256 balance = entryFeeBalance[token];
        if (balance < buybackThreshold) revert BelowThreshold();
        
        entryFeeBalance[token] = 0;
        swapCountThisHour++;
        
        IERC20(token).safeApprove(address(poolManager), balance);
        
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(balance),
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        uint256 veilBalanceBefore = veilToken.balanceOf(address(this));
        
        try poolManager.swap(poolKey, params, "") returns (BalanceDelta) {
            uint256 veilReceived = veilToken.balanceOf(address(this)) - veilBalanceBefore;
            if (veilReceived > 0) {
                uint256 half = veilReceived / 2;
                if (stakingContract != address(0)) veilToken.safeTransfer(stakingContract, half);
                if (burnAddress != address(0)) veilToken.safeTransfer(burnAddress, veilReceived - half);
                emit BuybackExecuted(token, balance, veilReceived);
            }
        } catch {
            entryFeeBalance[token] = balance;
            revert SwapFailed();
        }
    }
    
    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta delta, bytes calldata) 
        external returns (bytes4) 
    {
        require(msg.sender == address(poolManager), "Only PoolManager");
        if (delta.amount0() > 0) poolManager.settle(key.currency0);
        if (delta.amount1() > 0) poolManager.settle(key.currency1);
        if (delta.amount0() < 0) poolManager.take(key.currency0, address(this), uint256(uint128(-delta.amount0())));
        if (delta.amount1() < 0) poolManager.take(key.currency1, address(this), uint256(uint128(-delta.amount1())));
        return this.afterSwap.selector;
    }
    
    function sweepExitFees(address token) external whenNotPaused nonReentrant {
        uint256 amount = exitFeeBalance[token];
        if (amount > 0) {
            exitFeeBalance[token] = 0;
            IERC20(token).safeTransfer(vestingTreasury, amount);
            emit TreasuryFunded(amount);
        }
    }
    
    // Admin
    function authorizeVault(address vault, bool status) external onlyOwner { isAuthorizedVault[vault] = status; emit VaultAuthorized(vault, status); }
    function authorizeKeeper(address keeper, bool status) external onlyOwner { isKeeper[keeper] = status; emit KeeperAuthorized(keeper, status); }
    function setThreshold(uint256 _threshold) external onlyOwner { buybackThreshold = _threshold; }
    function pause() external onlyOwner { paused = true; }
    function unpause() external onlyOwner { paused = false; }
}
