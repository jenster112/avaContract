pragma solidity 0.8.7;

import "forge-std/Script.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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
import {Addresses} from "../Deployment/Base/address.sol";

contract UpgradeScript is Script {

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
        
        // vm.startBroadcast(deployer);
        // _placeMarketTrade();
        _upgradeTrading();
        _upgradePairInfos();
        // vm.stopBroadcast();
    }

    function _placeMarketTrade() internal {

        ITradingStorage.Trade memory _trade =  _generateTrade(
            deployer,
            0,
            true, 
            1, 
            100e6, 
            2400e10
        );
        IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MARKET;

        usdc.approve(address(tradingStorage), 100e6);

        trading.openTrade(
            _trade,
            _type,
            1e10,
            0);

    }


    function _generateTrade(address _trader, uint _pairIndex, bool _buy, uint _index, uint _amount, uint _price) internal view returns(ITradingStorage.Trade memory trade){

        trade.trader = _trader;
        trade.pairIndex = _pairIndex;
        trade.index = _index;
        trade.initialPosToken = 0;
        trade.positionSizeUSDC = _amount;
        trade.openPrice =  _price;
        trade.buy = _buy;
        trade.leverage = 10e10;
        trade.tp = 0; // tp: BigNumber.from(60000).mul(10**10)
        trade.sl = 0; // sl: BigNumber.from(20000).mul(10**10)
        trade.timestamp = block.number;
 
    }
    function _upgradePairStorage() internal {
        vm.startBroadcast(deployer);

        PairStorage newImpl = new PairStorage();
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(pairStorage)),
            address(newImpl)
        );
        vm.stopBroadcast();
    }

    function _upgradePairInfos() internal {
        vm.startBroadcast(deployer);

        PairInfos newImpl = new PairInfos();
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(pairInfos)),
            address(newImpl)
        );
        vm.stopBroadcast();
    }

    function _upgradeTradingStorage() internal {

        vm.startBroadcast(deployer);
        TradingStorage newImpl = new TradingStorage();
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(tradingStorage)), 
            address(newImpl)
        );
        vm.stopBroadcast();
    }
    
    function _upgradeTrading() internal {

        vm.startBroadcast(deployer);
        Trading newImpl = new Trading();
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(trading)), 
            address(newImpl)
        );
        vm.stopBroadcast();
    }

    function _upgradeTradingCallback() internal {

        vm.startBroadcast(deployer);
        TradingCallbacks newImpl = new TradingCallbacks();
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(tradingCallbacks)), 
            address(newImpl)
        );
        vm.stopBroadcast();
    }

    function _upgradePriceAggregator() internal {

        vm.startBroadcast(deployer);
        PriceAggregator newImpl = new PriceAggregator();
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(priceAggregator)), 
            address(newImpl)
        );
        vm.stopBroadcast();
    }

    function _upgradeVaultManager() internal {

        vm.startBroadcast(deployer);
        VaultManager newImpl = new VaultManager();
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(vaultManager)), 
            address(newImpl)
        );
        vm.stopBroadcast();
    }
}
