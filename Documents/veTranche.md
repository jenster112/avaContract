# VeTranche

## Table of Contents
1. [Purpose](#purpose)
2. [Vesting Methods](#vesting-methods)
3. [Updation Methods](#updation-methods)

## Purpose
VeTranche contract allows LP to lock their tranche LP positions to earn boosted yields.
---

## Vesting Methods

### `lock(...)`
Locks a specified amount of shares until a specified end time. Yield Multiplier is calculated of the lock duration. 

### `unlock(...)`
Unlocks a specific tokenId and rewards are claimed. 

### `forceUnlock(...)`
Force unlocks a token if its lock time has passed. To be called by keeper bots

### `checkUnlockFee(...)`
Calculate the unlock fee for a given token ID based on remaining lockTime

---

## Vesting Methods

### `distributeRewards(...)`
Distributes the reward among the vesting participants. Called by vault Manager

### `claimRewards(...)`
Claims rewards accumulated by tokenId. Callable only by holder of that tokenId.

---

