pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {LiquidBase} from "./LiquidBase.t.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import "../../src/interfaces/IPairInfos.sol";
import "forge-std/console.sol";

contract TradeBase is LiquidBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function _placeMarketLong(address _trader, uint _amount, uint _pairIndex, uint _rawPrice) internal returns(uint orderId) {

            ITradingStorage.Trade memory _trade =  _generateTrade(
                _trader,
                _pairIndex,
                true, 
                traderOrderIndex[_trader], 
                _amount, 
                withPricePrecision(_rawPrice)
            );
            IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MARKET;

            orderId = trading.openTrade(
                _trade,
                _type,
                1e10,
                0);

    }

    function _executeMarketLong(address _trader, uint _amount, uint _pairIndex, uint _rawPrice, uint _id) internal {

        vm.startPrank(operator);
        uint[] memory orderId = new uint256[](1);
        orderId[0] = _id;

        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, _pairIndex, _rawPrice);
        _setChainlinkBTC(_rawPrice);
        trading.executeMarketOrders{value: mockPyth.getUpdateFee(priceUpdateData)}(_pairIndex, orderId, priceUpdateData);
        traderOrderIndex[_trader]++;
        vm.stopPrank();

    }

    function _placeMarketClose(uint pairIndex, uint amount, uint index, uint rawPrice) internal returns(uint orderId) {
        orderId = trading.closeTradeMarket(
            pairIndex,
            index,
            amount,
            0);
        
    }   

    function _executeMarketClose(uint _pairIndex, uint amount, uint index, uint _rawPrice, uint _id) internal {

        vm.startPrank(operator);
        uint[] memory orderId = new uint256[](1);
        orderId[0] = _id;

        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, _pairIndex, _rawPrice);
        _setChainlinkBTC(_rawPrice);
        trading.executeMarketOrders{value: mockPyth.getUpdateFee(_generateSampleUpdateDataCrypto(1, _pairIndex, _rawPrice))}(
            _pairIndex,
            orderId,
            priceUpdateData
        );
        vm.stopPrank();
    }   

    function _placeMarketShort(address _trader, uint _amount, uint _pairIndex, uint _rawPrice) internal returns(uint orderId) {

            //Short BTC
            ITradingStorage.Trade memory _trade =  _generateTrade(
                _trader,
                _pairIndex,
                false,
                traderOrderIndex[_trader], 
                _amount ,
                withPricePrecision(_rawPrice)
            );
            IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MARKET;
            orderId = trading.openTrade(
                _trade,
                _type,
                1e10, 
                0);

    }

    function _executeMarketShort(address _trader, uint _amount, uint _pairIndex, uint _rawPrice, uint _id) internal {

        vm.startPrank(operator);
        uint[] memory orderId = new uint256[](1);
        orderId[0] = _id;

        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, _pairIndex, _rawPrice);
        _setChainlinkBTC(_rawPrice);
        trading.executeMarketOrders{value: mockPyth.getUpdateFee(priceUpdateData)}(_pairIndex, orderId, priceUpdateData);

        traderOrderIndex[_trader]++;
        vm.stopPrank();
    }

/**------------------------------Limit Orders-------------------------------------------- */

    function _placeLimitLong(address _trader, uint _amount, uint _pairIndex, uint _rawPrice, uint _executionFee) internal {

            ITradingStorage.Trade memory _trade =  _generateTrade(
                _trader,
                _pairIndex,
                true, 
                traderOrderIndex[_trader], 
                _amount, 
                withPricePrecision(_rawPrice)
            );
            // Reversal or momentum does not matter. Both are treated same in code
            IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MOMENTUM;

            trading.openTrade(
                _trade,
                _type,
                1e10,
                _executionFee);
            traderOrderIndex[_trader]++;
    }

    function _placeLimitShort(address _trader, uint _amount, uint _pairIndex, uint _rawPrice, uint _executionFee) internal {

            ITradingStorage.Trade memory _trade =  _generateTrade(
                _trader,
                _pairIndex,
                false, 
                traderOrderIndex[_trader], 
                _amount, 
                withPricePrecision(_rawPrice)
            );
            // Reversal or momentum does not matter. Both are treated same in code
            IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.MOMENTUM;

            trading.openTrade(
                _trade,
                _type,
                1e10,
                _executionFee);
            traderOrderIndex[_trader]++;
    }

