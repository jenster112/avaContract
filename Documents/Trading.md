# Trading

## Table of Contents
1. [Purpose](#purpose)
2. [Trading Methods](#trading-methods)
3. [Updation Methods](#updation-methods)

## Purpose
The "Trading" contract is end user interaction point with the whole suite. It has methods enabling opening/closing trade, deposit/withdraw margin, add/cancel limit orders.

---

## Trading Methods

### `openTrade(...)`
Opens a new Market trade or places new limit order.

### `closeTradeMarket(...)`
Closes a trade using market execution. Allows for partial execution by passing collateral amount to close.

### `executeLimitOrder(...)`
Called by Executor bots to execute eligible Limit orders. Limit order executed can be Open, Stop Loss, Take Profit or Liquidation orders.

---

## Updation Methods

### `updateMargin(...)`
A risk management tool to traders. Allow de-leveraging/over-leveraging by depositing/withdrawing collateral for a given position

### `updateOpenLimitOrder(...)`
Updates execution price/SL/TP for a open limit order

### `cancelOpenLimitOrder(...)`
Cancels an open limit order

### `updateTpAndSl(...)`
Allows update to the take-profit and stop-loss for a open position

---

