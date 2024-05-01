pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import "forge-std/console.sol";
contract LiquidateTrade is TradeBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testLiquidation() public {

        // Limit order is placed and executed
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);
        uint amount = 100*1e6;
        usdc.approve(address(tradingStorage), amount );
        //Limit Long at 51000
        _placeLimitLong(traders[rand], amount, btcPairIndex,  51000, 0);
        vm.stopPrank();
        assertEq(tradingStorage.hasOpenLimitOrder(
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1), true);
        uint rando = uint(keccak256(abi.encodePacked(block.timestamp + 1))) % numTraders;
        vm.startPrank(traders[rando]);
        _executeLimitOrder(
            ITradingStorage.LimitOrder.OPEN,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            50945);
        vm.stopPrank();


        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        rando = uint(keccak256(abi.encodePacked(block.timestamp + 2))) % numTraders;

        uint liquidationPrice = pairInfos.getTradeLiquidationPrice(
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            _trade.openPrice,
            _trade.buy,
            _trade.initialPosToken,
            _trade.leverage
        );
        vm.startPrank(traders[rando]);

        // Roll to increase publish Time for this price Feed
        vm.warp(100000);
        _executeLimitOrder(
            ITradingStorage.LimitOrder.LIQ,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            (liquidationPrice/1e10));
        vm.stopPrank();

        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_updatedTrade.leverage == 0);

    }

    function testClaimLiquidationReward() public {

        // Limit order is placed and executed
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);
        uint amount = 100*1e6;
        usdc.approve(address(tradingStorage), amount );
        //Limit Long at 51000
        _placeLimitLong(traders[rand], amount, btcPairIndex,  51000, 0);
        vm.stopPrank();
        assertEq(tradingStorage.hasOpenLimitOrder(
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1), true);
        uint rando = uint(keccak256(abi.encodePacked(block.timestamp + 1))) % numTraders;
        vm.startPrank(traders[rando]);
        _executeLimitOrder(
            ITradingStorage.LimitOrder.OPEN,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            50945);
        vm.stopPrank();


        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        rando = uint(keccak256(abi.encodePacked(block.timestamp + 2))) % numTraders;

        uint liquidationPrice = pairInfos.getTradeLiquidationPrice(
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            _trade.openPrice,
            _trade.buy,
            _trade.initialPosToken,
            _trade.leverage
        );
        vm.startPrank(traders[rando]);

        // Roll to increase publish Time for this price Feed
        vm.warp(100000);
        _executeLimitOrder(
            ITradingStorage.LimitOrder.LIQ,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            (liquidationPrice/1e10));


        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_updatedTrade.leverage == 0);

        //Liquidator now claims the liquidation reward
        uint balBefore = usdc.balanceOf(traders[rando]);
        execute.claimTokens();
        uint balAfter = usdc.balanceOf(traders[rando]);

        assert(execute.tokensToClaim(traders[rando]) == 0);
        assert(execute.tokensClaimed(traders[rando]) == balAfter - balBefore);

        vm.stopPrank();

    }
    function _executeLimitOrder(
        ITradingStorage.LimitOrder _orderType,
        address _trader,
        uint _pairIndex,
        uint _index,
        uint _rawPrice) internal{

        _setChainlinkBTC(_rawPrice);
        trading.executeLimitOrder{value: mockPyth.getUpdateFee(_generateSampleUpdateDataCrypto(1, btcPairIndex, _rawPrice))}(
            _orderType, 
            _trader, 
            _pairIndex, 
            _index, 
            _generateSampleUpdateDataCrypto(1, btcPairIndex, _rawPrice ));
    }
}
