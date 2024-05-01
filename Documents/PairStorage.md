# PairStorage Contract

## Table of Contents
1. [Purpose](#purpose)
2. [Storage Variables](#storage-variables)
    1. [Basic Counters](#basic-counters)
    2. [Mappings](#mappings)
3. [Functionality](#functionality)

---

## Purpose

The `PairStorage` contract serves mainly as a storage for trading pair-related parameters.The contract is mainly used as a queryable storage for other contracts in the suite. It does not possess transactional functionalities on its own.

---

## Storage Variables

### Basic Counters

- `currentOrderId`: Holds the value of the current order ID. Used while generating market/limit orders
- `pairsCount`: Provides a count of the number of trading pairs.
- `groupsCount`: Provides a count of the number of trading groups(Crypto/Forex/Commodities)
- `feesCount`: Provides a count of the number of fee configurations.
- `skewedFeesCount`: Provides a count of the number of skewed fee configurations.

---

### Mappings

#### General Mappings

- `pairs`: Mapping from a `uint` to a `Pair` struct. Contains details of trading pairs.
```
    struct Pair {
        string from;
        string to;
        Feed feed;
        BackupFeed backupFeed;
        uint spreadP;
        uint groupIndex;
        uint feeIndex;
        uint groupOpenInterestPecentage;
        uint maxWalletOI;
    }
```
- `groups`: Mapping from a `uint` to a `Group` struct. Contains details of trading groups.
```
    struct Group {
        string name;
        uint minLeverage;
        uint maxLeverage;
        uint maxOpenInterestP; 
    }
```
- `fees`: Mapping from a `uint` to a `Fee` struct. Contains details of fees.
```
    struct Fee {
        string name;
        uint openFeeP;
        uint closeFeeP; 
        uint limitOrderFeeP; 
        uint minLevPosUSDC; 
    }
```

#### Specialized Mappings

- `isPairListed`: A double mapping from `string` to `string` to a `bool`. Indicates whether a specific pair is listed.
- `groupOIs`: Mapping from a `uint` to an array of two `uints`. Holds the short and long OI info for groups
- `lossProtection`: A nested mapping from `uint` to `uint` to `uint`. Keeps track of the loss protection provided for pairs at different tier levels.
- `skewFees`: Mapping from a `uint` to a `SkewFee` struct. Contains details of skew fees used to calculate opening fee under different skews.

---




