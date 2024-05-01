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

contract SetupLossProtection is Script {

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

    IPairInfos.PairParams public pairParam = IPairInfos.PairParams({
        onePercentDepthAbove: 1000000*1e6, // 10m
        onePercentDepthBelow: 1000000*1e6, // USDCc
        rolloverFeePerBlockP: 55555 // 0.01% per hour
    });

    IPairInfos.PairParams public forexPairParam = IPairInfos.PairParams({
        onePercentDepthAbove: 10000000*1e6, // 10m
        onePercentDepthBelow: 10000000*1e6, // USDC
        rolloverFeePerBlockP: 8333 // 0.0015% per hour
    });
    IPairInfos.PairParams public silverPairParam = IPairInfos.PairParams({
        onePercentDepthAbove: 1000000*1e6, // 1m
        onePercentDepthBelow: 1000000*1e6, // USDC
        rolloverFeePerBlockP: 27777 // 0.005% per hour
    });
    IPairInfos.PairParams public goldPairParam = IPairInfos.PairParams({
        onePercentDepthAbove: 1000000*1e6, // 1m
        onePercentDepthBelow: 1000000*1e6, // USDC
        rolloverFeePerBlockP: 13888 // 0.0025% per hour
    });
    IPairInfos.PairParams public mediumCryptoPairParam = IPairInfos.PairParams({
        onePercentDepthAbove: 1000000*1e6, // 10m
        onePercentDepthBelow: 1000000*1e6, // USDC
        rolloverFeePerBlockP: 111111 // 0.02% per hour
    });

    IPairInfos.PairParams public smallCryptoPairParam = IPairInfos.PairParams({
        onePercentDepthAbove: 1000000*1e6, // 10m
        onePercentDepthBelow: 1000000*1e6, // USDC
        rolloverFeePerBlockP: 222222 // 0.04% per hour
    });


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
    
    function run() public {

        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        deployer = vm.rememberKey(deployerKey);

        trading = isTestnet 
                  ? Trading(Addresses.BASE_TESTNET_TRADING)
                  : Trading(Addresses.BASE_MAINNET_TRADING);
        pairStorage = isTestnet 
                  ? PairStorage(Addresses.BASE_TESTNET_PAIRSTORAGE)
                  : PairStorage(Addresses.BASE_MAINNET_PAIRSTORAGE);
        pairInfos = isTestnet
                  ? PairInfos(Addresses.BASE_TESTNET_PAIRINFOS)
                  : PairInfos(Addresses.BASE_MAINNET_PAIRINFOS);

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

        referral = isTestnet 
                  ? Referral(Addresses.BASE_TESTNET_REFERRAL)
                  : Referral(Addresses.BASE_MAINNET_REFERRAL);
        __setLossProtectionAndTiers();
        __setReferralTiers();
    }

    function __setLossProtectionAndTiers() internal{

        uint[] memory standardLossProtectionConfig = _getLossProtectionConfig(0, 60, 70, 80);  

        vm.startBroadcast(deployer);

        pairInfos.setPairParams(ethPairIndex, pairParam);
        pairInfos.setPairParams(btcPairIndex, pairParam);
        pairInfos.setPairParams(jpyPairIndex, forexPairParam);
        pairInfos.setPairParams(gbpPairIndex, forexPairParam);
        pairInfos.setPairParams(eurPairIndex, forexPairParam);
        pairInfos.setPairParams(xagPairIndex, silverPairParam);
        pairInfos.setPairParams(xauPairIndex, goldPairParam);
        pairInfos.setPairParams(solPairIndex, mediumCryptoPairParam);
        pairInfos.setPairParams(bnbPairIndex, mediumCryptoPairParam);
        pairInfos.setPairParams(arbPairIndex, mediumCryptoPairParam);
        pairInfos.setPairParams(dogePairIndex, mediumCryptoPairParam);
        pairInfos.setPairParams(avaxPairIndex, mediumCryptoPairParam);
        pairInfos.setPairParams(opPairIndex, mediumCryptoPairParam);
        pairInfos.setPairParams(maticPairIndex, mediumCryptoPairParam);
        pairInfos.setPairParams(tiaPairIndex, smallCryptoPairParam);
        pairInfos.setPairParams(seiPairIndex, smallCryptoPairParam);
        pairInfos.setPairParams(cadPairIndex, forexPairParam);
        pairInfos.setPairParams(chfPairIndex, forexPairParam);
        pairInfos.setPairParams(sekPairIndex, forexPairParam);
        pairInfos.setPairParams(audPairIndex, forexPairParam);
        pairInfos.setPairParams(nzdPairIndex, forexPairParam);
        pairInfos.setPairParams(sgdPairIndex, forexPairParam);

        for(uint i = 0; i< 22; i++){
            pairInfos.setLossProtectionConfig(i,standardLossProtectionConfig, standardLossProtectionConfig);
        }

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

        for(uint i; i< 22; i++){
            pairStorage.updateLossProtectionMultiplier(i, tier, tierMultiplier);          
        }

        uint256[] memory indexes =  new uint256[](22);
        uint256[] memory limits =  new uint256[](22);

        for(uint i; i< 22; i++){
            indexes[i] = i;
            limits[i] = 1000000e6;
        }

        pairStorage.setBlockOILImits(indexes, limits);

        vm.stopBroadcast();
    }

    function __setReferralTiers() internal {

        vm.startBroadcast(deployer);

        referral.setTier(1, 500, 500); // 5% on opening/closing, Total 10%, Total Loss to Protocol = 20%
        referral.setTier(2, 1000, 1000); // 10%, 20%, 40%
        referral.setTier(3, 1500, 1500); // 15%, 30%, 60%

        vm.stopBroadcast();
    }
/**------------------Utility Functions-------------------------------------------- */

    function _getLossProtectionConfig(uint a, uint b, uint c, uint d) internal pure returns (uint256[] memory) {
        uint256[] memory config = new uint256[](4);
        config[0] = a;
        config[1] = b;
        config[2] = c;
        config[3] = d;

        return config;
    }
}