pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";

contract LimitTrade is TradeBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testLimitOpenLong() public {
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
        
        // Get another Random Trader as executor
        uint rando = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rando]);

        _executeLimitOrder(
            ITradingStorage.LimitOrder.OPEN,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            50950);
        
        vm.stopPrank();

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        //consoleTrade(_trade);
        assert(_trade.leverage > 0);
        ///@dev Trade open price is set as 51000 but the order was executed at 50750. 
        ///This is correct as per code right now, but should be that way ?

        
    } 

    function testLimitOpenShort() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = 100*1e6;
        usdc.approve(address(tradingStorage), amount );

        //Limit Long at 51000
        _placeLimitShort(traders[rand], amount, btcPairIndex,  51000, 0);

        vm.stopPrank();
        assertEq(tradingStorage.hasOpenLimitOrder(
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1), true);
        
        // Get another Random Trader as executor
        uint rando = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rando]);

        _executeLimitOrder(
            ITradingStorage.LimitOrder.OPEN,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            51050);
        
        vm.stopPrank();

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_trade.leverage > 0);
        ///@dev Trade open price is set as 51000 but the order was executed at 50750. 
        ///This is correct as per code right now, but should be that way ?
        //consoleTrade(_trade);
        
    } 

    function testClaimExecutionFeeForLimitOpen() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);
        uint amount = 100*1e6;

        uint executionFee = 1e5;
        usdc.mint(traders[rand], executionFee);// Mint 0.1 USDC execution Fee
        usdc.approve(address(tradingStorage), executionFee + amount );
        //Limit Long at 51000
        _placeLimitShort(traders[rand], amount, btcPairIndex,  51000, executionFee);

        vm.stopPrank();
        assertEq(tradingStorage.hasOpenLimitOrder(
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1), true);
        
        // Get another Random Trader as executor
        uint rando = uint(keccak256(abi.encodePacked(block.timestamp+1))) % numTraders;
        vm.startPrank(traders[rando]);

        _executeLimitOrder(
            ITradingStorage.LimitOrder.OPEN,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            51055);
        
        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_trade.leverage > 0);
        //Executor now claims the execution reward
        uint balBefore = usdc.balanceOf(traders[rando]);
        execute.claimTokens();
        uint balAfter = usdc.balanceOf(traders[rando]);

        assert(execute.tokensToClaim(traders[rando]) == 0);
        assert(execute.tokensClaimed(traders[rando]) == balAfter - balBefore);

        vm.stopPrank();
        ///@dev Trade open price is set as 51000 but the order was executed at 50750. 
        ///This is correct as per code right now, but should be that way ?
        //consoleTrade(_trade);
        
    } 

    function testCancelLimitOrder() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        //Limit Long at 51000
        _placeLimitShort(traders[rand], amount, btcPairIndex,  51000, 0);

        vm.roll(1000);
        trading.cancelOpenLimitOrder(btcPairIndex, traderOrderIndex[traders[rand]] -1);

        vm.stopPrank();
        assertEq(tradingStorage.hasOpenLimitOrder(
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1), false);
    }

    function testUpdateLimitOrder() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        //Limit Long at 51000
        _placeLimitShort(traders[rand], amount, btcPairIndex,  51000, 0);

        vm.roll(1000);

        trading.updateOpenLimitOrder(
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1,
            withPricePrecision(52000),
            1e10,
            withPricePrecision(51000),
            withPricePrecision(53000));

        vm.stopPrank();

        assertEq(tradingStorage.hasOpenLimitOrder(
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1), true);

        ITradingStorage.OpenLimitOrder memory  _trade = 
            tradingStorage.getOpenLimitOrder(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_trade.price == withPricePrecision(52000));
        assert(_trade.tp == withPricePrecision(51000));
        assert(_trade.sl == withPricePrecision(53000));
    }

    function testLimitCloseLong() public {

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
            50960);
        vm.stopPrank();

        //Executor executes its closure
        rando = uint(keccak256(abi.encodePacked(block.timestamp + 2))) % numTraders;
        vm.startPrank(traders[rando]);
        _executeLimitOrder(
            ITradingStorage.LimitOrder.TP,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            51050);

        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        assert(_updatedTrade.leverage > 0);
        vm.stopPrank();
    }

    function testClaimExecutionFee() public {

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


        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        vm.warp(10000);
        _setChainlinkBTC(_trade.tp / 1e10);
        _executeLimitOrder(
            ITradingStorage.LimitOrder.TP,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            (_trade.tp)/1e10 + 1);

        //Liquidator now claims the liquidation reward
        uint balBefore = usdc.balanceOf(traders[rando]);
        execute.claimTokens();

        vm.stopPrank();

        uint balAfter = usdc.balanceOf(traders[rando]);

        assert(execute.tokensToClaim(traders[rando]) == 0);
        assert(execute.tokensClaimed(traders[rando]) == balAfter - balBefore);
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