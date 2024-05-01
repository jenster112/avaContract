pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";

contract IsolatedMargin is TradeBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testDeposit() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        usdc.mint(traders[rand], amount);
        usdc.approve(address(tradingStorage), amount );

        vm.roll(1641070800);
        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, btcPairIndex, 50000);
        _setChainlinkBTC(50000);
        trading.updateMargin{value: mockPyth.getUpdateFee(priceUpdateData)}(
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1, 
            ITradingStorage.updateType.DEPOSIT,
            amount,
            priceUpdateData);

        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        assert(_updatedTrade.leverage < _trade.leverage);
        assert(_updatedTrade.initialPosToken > _trade.initialPosToken);
        //owing to Margin Fees
        assert(_updatedTrade.leverage*_updatedTrade.initialPosToken < _trade.leverage*_trade.initialPosToken );
        vm.stopPrank();
    }

    function testWithdraw() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
            
        vm.roll(1641070800);
        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, btcPairIndex, 50000);
        _setChainlinkBTC(50000);
        trading.updateMargin{value: mockPyth.getUpdateFee(priceUpdateData)}(
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1, 
            ITradingStorage.updateType.WITHDRAW,
            amount/2,
            priceUpdateData);

        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        
        assert(_updatedTrade.leverage > _trade.leverage);
        assert(_updatedTrade.initialPosToken < _trade.initialPosToken);
        //owing to Margin Fees
        assert(_updatedTrade.leverage*_updatedTrade.initialPosToken < _trade.leverage*_trade.initialPosToken );

        vm.stopPrank();
    }

    function testCannotWithdraw() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);
        vm.startPrank(traders[rand]);

        vm.roll(1641070800);
        vm.warp(10000);
        bytes[] memory priceUpdateData = _generateSampleUpdateDataCrypto(1, btcPairIndex, 30000);
        _setChainlinkBTC(30000);
        uint val = mockPyth.getUpdateFee(priceUpdateData);
        vm.expectRevert("W_T_B");
        trading.updateMargin{value: val}(
            btcPairIndex, 
            traderOrderIndex[traders[rand]] -1, 
            ITradingStorage.updateType.WITHDRAW,
            amount/2,
            priceUpdateData);

        vm.stopPrank();
    }
}