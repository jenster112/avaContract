pragma solidity 0.8.7;

import "forge-std/Test.sol";
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
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {Referral} from "../../src/Referral.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import "../../src/interfaces/IPairInfos.sol";
import {AvantisTimelockOwner} from "../../src/Timelock.sol";

contract Base is Test {

    uint constant PRECISION = 1e10;
    uint constant numTraders = 3;
    uint constant numLPs =  3;

    address[numTraders] public traders;
    address[numLPs] public liquidityProviders;

    address public deployer;
    address public avntMinter;
    address public avntLp;
    address public avantisMultiSig;
    address public devTreasury;
    address public govTreasury;
    address public operator;

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
    USDC public usdc;
    MockPyth public mockPyth;
    mapping(string => address) public mockChainlink;
    Referral public referral;
    AvantisTimelockOwner public timelock;

    uint ethPairIndex;
    uint btcPairIndex;
    uint jpyPairIndex;
    uint gbpPairIndex;
    uint eurPairIndex;
    
    IPairStorage.Group  public forexGroup;

    mapping(address => uint256) public pKey;
    mapping(address => uint256) public traderOrderIndex;
    
    function setUp() public virtual{

        __labelAddress();
        __deployContracts();
        __setupLPs();
        __setupTraders();
        __setupCryptoPairs();
        __setupForexPairs();
        __runPairManangerService();
        __dealUSDCToTraders();
        __dealUSDCToLPs();
        __vaultSetup();
        __setReferralTiers();

    }

    function __labelAddress() internal {
        
        uint256 privateKey;
        (deployer, privateKey) = makeAddrAndKey("deployer");
        pKey[deployer] = privateKey;
        vm.deal(deployer, 1 ether);

        (avntMinter, privateKey) = makeAddrAndKey("avntMinter");
        pKey[avntMinter] = privateKey;
        vm.deal(avntMinter, 1 ether);

        (avntLp, privateKey) = makeAddrAndKey("avntLp");
        pKey[avntLp] = privateKey;
        vm.deal(avntLp, 1 ether);

        (avantisMultiSig, privateKey) = makeAddrAndKey("avantisMultiSig");
        pKey[avantisMultiSig] = privateKey;
        vm.deal(avantisMultiSig, 1 ether);

        (devTreasury, privateKey) = makeAddrAndKey("devTreasury");
        pKey[devTreasury] = privateKey;
        vm.deal(devTreasury, 1 ether);

        (govTreasury, privateKey) = makeAddrAndKey("govTreasury");
        pKey[govTreasury] = privateKey;
        vm.deal(govTreasury, 1 ether);

        (operator, privateKey) = makeAddrAndKey("operator");
        pKey[operator] = privateKey;
        vm.deal(operator, 1 ether);
    }

    function __deployContracts() internal {
    
        vm.startPrank(deployer);

        __deployMockPyth();
        __deployMockChainlink();
        __deployMockUSDC();
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
        _deployTimelock();
        vm.stopPrank();

        __wire();

        
    }

    function __deployMockPyth() internal {
        mockPyth = new MockPyth(1 days, 1 wei);
    }

    function __deployMockChainlink() internal {
        mockChainlink["ETH_USD_CHAINLINK"] = address(new MockV3Aggregator(8, 0));
        mockChainlink["BTC_USD_CHAINLINK"] = address(new MockV3Aggregator(8, 0));
    }

    function __deployMockUSDC() internal {
        usdc = new USDC("CIRCLE USD", "USDC", 1e20); // Deploy proxy Admin
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

    function _deployTimelock() internal {

        address[] memory proposers = new address[](1);
        proposers[0]= avantisMultiSig;
        address[] memory executors = new address[](1);
        executors[0]= avantisMultiSig;

        timelock =  new AvantisTimelockOwner(0, proposers, executors, deployer);
    }

    function __wire() internal{

        vm.startPrank(deployer);

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
        tradingStorage.setDev(address(devTreasury));
        tradingStorage.setGovTreasury(address(govTreasury));

        // Price Aggregator
        priceAggregator.setPyth(address(mockPyth));

        // Pair Infos
        pairInfos.setManager(deployer);

        trading.updateOperator(operator, true);
        trading.setMarketExecFeeReciever(address(operator));
        
        vm.stopPrank();

        vm.startPrank(deployer);

        // Vault Manager
        vaultManager.setJuniorTranche(address(juniorTranche));
        vaultManager.setSeniorTranche(address(seniorTranche));
        vaultManager.addTradingContract(address(tradingCallbacks));
        vaultManager.addTradingContract(address(tradingStorage));
        vaultManager.addTradingContract(address(trading));
        vaultManager.addTradingContract(address(juniorTranche));
        vaultManager.addTradingContract(address(seniorTranche));
        
        juniorTranche.setVeTranche(address(juniorVeTranche));
        seniorTranche.setVeTranche(address(seniorVeTranche));

        juniorTranche.setCap(1e18);
        seniorTranche.setCap(1e18); 

        vm.stopPrank();
    }

    function __setupLPs() internal {

        uint256 privateKey;
        string memory newLP;

        vm.startPrank(deployer);
        for(uint i = 0; i< numLPs; i++){    

            newLP = string(abi.encodePacked("LP", uintToString(i)));
            (liquidityProviders[i], privateKey) = makeAddrAndKey(newLP);
            pKey[liquidityProviders[i]] = privateKey;

            vm.deal(liquidityProviders[i], 1 ether);
            trading.addWhitelist(liquidityProviders[i]);
        }
        vm.stopPrank();
    }

    function __setupTraders() internal {

        uint256 privateKey;
        string memory newUser;
        vm.startPrank(deployer);
        for(uint i = 0; i< numTraders; i++){    

            newUser = string(abi.encodePacked("User", uintToString(i)));
            (traders[i], privateKey) = makeAddrAndKey(newUser);
            pKey[traders[i]] = privateKey;

            vm.deal(traders[i], 100 ether);
            trading.addWhitelist(traders[i]);
        }
        vm.stopPrank();
    }

    function __setupForexPairs() internal{
        
        forexGroup = IPairStorage.Group({
            name: "FOREX",
            minLeverage: 2*PRECISION,
            maxLeverage: 150*PRECISION,
            maxOpenInterestP: 20 // max = 80% liquidity
        });

        vm.prank(deployer);
        pairStorage.addGroup(forexGroup);

        __setupJPY();
        __setupGBP();
        __setupEUR();
    }

    function __setupJPY() public {

        uint jpyFeeIndex = 2;

        IPairStorage.Feed memory jpyUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: keccak256("JPY_USD_PYTH")
        });

        IPairStorage.BackupFeed memory jypUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: address(mockChainlink["JPY_USD_CHAINLINK"])
        });

        IPairStorage.Fee memory jpyUSDFee = IPairStorage.Fee({
            name: "JPY_USD_FEE",
            openFeeP: 3e8, //0.1%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1e6 // 1USD
        });

        IPairStorage.SkewFee memory jpyUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(1, 2)
        });


        IPairStorage.Pair memory jpyUSD = IPairStorage.Pair({
            from: "JPY",
            to:   "USD",
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

        vm.startPrank(deployer);
        pairStorage.addFee(jpyUSDFee);
        pairStorage.addPair(jpyUSD);
        pairStorage.addSkewOpenFees(jpyUSDSkewFee);
        jpyPairIndex = 2;
        vm.stopPrank();
    }

    function __setupGBP() public {


        uint gbpFeeIndex = 3;

        IPairStorage.Feed memory gbpUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: keccak256("GBP_USD_PYTH")
        });

        IPairStorage.BackupFeed memory gbpUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: address(mockChainlink["GBP_USD_CHAINLINK"])
        });

        IPairStorage.Fee memory gbpUSDFee = IPairStorage.Fee({
            name: "GBP_USD_FEE",
            openFeeP: 3e8, //0.1%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: gbpFeeIndex,
            groupOpenInterestPecentage: 30,
            maxWalletOI : 10
        });

        vm.startPrank(deployer);
        pairStorage.addFee(gbpUSDFee);
        pairStorage.addPair(gbpUSD);
        pairStorage.addSkewOpenFees(gbpUSDSkewFee);
        gbpPairIndex = 3;
        vm.stopPrank();
    }

    function __setupEUR() public {


        IPairStorage.Feed memory eurUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: keccak256("EUR_USD_PYTH")
        });

        IPairStorage.BackupFeed memory eurUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: address(mockChainlink["EUR_USD_CHAINLINK"])
        });

        IPairStorage.Fee memory eurUSDFee = IPairStorage.Fee({
            name: "EUR_USD_FEE",
            openFeeP: 3e8, //0.1%
            closeFeeP: 3e8,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1e6 // 1USD
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
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: 1,
            feeIndex: 4,
            groupOpenInterestPecentage: 40,
            maxWalletOI : 10
        });

        vm.startPrank(deployer);
        pairStorage.addFee(eurUSDFee);
        pairStorage.addPair(eurUSD);
        pairStorage.addSkewOpenFees(eurUSDSkewFee);
        eurPairIndex = 4;
        vm.stopPrank();
    }

    function __setupCryptoPairs() internal{

        uint ethFeeIndex = 0;
        uint btcFeeIndex = 1;    

        uint crytpoGroupIndex = 0;

        IPairStorage.Group memory cryptoGroup = IPairStorage.Group({
            name: "CRYPTO",
            minLeverage: 2*PRECISION,
            maxLeverage: 150*PRECISION,
            maxOpenInterestP: 80 // max = 80% liquidity
        });

        IPairStorage.Feed memory ethUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e10, //2%
            feedId: keccak256("ETH_USD_PYTH")
        });
        
        IPairStorage.BackupFeed memory ethUsdBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: address(mockChainlink["ETH_USD_CHAINLINK"])
        });

        IPairStorage.Fee memory ethUSDFee = IPairStorage.Fee({
            name: "ETH_USD_FEE",
            openFeeP: 1e9, //0.1%
            closeFeeP: 1e9,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 1e6 // 1USD
        });

        /**
            return 0.1
        elif 60 <= x < 70:
            return -0.0020 * x + 0.22
        elif 70 <= x < 80:
            return -0.0040 * x + 0.36
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
            spreadP: 1e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: crytpoGroupIndex,
            feeIndex: ethFeeIndex ,
            groupOpenInterestPecentage: 65,
            maxWalletOI : 5// 5 is extermely restrictive
        });


        IPairStorage.Feed memory btcUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e10, //2%
            feedId: keccak256("BTC_USD_PYTH")
        });
        
        IPairStorage.BackupFeed memory btcUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e10, //2%
            feedId: address(mockChainlink["BTC_USD_CHAINLINK"])
        });

        IPairStorage.Fee memory btcUSDFee = IPairStorage.Fee({
            name: "BTC_USD_FEE",
            openFeeP: 1e9, //0.1%
            closeFeeP: 1e9,
            limitOrderFeeP: 1*1e10,
            minLevPosUSDC: 1e6 // 1USD
        });

        IPairStorage.Pair memory btcUSD = IPairStorage.Pair({
            from: "BTC",
            to:   "USD",
            feed: btcUSDFeed,
            backupFeed: btcUSDBackupFeed,
            spreadP: 1e8,
            priceImpactMultiplier: 12e9,
            skewImpactMultiplier: int(1e10),
            groupIndex: crytpoGroupIndex,
            feeIndex: btcFeeIndex,
            groupOpenInterestPecentage: 65, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        IPairStorage.SkewFee memory btcUSDSkewFee = IPairStorage.SkewFee({
            eqParams: _getSkewFee(0, 1)
        });

        vm.startPrank(deployer);

        pairStorage.addGroup(cryptoGroup);
        pairStorage.addFee(ethUSDFee);
        pairStorage.addPair(ethUSD);
        pairStorage.addSkewOpenFees(ethUSDSkewFee);
        ethPairIndex = 0;

        pairStorage.addFee(btcUSDFee);
        pairStorage.addPair(btcUSD);
        btcPairIndex = 1;
        pairStorage.addSkewOpenFees(btcUSDSkewFee);

        vm.stopPrank();
    }

    function __runPairManangerService() internal{

        IPairInfos.PairParams memory pairParam = IPairInfos.PairParams({
            onePercentDepthAbove: 1000000*1e6, // 1m
            onePercentDepthBelow: 1000000*1e6, // USDC
            rolloverFeePerBlockP: 555555 // 0.1%
        });

        uint[] memory ethUSDLongLossProtectionConfig = _getLossProtectionConfig(0, 80, 90);
        uint[] memory ethUSDShortLossProtectionConfig = _getLossProtectionConfig(0, 80, 90);
        uint[] memory btcUSDLongLossProtectionConfig = _getLossProtectionConfig(0, 80, 90);
        uint[] memory btcUSDShortLossProtectionConfig = _getLossProtectionConfig(0, 80, 90);


        vm.startPrank(deployer);
        pairInfos.setPairParams(ethPairIndex, pairParam);
        pairInfos.setPairParams(btcPairIndex, pairParam);
        pairInfos.setLossProtectionConfig(ethPairIndex,ethUSDLongLossProtectionConfig, ethUSDShortLossProtectionConfig);
        pairInfos.setLossProtectionConfig(btcPairIndex,btcUSDLongLossProtectionConfig, btcUSDShortLossProtectionConfig);
        vm.stopPrank();

        vm.startPrank(deployer);

        uint256[] memory tier = new uint256[](3);
        tier[0] = 0;
        tier[1] = 1;
        tier[2] = 2;

        uint256[] memory tierMultiplier = new uint256[](3);
        tierMultiplier[0] = 100;
        tierMultiplier[1] = 80; // newLoss = 80%of Loss
        tierMultiplier[2] = 70;

        pairStorage.updateLossProtectionMultiplier(ethPairIndex, tier, tierMultiplier);
        pairStorage.updateLossProtectionMultiplier(btcPairIndex, tier, tierMultiplier);
    
        vm.stopPrank();

        vm.startPrank(deployer);

        uint256[] memory indexes =  new uint256[](7);
        indexes[0] = 0;
        indexes[1] = 1;
        indexes[2] = 2;
        indexes[3] = 3;
        indexes[4] = 4;
        indexes[5] = 5;
        indexes[6] = 6;

        uint256[] memory limits =  new uint256[](7);
        limits[0] = 1000000e6;
        limits[1] = 1000000e6;
        limits[2] = 1000000e6;
        limits[3] = 1000000e6;
        limits[4] = 1000000e6;
        limits[5] = 1000000e6;
        limits[6] = 1000000e6;

        pairStorage.setBlockOILImits(indexes, limits);

        vm.stopPrank();
    }

    function __dealUSDCToLPs() internal {

        for(uint i = 0; i< numLPs; i++){

            uint randomHash = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, i)));
            // Generate a random number between 1e6 and 1e12
            uint amount = 1e6 + (randomHash % (1e7*75000*1e6 - 1e6 + 1));

            vm.startPrank(liquidityProviders[i]);
            usdc.mint(liquidityProviders[i], amount);
            vm.stopPrank();
        }
    }

    function __dealUSDCToTraders() internal {

        for(uint i = 0; i< numTraders; i++){

            vm.deal(traders[i], 1 ether);
            uint randomHash = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, i)));
            // Generate a random number between 1e6 and 7500e6
            uint amount = 1e6 + (randomHash % (7500e6 - 1e6 + 1));

            vm.startPrank(traders[i]);
            usdc.mint(traders[i], amount);
            vm.stopPrank();
        }
    }
    
    function __vaultSetup() internal {

        vm.startPrank(deployer);

        juniorTranche.setFeesOn(true);
        seniorTranche.setFeesOn(true);

        vm.stopPrank();
    }

    function __setReferralTiers() internal {

        vm.startPrank(deployer);
        referral.setTier(1, 500, 500); // 5% on opening/closing, Total 10%, Total Loss to Protocol = 20%
        referral.setTier(2, 1000, 1000); // 10%, 20%, 40%
        referral.setTier(3, 1500, 1500); // 15%, 30%, 60%

        vm.stopPrank();
    }


/**------------------Utility Functions-------------------------------------------- */

    function _getLossProtectionConfig(uint a, uint b, uint c) internal pure returns (uint256[] memory) {
        uint256[] memory config = new uint256[](3);
        config[0] = a;
        config[1] = b;
        config[2] = c;
        return config;
    }

    function uintToString(uint _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k--;
            bstr[k] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
            if (k == 0) break;  // Add this line to prevent underflow
        }
        return string(bstr);
    }

    function _getSkewFee(uint _groupIndex, uint _pairIndex) internal pure returns(int256[2][10] memory){

        int[2][10] memory skew;
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