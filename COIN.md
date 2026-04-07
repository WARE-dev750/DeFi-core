## 1. Token Specification
The **$NOFACE** token is a standardized ERC-20 asset that serves as the core utility and governance instrument for the NOFACE Protocol.

*   **Ticker:** $NOFACE
*   **Total Supply:** 1,000,000,000 (Fixed; non-inflationary)
*   **Decimals:** 18
*   **Contract Standard:** OpenZeppelin ERC-20 with Permit (EIP-2612)

## 2. Technical Logic: The "Shielded Wrapper" Model
NOFACE Protocol does not attempt to create a new layer-1 privacy blockchain. Instead, it utilizes **Zero-Knowledge (ZK) Wrappers** for existing liquid assets.

1.  **The Vault:** Users deposit transparent assets (e.g., ETH, USDC) into the NOFACE Vault.
2.  **The zk-Asset:** The protocol issues a private, wrapped version (e.g., **zk-USDC**). 
3.  **The Privacy Layer:** Inside the vault, these zk-assets are moved via **Nullifier-based transactions**. $NOFACE is the required "Gas" or "Toll" for every shielding/unshielding event.

## 3. Token Utility & Value Accrual
$NOFACE derives its market value through three primary protocol mechanisms:

### A. Privacy-as-a-Service (Shielding Fees)
*   Every time a user "Shields" (privatizes) or "Unshields" (withdraws) an asset, a 0.3% protocol fee is levied.
*   A percentage of this fee is denominated in $NOFACE. This creates constant buying pressure on the token as protocol volume increases.

### B. Governance & Parameter Control
*   $NOFACE holders participate in the **NOFACE DAO**. 
*   Voting power is used to adjust fee structures, select new "Shielded Assets" for inclusion, and manage the Protocol Treasury.

### C. Staking & Yield Distribution
*   Users who "Stake" (lock) their $NOFACE tokens receive a proportional share of the protocol’s generated transaction fees.
*   This provides a recurring yield to long-term holders, incentivizing them to remove supply from the open market.

## 4. Genesis Allocation & Vesting
To ensure institutional-grade trust and prevent market manipulation, the total supply is distributed across five categories with strict vesting schedules.

| Allocation | Percentage | Vesting Schedule | Purpose |
| :--- | :--- | :--- | :--- |
| **Liquidity Mining** | **40%** | 5-Year Linear | Incentivizing "Whale" liquidity providers. |
| **Protocol Treasury** | **20%** | 3-Year Linear | Funding for audits, legal, and R&D. |
| **Team & Founders** | **15%** | 1-Year Cliff; 4-Year Linear | Long-term commitment from core developers. |
| **Private Investors** | **15%** | 6-Month Cliff; 2-Year Linear | Initial capital for Tier-1 security audits. |
| **Community Airdrop** | **10%** | 100% Unlocked | Bootstrapping initial users and volume. |

## 5. Economic Stability Mechanisms

### A. Buyback & Burn
*   A dedicated 0.1% of every transaction fee is used by the protocol to market-buy $NOFACE tokens and permanently "Burn" them (sending them to the `0x00...` address).
*   This creates a **deflationary pressure** where the total supply of $NOFACE decreases as the protocol gains adoption.

### B. The "Whale" Multiplier
*   Liquidity providers who hold and stake a minimum threshold of $NOFACE receive a "Multiplier" on their rewards.
*   This encourages large capital holders to maintain a significant position in the $NOFACE token to maximize their returns, reducing sell-pressure.

---
