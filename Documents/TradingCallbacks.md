# Trading Callbacks

## Table of Contents
1. [Purpose](#purpose)
2. [Trading Methods](#trading-methods)
3. [Updation Methods](#updation-methods)

## Purpose
The "Trading Callback" contract execution logic for all user facing trading methods. Callbacks invovked in execution flow verfies and updates the Trading storage with resultant trades.

---

## Trading Methods

### `openTradeMarketCallback(...)`
Callback function for opening a trade on the market.

### `closeTradeMarketCallback(...)`
 Callback function for closing a trade on the market.

### `executeLimitOpenOrderCallback(...)`
Callback function for executing limit open orders.

### `executeLimitCloseOrderCallback(...)`
Callback function for executing limit close orders(TP/SL/LIQ)

### `updateSlCallback(...)`
Updates stop loss order based on aggregator's callback

### `updateMarginCallback(...)`
Callback function for updating a trader's margin.(Deposit/Withdraw)

---

## Updation Methods

### `_registerTrade(...)`
Registers a new trade, calculates fees, reserves OI from vaults, starts rolloever fee counter and updates trading storage

### `_unregisterTrade(...)`
Registers a new trade, calculates Pnl and Fees, releases OI from vaults, sends usdc back to trader and updates trading storage

---

