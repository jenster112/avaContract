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

contract SetupPairs is Script {

    // Set This false for mainnet Deployment
    bool constant isTestnet  = false; 
    uint constant PRECISION = 1e10;
    
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
    uint public ethPairIndex;
    uint public btcPairIndex;
    uint public jpyPairIndex;
    uint public gbpPairIndex;
    uint public eurPairIndex;
    uint public xagPairIndex;
    uint public xauPairIndex;

    uint public solPairIndex;
    uint public avaxPairIndex;
    uint public dogePairIndex;
    uint public tiaPairIndex;
    uint public arbPairIndex;
    uint public bnbPairIndex;
    uint public opPairIndex;

    uint public cadPairIndex;
    uint public chfPairIndex;
    uint public sekPairIndex;
    uint public audPairIndex;
    uint public nzdPairIndex;
    uint public sgdPairIndex;

    uint public maticPairIndex;
    uint public seiPairIndex;

    int public constant _INT_PRECISION = 1e10;
    IPairStorage.Group  public forexGroup;
    IPairStorage.Group public cryptoGroupOne;
    IPairStorage.Group public cryptoGroupTwo;
    IPairStorage.Group  public commoditiesGroup;
    
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
        __setupPairs();
    }

    function __setupPairs() internal{
        
        cryptoGroupOne = IPairStorage.Group({
            name: "CRYPTO1",
            minLeverage: 2*PRECISION,
            maxLeverage: 25*PRECISION,
            maxOpenInterestP: 49
        });

        cryptoGroupTwo = IPairStorage.Group({
            name: "CRYPTO2",
            minLeverage: 2*PRECISION,
            maxLeverage: 20*PRECISION,
            maxOpenInterestP: 21
        });

        forexGroup = IPairStorage.Group({
            name: "FOREX",
            minLeverage: 2*PRECISION,
            maxLeverage: 50*PRECISION,
            maxOpenInterestP: 20 // max = 20% liquidity
        });

        commoditiesGroup = IPairStorage.Group({
            name: "COMMODITIES",
            minLeverage: 2*PRECISION,
            maxLeverage: 30*PRECISION,
            maxOpenInterestP: 10 // max = 10% liquidity
        });

        vm.startBroadcast(deployer);
        pairStorage.addGroup(cryptoGroupOne);
        pairStorage.addGroup(cryptoGroupTwo);
        pairStorage.addGroup(forexGroup);
        pairStorage.addGroup(commoditiesGroup);
        vm.stopBroadcast();

        __setupETH();
        __setupBTC();

        __setupSOL();
        __setupBNB();
        __setupARB();
        __setupDOGE();
        __setupAVAX();
        __setupOP();
        __setupMATIC();
        __setupTIA();
        __setupSEI();

        __setupEUR();
        __setupJPY();
        __setupGBP();


        __setupUSDCAD();
        __setupUSDCHF();
        __setupUSDSEK();
        __setupAUDUSD();
        __setupNZDUSD();
        __setupUSDSDG();

        __setupSilver();
        __setupGold();
        
    }

    function __setupETH() internal {

        IPairStorage.Feed memory ethUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_ETH_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_ETH_USD_FEED_BASE_MAINNET
        });

        IPairStorage.BackupFeed memory ethUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.ETH_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.ETH_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory ethUSDFee = IPairStorage.Fee({
            name: "ETH_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 500*1e6 //  
        });

        /**
        if 0 <= x < 60:
            return 0.08
        elif 60 <= x < 70:
            return -0.001 * x + 0.14  # Updated values
        elif 70 <= x < 80:
            return -0.0030 * x + 0.28  # Updated m2 and b2
        elif 80 <= x <= 100:
            return 0.04  # Flatline to 0.004 after 80%
         */
        IPairStorage.SkewFee memory ethUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 0)
        });


        IPairStorage.Pair memory ethUSD = IPairStorage.Pair({
            from: "ETH",
            to:   "USD",
            feed: ethUSDFeed,
            backupFeed: ethUsdBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 0,
            feeIndex: 0 ,
            groupOpenInterestPecentage: 85,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(ethUSDFee);
        pairStorage.addPair(ethUSD);
        pairStorage.addSkewOpenFees(ethUSDSkewFee);
        ethPairIndex = 0;
        vm.stopBroadcast();
    }

    function __setupBTC() internal {

        uint btcFeeIndex = 1;
        IPairStorage.Feed memory btcUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_BTC_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_BTC_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory btcUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.BTC_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.BTC_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory btcUSDFee = IPairStorage.Fee({
            name: "BTC_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory btcUSD = IPairStorage.Pair({
            from: "BTC",
            to:   "USD",
            feed: btcUSDFeed,
            backupFeed: btcUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 14e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 0,
            feeIndex: btcFeeIndex,
            groupOpenInterestPecentage: 85, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory btcUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(btcUSDFee);
        pairStorage.addPair(btcUSD);
        btcPairIndex = 1;
        pairStorage.addSkewOpenFees(btcUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupSOL() internal {

        uint solFeeIndex = 2;
        IPairStorage.Feed memory solUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_SOL_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_SOL_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory solUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.SOL_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.SOL_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory solUSDFee = IPairStorage.Fee({
            name: "SOL_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory solUSD = IPairStorage.Pair({
            from: "SOL",
            to:   "USD",
            feed: solUSDFeed,
            backupFeed: solUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: solFeeIndex,
            groupOpenInterestPecentage: 50, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory solUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 2)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(solUSDFee);
        pairStorage.addPair(solUSD);
        pairStorage.addSkewOpenFees(solUSDSkewFee);
        solPairIndex = 2;
        vm.stopBroadcast();
    }

    function __setupBNB() internal {

        uint bnbFeeIndex = 3;
        IPairStorage.Feed memory bnbUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_BNB_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_BNB_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory bnbUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.BNB_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.BNB_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory bnbUSDFee = IPairStorage.Fee({
            name: "BNB_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory bnbUSD = IPairStorage.Pair({
            from: "BNB",
            to:   "USD",
            feed: bnbUSDFeed,
            backupFeed: bnbUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: bnbFeeIndex,
            groupOpenInterestPecentage: 50, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory bnbUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(bnbUSDFee);
        pairStorage.addPair(bnbUSD);
        pairStorage.addSkewOpenFees(bnbUSDSkewFee);
        bnbPairIndex = 3;
        vm.stopBroadcast();
    }

    function __setupARB() internal {

        uint arbFeeIndex = 4;
        IPairStorage.Feed memory arbUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_ARB_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_ARB_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory arbUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.ARB_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.ARB_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory arbUSDFee = IPairStorage.Fee({
            name: "ARB_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory arbUSD = IPairStorage.Pair({
            from: "ARB",
            to:   "USD",
            feed: arbUSDFeed,
            backupFeed: arbUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: arbFeeIndex,
            groupOpenInterestPecentage: 50, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory arbUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(arbUSDFee);
        pairStorage.addPair(arbUSD);
        pairStorage.addSkewOpenFees(arbUSDSkewFee);
        arbPairIndex = 4;
        vm.stopBroadcast();
    }

    function __setupDOGE() internal {

        uint dogeFeeIndex = 5;
        IPairStorage.Feed memory dogeUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_DOGE_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_DOGE_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory dogeUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.DOGE_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.DOGE_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory dogeUSDFee = IPairStorage.Fee({
            name: "DOGE_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory dogeUSD = IPairStorage.Pair({
            from: "DOGE",
            to:   "USD",
            feed: dogeUSDFeed,
            backupFeed: dogeUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: dogeFeeIndex,
            groupOpenInterestPecentage: 35, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory dogeUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(dogeUSDFee);
        pairStorage.addPair(dogeUSD);
        pairStorage.addSkewOpenFees(dogeUSDSkewFee);
        dogePairIndex = 5;
        vm.stopBroadcast();
    }

    function __setupAVAX() internal {

        uint avaxFeeIndex = 6;
        IPairStorage.Feed memory avaxUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_AVAX_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_AVAX_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory avaxUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.AVAX_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.AVAX_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory avaxUSDFee = IPairStorage.Fee({
            name: "AVAX_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory avaxUSD = IPairStorage.Pair({
            from: "AVAX",
            to:   "USD",
            feed: avaxUSDFeed,
            backupFeed: avaxUSDBackupFeed,
            spreadP: 6e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: avaxFeeIndex,
            groupOpenInterestPecentage: 35, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory avaxUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(avaxUSDFee);
        pairStorage.addPair(avaxUSD);
        pairStorage.addSkewOpenFees(avaxUSDSkewFee);
        avaxPairIndex = 6;
        vm.stopBroadcast();
    }

    function __setupOP() internal {

        uint opFeeIndex = 7;
        IPairStorage.Feed memory opUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_OP_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_OP_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory opUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.OP_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.OP_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory opUSDFee = IPairStorage.Fee({
            name: "OP_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory opUSD = IPairStorage.Pair({
            from: "OP",
            to:   "USD",
            feed: opUSDFeed,
            backupFeed: opUSDBackupFeed,
            spreadP: 6e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: opFeeIndex,
            groupOpenInterestPecentage: 35, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory opUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(opUSDFee);
        pairStorage.addPair(opUSD);
        pairStorage.addSkewOpenFees(opUSDSkewFee);
        opPairIndex = 7;
        vm.stopBroadcast();
    }

    function __setupMATIC() internal {

        uint maticFeeIndex = 8;
        IPairStorage.Feed memory maticUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_MATIC_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_MATIC_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory maticUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.MATIC_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.MATIC_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory maticUSDFee = IPairStorage.Fee({
            name: "MATIC_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory maticUSD = IPairStorage.Pair({
            from: "MATIC",
            to:   "USD",
            feed: maticUSDFeed,
            backupFeed: maticUSDBackupFeed,
            spreadP: 6e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: maticFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory maticUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(maticUSDFee);
        pairStorage.addPair(maticUSD);
        pairStorage.addSkewOpenFees(maticUSDSkewFee);
        maticPairIndex = 8;
        vm.stopBroadcast();
    }

    function __setupTIA() internal {

        uint tiaFeeIndex = 9;
        IPairStorage.Feed memory tiaUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_TIA_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_TIA_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory tiaUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.TIA_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.TIA_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory tiaUSDFee = IPairStorage.Fee({
            name: "TIA_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory tiaUSD = IPairStorage.Pair({
            from: "TIA",
            to:   "USD",
            feed: tiaUSDFeed,
            backupFeed: tiaUSDBackupFeed,
            spreadP: 8e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: tiaFeeIndex,
            groupOpenInterestPecentage: 18, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory tiaUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(tiaUSDFee);
        pairStorage.addPair(tiaUSD);
        pairStorage.addSkewOpenFees(tiaUSDSkewFee);
        tiaPairIndex = 9;
        vm.stopBroadcast();
    }

    function __setupSEI() internal {

        uint seiFeeIndex = 10;
        IPairStorage.Feed memory seiUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_SEI_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_SEI_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory seiUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet   
                    ? Constants.SEI_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.SEI_USD_CHAINLINK_FEED_BASE_MAINNET

        });

        IPairStorage.Fee memory seiUSDFee = IPairStorage.Fee({
            name: "SEI_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 500*1e6 // 1USD
        });

        IPairStorage.Pair memory seiUSD = IPairStorage.Pair({
            from: "SEI",
            to:   "USD",
            feed: seiUSDFeed,
            backupFeed: seiUSDBackupFeed,
            spreadP: 8e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 1,
            feeIndex: seiFeeIndex,
            groupOpenInterestPecentage: 18, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory seiUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(seiUSDFee);
        pairStorage.addPair(seiUSD);
        pairStorage.addSkewOpenFees(seiUSDSkewFee);
        seiPairIndex = 10;
        vm.stopBroadcast();
    }

    function __setupJPY() internal {

        uint jpyFeeIndex = 12;

        IPairStorage.Feed memory jpyUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_JPY_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_JPY_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory jypUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.JPY_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.JPY_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory jpyUSDFee = IPairStorage.Fee({
            name: "JPY_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory jpyUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory jpyUSD = IPairStorage.Pair({
            from: "USD",
            to:   "JPY",
            feed: jpyUSDFeed,
            backupFeed: jypUsdBackupFeed,
            spreadP: 1e8,
            groupIndex: 2,
            priceImpactMultiplier: 0, // only for cryptos
            skewImpactMultiplier: 0,
            feeIndex: jpyFeeIndex,
            groupOpenInterestPecentage: 70,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(jpyUSDFee);
        pairStorage.addPair(jpyUSD);
        pairStorage.addSkewOpenFees(jpyUSDSkewFee);
        jpyPairIndex = 12;
        vm.stopBroadcast();
    }

    function __setupGBP() internal {

        uint gbpFeeIndex = 13;

        IPairStorage.Feed memory gbpUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_GBP_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_GBP_USD_FEED_BASE_MAINNET
        });

        IPairStorage.BackupFeed memory gbpUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet
                    ? Constants.GBP_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.GBP_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory gbpUSDFee = IPairStorage.Fee({
            name: "GBP_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory gbpUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 3)
        });


        IPairStorage.Pair memory gbpUSD = IPairStorage.Pair({
            from: "GBP",
            to:   "USD",
            feed: gbpUSDFeed,
            backupFeed: gbpUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: gbpFeeIndex,
            groupOpenInterestPecentage: 70,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(gbpUSDFee);
        pairStorage.addPair(gbpUSD);
        pairStorage.addSkewOpenFees(gbpUSDSkewFee);
        gbpPairIndex = 13;
        vm.stopBroadcast();
    }

    function __setupEUR() internal {
        uint eurFeeIndex = 11;
        IPairStorage.Feed memory eurUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_EUR_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_EUR_USD_FEED_BASE_MAINNET
        });

        IPairStorage.BackupFeed memory eurUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.EUR_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.EUR_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory eurUSDFee = IPairStorage.Fee({
            name: "EUR_USD_FEE",
            openFeeP: 3e8, //0.1%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory eurUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 4)
        });


        IPairStorage.Pair memory eurUSD = IPairStorage.Pair({
            from: "EUR",
            to:   "USD",
            feed: eurUSDFeed,
            backupFeed: eurUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: eurFeeIndex,
            groupOpenInterestPecentage: 70,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(eurUSDFee);
        pairStorage.addPair(eurUSD);
        pairStorage.addSkewOpenFees(eurUSDSkewFee);
        eurPairIndex = 11;
        vm.stopBroadcast();
    }

    function __setupUSDCAD() internal {

        uint cadFeeIndex = 14;

        IPairStorage.Feed memory cadUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_CAD_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_CAD_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory cadUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.CAD_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.CAD_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory cadUSDFee = IPairStorage.Fee({
            name: "CAD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory cadUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory cadUSD = IPairStorage.Pair({
            from: "USD",
            to:   "CAD",
            feed: cadUSDFeed,
            backupFeed: cadUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: cadFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(cadUSDFee);
        pairStorage.addPair(cadUSD);
        pairStorage.addSkewOpenFees(cadUSDSkewFee);
        cadPairIndex = 14;
        vm.stopBroadcast();
    }

    function __setupUSDCHF() internal {

        uint chfFeeIndex = 15;

        IPairStorage.Feed memory chfUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_CHF_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_CHF_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory chfUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.CHF_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.CHF_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory chfUSDFee = IPairStorage.Fee({
            name: "CHF_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory chfUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory chfUSD = IPairStorage.Pair({
            from: "USD",
            to:   "CHF",
            feed: chfUSDFeed,
            backupFeed: chfUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: chfFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(chfUSDFee);
        pairStorage.addPair(chfUSD);
        pairStorage.addSkewOpenFees(chfUSDSkewFee);
        chfPairIndex = 15;
        vm.stopBroadcast();
    }

    function __setupUSDSEK() internal {

        uint sekFeeIndex = 16;

        IPairStorage.Feed memory sekUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_SEK_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_SEK_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory sekUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.SEK_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.SEK_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory sekUSDFee = IPairStorage.Fee({
            name: "SEK_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory sekUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory sekUSD = IPairStorage.Pair({
            from: "USD",
            to:   "SEK",
            feed: sekUSDFeed,
            backupFeed: sekUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: sekFeeIndex,
            groupOpenInterestPecentage: 30,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(sekUSDFee);
        pairStorage.addPair(sekUSD);
        pairStorage.addSkewOpenFees(sekUSDSkewFee);
        sekPairIndex = 16;
        vm.stopBroadcast();
    }

    function __setupAUDUSD() internal {

        uint audFeeIndex = 17;

        IPairStorage.Feed memory audUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_AUD_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_AUD_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory audUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.AUD_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.AUD_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory audUSDFee = IPairStorage.Fee({
            name: "AUD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory audUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory audUSD = IPairStorage.Pair({
            from: "AUD",
            to:   "USD",
            feed: audUSDFeed,
            backupFeed: audUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: audFeeIndex,
            groupOpenInterestPecentage: 30,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(audUSDFee);
        pairStorage.addPair(audUSD);
        pairStorage.addSkewOpenFees(audUSDSkewFee);
        audPairIndex = 17;
        vm.stopBroadcast();
    }

    function __setupNZDUSD() internal {

        uint nzdFeeIndex = 18;

        IPairStorage.Feed memory nzdUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_NZD_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_NZD_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory nzdUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.NZD_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.NZD_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory nzdUSDFee = IPairStorage.Fee({
            name: "NZD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory nzdUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory nzdUSD = IPairStorage.Pair({
            from: "NZD",
            to:   "USD",
            feed: nzdUSDFeed,
            backupFeed: nzdUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: nzdFeeIndex,
            groupOpenInterestPecentage: 30,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(nzdUSDFee);
        pairStorage.addPair(nzdUSD);
        pairStorage.addSkewOpenFees(nzdUSDSkewFee);
        nzdPairIndex = 18;
        vm.stopBroadcast();
    }

    function __setupUSDSDG() internal {

        uint sgdFeeIndex = 19;

        IPairStorage.Feed memory sgdUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_SGD_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_SGD_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory sgdUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.SGD_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.SGD_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory sgdUSDFee = IPairStorage.Fee({
            name: "SGD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1000*1e6 // 1USD
        });

        IPairStorage.SkewFee memory sgdUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory sgdUSD = IPairStorage.Pair({
            from: "USD",
            to:   "SGD",
            feed: sgdUSDFeed,
            backupFeed: sgdUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 2,
            feeIndex: sgdFeeIndex,
            groupOpenInterestPecentage: 30,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(sgdUSDFee);
        pairStorage.addPair(sgdUSD);
        pairStorage.addSkewOpenFees(sgdUSDSkewFee);
        sgdPairIndex = 19;
        vm.stopBroadcast();
    }

    function __setupSilver() internal {

        uint xagFeeIndex = 20;

        IPairStorage.Feed memory xagUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_XAG_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_XAG_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory xagUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.XAG_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.XAG_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory xagUSDFee = IPairStorage.Fee({
            name: "XAG_USD_FEE",
            openFeeP: 8e8, //3 bps
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1500*1e6 
        });

        IPairStorage.SkewFee memory xagUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(2, 5)
        });


        IPairStorage.Pair memory xagUSD = IPairStorage.Pair({
            from: "XAG",
            to:   "USD",
            feed: xagUSDFeed,
            backupFeed: xagUsdBackupFeed,
            spreadP: 2e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 3,
            feeIndex: xagFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 5
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(xagUSDFee);
        pairStorage.addPair(xagUSD);
        pairStorage.addSkewOpenFees(xagUSDSkewFee);
        xagPairIndex = 20;
        vm.stopBroadcast();
    }

    function __setupGold() internal {

        uint xauFeeIndex = 21;

        IPairStorage.Feed memory xauUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_XAU_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_XAU_USD_FEED_BASE_MAINNET

        });

        IPairStorage.BackupFeed memory xauUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.XAU_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.XAU_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Fee memory xauUSDFee = IPairStorage.Fee({
            name: "XAU_USD_FEE",
            openFeeP: 6e8, //0.1%
            closeFeeP: 6e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1500*1e6 
        });

        IPairStorage.SkewFee memory xauUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(2, 21)
        });


        IPairStorage.Pair memory xauUSD = IPairStorage.Pair({
            from: "XAU",
            to:   "USD",
            feed: xauUSDFeed,
            backupFeed: xauUsdBackupFeed,
            spreadP: 2e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: int(0),
            groupIndex: 3,
            feeIndex: xauFeeIndex,
            groupOpenInterestPecentage: 80,
            maxWalletOI : 8
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(xauUSDFee);
        pairStorage.addPair(xauUSD);
        pairStorage.addSkewOpenFees(xauUSDSkewFee);
        xauPairIndex = 21;
        vm.stopBroadcast();
    }

/**------------------Utility Functions-------------------------------------------- */
    // Group Index is the class Index here. Crypto is one class even though we have two groups within crypto
    function _getSkewFee(uint _groupIndex, uint _pairIndex) internal pure returns(int256[2][10] memory){

        int256[2][10] memory skew ;
        
        if(_groupIndex == 0 ){
            skew[0][0] = -10 ;
            skew[0][1] = 1200 ;
            skew[1][0] = -10 ;
            skew[1][1] = 1200 ;
            skew[2][0] = -10 ;
            skew[2][1] = 1200 ;
            skew[3][0] = -10 ;
            skew[3][1] = 1200 ;
            skew[4][0] = 0 ;
            skew[4][1] = 800 ;
            skew[5][0] = 0 ;
            skew[5][1] = 800 ;
            skew[6][0] = -10 ;
            skew[6][1] = 1400 ;
            skew[7][0] = -10 ;
            skew[7][1] = 1400 ;
            skew[8][0] = -10 ;
            skew[8][1] = 1400 ;
            skew[9][0] = -10 ;
            skew[9][1] = 1400 ;
        }
        else if(_groupIndex == 1){
            skew[0][0] = -5;
            skew[0][1] = 500 ;
            skew[1][0] = -5 ;
            skew[1][1] = 500 ;
            skew[2][0] = -5 ;
            skew[2][1] = 500 ;
            skew[3][0] = -5 ;
            skew[3][1] = 500 ;
            skew[4][0] = 0 ;
            skew[4][1] = 300 ;
            skew[5][0] = 0 ;
            skew[5][1] = 300 ;
            skew[6][0] = -5 ;
            skew[6][1] = 600 ;
            skew[7][0] = -5 ;
            skew[7][1] = 600 ;
            skew[8][0] = -5 ;
            skew[8][1] = 600 ;
            skew[9][0] = -5 ;
            skew[9][1] = 600 ;
        }
        else if(_groupIndex == 2){
            if(_pairIndex == 20){ // Silver
                skew[0][0] = 0;
                skew[0][1] = 800 ;
                skew[1][0] = 0 ;
                skew[1][1] = 800 ;
                skew[2][0] = 0 ;
                skew[2][1] = 800 ;
                skew[3][0] = 0 ;
                skew[3][1] = 800 ;
                skew[4][0] = 0 ;
                skew[4][1] = 800 ;
                skew[5][0] = 0 ;
                skew[5][1] = 800 ;
                skew[6][0] = 0 ;
                skew[6][1] = 800 ;
                skew[7][0] = 0 ;
                skew[7][1] = 800 ;
                skew[8][0] = 0 ;
                skew[8][1] = 800 ;
                skew[9][0] = 0 ;
                skew[9][1] = 800 ;
            }
            else if(_pairIndex == 21){ // Gold
                skew[0][0] = 0;
                skew[0][1] = 600 ;
                skew[1][0] = 0 ;
                skew[1][1] = 600 ;
                skew[2][0] = 0 ;
                skew[2][1] = 600 ;
                skew[3][0] = 0 ;
                skew[3][1] = 600 ;
                skew[4][0] = 0 ;
                skew[4][1] = 600 ;
                skew[5][0] = 0 ;
                skew[5][1] = 600 ;
                skew[6][0] = 0 ;
                skew[6][1] = 600 ;
                skew[7][0] = 0 ;
                skew[7][1] = 600 ;
                skew[8][0] = 0 ;
                skew[8][1] = 600 ;
                skew[9][0] = 0 ;
                skew[9][1] = 600 ;
            }
        }

        return skew;
    }
}
