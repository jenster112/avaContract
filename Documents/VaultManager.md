# Vault Manager

## Table of Contents
1. [Purpose](#purpose)
2. [Rewards](#reward-methods)
3. [Tranche Interactions](#Tranche-methods)

## Purpose
Vault Manager holds trader collateral, distributes allocated rewards to tranches and sends back profit to the trader. All the fees generated in trading operations as well as LPing operations is marked as rewards in vault manager.
---

## Reward 

### `allocateRewards(...)`
Allocates rewards to the LPs. Called by other contracts in suite to mark certain collateral as rewards.

### `distributeRewards(...)`
Distributes the allocated rewards among junior and senior tranches. Distributes Vesting rewards as well to lockers in veTranches.

### `sendReferrerRebateToStorage(...)`
Sends a part of rewards as a referral rebate to trading storage. referrer rebates are accumulated in trading storage contract.

### `sendUSDCToTrader(...)`
Sends USDC tokens to a trader. Called by Callbacks during unregister flow. Taps into Tranches if vault Manager's collateral falls short.

### `receiveUSDCFromTrader(...)`
Receives USDC tokens from a trader. Called by callback contract. Vault Fee is allocated as Lp rewards

---

## Tranche Interactions

### `reserveBalance(...)`
Reserves balance for junior and senior tranches based on reserve Ratio

### `releaseBalance(...)`
Releases balance to junior and senior tranches according to release ratio.

### `getBalancingFee(...)`
Calculates the balancing fee for deposits or withdrawals. Fees is charged is tranche ratio falls outside of 62.5%. 

### `getReserveRatio(...)`
Retrieves the resrve Ratio given current state junior/Senior tranches. 

### `getReleaseRatio(...)`
Calculates the release ratio based on total reserved amounts in tranches.

---

