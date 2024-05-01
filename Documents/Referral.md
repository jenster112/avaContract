# Referral Contract

## Table of Contents
1. [Purpose](#purpose)
2. [Functions](#functions)
---

## Purpose
The Referral contract is designed to handle a multi-tiered referral program. It is providing discount in trading fees to referral users and rewards to referrers.

---

## Functions

### `setGov(...)`
Sets the governance address.

### `setHandler(...)`
Sets the handler status for an address.

### `setTier(...)`
Sets the tier details for a given tier ID.

### `setReferrerTier(...)`
Sets the tier for a given referrer address.

### `setTraderReferralCode(...)`
Sets the referral code for a given trader.

### `setTraderReferralCodeByUser(...)`
Allows a trader to set their own referral code.

### `registerCode(...)`
Registers a new referral code for the message sender.

### `setCodeOwner(...)`
Changes the owner of a given referral code.

### `govSetCodeOwner(...)`
Allows governance to set the owner of a referral code.

### `traderReferralDiscount(...)`
Fetches trader discount and referrer rebate information.

### `getTraderReferralInfo(...)`
Fetches the referral code and referrer for a given trader.

---
