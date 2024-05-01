# PairInfos Contract

## Table of Contents
1. [Purpose](#purpose)
2. [Margin Fee Management](#Margin-Fees)
3. [Pnl And Price Impact](#pnl)
4. [Loss Protection](#query-functions)

## Purpose
The "PairInfos" contract is designed to store margin fee related params, loss protection for each pair and has methods to derive them given current skew and config params.

---

## Margin Fee Management

### `storeTradeInitialAccFees(...)`
Called while registering trade. Stores margin fee accumulator at start of a trade.

### `getPendingAccRolloverFees(...)`
Retrieves the pending accumulated rollover fees for a given trading pair.

### `getLongMultiplier(...)`
Retrieves the long multiplier for margin fees for a given trading pair Based on config and skew.

### `getUtilizationMultiplier(...)`
Retrieves the utilization multiplier for a given trading pair based on TVL utlization. 

### `getTradeRolloverFee(...)`
Calculates the trade rollover fee for a given trader and trading pair. 

---

## Pnl And Price Impact

### `getTradeValue(...)`
Get trade value, PnL, and fees for a trade after deducting margin fees

### `getTradePriceImpact()`
Calculate price impact on trade opening based on one percent depths. Only for Crypto Group.

---

## Loss Protection

### `lossProtectionTier(...)`
Calculate and return the loss protection tier for a given trade based on current skew

---
