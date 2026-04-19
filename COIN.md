## 1. Token Specification
The **$NOFACE** token is a freely tradable, standardized ERC-20 asset that serves as the core utility, governance, and security instrument for the NOFACE Protocol.

*   **Ticker:** $NOFACE
*   **Total Supply:** 1,000,000,000 (Fixed; non-inflationary)
*   **Decimals:** 18
*   **Contract Standard:** OpenZeppelin ERC-20 with Permit (EIP-2612)

## 2. Technical Logic: The "Under-the-Hood" Privacy Model
NOFACE Protocol utilizes **Zero-Knowledge (ZK) Wrappers** that operate completely invisibly to the end user. To solve the "Fresh Wallet" gas problem, the protocol completely abstracts away network fees.

1.  **The Deposit:** Users deposit transparent assets (e.g., ETH, USDC) into the NOFACE Vault.
2.  **The Internal Ledger:** The protocol issues a private, wrapped version (e.g., **zk-USDC**) entirely under the hood. Users never manage wrapped tokens in their wallets; they simply see their "Private Balance" on the NOFACE interface.
3.  **Gasless Transactions:** Users move or trade these assets by signing digital "ZK-Intents." They **do not need to hold ETH or $NOFACE** to pay for gas. The off-chain Solvers pay the network gas fee and automatically deduct the protocol fee (0.3%) directly from the asset being traded.

## 3. Token Utility & Value Accrual
$NOFACE derives its market value through structural buy-pressure and protocol security mechanics, without forcing retail users to hold it just to transact.

### A. Solver Staking & Slashing (Security Bond)
*   To process user Intents and earn execution fees, **Solvers** must lock up and stake a significant amount of $NOFACE.
*   If a Solver attempts to front-run a user or act maliciously off-chain, the protocol mathematically rejects their proof and **slashes** their staked $NOFACE. This creates massive institutional demand for the token.

### B. Fee Abstraction & Structural Buy-Pressure
*   Every time a user trades or unshields, a 0.3% protocol fee is levied invisibly in the asset being traded (e.g., USDC).
*   The protocol takes a portion of this collected USDC, programmatically **market-buys $NOFACE** in the background, and distributes it to the treasury and stakers.

### C. Governance & Yield Distribution
*   $NOFACE holders participate in the **NOFACE DAO**, voting on fee structures, new "Clean Set" compliance parameters, and treasury management.
*   Users who "Stake" (lock) their $NOFACE tokens receive a proportional share of the protocol’s generated transaction fees, providing a "Real Yield" to long-term holders.

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
*   A dedicated percentage of every transaction fee is used by the protocol to market-buy $NOFACE tokens and permanently "Burn" them (sending them to the `0x00...` address).
*   Because $NOFACE is freely tradable on public DEXs, this creates continuous **deflationary pressure** where the total supply of the token decreases as the protocol gains adoption, inherently raising the value of the remaining supply.

### B. The "Whale" Multiplier
*   Liquidity providers who hold and stake a minimum threshold of $NOFACE receive a "Multiplier" on their liquidity mining rewards.
*   This encourages large capital holders to maintain a significant position in the $NOFACE token to maximize their returns, heavily reducing open-market sell pressure.

