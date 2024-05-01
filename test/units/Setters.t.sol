pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {SkewedBase} from "../fixtures/SkewedBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import {IPairStorage} from "../../src/interfaces/IPairStorage.sol";
import {IPairInfos} from "../../src/interfaces/IPairInfos.sol";

contract Setters is SkewedBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testTrading() public {

        vm.startPrank(deployer);

        trading.setLimitOrdersTimelock(50); 
        assert(trading.limitOrdersTimelock() == 50);

        trading.toggleWhitelist(); 
        assert(trading.isWhitelisted() == true);

        trading.pause(); 
        assert(trading.paused() == true);

        trading.unpause();
        assert(trading.paused() == false);

        vm.stopPrank();
    }

    function testCallbacks() public {

        vm.startPrank(deployer);

        tradingCallbacks.setFeeP(7, 12,30 ); 
        assert(tradingCallbacks.liqFeeP() == 7);
        assert(tradingCallbacks.liqTotalFeeP() == 12);
        assert(tradingCallbacks.vaultFeeP() == 30);
        vm.stopPrank();
    }

    function testTradingStorage() public {

        vm.startPrank(deployer);

        tradingStorage.setMaxTradesPerPair(10); 
        assert(tradingStorage.maxTradesPerPair() == 10);

        tradingStorage.setMaxPendingMarketOrders(30); 
        assert(tradingStorage.maxPendingMarketOrders() == 30);

        vm.stopPrank();
    }

   function testPriceAggregator() public {

        vm.startPrank(deployer);

        (address newAggregator, ) = makeAddrAndKey("newAggregator");
        priceAggregator.updatePairsStorage(newAggregator); 
        assert(address(priceAggregator.pairsStorage()) == newAggregator);

        vm.stopPrank();
    }
   
   function testTranche() public {

        vm.startPrank(deployer);
        
        juniorTranche.setWithdrawThreshold(80*1e10); 

        vm.stopPrank();
        
        vm.startPrank(deployer);

        assert(juniorTranche.withdrawThreshold() == 80*1e10);

        uint utilizationRatio = juniorTranche.utilizationRatio();
        assert(utilizationRatio!= 0);

        assertEq(juniorTranche.depositCap(), 1e18);

        vm.stopPrank();
    }

   
   function testPairStorage() public {
        IPairStorage.Feed memory btcUSDFeed =  IPairStorage.Feed({
            maxDeviationP: 2e9, //2%
            feedId: keccak256("BTC_USD_PYTH")
        });
        
        IPairStorage.BackupFeed memory btcUSDBackupFeed =  IPairStorage.BackupFeed({
            maxDeviationP: 2e9, //2%
            feedId: makeAddr("BTC_USD_CHAINLINK")
        });

        IPairStorage.Pair memory btcUSD = IPairStorage.Pair({
            from: "BTC",
            to:   "USD",
            feed: btcUSDFeed,
            backupFeed: btcUSDBackupFeed,
            spreadP: 10e8,
            priceImpactMultiplier: 0, 
            skewImpactMultiplier: 0,
            groupIndex: 0,
            feeIndex: 0,
            groupOpenInterestPecentage: 65, // Percentage of Group OI
            maxWalletOI : 5 // wallet OI cap
        });

        vm.startPrank(deployer);

        pairStorage.updatePair(btcPairIndex, btcUSD); 
        (,,,, uint spreadNewP,,,,,,) = pairStorage.pairs(btcPairIndex);
        assert(spreadNewP == 10e8);

        IPairStorage.Fee memory newFee = IPairStorage.Fee({
            name: "BTC_USD_FEE",
            openFeeP: 1e9, //0.1%
            closeFeeP: 1e9,
            limitOrderFeeP: 1*1e10,// Multiply By precsision
            minLevPosUSDC: 3e6 // 1USD
        });
        
        pairStorage.updateFee(btcPairIndex, newFee);
        (,,,,uint minLevel) = pairStorage.fees(btcPairIndex);
        assert(minLevel == 3e6);
        /**
        IPairStorage.SkewFee memory newOpenSkewFees = IPairStorage.SkewFee({
            thresholdHigh: 100,
            thresholdMid: 100, 
            thresholdLow: 100,
            slopeMid: -40,
            slopeLow: -20,
            interceptMid: 3600,
            interceptLow: 2200,
            feeHigh: 400  
        });

        pairStorage.udpateSkewOpenFees(btcPairIndex, newOpenSkewFees);
        (,uint threshold,,,,,,) = pairStorage.skewFees(btcPairIndex);
        assert(threshold == 100);
        */
        pairStorage.delistPair(btcPairIndex);
        assert( pairStorage.isPairListed("BTC", "USD") == false);

        IPairStorage.Group memory newGroup = IPairStorage.Group({
            name: "CRYPTO",
            minLeverage: 2*PRECISION,
            maxLeverage: 75*PRECISION,
            maxOpenInterestP: 80 // max = 80% liquidity
        });

        pairStorage.updateGroup(btcPairIndex, newGroup);
        (,,uint maxL,) = pairStorage.groups(btcPairIndex);
        assertEq(maxL, 75*PRECISION);

        vm.stopPrank();
    }

    function testReferral() public {

        vm.startPrank(deployer);

        (address newHandler, ) = makeAddrAndKey("newHandler");
        referral.setHandler(newHandler, true); 
        assert(referral.isHandler(newHandler) == true);

        (address latestHandler, ) = makeAddrAndKey("latestHandler");
        referral.govSetCodeOwner(bytes32("milk"), latestHandler ); 
        assert(referral.codeOwners(bytes32("milk")) == latestHandler);

        vm.stopPrank();

        vm.startPrank(newHandler);
        referral.setTraderReferralCode(newHandler, bytes32("milk")); 
        assert(referral.traderReferralCodes(newHandler) == bytes32("milk"));
        vm.stopPrank();
    }

    function testExecute() public {

        vm.startPrank(deployer);

        execute.updateTriggerTimeout(10); 
        assert(execute.triggerTimeout() == 10);

        vm.stopPrank();
    }

    function testVaultManager() public {

        vm.startPrank(deployer);

        vaultManager.setStorage(address(0x96ec02F6c1ed3c1bf31b81A16742f54dbfB26C7F));
        assert(address(vaultManager.storageT()) == address(0x96ec02F6c1ed3c1bf31b81A16742f54dbfB26C7F));

        vaultManager.setJuniorTranche(address(0x96ec02F6c1ed3c1bf31b81A16742f54dbfB26C7F));
        assert(address(vaultManager.junior()) == address(0x96ec02F6c1ed3c1bf31b81A16742f54dbfB26C7F));

        vaultManager.setSeniorTranche(address(0x96ec02F6c1ed3c1bf31b81A16742f54dbfB26C7F));
        assert(address(vaultManager.senior()) == address(0x96ec02F6c1ed3c1bf31b81A16742f54dbfB26C7F));

        vaultManager.setReserveRatio(30);
        assert(vaultManager.targetReserveRatio() == 30);

        vaultManager.setBalancingDeltaThreshold(30);
        assert(vaultManager.balancingDeltaThreshold() == 30);

        vaultManager.setConstrainedLiquidityThreshold(30);
        assert(vaultManager.constrainedLiquidityThreshold() == 30);

        vaultManager.setEarlyWithdrawFee(50);
        assert(vaultManager.earlyWithdrawFee() == 50);

        vaultManager.setBalancingFee(30);
        assert(vaultManager.balancingFee() == 30);

        vaultManager.setMinLockTime(1 days);
        assert(vaultManager.minLockTime() == 1 days);

        vaultManager.setMaxLockTime(2 days);
        assert(vaultManager.maxLockTime() == 2 days);

        vaultManager.setBaseMultiplier(100);
        assert(vaultManager.baseMultiplier() == 100);

        vaultManager.setMaxMultiplier(150);
        assert(vaultManager.maxMultiplier() == 150);

        vaultManager.setMultiplierDenom(150);
        assert(vaultManager.multiplierDenom() == 150);

        vaultManager.setMultiplierCoeff(150);
        assert(vaultManager.multiplierCoeff() == 150);

        vaultManager.setRewardPeriod(5 days);
        assert(vaultManager.rewardPeriod() == 5 days);

        vaultManager.setCurrentOpenPnl(150);
        assert(vaultManager.currentOpenPnl() == 150);
        uint256[5] memory _collateralFees = [uint(1),uint(2),uint(3),uint(4),uint(5)];

        vaultManager.setCollateralFees(_collateralFees);
        assert(vaultManager.collateralFees(0) == 1);

        vaultManager.setBufferThresholds(_collateralFees);
        assert(vaultManager.bufferThresholds(0) == 1);

        vm.stopPrank();  
    }

    function testPairInfos() public {

        vm.startPrank(deployer);

        IPairInfos.PairParams memory newPairParam = IPairInfos.PairParams({
            onePercentDepthAbove: 100000*1e6, // 1m
            onePercentDepthBelow: 100000*1e6, // USDC
            rolloverFeePerBlockP: 32323 // 0.1%
        });

        pairInfos.setPairParams(0, newPairParam);
        (,,uint rP) = pairInfos.pairParams(0);
        assertEq(rP, 32323);

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        IPairInfos.PairParams[] memory newPairParams = new IPairInfos.PairParams[](2);
        newPairParams[0].onePercentDepthAbove = 100000*1e6;
        newPairParams[1].onePercentDepthAbove = 100000*1e6;  

        newPairParams[0].onePercentDepthBelow = 100000*1e6;
        newPairParams[1].onePercentDepthBelow = 100000*1e6;   

        newPairParams[0].rolloverFeePerBlockP = 32323;
        newPairParams[1].rolloverFeePerBlockP = 32323;      

        pairInfos.setPairParamsArray(indices, newPairParams);
        (,,uint rPs) = pairInfos.pairParams(1);
        assertEq(rPs, 32323);

        vm.stopPrank();
    }
}