/**------------------------------Limit Orders-------------------------------------------- */

    function _placeStopLimitLong(address _trader, uint _amount, uint _pairIndex, uint _rawPrice, uint _executionFee) internal {

            ITradingStorage.Trade memory _trade =  _generateTrade(
                _trader,
                _pairIndex,
                true, 
                traderOrderIndex[_trader], 
                _amount, 
                withPricePrecision(_rawPrice)
            );
            // Reversal or momentum does not matter. Both are treated same in code
            IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.REVERSAL;
            trading.openTrade(
                _trade,
                _type,
                1e10,
                _executionFee);
            traderOrderIndex[_trader]++;
    }

    function _placeStopLimitShort(address _trader, uint _amount, uint _pairIndex, uint _rawPrice, uint _executionFee) internal {

            ITradingStorage.Trade memory _trade =  _generateTrade(
                _trader,
                _pairIndex,
                false, 
                traderOrderIndex[_trader], 
                _amount, 
                withPricePrecision(_rawPrice)
            );
            // Reversal or momentum does not matter. Both are treated same in code
            IExecute.OpenLimitOrderType _type = IExecute.OpenLimitOrderType.REVERSAL;
            trading.openTrade(
                _trade,
                _type,
                1e10,
                _executionFee);
            traderOrderIndex[_trader]++;
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

    function _setChainlinkBTC(uint256 _price) internal {
        // setup default cl to return the same price
        MockV3Aggregator currentMockChainlink = MockV3Aggregator(mockChainlink["BTC_USD_CHAINLINK"]);
        currentMockChainlink.updateAnswer(int256(int(_price * (10 ** currentMockChainlink.decimals()))));
    }

    function _generateSampleUpdateDataCrypto(uint numberOfFeeds, uint _pairIndex, uint256 _price) internal view returns (bytes[] memory) {
        bytes[] memory updateDataArray = new bytes[](numberOfFeeds);

        for (uint i = 0; i < numberOfFeeds; i++) {
            bytes32 sampleId = _pairIndex == btcPairIndex ? keccak256("BTC_USD_PYTH") : keccak256("ETH_USD_PYTH")  ; // Adding i to make each ID unique
            int64 samplePrice =  int64(int((_price)*1e8)); // Example: $50,000 for BTC/USD, incrementing for variety
            uint64 sampleConf = 100; // Example confidence interval
            int32 sampleExpo = -8; // Example exponent, meaning the price is $500.00
            int64 sampleEmaPrice = int64(int(_price*1e8)); // Example EMA price, incrementing for variety
            uint64 sampleEmaConf = 90; // Example EMA confidence interval
            uint64 samplePublishTime = uint64(block.timestamp + i); // Current block timestamp, incrementing for variety

            PythStructs.PriceFeed memory priceFeed;
            priceFeed.id = sampleId;
            priceFeed.price.price = samplePrice;
            priceFeed.price.conf = sampleConf;
            priceFeed.price.expo = sampleExpo;
            priceFeed.price.publishTime = samplePublishTime;
            priceFeed.emaPrice.price = sampleEmaPrice;
            priceFeed.emaPrice.conf = sampleEmaConf;
            priceFeed.emaPrice.expo = sampleExpo;
            priceFeed.emaPrice.publishTime = samplePublishTime;

            updateDataArray[i] = abi.encode(priceFeed);
        }

        return updateDataArray;
    }

    function consoleTrade(ITradingStorage.Trade memory _trade) internal view {
        console.logString("Trader address: ");
        console.logAddress(_trade.trader);
        
        console.logString("Pair Index: ");
        console.logUint(_trade.pairIndex);
        
        console.logString("Index: ");
        console.logUint(_trade.index);
        
        console.logString("Initial Position Token: ");
        console.logUint(_trade.initialPosToken);
        
        console.logString("Position Size USDC: ");
        console.logUint(_trade.positionSizeUSDC);
        
        console.logString("Open Price: ");
        console.logUint(_trade.openPrice);
        
        console.logString("Buy: ");
        console.logBool(_trade.buy);
        
        console.logString("Leverage: ");
        console.logUint(_trade.leverage);
        
        console.logString("Take Profit (tp): ");
        console.logUint(_trade.tp);
        
        console.logString("Stop Loss (sl): ");
        console.logUint(_trade.sl);
        
        console.logString("Timestamp: ");
        console.logUint(_trade.timestamp);
    }

    function withPricePrecision(uint amount) internal pure returns(uint){

        return amount*1e10;
    } 

}