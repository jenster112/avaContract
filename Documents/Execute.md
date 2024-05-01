# Execute Contract

## Table of Contents
1. [Purpose](#purpose)
2. [Limit Order Management](#limit-order-management)
3. [Reward Management](#reward-management)
4. [Query Functions](#query-functions)

## Purpose
The "Execute" contract is designed to manage Execution of limit orders in Avantis Perpetuals. It oversees the initialization of the system, updating timeouts, storing and unregistering triggered limit orders, and the distribution and claiming of rewards for those triggers.

---

## Limit Order Management

### `storeFirstToTrigger(...)`
Stores the first address to trigger a limit order.

### `unregisterTrigger(...)`
Unregisters a triggered limit order.

### `setOpenLimitOrderType(...)`
Sets the type of an open limit order.

---

## Reward Management

### `distributeReward(...)`
Distributes the reward for a triggered limit order.

### `claimTokens()`
Claims the pending token reward for the caller.

---

