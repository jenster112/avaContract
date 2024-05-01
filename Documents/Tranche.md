# Tranche

## Table of Contents
1. [Purpose](#purpose)
2. [Trading Methods](#trading-methods)
3. [Updation Methods](#updation-methods)

## Purpose
Tranches act as a risk management tool for LPs. Tranche contract is a ERC4626 vault allowing LPs to deposit, mint, redeem and withdraw USDC. Vault Manager distributes rewards to tranches which generates real yield for tranche share holders.
---

## Economic Methods

### `reserveBalance(...)`
Reserves a certain amount of assets for trading OI. Called by the vault manager.

### `releaseBalance(...)`
Releases the Trading OI. Called by vault manager on position close.

### `withdrawAsVaultManager(...)`
Allows the vault manager to withdraw a specific amount of assets. Called by Vault Manager when distributing profits to trader in case profit is not covered by collateral accumulated in vault Manager. 

---

## Updation Methods

### `_deposit(...)`
Internal method to deposit USDC in tranche. Sends the fees to the Vault Manager. 

### `_withdraw(...)`
Internal function to handle withdrawal actions. Sends the fees to the Vault Manager. 

---

