pragma solidity 0.8.7;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Execute} from "../../src/Execute.sol";
import {PairInfos} from "../../src/PairInfos.sol";
import {PairStorage} from "../../src/PairStorage.sol";
import {PriceAggregator} from "../../src/PriceAggregator.sol";
import {Trading} from "../../src/Trading.sol";
import {TradingCallbacks} from "../../src/TradingCallbacks.sol";
import {TradingStorage} from "../../src/TradingStorage.sol";
import {Tranche} from "../../src/Tranche.sol";
import {VaultManager} from "../../src/VaultManager.sol";
import {VeTranche} from "../../src/VeTranche.sol";
import {USDC} from "../../src/testnet/USDC.sol";
import {MockPyth} from "pyth-sdk-solidity/MockPyth.sol";
import {Referral} from "../../src/Referral.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import "../../src/interfaces/IPairInfos.sol";
import "forge-std/console.sol";
import {Constants} from "../Deployment/Constants.sol";

contract UpdateScript is Script {

    // Set This false for mainnet Deployment
    bool constant isTestnet  = true; 

    address public deployer;
    address public vaultGovernor;
    address public pairInfoManager;

    Trading public trading;

    Tranche public juniorTranche;
    Tranche public seniorTranche;
    USDC public usdc;
    TradingStorage public tradingStorage;
    PairStorage public pairStorage;
    
    function run() public {

        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        deployer = vm.rememberKey(deployerKey);

        uint256 vaultGovernorKey = vm.envUint("VAULT_GOVERNOR_KEY");
        vaultGovernor = vm.rememberKey(vaultGovernorKey);

        uint256 pairInfoManagerKey = vm.envUint("PAIR_INFO_MANAGER_KEY");
        pairInfoManager = vm.rememberKey(pairInfoManagerKey);

        trading = Trading(0x3Eae140CDbAcC9a0777198DAD939649820B83886);
        juniorTranche = Tranche(0x655b92c8E1196dD5233fF3BE19F900257780038e);
        seniorTranche = Tranche(0x157c6d2277e1b9158ee2c93C3DDDAfE54e7cd24d);
        usdc = USDC(0xab3AFb807b623195CC43433f44f07a5051F9519E);
        tradingStorage = TradingStorage(0x711871098b840Ed5027ed20f4132657986CFe7FC);
        pairStorage = PairStorage(0x98c3E0d5e30Ae78BF1cfC254aD1728F4066667af);

    }
/**
    function __updateJPYUSDPair() internal {


        uint jpyFeeIndex = 2;

        IPairStorage.Feed memory jpyUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: isTestnet 
                    ? Constants.PYTH_JPY_USD_FEED_OPTIMISM_GOERLI
                    : Constants.PYTH_JPY_USD_FEED_OPTIMISM_MAINNET

        });

        IPairStorage.BackupFeed memory jypUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: isTestnet 
                    ? Constants.JPY_USD_CHAINLINK_FEED_OPTIMISM_GOERLI
                    : Constants.JPY_USD_CHAINLINK_FEED_OPTIMISM_MAINNET
        });

        IPairStorage.Fee memory jpyUSDFee = IPairStorage.Fee({
            name: "JPY_USD_FEE",
            openFeeP: 3e8, //0.1%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1e6 // 1USD
        });


        IPairStorage.Pair memory jpyUSD = IPairStorage.Pair({
            from: "USD",
            to:   "JPY",
            feed: jpyUSDFeed,
            backupFeed: jypUsdBackupFeed,
            spreadP: 5e8,
            groupIndex: 1,
            feeIndex: jpyFeeIndex,
            groupOpenInterestPecentage: 50,
            maxWalletOI : 10
        });

        vm.startBroadcast(deployer);
        pairStorage.updatePair(2, jpyUSD);
        tradingStorage.setMaxTradesPerPair(20);
        vm.stopBroadcast();
    }
*/
}
