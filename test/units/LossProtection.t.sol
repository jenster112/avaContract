pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {SkewedBase} from "../fixtures/SkewedBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import {TradingStorage} from "../../src/TradingStorage.sol";
import "../../src/interfaces/ITradingStorage.sol";
import {PositionMath} from "../../src/library/PositionMath.sol";

contract LossProtection is SkewedBase{

    using PositionMath for uint;
    address public newTrader;
    function setUp() public virtual override{
        super.setUp();
        _setupNewTrader();
    }

    function _setupNewTrader() internal {
        (newTrader, ) = makeAddrAndKey("newTrader");
        vm.deal(newTrader, 1 ether);
        vm.prank(deployer);
        trading.addWhitelist(newTrader);
    }

    function testLossProtectionTier() public {

        uint collateralAmount = 100e6;

        vm.startPrank(newTrader);

        usdc.mint(newTrader,collateralAmount );
        usdc.approve(address(tradingStorage), collateralAmount );

        uint id = _placeMarketShort(newTrader, collateralAmount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketShort(newTrader, collateralAmount, btcPairIndex,  50000, id);

        ITradingStorage.TradeInfo memory  _tradeInfo = tradingStorage.openTradesInfo(newTrader, btcPairIndex, 0);

        assertEq(_tradeInfo.lossProtection, 1);
        assertEq(pairStorage.lossProtectionMultiplier(btcPairIndex, _tradeInfo.lossProtection) , 80);
    }

    function testLossProtectionDiscount() public {

        uint collateralAmount = 500e6;

        vm.startPrank(newTrader);
        // Burn initial Balance
        usdc.transfer(address(vaultManager), usdc.balanceOf(newTrader));

        //Mint 5000USDC
        usdc.mint(newTrader,collateralAmount);
        usdc.approve(address(tradingStorage), collateralAmount );

        uint balanceBefore = usdc.balanceOf(newTrader);
        uint id = _placeMarketShort(newTrader, collateralAmount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketShort(newTrader, collateralAmount, btcPairIndex,  50000, id);
        vm.startPrank(newTrader);

        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(newTrader, btcPairIndex, 0);
     
        vm.warp(1000);

        uint closeId = _placeMarketClose(btcPairIndex, _trade.initialPosToken, 0, 50600);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _trade.initialPosToken, 0, 50600, closeId);

        // Trader opened position worth 1 BTC. Now he is at loss 0f 600USDC but since he is loss protected
        // His loss would be 480(0.8*600)

        uint balanceAfter = usdc.balanceOf(newTrader);
        uint expectedFees =  7e6 ; // 70USD
        uint loss = balanceBefore - balanceAfter;
        //console.logUint(balanceBefore - balanceAfter);
        assertLt(loss, 60e6 + expectedFees );
        //assertGt(loss, 48e6 + expectedFees );
    }

    function testExtremeSkewedOpenFees() public {

        uint collateralAmount = 100e6;

        vm.startPrank(newTrader);

        usdc.mint(newTrader,collateralAmount );
        usdc.approve(address(tradingStorage), collateralAmount );

        uint id = _placeMarketShort(newTrader, collateralAmount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketShort(newTrader, collateralAmount, btcPairIndex,  50000, id);
        vm.stopPrank();
        ITradingStorage.Trade memory  _trade = tradingStorage.openTrades(newTrader, btcPairIndex, 0);
        assert(_trade.initialPosToken < collateralAmount );
        assert((collateralAmount - _trade.initialPosToken) > (collateralAmount.mul(_trade.leverage)*55)/1e5);
    }

    function testClaimFees() public{
        uint govFees = tradingStorage.govFeesUSDC();
        uint devFees = tradingStorage.devFeesUSDC();
        
        vm.startPrank(deployer);
        tradingStorage.claimFees();
        vm.stopPrank();

        assert(usdc.balanceOf(devTreasury) == devFees);
        assert(usdc.balanceOf(govTreasury) == govFees);
        assert(tradingStorage.govFeesUSDC() == 0);
        assert(tradingStorage.devFeesUSDC() == 0);

    }
}