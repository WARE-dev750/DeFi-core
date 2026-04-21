# TOKENOMICS.md: $VielFI Token Economic Model

## 1. Token Overview
The **$VielFI** token is the native utility and governance asset of the VielFI Protocol. It coordinates the interests of users, liquidity providers, and the protocol treasury through mathematical incentives.

*   **Ticker:** $VielFI
*   **Total Supply:** 1,000,000,000 (Fixed; non-inflationary)
*   **Asset Standard:** ERC-20 (L2-Native)

## 2. Token Allocation & Vesting
To ensure long-term stability and prevent market manipulation, all team and investor tokens are held in **Smart Contract Escrow** with strict vesting schedules.

| Category | Allocation | Vesting Schedule | Purpose |
| :--- | :--- | :--- | :--- |
| **Liquidity Mining** | **40%** | 5-Year Linear Emission | Incentivizing deep liquidity for shielded pools. |
| **Protocol Treasury** | **20%** | 3-Year Linear Vesting | Funding for Tier-1 audits, R&D, and legal costs. |
| **Founders & Team** | **15%** | 1-Year Cliff; 4-Year Vesting | Aligning incentives for long-term development. |
| **Private Investors** | **15%** | 6-Month Cliff; 2-Year Vesting | Raising capital for initial security audits. |
| **Airdrop & Community**| **10%** | 100% Unlocked at Launch | Bootstrapping initial protocol volume and users. |

## 3. Revenue Model & Gas Economics
To account for the high computational cost of Zero-Knowledge proof verification, VielFI utilizes a **Hybrid Fee Structure**:

1.  **The Proof Verification Fee (Flat):** A fixed cost (calculated in gas) charged on every shielding transaction to cover the cost of ZK-proof verification on the L2.
2.  **The Protocol Service Fee (0.3%):** A percentage-based fee charged on the volume of assets being privatized.
3.  **Revenue Distribution:**
    *   **50%** distributed to $VielFI stakers as "Real Yield."
    *   **25%** to the Protocol Treasury for ongoing operations.
    *   **25%** used for "Buyback-and-Burn" to increase token scarcity.

## 4. Sybil-Resistant Liquidity Incentives
To prevent "Whales" from gaming the system by splitting capital into multiple wallets, VielFI uses **Time-Weighted Staking**:

*   **The Multiplier:** Liquidity rewards are not based solely on the amount of capital. They are multiplied based on the **duration** the capital has been locked in the pool.
*   **Governance Locking:** Users who lock $VielFI for longer periods (e.g., 6 months to 2 years) receive higher voting power and a larger share of the protocol revenue.
*   **The Result:** This makes it mathematically more profitable to keep capital in one "aged" account rather than splitting it into new wallets.

## 5. Institutional "Whitelisted" Liquidity
To attract high-net-worth capital while maintaining regulatory resilience, the protocol supports **Whitelisted Vaults**:
*   Large liquidity providers (Hedge Funds/Market Makers) can provide liquidity to specific "Institutional-only" pools.
*   These pools allow institutions to utilize the privacy layer while maintaining the "Source of Funds" transparency required by their own internal auditors.
