pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";

contract MarketTrade is TradeBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testMarketOpenLong() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        assert(_trade.leverage > 0);
    } 

    function testCancelMarketOpenLong() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);

        vm.stopPrank();

        vm.startPrank(operator);
        trading.cancelPendingMarketOrder(id);
        vm.stopPrank();

        assertEq(amount, usdc.balanceOf(traders[rand]));
    }
    
    function testMarketCloseLong() public{

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        
        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);

        vm.warp(100000);

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        _setChainlinkBTC(51000);
        uint closed = _placeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  51000);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  51000, closed);

        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        assert(_updatedTrade.leverage == 0);
    }

    function testMarketPartialCloseLong() public{

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);
        

        vm.warp(10000);
        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        _setChainlinkBTC(51500);
        uint closed = _placeMarketClose(btcPairIndex, _trade.initialPosToken/2, traderOrderIndex[traders[rand]] - 1,  51500);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _trade.initialPosToken/2, traderOrderIndex[traders[rand]] - 1,  51500, closed);
        vm.startPrank(traders[rand]);

        vm.warp(10000);
        ITradingStorage.Trade memory _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        _setChainlinkBTC(51500);
        closed = _placeMarketClose(btcPairIndex, _updatedTrade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  51500);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _updatedTrade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  51500, closed);
    }

    function testUpdateTP() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);
        
        vm.roll(1000);
        trading.updateTp(btcPairIndex, traderOrderIndex[traders[rand]] -1, withPricePrecision(51000));

        vm.stopPrank();

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_trade.tp == withPricePrecision(51000));

    }

    function testUpdateTpAndSl() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);
        
        vm.roll(1000);
        vm.warp(1000000);

        _setChainlinkBTC(51500);
        trading.updateTpAndSl{value: mockPyth.getUpdateFee(_generateSampleUpdateDataCrypto(1, btcPairIndex, 51500))}(
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1, 
            withPricePrecision(50500),
            withPricePrecision(51000),
            _generateSampleUpdateDataCrypto(1, btcPairIndex, 51500)
            );
        vm.stopPrank();

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_trade.tp == withPricePrecision(51000));
        assert(_trade.sl == withPricePrecision(50500));
    }

    function testUpdateSL() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);
        
        vm.roll(1000);
        vm.warp(1000000);

        _setChainlinkBTC(51500);
        trading.updateSl{value: mockPyth.getUpdateFee(_generateSampleUpdateDataCrypto(1, btcPairIndex, 51500))}(
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1, 
            withPricePrecision(50500),
            _generateSampleUpdateDataCrypto(1, btcPairIndex, 51500)
            );

        vm.stopPrank();

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        assert(_trade.sl == withPricePrecision(50500));

    }

/**-----------------------Shorts-------------------------------------- */

    function testMarketOpenShort() public{
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        uint id = _placeMarketShort(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketShort(traders[rand], amount, btcPairIndex,  50000, id);

    } 

    function testMarketCloseShort() public{

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id =  _placeMarketShort(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketShort(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);

        vm.warp(10000);
        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        uint closed = _placeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  51000);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  51000, closed);
    }

    function testMarketPartialCloseShort() public{

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id = _placeMarketShort(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketShort(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        vm.warp(10000);
        uint closed = _placeMarketClose(btcPairIndex, _trade.initialPosToken/2, traderOrderIndex[traders[rand]] - 1,  50500);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _trade.initialPosToken/2, traderOrderIndex[traders[rand]] - 1,  50500, closed);
        vm.startPrank(traders[rand]);

        ITradingStorage.Trade memory _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        vm.warp(10000);
        closed = _placeMarketClose(btcPairIndex, _updatedTrade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  50500);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _updatedTrade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  50500, closed);
    }

    function testOpenExecutionFee()  public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        uint ethBal = operator.balance;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        ITradingStorage.Trade memory _trade =  _generateTrade(
            traders[rand],
            btcPairIndex,
            true, 
            traderOrderIndex[traders[rand]], 
            amount, 
            withPricePrecision(50000)
        );
        IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MARKET;

        uint orderId = trading.openTrade{value: 0.5 ether}(
            _trade,
            _type,
            1e10,
            0);

        vm.stopPrank();

        vm.startPrank(operator);
        uint[] memory orderIds = new uint256[](1);
        orderIds[0] = orderId;

        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, btcPairIndex, 50000);
        _setChainlinkBTC(50000);
        trading.executeMarketOrders{value: mockPyth.getUpdateFee(priceUpdateData)}(btcPairIndex, orderIds, priceUpdateData);

        vm.stopPrank();

        uint balAfter = operator.balance;
        assert(balAfter > ethBal);
    
    }

    function testCloseExecutionFee() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        uint ethBal = operator.balance;
        console.logUint(ethBal);
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        ITradingStorage.Trade memory _trade =  _generateTrade(
            traders[rand],
            btcPairIndex,
            true, 
            traderOrderIndex[traders[rand]], 
            amount, 
            withPricePrecision(50000)
        );
        IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MARKET;

        uint orderId = trading.openTrade{value: 0.5 ether}(
            _trade,
            _type,
            1e10,
            0);

        vm.stopPrank();

        vm.startPrank(operator);
        uint[] memory orderIds = new uint256[](1);
        orderIds[0] = orderId;

        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, btcPairIndex, 50000);
        _setChainlinkBTC(50000);
        trading.executeMarketOrders{value: mockPyth.getUpdateFee(priceUpdateData)}(btcPairIndex, orderIds, priceUpdateData);
        traderOrderIndex[traders[rand]]++;
        vm.stopPrank();

        uint balAfter = operator.balance;
        assert(balAfter > ethBal );
        console.logUint(balAfter);
        vm.startPrank(traders[rand]);
        _setChainlinkBTC(51000);

        uint closeOrderId = trading.closeTradeMarket{value : 0.1 ether}(
            btcPairIndex,
            0,
            amount/2,
            0);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, amount/2, 0,  51000, closeOrderId);
        console.logUint(operator.balance);
        assert(operator.balance > balAfter );
    }
/**------------------------------------------------------------- */
}