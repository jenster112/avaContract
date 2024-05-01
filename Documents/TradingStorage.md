# TradingStorage Contract

## Table of Contents
1. [Purpose](#purpose)
2. [Storage Variables](#storage-variables)
    1. [Basic Counters](#basic-counters)
    2. [Arrays](#arrays)
    3. [Mappings](#mappings)
3. [Functionality](#functionality)

---

## Purpose

The `TradingStorage` contract acts as the central storage unit for trades, orders, and fees and data within the platform. The contract is used as a queryable storage for other contracts in the suite but it does hold some transactional methods primarily involving storage of trades.

---

## Storage Variables

### Basic Counters

- `maxTradesPerPair`: Maximum number of trades allowed for a given trading pair.
- `maxPendingMarketOrders`: Maximum number of pending market orders.
- `totalOI`: Total Open Interest across all pairs.
- `tvlCap`: OI cap on TVL locked in tranches
- `devFeesUSDC`: Developer fees in USDC.
- `govFeesUSDC`: Governance fees in USDC.

---

### Arrays

- `openLimitOrders`: Array of `OpenLimitOrder` structs storing details of all open limit orders. Used by executor bots.

---

### Mappings

#### General Mappings

- `_openTrades`: Contains details of open trades for a trader with a trading pair
- `_openTradesInfo`: Contains additional details about a open trade such as openinterest and lastupdate timelines.
- `_openTradesCount`: Tracks the number of open trades for a trader on a trading pair
- `_walletOI`: Holds the Open Interest per wallet across all pairs

#### Order Mappings

- `openLimitOrderIds`: Contains IDs of open limit orders for a trader/pair.
- `openLimitOrdersCount`: Counts the number of open limit orders per address.

#### Pending Orders Mappings

- `_reqIDpendingMarketOrder`: Mapping from a `uint` to a `PendingMarketOrder` struct. Contains pending market orders indexed by request ID.
- `_reqIDpendingLimitOrder`: Mapping from a `uint` to a `PendingLimitOrder` struct. Contains pending limit orders indexed by request ID.
- `pendingOrderIds`: Mapping from an `address` to an array of `uints`. Holds the IDs of pending orders per address.

#### Open Interest and Traders

- `pairTraders`: Mapping from a `uint` to an array of `addresses`. Holds the traders involved in each pair.
- `pairTradersId`: Nested mapping from an `address` to a `uint` to a `uint`. Holds the ID of traders per pair.
- `openInterestUSDC`: Mapping from a `uint` to an array of two `uints`. Holds the Long and short Open Interest in USDC for each pair.

---

## Functionality

### `handleDevGovFees(...)`
Handles the calculation of opening fees, referral rebates and finally distributes it to vault, gov and devs.

### `storeTrade(...)`
tores a new trade and updates the associated trade information. 

### `registerPartialTrade(...)`
Registers a partial trade and updates trade information accordingly.

### `unregisterTrade(...)`
Unregisters a trade and deletes trade information accordingly.

### `updateOpenLimitOrder(...)`
Updates an existing open limit order.

### `applyReferralOpen(...)`
Applies the referral trading discount while opening of trade.

### `applyReferralClose(...)`
Applies the referral trading discount while opening of trade.

---