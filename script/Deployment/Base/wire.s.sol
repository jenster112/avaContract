pragma solidity 0.8.7;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Execute} from "../../../src/Execute.sol";
import {PairInfos} from "../../../src/PairInfos.sol";
import {PairStorage} from "../../../src/PairStorage.sol";
import {PriceAggregator} from "../../../src/PriceAggregator.sol";
import {Trading} from "../../../src/Trading.sol";
import {TradingCallbacks} from "../../../src/TradingCallbacks.sol";
import {TradingStorage} from "../../../src/TradingStorage.sol";
import {Tranche} from "../../../src/Tranche.sol";
import {VaultManager} from "../../../src/VaultManager.sol";
import {VeTranche} from "../../../src/VeTranche.sol";
import {USDC} from "../../../src/testnet/USDC.sol";
import {MockPyth} from "pyth-sdk-solidity/MockPyth.sol";
import {Referral} from "../../../src/Referral.sol";
import "../../../src/interfaces/ITradingStorage.sol";
import "../../../src/interfaces/IExecute.sol";
import "../../../src/interfaces/IPairInfos.sol";
import {Constants} from "../Constants.sol";
import {Addresses} from "./address.sol";

contract Wire is Script {

    // Set This false for mainnet Deployment
    bool constant isTestnet  = false; 

    ProxyAdmin public proxyAdmin;
    address public deployer;

    Trading public trading;
    Tranche public juniorTranche;
    Tranche public seniorTranche;
    VeTranche public veJuniorTranche;
    VeTranche public veSeniorTranche;
    VaultManager public vaultManager;
    USDC public usdc;
    TradingStorage public tradingStorage;
    PairStorage public pairStorage;
    PriceAggregator public priceAggregator;
    TradingCallbacks public tradingCallbacks;
    PairInfos public pairInfos;
    Referral public referral;
    Execute public execute;
    address public pyth;

    function run() public {

        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        deployer = vm.rememberKey(deployerKey);

        trading = isTestnet 
                  ? Trading(Addresses.BASE_TESTNET_TRADING)
                  : Trading(Addresses.BASE_MAINNET_TRADING);
        pairStorage = isTestnet 
                  ? PairStorage(Addresses.BASE_TESTNET_PAIRSTORAGE)
                  : PairStorage(Addresses.BASE_MAINNET_PAIRSTORAGE);
        juniorTranche = isTestnet 
                  ? Tranche(Addresses.BASE_TESTNET_JUNIOR_TRANCHE)
                  : Tranche(Addresses.BASE_MAINNET_JUNIOR_TRANCHE);
        seniorTranche = isTestnet 
                  ? Tranche(Addresses.BASE_TESTNET_SENIOR_TRANCHE)
                  : Tranche(Addresses.BASE_MAINNET_SENIOR_TRANCHE);
        veJuniorTranche = isTestnet 
                  ? VeTranche(Addresses.BASE_TESTNET_JUNIOR_VE_TRANCHE)
                  : VeTranche(Addresses.BASE_MAINNET_JUNIOR_VE_TRANCHE);
        veSeniorTranche = isTestnet 
                  ? VeTranche(Addresses.BASE_TESTNET_SENIOR_VE_TRANCHE)
                  : VeTranche(Addresses.BASE_MAINNET_SENIOR_VE_TRANCHE);
        vaultManager = isTestnet 
                  ? VaultManager(Addresses.BASE_TESTNET_VAULT_MANAGER)
                  : VaultManager(Addresses.BASE_MAINNET_VAULT_MANAGER);
        priceAggregator = isTestnet 
                  ? PriceAggregator(Addresses.BASE_TESTNET_PRICE_AGGREGATOR)
                  : PriceAggregator(Addresses.BASE_MAINNET_PRICE_AGGREGATOR);
        tradingCallbacks = isTestnet 
                  ? TradingCallbacks(Addresses.BASE_TESTNET_TRADING_CALLBACKS)
                  : TradingCallbacks(Addresses.BASE_MAINNET_TRADING_CALLBACKS);
        usdc = isTestnet 
                  ? USDC(Addresses.BASE_TESTNET_USDC)
                  : USDC(Addresses.BASE_MAINNET_USDC);
        proxyAdmin = isTestnet 
                  ? ProxyAdmin(Addresses.BASE_TESTNET_PROXY_ADMIN)
                  : ProxyAdmin(Addresses.BASE_MAINNET_PROXY_ADMIN);
        tradingStorage = isTestnet 
                  ? TradingStorage(Addresses.BASE_TESTNET_TRADING_STORAGE)
                  : TradingStorage(Addresses.BASE_MAINNET_TRADING_STORAGE);

        pairInfos = isTestnet
                  ? PairInfos(Addresses.BASE_TESTNET_PAIRINFOS)
                  : PairInfos(Addresses.BASE_MAINNET_PAIRINFOS);

        referral = isTestnet 
                  ? Referral(Addresses.BASE_TESTNET_REFERRAL)
                  : Referral(Addresses.BASE_MAINNET_REFERRAL);

        execute = isTestnet 
                  ? Execute(Addresses.BASE_TESTNET_EXECUTE)
                  : Execute(Addresses.BASE_MAINNET_EXECUTE);
        __setPythOracle();
        __wire();
        __setMarketOperator();
    }

    function __setPythOracle() internal {

        pyth = isTestnet
                ? Constants.PYTH_BASE_SEPOLIA
                : Constants.PYTH_BASE_MAINNET;
    }

    function __wire() internal{

        vm.startBroadcast(deployer);

        // Trading Storage wiring
        tradingStorage.setPriceAggregator(address(priceAggregator));
        tradingStorage.setVaultManager(address(vaultManager));
        tradingStorage.setTrading(address(trading));
        tradingStorage.setCallbacks(address(tradingCallbacks));
        tradingStorage.setUSDC(address(usdc));
        tradingStorage.setReferral(address(referral));
        tradingStorage.addTradingContract(address(trading));
        tradingStorage.addTradingContract(address(tradingCallbacks));
        tradingStorage.addTradingContract(address(vaultManager));
        tradingStorage.addTradingContract(address(tradingStorage));
        tradingStorage.addTradingContract(address(execute));

        address govTreasury = isTestnet
                ? Constants.BASE_SEPOLIA_GOV_TREASURY
                : Constants.BASE_MAINNET_GOV_TREASURY;

        address devTreasury = isTestnet
                ? Constants.BASE_SEPOLIA_DEV_TREASURY
                : Constants.BASE_MAINNET_DEV_TREASURY;

        tradingStorage.setDev(address(devTreasury));
        tradingStorage.setGovTreasury(address(govTreasury));

        // Price Aggregator
        priceAggregator.setPyth(pyth);

        // Pair Infos
        pairInfos.setManager(deployer);
        pairInfos.setKeeper(Constants.BASE_MAINNET_PAIR_INFOS_KEEPER);

        vaultManager.setKeeper(Constants.BASE_MAINNET_VAULT_KEEPER);
        vaultManager.setJuniorTranche(address(juniorTranche));
        vaultManager.setSeniorTranche(address(seniorTranche));
        vaultManager.addTradingContract(address(tradingCallbacks));
        vaultManager.addTradingContract(address(tradingStorage));
        vaultManager.addTradingContract(address(trading));

        vaultManager.addTradingContract(address(juniorTranche));
        vaultManager.addTradingContract(address(seniorTranche));

        juniorTranche.setVeTranche(address(veJuniorTranche));
        seniorTranche.setVeTranche(address(veSeniorTranche));

        vm.stopBroadcast();
    }

    function __setMarketOperator() internal {

        vm.startBroadcast(deployer);

        address market_operator_1 = isTestnet
                ? Constants.BASE_SEPOLIA_MARKET_OPERATOR_1
                : Constants.BASE_MAINNET_MARKET_OPERATOR_1;

        trading.updateOperator(market_operator_1, true);

        address market_operator_2 = isTestnet
                ? Constants.BASE_SEPOLIA_MARKET_OPERATOR_2
                : Constants.BASE_MAINNET_MARKET_OPERATOR_2;

        trading.updateOperator(market_operator_2, true);
        address market_operator_3 = isTestnet
                ? Constants.BASE_SEPOLIA_MARKET_OPERATOR_3
                : Constants.BASE_MAINNET_MARKET_OPERATOR_3;

        trading.updateOperator(market_operator_3, true);
        address market_operator_4 = isTestnet
                ? Constants.BASE_SEPOLIA_MARKET_OPERATOR_4
                : Constants.BASE_MAINNET_MARKET_OPERATOR_4;

        trading.updateOperator(market_operator_4, true);
        address market_operator_5 = isTestnet
                ? Constants.BASE_SEPOLIA_MARKET_OPERATOR_5
                : Constants.BASE_MAINNET_MARKET_OPERATOR_5;

        trading.updateOperator(market_operator_5, true);

        address market_operator_6 = isTestnet
                ? Constants.BASE_SEPOLIA_MARKET_OPERATOR_6
                : Constants.BASE_MAINNET_MARKET_OPERATOR_6;

        trading.updateOperator(market_operator_6, true);

        address market_operator_fee_reciever = isTestnet
                ? Constants.BASE_SEPOLIA_MARKET_OPERATOR_FEE_RECIEVER
                : Constants.BASE_MAINNET_MARKET_OPERATOR_FEE_RECIEVER;

        trading.setMarketExecFeeReciever(address(market_operator_fee_reciever));

        vm.stopBroadcast();
    }
}
