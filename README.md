# Avantis Perpetuals

This project is a comprehensive solution for Avantis Perp Exchange, built using Foundry. It includes a variety of smart contracts, tests, and utility scripts to ensure seamless deployment, updating, and upgrading of the exchange.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Deployed Addresses](#deployed-addresses)
- [Commands](#commands)
- [Additional Resources](#additional-resources)

## Directory Structure

- **Smart Contracts**: Located in the `src/` folder.
- **Tests**: Test scripts are located in `test/` with unit and fixtures.
- **Scripts**: Deployment, updating, upgrading and utility scripts can be found in the `script/` folder. 

## Deployed Addresses

### Sepolia Testnet
```
{
    "USDC": "0xa1A1422aa49AF1639A99A3174Aa004970f79224c",
    "ProxyAdmin": "0x1f99BFCF008b630d1BaF7123707141F0179706da",
    "TradingStorage": "0xDaC9aDAEB61a3da71A789F4AE8D2c877cE823C15",
    "PairStorage": "0xb12Ec29f00fB2eC2eA52A513F74924738707b521",
    "PairInfos": "0xd3592342AF7c2b377C6A0BB48257d4218d3B1259",
    "Trading": "0xd024CbaA3285e2EF745e9913349d6a436c715147",
    "Execute": "0x31cAD753fb2529742d4934aCB5bf25e29184587a",
    "TradingCallbacks": "0xdc9dACEC5Cc3AAfD43215E3b21F73f48E28BB6bC",
    "PriceAggregator": "0xb5257143e54A8DC36d61455E76cA7B23288A451E",
    "VaultManager": "0xF38a91cE681542a3fB18D567F5E0304A5C732bFD",
    "JuniorTranche": "0x12168d4fa2C2b552E9A1c8908AF2B36b40c83654",
    "SeniorTranche": "0x79325ccF0242a03d97d34d00620510Ad7DE7B9DF",
    "JuniorVeTranche": "0xA43f9BCEa9c53a4B33963d2Dc9bA3293a15eF97B",
    "SeniorVeTranche": "0x3508c8a3888a534c4ea8A47ff37aAc7954A72565",
    "Referral": "0x655b92c8E1196dD5233fF3BE19F900257780038e",
    "MultiCall": "0xA0B9B9B3e0154cc4065Ee83fB533De878EE176BF",
    "Network": "Base Sepolia"
}
```


### Base Mainnet
```
{
    "ProxyAdmin": "0x2D898e46a20eBFc1424d4BBF69bacD92dc1ae8bb",
    "TradingStorage": "0x8a311D7048c35985aa31C131B9A13e03a5f7422d",
    "PairStorage": "0x92Ed158d5e423CFdc9eed5Bd7328FFF7CeD6fF94",
    "PairInfos": "0x81F22d0Cc22977c91bEfE648C9fddf1f2bd977e5",
    "Trading": "0x5FF292d70bA9cD9e7CCb313782811b3D7120535f",
    "Execute": "0xdbDd7B8a8747904f53eb7AEF655a6FF81e2c306a",
    "TradingCallbacks": "0x0C16ff40065Cc3Ab4bc55B60E447504AFB9C7970",
    "PriceAggregator": "0x64e2625621970F8cfA17B294670d61CB883dA511",
    "VaultManager": "0xe9fB8C70aF1b99F2Baaa07Aa926FCf3d237348DD",
    "JuniorTranche": "0x944766f715b51967E56aFdE5f0Aa76cEaCc9E7f9",
    "SeniorTranche": "0x83084cB182162473d6FEFfCd3Aa48BA55a7B66F7",
    "JuniorVeTranche": "0x7BF094c44B3cFF8C95e06a76557443F5408efB05",
    "SeniorVeTranche": "0x6914110eFe4E61cFa0F28dE5f6606bAa33D21693",
    "Referral": "0xA96f577821933d127B491D0F91202405B0dbB1bd",
    "Multicall":"0x118f99aBD7101b528B17AB91c7d7aeFD2Cc1E5c0",
    "USDC": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "Network": "Base Mainnet"
}

```

## Deployment Guide

This guide provides a detailed sequence for deploying smart contracts. Please follow the steps meticulously to ensure successful deployment.

 1) Deploy All Contracts (39 Txns)(0.14ETH)
Start by deploying all the necessary contracts with the following commands:

```shell
forge script script/Deployment/Base/deployBase.s.sol:DeployScript --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv
forge script script/Deployment/Base/deployBaseMulticall.s.sol:MulticallDeployScript --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv
```

2) Generate Address List using parser. List is generated in contractAddressesBase.json
`python3 contractAddressesBase.py`

3) Update the Addresses manually in address.sol lib

4) Wire the contracts (31 Txns)(0.01 ETH)
```shell
forge script script/Deployment/Base/wire.s.sol:Wire --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv
```

6) Setup Pairs (24 Txns)(0.01 ETH)
```shell
forge script script/Deployment/Base/setupPairs.s.sol:SetupPairs --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv
```

7) Setup Loss Protection(25 Txns)(0.01ETH)
```shell
forge script script/Deployment/Base/SetupLossProtection.s.sol:SetupLossProtection --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv
```

8) Deploy Timelock and transferowneship to timelock (Optional)
```shell
forge script Deployment/Base/setupTimelock.s.sol:SetupTimelock --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv
```

9) LP (4 Txns)(Optional)
```shell
forge script script/Deployment/Base/lp.s.sol:Lp --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv
```
## Commands

- **Compilation**: Run `forge build` to compile the smart contracts.
- **Testing**: Use `forge test` to execute the test cases.
- **Coverage Report**: Run `forge coverage` to generate a coverage report.
- **Update Script**: Run `forge script script/Updates/updateBase.s.sol:UpdateScript --rpc-url $BASE_MAINNET_RPC_URL --slow --priority-gas-price 672985 --broadcast -vvvv`
- **Upgrade Script**: Run `forge script script/Upgrades/upgradesBase.s.sol:UpgradeScript --rpc-url $BASE_MAINNET_RPC_URL --broadcast -vvvv`
- **Interact with Smart Contracts**: Use `cast call` to interact with deployed smart contracts.
- **Send Transactions**: Use `cast tx` to send transactions.

## Submodule Version Info

- **Openzeppelin Contracts** : v4.9.3/@fd81a96f 
- **Openzeppelin upgradeable Contracts** : v4.9.3/@3d4c0d57
- **Chainlink Contracts** : v2.5.0/@b96cb80
- **Pyth Contracts**: v2.2.0/@11d6bcf
- **Forge-std**: @74cfb77

For more information on how to use Foundry, please refer to the [Foundry Book Website](https://book.getfoundry.sh/).
