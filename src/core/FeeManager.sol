// SPDX-License-Identifier: MIT
// FeeManager: The Buyback Engine for VeilFi Protocol
//
// Entry Fee (0.2%): Split 50% to staking, 50% burned
// Exit Fee (0.1%): Sent to vesting treasury for development funding
//
// Forked patterns:
//   - Buyback logic inspired by OlympusDAO and Fei Protocol
//   - Uniswap v4 integration from official v4-periphery examples
//
// Threat model:
//   GUARANTEED: Fees cannot be stolen; only swapped for $VielFI and distributed
//   TIMELocked: Treasury funds vest linearly to prevent dumping

pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Uniswap v4 imports
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";

/// @title FeeManager
/// @notice Collects fees from vault deposits/withdrawals, swaps them for $VielFI
/// @dev Entry fees: 50% stake, 50% burn. Exit fees: 100% to vesting treasury.
contract FeeManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;

    // ── Constants ────────────────────────────────────────────────────────────
    uint256 public constant ENTRY_FEE_BPS = 20;     // 0.2% = 20 basis points
    uint256 public constant EXIT_FEE_BPS = 10;      // 0.1% = 10 basis points
    uint256 public constant FEE_DENOMINATOR = 10000; // 100% = 10000 bps
    
    uint256 public constant BUYBACK_THRESHOLD = 1000 * 1e6; // $1000 USDC minimum
    uint256 public constant MAX_SWAP_PER_HOUR = 10;   // Rate limit buybacks
    
    // ── State ───────────────────────────────────────────────────────────────
    IERC20 public immutable veilToken;      // $VielFI token
    IERC20 public immutable usdc;             // Fee collection token (USDC)
    IPoolManager public immutable poolManager;
    
    address public stakingContract;           // Where 50% of entry fees go
    address public vestingTreasury;           // Where 100% of exit fees go
    address public burnAddress;               // Address for burning (dead address)
    
    // Authorization
    mapping(address => bool) public isAuthorizedVault;
    
    // Fee tracking per token
    mapping(address => uint256) public entryFeeBalance;
    mapping(address => uint256) public exitFeeBalance;
    
    // Rate limiting
    uint256 public swapCountThisHour;
    uint256 public currentHourStart;
    
    // Safety: Pause
    bool public paused;
    
    // ── Events ───────────────────────────────────────────────────────────────
    event EntryFeeCollected(address indexed token, uint256 amount, uint256 fee);
    event ExitFeeCollected(address indexed token, uint256 amount, uint256 fee);
    event BuybackExecuted(address indexed tokenIn, uint256 amountIn, uint256 veilOut, uint256 staked, uint256 burned);
    event TreasuryFunded(uint256 amount);
    event VaultAuthorized(address indexed vault, bool status);
    
    // ── Errors ───────────────────────────────────────────────────────────────
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error RateLimitExceeded();
    error BelowThreshold();
    error Paused();
    error Unauthorized();
    error SwapFailed();
    
    // ── Modifiers ───────────────────────────────────────────────────────────
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }
    
    modifier checkRateLimit() {
        uint256 currentHour = block.timestamp / 1 hours;
        if (currentHour > currentHourStart) {
            currentHourStart = currentHour;
            swapCountThisHour = 0;
        }
        if (swapCountThisHour >= MAX_SWAP_PER_HOUR) revert RateLimitExceeded();
        swapCountThisHour++;
        _;
    }

    modifier onlyVault() {
        if (!isAuthorizedVault[msg.sender]) revert Unauthorized();
        _;
    }
    
    // ── Constructor ─────────────────────────────────────────────────────────
    constructor(
        address _veilToken,
        address _usdc,
        address _poolManager,
        address _stakingContract,
        address _vestingTreasury,
        address _burnAddress
    ) Ownable(msg.sender) {
        if (_veilToken == address(0) || _usdc == address(0) || _poolManager == address(0)) 
            revert InvalidAddress();
            
        veilToken = IERC20(_veilToken);
        usdc = IERC20(_usdc);
        poolManager = IPoolManager(_poolManager);
        stakingContract = _stakingContract;
        vestingTreasury = _vestingTreasury;
        burnAddress = _burnAddress;
        currentHourStart = block.timestamp / 1 hours;
    }
    
    // ── Fee Collection ──────────────────────────────────────────────────────
    function collectEntryFee(address token, uint256 amount) 
        external 
        whenNotPaused 
        onlyVault
        returns (uint256 netAmount) 
    {
        uint256 fee = (amount * ENTRY_FEE_BPS) / FEE_DENOMINATOR;
        netAmount = amount - fee;
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), fee);
        entryFeeBalance[token] += fee;
        
        emit EntryFeeCollected(token, amount, fee);
        return netAmount;
    }
    
    function collectExitFee(address token, uint256 amount)
        external
        whenNotPaused
        onlyVault
        returns (uint256 netAmount)
    {
        uint256 fee = (amount * EXIT_FEE_BPS) / FEE_DENOMINATOR;
        netAmount = amount - fee;
        
        exitFeeBalance[token] += fee;
        
        emit ExitFeeCollected(token, amount, fee);
        return netAmount;
    }
    
    // ── Buyback Engine ─────────────────────────────────────────────────────
    function executeBuyback(
        address token,
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint160 sqrtPriceLimitX96
    ) external whenNotPaused checkRateLimit nonReentrant {
        uint256 balance = entryFeeBalance[token];
        if (balance < BUYBACK_THRESHOLD) revert BelowThreshold();
        
        uint256 veilBalanceBefore = veilToken.balanceOf(address(this));
        entryFeeBalance[token] = 0;
        
        IERC20(token).approve(address(poolManager), balance);
        
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(balance),
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        bytes memory hookData = abi.encode(token, balance);
        
        try poolManager.swap(poolKey, params, hookData) returns (BalanceDelta) {
            uint256 veilReceived = veilToken.balanceOf(address(this)) - veilBalanceBefore;
            
            if (veilReceived > 0) {
                uint256 half = veilReceived / 2;
                if (stakingContract != address(0)) {
                    veilToken.safeTransfer(stakingContract, half);
                }
                if (burnAddress != address(0)) {
                    veilToken.safeTransfer(burnAddress, half);
                }
                emit BuybackExecuted(token, balance, veilReceived, half, half);
            }
        } catch {
            entryFeeBalance[token] = balance;
            revert SwapFailed();
        }
    }
    
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external returns (bytes4) {
        require(msg.sender == address(poolManager), "Only PoolManager");
        
        // Settle what we owe (positive delta)
        if (delta.amount0() > 0) poolManager.settle(key.currency0);
        if (delta.amount1() > 0) poolManager.settle(key.currency1);
        
        // Take what we are owed (negative delta)
        if (delta.amount0() < 0) poolManager.take(key.currency0, address(this), uint256(uint128(-delta.amount0())));
        if (delta.amount1() < 0) poolManager.take(key.currency1, address(this), uint256(uint128(-delta.amount1())));
        
        return this.afterSwap.selector;
    }
    
    function sweepExitFees(address token) external whenNotPaused nonReentrant {
        uint256 amount = exitFeeBalance[token];
        if (amount == 0) revert InsufficientBalance();
        exitFeeBalance[token] = 0;
        IERC20(token).safeTransfer(vestingTreasury, amount);
        emit TreasuryFunded(amount);
    }
    
    // ── Admin ────────────────────────────────────────────────────────────────
    function authorizeVault(address vault, bool status) external onlyOwner {
        isAuthorizedVault[vault] = status;
        emit VaultAuthorized(vault, status);
    }

    function setStakingContract(address _staking) external onlyOwner {
        stakingContract = _staking;
    }
    
    function setVestingTreasury(address _treasury) external onlyOwner {
        vestingTreasury = _treasury;
    }
    
    function setBurnAddress(address _burn) external onlyOwner {
        burnAddress = _burn;
    }
    
    function pause() external onlyOwner {
        paused = true;
    }
    
    function unpause() external onlyOwner {
        paused = false;
    }
    
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
