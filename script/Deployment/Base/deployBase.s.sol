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

contract DeployScript is Script {

    // Set This false for mainnet Deployment
    bool constant isTestnet  = false; 

    uint constant PRECISION = 1e10;

    address public deployer;

    ProxyAdmin public proxyAdmin;
    TradingStorage public tradingStorage;
    PairStorage public pairStorage;
    PairInfos public pairInfos;
    PriceAggregator public priceAggregator;
    Trading public trading;
    TradingCallbacks public tradingCallbacks;
    Tranche public juniorTranche;
    Tranche public seniorTranche;
    VaultManager public vaultManager;
    VeTranche public juniorVeTranche;
    VeTranche public seniorVeTranche;
    Execute public execute;
    Referral public referral;

    USDC public usdc;
    address public pyth;

    function run() public {

        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        deployer = vm.rememberKey(deployerKey);

        __deployContracts();
    }

    function __deployContracts() internal {

        vm.startBroadcast(deployer);
        
        __deployUSDC();
        __deployProxyAdmin();
        __deployTradingStorage();
        __deployPairStorage();
        __deployPairsInfos();
        __deployTrading();
        __deployExecution();
        __deployTradingCallbacks();
        __deployPriceAggregator();
        __deployVaultManager();
        __deployTranches();
        __deployVeTranches();
        __deployReferral();

        vm.stopBroadcast();
    }

    function __deployUSDC() internal {
        isTestnet 
            ? usdc = new USDC('Avantis USDC', 'aUSDC', 1e15)
            : usdc = USDC(Addresses.BASE_MAINNET_USDC);
    }

    function __deployProxyAdmin() internal {
        proxyAdmin = new ProxyAdmin(); // Deploy proxy Admin
    }

    function __deployTradingStorage() internal {
        TradingStorage tradingStorageImpl = new TradingStorage();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(tradingStorageImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        tradingStorage = TradingStorage(address(proxy));

        tradingStorage.initialize();
    }

    function __deployPairStorage() internal {
        PairStorage pairStorageImpl = new PairStorage();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(pairStorageImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        pairStorage = PairStorage(address(proxy));

        pairStorage.initialize(address(tradingStorage),1 );
    }

    function __deployPairsInfos() internal {
        PairInfos pairInfosImpl = new PairInfos();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(pairInfosImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        pairInfos = PairInfos(address(proxy));

        pairInfos.initialize(address(tradingStorage), address(pairStorage));
    }

    function __deployTrading() internal {
        Trading tradingImpl = new Trading();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(tradingImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        trading = Trading(address(proxy));

        trading.initialize(address(tradingStorage), address(pairInfos));
    }

    function __deployExecution() internal {
        Execute executeImpl = new Execute();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(executeImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        execute = Execute(address(proxy));

        execute.initialize(address(tradingStorage));
    }

    function __deployTradingCallbacks() internal {
        TradingCallbacks tradingCallbacksImpl = new TradingCallbacks();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(tradingCallbacksImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        tradingCallbacks = TradingCallbacks(address(proxy));

        tradingCallbacks.initialize(address(tradingStorage), address(pairInfos));
    }

    function __deployPriceAggregator() internal {
        PriceAggregator priceAggregatorImpl = new PriceAggregator();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(priceAggregatorImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        priceAggregator = PriceAggregator(address(proxy));

        priceAggregator.initialize(address(tradingStorage), address(pairStorage), address(execute));
    }

    function __deployVaultManager() internal {
        VaultManager vaultMangerImpl = new VaultManager();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(vaultMangerImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        vaultManager = VaultManager(address(proxy));

        vaultManager.initialize(deployer, address(tradingStorage));
    }

    function __deployTranches() internal {

        __deployJuniorTranch();
        __deploySeniorTranch();

    }

    function __deployJuniorTranch() internal {
        Tranche tranchImpl = new Tranche();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(tranchImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        juniorTranche = Tranche(address(proxy));

        juniorTranche.initialize(address(usdc), address(vaultManager), "JUNIOR TRANCHE", "j");
    }

    function __deploySeniorTranch() internal {
        Tranche tranchImpl = new Tranche();

        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(tranchImpl),
            address(proxyAdmin),
            new bytes(0));

        // Cast proxy to orderManager   
        seniorTranche = Tranche(address(proxy));


        seniorTranche.initialize(address(usdc), address(vaultManager), "SENIOR TRANCHE", "s");
    }

    function __deployVeTranches() internal {
        __deployJuniorVeTranche();
        __deploySeniorVeTranche();
    }

    function __deployJuniorVeTranche() internal {

        VeTranche veTrancheImpljunior = new VeTranche();
        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(veTrancheImpljunior),
            address(proxyAdmin),
            new bytes(0));
        // Cast proxy to orderManager   
        juniorVeTranche = VeTranche(address(proxy));
        juniorVeTranche.initialize(address(juniorTranche), address(vaultManager));
    }

    function __deploySeniorVeTranche() internal {

        VeTranche veTrancheImplsenior = new VeTranche();
        // Deploy Proxy calling initialize as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(veTrancheImplsenior),
            address(proxyAdmin),
            new bytes(0));
        // Cast proxy to orderManager   
        seniorVeTranche = VeTranche(address(proxy));
        seniorVeTranche.initialize(address(seniorTranche), address(vaultManager));
    }

    function __deployReferral() internal {

        referral = new Referral();
    }

}