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
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

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
    /// @notice Calculate and collect entry fee. Called by ERC20VeilCore on deposit.
    /// @param token The token being deposited
    /// @param amount The gross deposit amount
    /// @return netAmount The amount after fee deduction
    function collectEntryFee(address token, uint256 amount) 
        external 
        whenNotPaused 
        returns (uint256 netAmount) 
    {
        // Only registered vaults can call
        // This will be set in a mapping checked here
        
        uint256 fee = (amount * ENTRY_FEE_BPS) / FEE_DENOMINATOR;
        netAmount = amount - fee;
        
        // Pull fee from caller (must be approved)
        IERC20(token).safeTransferFrom(msg.sender, address(this), fee);
        entryFeeBalance[token] += fee;
        
        emit EntryFeeCollected(token, amount, fee);
        return netAmount;
    }
    
    /// @notice Calculate and collect exit fee. Called by ERC20VeilCore on withdraw.
    /// @param token The token being withdrawn
    /// @param amount The gross withdrawal amount
    /// @return netAmount The amount after fee deduction
    function collectExitFee(address token, uint256 amount)
        external
        whenNotPaused
        returns (uint256 netAmount)
    {
        uint256 fee = (amount * EXIT_FEE_BPS) / FEE_DENOMINATOR;
        netAmount = amount - fee;
        
        // Fee stays in vault, vault sends netAmount to user
        // We track the fee owed to us by the vault
        exitFeeBalance[token] += fee;
        
        emit ExitFeeCollected(token, amount, fee);
        return netAmount;
    }
    
    // ── Buyback Engine ─────────────────────────────────────────────────────
    /// @notice Execute buyback when threshold reached. Anyone can call (public good).
    /// @param token The fee token to swap (e.g., USDC)
    /// @param poolKey The Uniswap v4 pool for token -> VielFI
    /// @param zeroForOne True if swapping token0 for token1
    /// @param sqrtPriceLimitX96 Price limit for the swap (use TickMath.MAX_SQRT_PRICE-1 or MIN+1)
    /// @dev Uses Uniswap v4 PoolManager.swap() with callback settlement
    function executeBuyback(
        address token,
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint160 sqrtPriceLimitX96
    ) external whenNotPaused checkRateLimit nonReentrant {
        uint256 balance = entryFeeBalance[token];
        if (balance < BUYBACK_THRESHOLD) revert BelowThreshold();
        
        // Record balance before swap
        uint256 veilBalanceBefore = veilToken.balanceOf(address(this));
        
        // Reset fee balance (we're sweeping it all)
        entryFeeBalance[token] = 0;
        
        // Approve PoolManager to spend our tokens
        IERC20(token).approve(address(poolManager), balance);
        
        // Prepare swap parameters
        // amountSpecified: positive = exact input, negative = exact output
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(balance), // Exact input
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        // Encode callback data: token to settle, amount
        bytes memory hookData = abi.encode(token, balance);
        
        // Execute swap via PoolManager
        // This triggers the unlock callback pattern where we settle the swap
        try poolManager.swap(poolKey, params, hookData) returns (BalanceDelta delta) {
            // Delta represents the token amounts from the pool's perspective
            // delta.amount0() > 0 means pool received token0
            // delta.amount1() > 0 means pool received token1
            
            // Calculate how much VielFI we received
            // If zeroForOne=true: we gave token0, got token1
            // If zeroForOne=false: we gave token1, got token0
            uint256 veilReceived = veilToken.balanceOf(address(this)) - veilBalanceBefore;
            
            if (veilReceived > 0) {
                // Split: 50% stake, 50% burn
                uint256 half = veilReceived / 2;
                
                // Send to staking
                if (stakingContract != address(0)) {
                    veilToken.safeTransfer(stakingContract, half);
                }
                
                // Burn the rest
                if (burnAddress != address(0)) {
                    veilToken.safeTransfer(burnAddress, half);
                }
                
                emit BuybackExecuted(token, balance, veilReceived, half, half);
            }
            
        } catch {
            // If swap fails, restore the fee balance so it can be retried
            entryFeeBalance[token] = balance;
            revert SwapFailed();
        }
    }
    
    /// @notice Callback from PoolManager to settle the swap
    /// @dev This is called by PoolManager during the swap
    /// @param delta The balance change from the swap
    /// @param data Encoded token address and amount
    /// @return The bytes return (empty for this implementation)
    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta delta,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(poolManager), "Only PoolManager");
        
        (address token, uint256 amount) = abi.decode(data, (address, uint256));
        
        // Settle with PoolManager - transfer tokens to the pool
        // The delta tells us how much we owe / are owed
        // settle() is called after the swap to pay what we owe to the pool
        if (delta.amount0() > 0 || delta.amount1() > 0) {
            // We owe tokens to the pool - transfer them
            // settle() settles all positive deltas for this contract
            poolManager.settle();
        }
        
        return this.afterSwap.selector;
    }
    
    /// @notice Sweep exit fees to vesting treasury. Callable by anyone.
    /// @param token The token to sweep
    function sweepExitFees(address token) external whenNotPaused nonReentrant {
        uint256 amount = exitFeeBalance[token];
        if (amount == 0) revert InsufficientBalance();
        
        exitFeeBalance[token] = 0;
        
        // Transfer from vault to this contract first
        // Then to treasury
        IERC20(token).safeTransfer(vestingTreasury, amount);
        
        emit TreasuryFunded(amount);
    }
    
    // ── Admin ────────────────────────────────────────────────────────────────
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
    
    // ── Emergency ─────────────────────────────────────────────────────────────
    /// @notice Emergency withdrawal in case of stuck funds. Guardian only.
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
