pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";

contract BackupOracle is TradeBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testBackupOracleTrigger() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

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
        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, btcPairIndex,  50000);
        _setChainlinkBTC(55001); // default is 2%, setting 3% dev

        uint val = mockPyth.getUpdateFee(priceUpdateData); 

        uint orderIDS = trading.openTrade(
            _trade,
            _type,
            26e8,
            0);
        traderOrderIndex[traders[rand]]++;

        console.logString('Printing Order Id');
        console.logUint(orderIDS);
        vm.stopPrank();

        uint[] memory orderId = new uint256[](1);
        orderId[0] = 1;
        vm.startPrank(operator);
        vm.expectRevert("BACKUP_DEVIATION_TOO_HIGH");
        trading.executeMarketOrders{value: val}(btcPairIndex, orderId, priceUpdateData);
        vm.stopPrank();
    }

    function testnoTradeWithCLOnly() public {

        vm.startPrank(deployer);
        priceAggregator.useBackUpOracleOnly(true);
        vm.stopPrank();

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint _amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), _amount );

        _openMarketLongExpectRevert(traders[rand], _amount, btcPairIndex, 50000);
        
        assertEq(_amount, usdc.balanceOf(traders[rand]));
        vm.stopPrank();
    }

    function testLiquidationWithCLOnly() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        uint _amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), _amount );

        uint id = _placeMarketLong(traders[rand],  _amount/3, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand],  _amount/3, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);

        ITradingStorage.Trade memory  trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        assert(trade.leverage > 0);
        uint liquidationPrice = pairInfos.getTradeLiquidationPrice(
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -1,
            trade.openPrice,
            trade.buy,
            trade.initialPosToken,
            trade.leverage
        );
        vm.stopPrank();

        vm.startPrank(deployer);
        priceAggregator.useBackUpOracleOnly(true);
        vm.stopPrank();

        vm.startPrank(traders[rand]);
        vm.warp(100000);
        uint balBefore = usdc.balanceOf(traders[rand]);
        _openMarketLongExpectRevert(traders[rand], _amount/3, btcPairIndex, 5000);
        assertEq(balBefore, usdc.balanceOf(traders[rand]));
        vm.stopPrank();

        uint rando = uint(keccak256(abi.encodePacked(block.timestamp))) % numLPs;
        vm.startPrank(liquidityProviders[rando]);
        vm.warp(100000);
        _executeLimitOrder(
            ITradingStorage.LimitOrder.LIQ,
            traders[rand],
            btcPairIndex,
            traderOrderIndex[traders[rand]] -2,
            (liquidationPrice/1e10) -2);
        vm.stopPrank();

        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -2);

        assertEq(_updatedTrade.leverage, 0);
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

    function _openMarketLongExpectRevert(address _trader, uint _amount, uint _pairIndex, uint _rawPrice) internal {

            ITradingStorage.Trade memory _trade =  _generateTrade(
                _trader,
                _pairIndex,
                true, 
                traderOrderIndex[_trader], 
                _amount, 
                withPricePrecision(_rawPrice)
            );
            IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MARKET;

            bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, _pairIndex, _rawPrice);
            _setChainlinkBTC(_rawPrice);

            uint val =  mockPyth.getUpdateFee(priceUpdateData);

            uint newId = trading.openTrade(
                _trade,
                _type,
                1e10,
                0);
            traderOrderIndex[_trader]++;
            vm.stopPrank();
            uint[] memory orderId = new uint256[](1);
            orderId[0] = newId;
            vm.startPrank(operator);
            trading.executeMarketOrders{value: val}(btcPairIndex, orderId, priceUpdateData);
            vm.stopPrank();
    }
}