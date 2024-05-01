pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";

contract StopLimitTrade is TradeBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testStopLimitLongOrder() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = 100*1e6;
        usdc.approve(address(tradingStorage), amount );

        //Limit Long at 51000
        _placeStopLimitLong(traders[rand], amount, btcPairIndex,  51000, 0);

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
            51055);
        
        vm.stopPrank();

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        //consoleTrade(_trade);
        assert(_trade.leverage > 0);

    }

    function testStopLimitLongOrderWrongExecution() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = 100*1e6;
        
        usdc.approve(address(tradingStorage), amount );

        //Limit Long at 51000
        _placeStopLimitLong(traders[rand], amount, btcPairIndex,  51000, 0);

        vm.stopPrank();
        assertEq(tradingStorage.hasOpenLimitOrder(
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1), true);
        
        // Get another Random Trader as executor
        uint rando = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rando]);
        
        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, btcPairIndex, 50900);
        uint val =  mockPyth.getUpdateFee(priceUpdateData);
        _setChainlinkBTC(50900);

        trading.executeLimitOrder{value: val}(
            ITradingStorage.LimitOrder.OPEN, 
            traders[rand], 
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1, 
            priceUpdateData);

        vm.stopPrank();

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        //consoleTrade(_trade);
        assert(_trade.leverage == 0);
    }

    function testStopLimitShortOrder() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        //Limit Long at 51000
        _placeStopLimitShort(traders[rand], amount, btcPairIndex,  51000, 0);

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