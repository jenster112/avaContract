# Price Aggregator Contract

## Table of Contents
1. [Purpose](#purpose)
2. [Price Fetching and Handling](#price-fetching-and-handling)
3. [Pending Orders Handling](#Pending-Orders-Handling)

## Purpose
Price Aggregator aggregates pyth price updates, verifies it with chainlink back up and corresponding invokes callbacks for trading operations. 

---

## Price Fetching and Handling

### `fulfill(...)`
Fulfills an order by updating price feeds and invoking corresponding callbacks.

### `getPrice(...)`
Creates an order and return the order ID

---

## Pending Orders Handling

### `storePendingSlOrder(...)`
Store information about a pending stop-loss (SL) order

### `storePendingMarginUpdateOrder(...)`
Stores a pending margin update order.

### `unregisterPendingSlOrder(...)`
Removes a registered pending stop-loss order.

### `unregisterPendingMarginUpdateOrder(...)`
Removes a registered pending margin update order.

### `pendingSlOrders(...)`
Fetches a pending stop-loss order.

### `pendingMarginUpdateOrders(...)`
Fetches a pending margin update order.

---