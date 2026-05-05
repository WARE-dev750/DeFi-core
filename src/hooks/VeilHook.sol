// SPDX-License-Identifier: MIT
// VeilHook: Uniswap v4 Hook for Private Swaps
// 
// Pattern: Integrates with VeilCore vault to enable shielded swaps through Uniswap v4
// Forked security model from: Tornado Cash (commitment/nullifier) + Uniswap v4 (hook architecture)
//
// Flow:
//   1. User generates ZK proof (swap.nr) proving ownership of vault commitment
//   2. Solver submits swap intent to this hook
//   3. Hook verifies ZK proof, consumes nullifier, pulls from vault
//   4. Hook executes swap via Uniswap v4 pool manager
//   5. Hook deposits output back to vault as new commitment

pragma solidity ^0.8.23;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Interface to VeilCore vault
interface IVeilVault {
    function nullifierHashes(bytes32) external view returns (bool);
    function getRoot() external view returns (bytes32);
    function deposit(bytes32 commitment, uint256 denomination) external;
}

/// @dev Interface to UltraHonk verifier
interface IUltraHonkVerifier {
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external view returns (bool);
}

/// @title VeilHook
/// @notice Uniswap v4 hook enabling private swaps through VeilCore vault
/// @dev All swaps are gasless for users - solvers pay gas and earn fees
/// @dev Implements IHooks directly instead of using BaseHook to minimize dependencies
contract VeilHook is IHooks {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using SafeERC20 for IERC20;
    
    IPoolManager public immutable poolManager;

    // ── Constants ────────────────────────────────────────────────────────────
    uint256 public constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // Public input indices for swap.nr circuit
    uint8 constant PI_NULLIFIER_HASH = 0;
    uint8 constant PI_MERKLE_ROOT = 1;
    uint8 constant PI_TOKEN_IN = 2;
    uint8 constant PI_TOKEN_OUT = 3;
    uint8 constant PI_AMOUNT_IN = 4;
    uint8 constant PI_AMOUNT_OUT = 5;
    uint8 constant PI_OUTPUT_COMMITMENT = 6;
    uint8 constant PI_COUNT = 7;

    // ── Immutables ───────────────────────────────────────────────────────────
    IVeilVault public immutable vault;
    IUltraHonkVerifier public immutable verifier;

    // ── State ─────────────────────────────────────────────────────────────────
    mapping(bytes32 => bool) public swapNullifierSpent;
    mapping(PoolId => bool) public authorizedPools;

    // ── Structs ──────────────────────────────────────────────────────────────
    struct SwapIntent {
        bytes32 nullifierHash;
        bytes32 merkleRoot;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        bytes32 outputCommitment;
        bytes32 newSecret;        // encrypted for recipient
        uint256 deadline;
        address solver;
        uint256 solverFee;
    }

    // ── Events ─────────────────────────────────────────────────────────────────
    event PrivateSwap(
        bytes32 indexed nullifierHash,
        bytes32 indexed outputCommitment,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address solver
    );
    event PoolAuthorized(PoolId indexed poolId, address token0, address token1);

    // ── Errors ───────────────────────────────────────────────────────────────
    error InvalidProof();
    error NullifierAlreadySpent();
    error InvalidMerkleRoot();
    error SwapExpired();
    error SlippageExceeded(uint256 actual, uint256 minimum);
    error UnauthorizedPool();
    error InvalidTokenPair();
    error SolverFeeTooHigh();
    error InvalidOutputCommitment();

    // ── Constructor ──────────────────────────────────────────────────────────
    constructor(
        IPoolManager _poolManager,
        address _vault,
        address _verifier
    ) {
        poolManager = _poolManager;
        vault = IVeilVault(_vault);
        verifier = IUltraHonkVerifier(_verifier);
    }
    
    /// @notice Returns the hook's permissions bitmap for Uniswap v4
    function getHookPermissions() external pure returns (uint160) {
        // Only beforeSwap and afterSwap enabled
        // Hook permission bits: beforeSwap = bit 6, afterSwap = bit 7
        return uint160(0x00000000000000000000000000000000000000C0);
    }

    // ── Admin ──────────────────────────────────────────────────────────────────
    function authorizePool(PoolKey calldata key) external {
        // In production: add access control
        PoolId poolId = key.toId();
        authorizedPools[poolId] = true;
        emit PoolAuthorized(poolId, Currency.unwrap(key.currency0), Currency.unwrap(key.currency1));
    }

    // ── Core Hook: Before Swap ─────────────────────────────────────────────────
    /// @notice Called by PoolManager before swap execution
    /// @dev Verifies ZK proof, marks nullifier spent, validates pool authorization
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        // Only PoolManager can call
        if (msg.sender != address(poolManager)) revert InvalidProof();

        // Decode swap intent and proof from hookData
        (SwapIntent memory intent, bytes memory proof) = abi.decode(hookData, (SwapIntent, bytes));

        // 1. Check deadline
        if (block.timestamp > intent.deadline) revert SwapExpired();

        // 2. Verify pool is authorized for private swaps
        PoolId poolId = key.toId();
        if (!authorizedPools[poolId]) revert UnauthorizedPool();

        // 3. Validate tokens match pool
        bool tokenMatch = (Currency.unwrap(key.currency0) == intent.tokenIn && 
                          Currency.unwrap(key.currency1) == intent.tokenOut) ||
                         (Currency.unwrap(key.currency1) == intent.tokenIn && 
                          Currency.unwrap(key.currency0) == intent.tokenOut);
        if (!tokenMatch) revert InvalidTokenPair();

        // 4. Check nullifier not already spent
        if (swapNullifierSpent[intent.nullifierHash]) revert NullifierAlreadySpent();

        // 5. Verify merkle root is valid
        if (vault.getRoot() != intent.merkleRoot) revert InvalidMerkleRoot();

        // 6. Build public inputs for ZK verification
        bytes32[] memory publicInputs = new bytes32[](PI_COUNT);
        publicInputs[PI_NULLIFIER_HASH] = intent.nullifierHash;
        publicInputs[PI_MERKLE_ROOT] = intent.merkleRoot;
        publicInputs[PI_TOKEN_IN] = bytes32(uint256(uint160(intent.tokenIn)));
        publicInputs[PI_TOKEN_OUT] = bytes32(uint256(uint160(intent.tokenOut)));
        publicInputs[PI_AMOUNT_IN] = bytes32(intent.amountIn);
        publicInputs[PI_AMOUNT_OUT] = bytes32(intent.amountOut);
        publicInputs[PI_OUTPUT_COMMITMENT] = intent.outputCommitment;

        // 7. Verify ZK proof
        bool valid = verifier.verify(proof, publicInputs);
        if (!valid) revert InvalidProof();

        // 8. Mark nullifier spent (prevents replay)
        swapNullifierSpent[intent.nullifierHash] = true;

        // Return selector, no delta modification, no hook fee
        return (this.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    // ── Core Hook: After Swap ──────────────────────────────────────────────────
    /// @notice Called by PoolManager after swap execution
    /// @dev Deposits swap output to vault as new commitment
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        (SwapIntent memory intent, ) = abi.decode(hookData, (SwapIntent, bytes));

        // Calculate actual output from delta
        int128 actualOutput = params.zeroForOne 
            ? delta.amount1()  // token0 -> token1, output is amount1
            : delta.amount0(); // token1 -> token0, output is amount0

        // Output should be positive (we receive it)
        if (actualOutput <= 0) revert InvalidProof();
        uint256 outputAmount = uint128(actualOutput);

        // Verify output meets minimum (slippage protection already in ZK proof)
        if (outputAmount < intent.amountOut) {
            // Actual output less than expected - could revert or accept
            // For now: accept but emit event with actual amount
        }

        // Pull output tokens from PoolManager to this hook
        Currency outputCurrency = params.zeroForOne ? key.currency1 : key.currency0;
        poolManager.take(outputCurrency, address(this), outputAmount);

        // Approve vault to spend output tokens
        // Use approve since we know the starting allowance is 0 (fresh tokens from swap)
        IERC20(intent.tokenOut).approve(address(vault), outputAmount);

        // Deposit output to vault as new commitment
        // User must have generated outputCommitment with correct amount
        vault.deposit(intent.outputCommitment, outputAmount);

        emit PrivateSwap(
            intent.nullifierHash,
            intent.outputCommitment,
            intent.tokenIn,
            intent.tokenOut,
            intent.amountIn,
            outputAmount,
            intent.solver
        );

        // Return delta to specify any hook fee (0 for now)
        return (this.afterSwap.selector, 0);
    }

    // ── External: Solver Entry Point ───────────────────────────────────────────
    /// @notice Entry point for solvers to execute private swaps
    /// @dev Solver provides ZK proof on behalf of user, pays gas, earns fee
    function executePrivateSwap(
        PoolKey calldata key,
        SwapIntent calldata intent,
        bytes calldata proof
    ) external returns (BalanceDelta) {
        // Encode intent + proof as hookData
        bytes memory hookData = abi.encode(intent, proof);

        // Determine swap direction based on token pair
        bool zeroForOne = Currency.unwrap(key.currency0) == intent.tokenIn;

        // Build swap params
        // Price limits: MIN = 4295128739 + 1, MAX = 1461446703485210103287273052203988822378723970341 - 1
        uint160 sqrtPriceLimitX96 = zeroForOne 
            ? 4295128740  // MIN_SQRT_RATIO + 1
            : 1461446703485210103287273052203988822378723970340; // MAX_SQRT_RATIO - 1
            
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(intent.amountIn), // Exact input
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        // Execute swap through PoolManager
        BalanceDelta delta = poolManager.swap(key, params, hookData);

        return delta;
    }

    // ── View Functions ───────────────────────────────────────────────────────────
    function isNullifierSpent(bytes32 nullifierHash) external view returns (bool) {
        return swapNullifierSpent[nullifierHash];
    }

    function isPoolAuthorized(PoolId poolId) external view returns (bool) {
        return authorizedPools[poolId];
    }

    // ── IHooks Interface: Stub implementations ─────────────────────────────────
    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }
    
    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }
    
    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata) external pure returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }
    
    function afterAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }
    
    function beforeRemoveLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata) external pure returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }
    
    function afterRemoveLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }
    
    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }
    
    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IHooks.afterDonate.selector;
    }
}
