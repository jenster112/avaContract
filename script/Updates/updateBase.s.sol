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
import {Constants} from "../Deployment/Constants.sol";
import {Addresses} from "../Deployment/Base/address.sol";
import "../../../src/interfaces/IPairStorage.sol";
contract UpdateScript is Script {

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

    uint public PRECISION = 1e10;

    uint public ethPairIndex = 0;
    uint public btcPairIndex = 1;
    uint public solPairIndex = 2;
    uint public bnbPairIndex = 3;
    uint public arbPairIndex = 4;
    uint public dogePairIndex = 5;
    uint public avaxPairIndex = 6;
    uint public opPairIndex = 7;
    uint public maticPairIndex = 8;
    uint public tiaPairIndex = 9;
    uint public seiPairIndex = 10;
    uint public eurPairIndex = 11;
    uint public jpyPairIndex = 12;
    uint public gbpPairIndex = 13;
    uint public cadPairIndex = 14;
    uint public chfPairIndex = 15;
    uint public sekPairIndex = 16;
    uint public audPairIndex = 17;
    uint public nzdPairIndex = 18;
    uint public sgdPairIndex = 19;
    uint public xagPairIndex = 20;
    uint public xauPairIndex = 21;
    int public constant _INT_PRECISION = 1e10;
    
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

        //_correctFeeds();
        //_setupNewFeeds();
        // _setupBaseFees();

        // for (uint i = 0 ;i < 21; i++){
        //     (string memory from, , , , , , , , , ) = pairStorage.pairs(i);
        //     console.logUint(i);
        //     console.logString(from);
        //     (string memory name, , , ,) = pairStorage.fees(i);
        //     console.logString(name);
        // }

        //__setupSEI();
        //__updateLeverages();
        //__updateMinPos();
        // __setLossProtectionAndTiers();
        //_updateCaps();
        __setFeesOn();
    }

    function __setFeesOn() internal {

        vm.startBroadcast(deployer);
        juniorTranche.setFeesOn(true);
        seniorTranche.setFeesOn(true);
        vm.stopBroadcast();
    }
    
    function _updateCaps() internal {
        vm.startBroadcast(deployer);
        juniorTranche.setCap(750000e6);
        seniorTranche.setCap(750000e6);
        vm.stopBroadcast();
    }
    
    function _addOperator() internal {

        vm.startBroadcast(deployer);
        trading.updateOperator(0xdacF6F424E6feAB7Ec556FB5d8Bb28242840ec65, true);
        trading.updateOperator(0x30C5dD3E5e6a6c02a1bccd4a0Cb52958522445D5, true);
        trading.updateOperator(0x05E88146Caa54c09eE22d0844780DCEe441EAa38, true);
        trading.updateOperator(0xdfFD332E0664e3397caDEbcEBe89901622162C3B, true);
        trading.updateOperator(0xC505d4da24179770515eDD83dDBB8abF3DA88923, true);
        trading.updateOperator(0x4758844C73EdA5e44aBEdF75aE3D2B1aB2dB6A8b, true);
        vm.stopBroadcast();
    }

    function __updateLeverages() internal {


        IPairStorage.Group memory forexGroup = IPairStorage.Group({
            name: "FOREX",
            minLeverage: 2*PRECISION,
            maxLeverage: 75*PRECISION,
            maxOpenInterestP: 20 // max = 20% liquidity
        });

        vm.startBroadcast(deployer);

        pairStorage.updateGroup(2, forexGroup);

        vm.stopBroadcast();

    }


    function __updateMinPos() internal{
        vm.startBroadcast(deployer);
        _updateETH();
        _updateBTC();
        _updateSOL();
        _updateBNB();
        _updateARB();
        _updateDOGE();
        _updateAVAX();
        _updateOP();
        _updateMATIC();
        _updateTIA();
        _updateSEI();
        _updateEUR();
        _updateJPY();
        _updateGBP();
        _updateCAD();
        _updateCHF();
        _updateSEK();
        _updateAUD();
        _updateNZD();
        _updateSGD();
        _updateXAU();
        _updateXAG();
        vm.stopBroadcast();
    }

    function _updateETH() internal{

        IPairStorage.Fee memory ethUSDFee = IPairStorage.Fee({
            name: "ETH_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 200e6 //  
        });

        pairStorage.updateFee(ethPairIndex, ethUSDFee );

        IPairStorage.BackupFeed memory ethUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.ETH_USD_CHAINLINK_FEED_BASE_SEPOLIA
                    : Constants.ETH_USD_CHAINLINK_FEED_BASE_MAINNET
        });

        IPairStorage.Feed memory ethUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_ETH_USD_FEED_BASE_SEPOLIA
                    : Constants.PYTH_ETH_USD_FEED_BASE_MAINNET
        });

        IPairStorage.Pair memory ethUSD = IPairStorage.Pair({
            from: "ETH",
            to:   "USD",
            feed: ethUSDFeed,
            backupFeed: ethUsdBackupFeed,
            spreadP: 4e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 0,
            feeIndex: 0 ,
            groupOpenInterestPecentage: 85,
            maxWalletOI : 5
        });

        pairStorage.updatePair(ethPairIndex, ethUSD);

    }

    function _updateBTC() internal{

        IPairStorage.Fee memory btcUSDFee = IPairStorage.Fee({
            name: "BTC_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(btcPairIndex, btcUSDFee);

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


        IPairStorage.Pair memory btcUSD = IPairStorage.Pair({
            from: "BTC",
            to:   "USD",
            feed: btcUSDFeed,
            backupFeed: btcUSDBackupFeed,
            spreadP: 4e8,
            priceImpactMultiplier: 14e9,
            skewImpactMultiplier: _INT_PRECISION,
            groupIndex: 0,
            feeIndex: 1,
            groupOpenInterestPecentage: 85, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        pairStorage.updatePair(btcPairIndex, btcUSD);
    }

    function _updateSOL() internal{

        IPairStorage.Fee memory solUSDFee = IPairStorage.Fee({
            name: "SOL_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(solPairIndex, solUSDFee);
    }

    function _updateBNB() internal{

        IPairStorage.Fee memory bnbUSDFee = IPairStorage.Fee({
            name: "BNB_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(bnbPairIndex, bnbUSDFee);
    }

    function _updateARB() internal{

        IPairStorage.Fee memory arbUSDFee = IPairStorage.Fee({
            name: "ARB_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(arbPairIndex, arbUSDFee);
    }

    function _updateDOGE() internal{

        IPairStorage.Fee memory dogeUSDFee = IPairStorage.Fee({
            name: "DOGE_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(dogePairIndex, dogeUSDFee);
    }

    function _updateAVAX() internal{

        IPairStorage.Fee memory avaxUSDFee = IPairStorage.Fee({
            name: "AVAX_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(avaxPairIndex, avaxUSDFee);
    }

    function _updateOP() internal{

        IPairStorage.Fee memory opUSDFee = IPairStorage.Fee({
            name: "OP_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(opPairIndex, opUSDFee);
    }

    function _updateMATIC() internal{

        IPairStorage.Fee memory maticUSDFee = IPairStorage.Fee({
            name: "MATIC_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(maticPairIndex, maticUSDFee);
    }

    function _updateTIA() internal{
        IPairStorage.Fee memory tiaUSDFee = IPairStorage.Fee({
            name: "TIA_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });

        pairStorage.updateFee(tiaPairIndex, tiaUSDFee);
    }

    function _updateSEI() internal {

        IPairStorage.Fee memory seiUSDFee = IPairStorage.Fee({
            name: "SEI_USD_FEE",
            openFeeP: 8e8, //0.1%
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 200e6// 1USD
        });
        pairStorage.updateFee(seiPairIndex, seiUSDFee);
    }

    function _updateJPY() internal {

        IPairStorage.Fee memory jpyUSDFee = IPairStorage.Fee({
            name: "JPY_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });
        pairStorage.updateFee(jpyPairIndex, jpyUSDFee);
    }

    function _updateGBP() internal {
        IPairStorage.Fee memory gbpUSDFee = IPairStorage.Fee({
            name: "GBP_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });
        pairStorage.updateFee(gbpPairIndex, gbpUSDFee);
    }

    function _updateEUR() internal {

        IPairStorage.Fee memory eurUSDFee = IPairStorage.Fee({
            name: "EUR_USD_FEE",
            openFeeP: 3e8, //0.1%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });
        pairStorage.updateFee(eurPairIndex, eurUSDFee);

    }

    function _updateCAD() internal{

        IPairStorage.Fee memory cadUSDFee = IPairStorage.Fee({
            name: "CAD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });
        pairStorage.updateFee(cadPairIndex, cadUSDFee);
    }

    function _updateCHF() internal{

        IPairStorage.Fee memory chfUSDFee = IPairStorage.Fee({
            name: "CHF_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });
        pairStorage.updateFee(chfPairIndex, chfUSDFee);
    }

    function _updateSEK() internal{
        IPairStorage.Fee memory sekUSDFee = IPairStorage.Fee({
            name: "SEK_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });
        pairStorage.updateFee(sekPairIndex, sekUSDFee);
    }

    function _updateAUD() internal{

        IPairStorage.Fee memory audUSDFee = IPairStorage.Fee({
            name: "AUD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });

        pairStorage.updateFee(audPairIndex, audUSDFee);
    }

    function _updateNZD() internal {

        IPairStorage.Fee memory nzdUSDFee = IPairStorage.Fee({
            name: "NZD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });

        pairStorage.updateFee(nzdPairIndex, nzdUSDFee);
    }

    function _updateSGD() internal{
        IPairStorage.Fee memory sgdUSDFee = IPairStorage.Fee({
            name: "SGD_USD_FEE",
            openFeeP: 3e8, //0.03%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 750e6// 1USD
        });

        pairStorage.updateFee(sgdPairIndex, sgdUSDFee);
    }

    function _updateXAG() internal {

        IPairStorage.Fee memory xagUSDFee = IPairStorage.Fee({
            name: "XAG_USD_FEE",
            openFeeP: 8e8, //3 bps
            closeFeeP: 8e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 300e6
        });

        pairStorage.updateFee(xagPairIndex, xagUSDFee);
    }


    function _updateXAU() internal {

        IPairStorage.Fee memory xauUSDFee = IPairStorage.Fee({
            name: "XAU_USD_FEE",
            openFeeP: 6e8, //0.1%
            closeFeeP: 6e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 300e6
        });

        pairStorage.updateFee(xauPairIndex, xauUSDFee);
    }

    function _getLossProtectionConfig(uint a, uint b, uint c, uint d) internal pure returns (uint256[] memory) {
        uint256[] memory config = new uint256[](4);
        config[0] = a;
        config[1] = b;
        config[2] = c;
        config[3] = d;

        return config;
    }

    function __setLossProtectionAndTiers() internal{

        uint[] memory standardLossProtectionConfig = _getLossProtectionConfig(0, 60, 70, 80);

        vm.startBroadcast(deployer);

        for (uint i = 0 ;i < 21; i++){
            pairInfos.setLossProtectionConfig(i, standardLossProtectionConfig, standardLossProtectionConfig);
        }

        vm.stopBroadcast();

        vm.startBroadcast(deployer);

        uint256[] memory tier = new uint256[](4);
        tier[0] = 0;
        tier[1] = 1;
        tier[2] = 2;
        tier[3] = 3;

        uint256[] memory tierMultiplier = new uint256[](4);
        tierMultiplier[0] = 100;
        tierMultiplier[1] = 90; // newLoss = 90%of Loss // FIrst Tier
        tierMultiplier[2] = 80;
        tierMultiplier[3] = 70;

        for (uint i = 0 ;i < 21; i++){
            pairStorage.updateLossProtectionMultiplier(i, tier, tierMultiplier);
        }
        vm.stopBroadcast();

        vm.startBroadcast(deployer);

        uint256[] memory indexes =  new uint256[](21);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        indexes[3] = 3;
        indexes[4] = 4;
        indexes[5] = 5;
        indexes[6] = 6;
        indexes[7] = 7;
        indexes[8] = 8;
        indexes[9] = 9;
        indexes[10] = 10;
        indexes[11] = 11;
        indexes[12] = 12;
        indexes[13] = 13;
        indexes[14] = 14;
        indexes[15] = 15;
        indexes[16] = 16;
        indexes[17] = 17;
        indexes[18] = 18;
        indexes[19] = 19;
        indexes[20] = 20;

        uint256[] memory limits =  new uint256[](21);
        limits[0] = 1000000e6;
        limits[1] = 1000000e6;
        limits[2] = 1000000e6;
        limits[3] = 1000000e6;
        limits[4] = 1000000e6;
        limits[5] = 1000000e6;
        limits[6] = 1000000e6;
        limits[7] = 1000000e6;
        limits[8] = 1000000e6;
        limits[9] = 1000000e6;
        limits[10] = 1000000e6;
        limits[11] = 1000000e6;
        limits[12] = 1000000e6;
        limits[13] = 1000000e6;
        limits[14] = 1000000e6;
        limits[15] = 1000000e6;
        limits[16] = 1000000e6;
        limits[17] = 1000000e6;
        limits[18] = 1000000e6;
        limits[19] = 1000000e6;
        limits[20] = 1000000e6;

        pairStorage.setBlockOILImits(indexes, limits);

        vm.stopBroadcast();
    }

    function _setupBaseFees() internal {

        vm.startBroadcast(deployer);

        IPairInfos.PairParams memory pairParam = IPairInfos.PairParams({
            onePercentDepthAbove: 1000000*1e6, // 10m
            onePercentDepthBelow: 1000000*1e6, // USDC
            rolloverFeePerBlockP: 33333 // 0.006% per hour
        });

        for (uint i = 9 ;i < 21; i++){
            pairInfos.setPairParams(i, pairParam);
        }

        vm.stopBroadcast();

    }

    function _correctFeeds() internal{


        vm.startBroadcast(deployer);

        IPairStorage.Group memory forexGroup = IPairStorage.Group({
            name: "FOREX",
            minLeverage: 2*PRECISION,
            maxLeverage: 100*PRECISION,
            maxOpenInterestP: 20 // max = 15% liquidity
        });
        pairStorage.updateGroup(1, forexGroup);

        IPairStorage.Group memory commoditiesGroup = IPairStorage.Group({
            name: "COMMODITIES",
            minLeverage: 2*PRECISION,
            maxLeverage: 100*PRECISION,
            maxOpenInterestP: 10 // max = 15% liquidity
        });

        pairStorage.updateGroup(2, commoditiesGroup);

        __correctETH();
        __correctBTC();
        vm.stopBroadcast();
    }

    function _setupNewFeeds() internal {

        __setupSOL();
        __setupBNB();
        __setupARB();
        __setupDOGE();
        __setupAVAX();
        __setupOP();
        __setupMATIC();
        __setupTIA();
        __setupSEI();
        __setupUSDCAD();
        __setupUSDCHF();
        __setupUSDSEK();
        __setupAUDUSD();
        __setupNZDUSD();
        __setupUSDSDG();

    }

    function __setupSOL() internal {

        uint solFeeIndex = 7;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory solUSD = IPairStorage.Pair({
            from: "SOL",
            to:   "USD",
            feed: solUSDFeed,
            backupFeed: solUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: solFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory solUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(solUSDFee);
        pairStorage.addPair(solUSD);
        pairStorage.addSkewOpenFees(solUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupBNB() internal {

        uint bnbFeeIndex = 8;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory bnbUSD = IPairStorage.Pair({
            from: "BNB",
            to:   "USD",
            feed: bnbUSDFeed,
            backupFeed: bnbUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: bnbFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory bnbUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(bnbUSDFee);
        pairStorage.addPair(bnbUSD);
        pairStorage.addSkewOpenFees(bnbUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupARB() internal {

        uint arbFeeIndex = 9;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory arbUSD = IPairStorage.Pair({
            from: "ARB",
            to:   "USD",
            feed: arbUSDFeed,
            backupFeed: arbUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: arbFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory arbUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(arbUSDFee);
        pairStorage.addPair(arbUSD);
        pairStorage.addSkewOpenFees(arbUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupDOGE() internal {

        uint dogeFeeIndex = 10;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory dogeUSD = IPairStorage.Pair({
            from: "DOGE",
            to:   "USD",
            feed: dogeUSDFeed,
            backupFeed: dogeUSDBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: dogeFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory dogeUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(dogeUSDFee);
        pairStorage.addPair(dogeUSD);
        pairStorage.addSkewOpenFees(dogeUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupAVAX() internal {

        uint avaxFeeIndex = 11;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory avaxUSD = IPairStorage.Pair({
            from: "AVAX",
            to:   "USD",
            feed: avaxUSDFeed,
            backupFeed: avaxUSDBackupFeed,
            spreadP: 6e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: avaxFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory avaxUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(avaxUSDFee);
        pairStorage.addPair(avaxUSD);
        pairStorage.addSkewOpenFees(avaxUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupOP() internal {

        uint opFeeIndex = 12;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory opUSD = IPairStorage.Pair({
            from: "OP",
            to:   "USD",
            feed: opUSDFeed,
            backupFeed: opUSDBackupFeed,
            spreadP: 6e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: opFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory opUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(opUSDFee);
        pairStorage.addPair(opUSD);
        pairStorage.addSkewOpenFees(opUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupMATIC() internal {

        uint maticFeeIndex = 13;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory maticUSD = IPairStorage.Pair({
            from: "MATIC",
            to:   "USD",
            feed: maticUSDFeed,
            backupFeed: maticUSDBackupFeed,
            spreadP: 6e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
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
        vm.stopBroadcast();
    }

    function __setupTIA() internal {

        uint tiaFeeIndex = 14;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory tiaUSD = IPairStorage.Pair({
            from: "TIA",
            to:   "USD",
            feed: tiaUSDFeed,
            backupFeed: tiaUSDBackupFeed,
            spreadP: 8e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: tiaFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory tiaUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        pairStorage.addFee(tiaUSDFee);
        pairStorage.addPair(tiaUSD);
        pairStorage.addSkewOpenFees(tiaUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupSEI() internal {

        uint seiFeeIndex = 15;
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
            minLevPosUSDC: 100*1e6 // 1USD
        });

        IPairStorage.Pair memory seiUSD = IPairStorage.Pair({
            from: "SEI",
            to:   "USD",
            feed: seiUSDFeed,
            backupFeed: seiUSDBackupFeed,
            spreadP: 8e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: seiFeeIndex,
            groupOpenInterestPecentage: 25, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory seiUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });


        vm.startBroadcast(deployer);
        vm.stopBroadcast();
    }

    function __setupUSDCAD() internal {

        uint cadFeeIndex = 16;

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
            minLevPosUSDC: 1500*1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: cadFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(cadUSDFee);
        pairStorage.addPair(cadUSD);
        pairStorage.addSkewOpenFees(cadUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupUSDCHF() internal {

        uint chfFeeIndex = 17;

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
            minLevPosUSDC: 1500*1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: chfFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(chfUSDFee);
        pairStorage.addPair(chfUSD);
        pairStorage.addSkewOpenFees(chfUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupUSDSEK() internal {

        uint sekFeeIndex = 18;

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
            minLevPosUSDC: 100*1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: sekFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(sekUSDFee);
        pairStorage.addPair(sekUSD);
        pairStorage.addSkewOpenFees(sekUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupAUDUSD() internal {

        uint audFeeIndex = 19;

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
            minLevPosUSDC: 100*1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: audFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(audUSDFee);
        pairStorage.addPair(audUSD);
        pairStorage.addSkewOpenFees(audUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupNZDUSD() internal {

        uint nzdFeeIndex = 20;

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
            minLevPosUSDC: 100*1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: nzdFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(nzdUSDFee);
        pairStorage.addPair(nzdUSD);
        pairStorage.addSkewOpenFees(nzdUSDSkewFee);
        vm.stopBroadcast();
    }

    function __setupUSDSDG() internal {

        uint sgdFeeIndex = 20;

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
            minLevPosUSDC: 100*1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: sgdFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        vm.startBroadcast(deployer);
        pairStorage.addFee(sgdUSDFee);
        pairStorage.addPair(sgdUSD);
        pairStorage.addSkewOpenFees(sgdUSDSkewFee);
        vm.stopBroadcast();
    }

    function __correctETH() internal {

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
            minLevPosUSDC: 500*1e6 
        });


        IPairStorage.Pair memory ethUSD = IPairStorage.Pair({
            from: "ETH",
            to:   "USD",
            feed: ethUSDFeed,
            backupFeed: ethUsdBackupFeed,
            spreadP: 5e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 0,
            feeIndex: 0 ,
            groupOpenInterestPecentage: 70,
            maxWalletOI : 5
        });

        pairStorage.updatePair(0, ethUSD);
    }
    
    function __correctBTC() internal {

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
            spreadP:5e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: 0,
            groupIndex: 0,
            feeIndex: btcFeeIndex,
            groupOpenInterestPecentage: 70, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        pairStorage.updatePair(1, btcUSD);
    }

    function __setupJPY() internal {

        uint jpyFeeIndex = 2;

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
            minLevPosUSDC: 1500*1e6 // 1USD
        });

        IPairStorage.Pair memory jpyUSD = IPairStorage.Pair({
            from: "USD",
            to:   "JPY",
            feed: jpyUSDFeed,
            backupFeed: jypUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: jpyFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        pairStorage.updatePair(2, jpyUSD);
    }

    function __setupGBP() internal {

        uint gbpFeeIndex = 3;

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
            minLevPosUSDC: 1500*1e6 // 1USD
        });

        IPairStorage.Pair memory gbpUSD = IPairStorage.Pair({
            from: "GBP",
            to:   "USD",
            feed: gbpUSDFeed,
            backupFeed: gbpUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: gbpFeeIndex,
            groupOpenInterestPecentage: 30,
            maxWalletOI : 10
        });

        pairStorage.updatePair(3, gbpUSD);
    }

    function __setupEUR() internal {

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
            minLevPosUSDC: 1500*1e6 // 1USD
        });

        IPairStorage.Pair memory eurUSD = IPairStorage.Pair({
            from: "EUR",
            to:   "USD",
            feed: eurUSDFeed,
            backupFeed: eurUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: 4,
            groupOpenInterestPecentage: 40,
            maxWalletOI : 10
        });

        pairStorage.updatePair(4, eurUSD);
    }

    function __setupSilver() internal {

        uint xagFeeIndex = 5;

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
            minLevPosUSDC: 1000*1e6 
        });

        IPairStorage.Pair memory xagUSD = IPairStorage.Pair({
            from: "XAG",
            to:   "USD",
            feed: xagUSDFeed,
            backupFeed: xagUsdBackupFeed,
            spreadP: 2e8,
            priceImpactMultiplier: 0,
            skewImpactMultiplier: 0,
            groupIndex: 2,
            feeIndex: xagFeeIndex,
            groupOpenInterestPecentage: 70,
            maxWalletOI : 10
        });

        pairStorage.updatePair(5, xagUSD);
    }

    function __setupGold() internal {

        uint xauFeeIndex = 6;

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
            minLevPosUSDC: 1000*1e6 
        });

          IPairStorage.Pair memory xauUSD = IPairStorage.Pair({
            from: "XAU",
            to:   "USD",
            feed: xauUSDFeed,
            backupFeed: xauUsdBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 2,
            feeIndex: xauFeeIndex,
            groupOpenInterestPecentage: 70,
            maxWalletOI : 10
        });

        pairStorage.updatePair(6, xauUSD);
    }

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
            if(_pairIndex == 5){ // Silver
                skew[0][0] = -5;
                skew[0][1] = 800 ;
                skew[1][0] = -5 ;
                skew[1][1] = 800 ;
                skew[2][0] = -5 ;
                skew[2][1] = 800 ;
                skew[3][0] = -5 ;
                skew[3][1] = 800 ;
                skew[4][0] = 0 ;
                skew[4][1] = 600 ;
                skew[5][0] = 0 ;
                skew[5][1] = 600 ;
                skew[6][0] = -5 ;
                skew[6][1] = 900 ;
                skew[7][0] = -5 ;
                skew[7][1] = 900 ;
                skew[8][0] = -5 ;
                skew[8][1] = 900 ;
                skew[9][0] = -5 ;
                skew[9][1] = 900 ;
            }
            else if(_pairIndex == 6){ // Gold
                skew[0][0] = -5;
                skew[0][1] = 1000 ;
                skew[1][0] = -5 ;
                skew[1][1] = 1000 ;
                skew[2][0] = -5 ;
                skew[2][1] = 1000 ;
                skew[3][0] = -5 ;
                skew[3][1] = 1000 ;
                skew[4][0] = 0 ;
                skew[4][1] = 800 ;
                skew[5][0] = 0 ;
                skew[5][1] = 800 ;
                skew[6][0] = -5 ;
                skew[6][1] = 1100 ;
                skew[7][0] = -5 ;
                skew[7][1] = 1100 ;
                skew[8][0] = -5 ;
                skew[8][1] = 1100 ;
                skew[9][0] = -5 ;
                skew[9][1] = 1100 ;
            }
        }

        return skew;
    }

}