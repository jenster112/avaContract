pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";

contract Referral is TradeBase{

    address public averageJoe;
    address public coinFlipCanada;

    mapping (address => bytes32) public codes;

    function setUp() public virtual override{
        super.setUp();
        _labelReferrers();
        _registerCodes();
    }

    function testReferralCodeInMarketOpen() public {

        assert(tradingStorage.rebates(averageJoe) == 0);
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        // Trade Without Referral Code
        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);

        vm.startPrank(traders[rand]);
        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        uint fees = amount - _trade.initialPosToken;

        referral.setTraderReferralCodeByUser(codes[averageJoe]);

        // Trade with referral Code
        usdc.mint(traders[rand], amount);
        usdc.approve(address(tradingStorage), amount );
        usdc.approve(address(tradingStorage), amount );
        id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);

        vm.startPrank(traders[rand]);
        ITradingStorage.Trade memory  _updatedTrade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);
        uint feesWithReferral = amount - _updatedTrade.initialPosToken;
        vm.stopPrank();

        assert(feesWithReferral < fees );
        assert(feesWithReferral < fees*9500/10000 );
        assert(tradingStorage.rebates(averageJoe) != 0);

        uint rebate = tradingStorage.rebates(averageJoe);
        uint balanceBefore = usdc.balanceOf(averageJoe);
        vm.startPrank(averageJoe);
        tradingStorage.claimRebate();
        vm.stopPrank();
        uint balanceAfter = usdc.balanceOf(averageJoe);

        assert((balanceAfter - balanceBefore) == rebate);
        assert(tradingStorage.rebates(averageJoe) == 0);
    }

    function testReferralCodeInMarketClose() public {

        assert(tradingStorage.rebates(averageJoe) == 0);
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;

        vm.startPrank(traders[rand]);

        // Trade Open And close Without Referral Code
        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);

        vm.startPrank(traders[rand]);
        ITradingStorage.Trade memory  _trade = 
            tradingStorage.openTrades(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        vm.warp(10000);
        uint closeId = _placeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  50000);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  50000, closeId);
        vm.startPrank(traders[rand]);
        
        traderOrderIndex[traders[rand]] -= 1;

        uint balanceAfter = usdc.balanceOf(traders[rand]);
        uint fees = amount - balanceAfter;

        // Trade with referral Code
        usdc.mint(traders[rand], amount);

        uint balance = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );

        vm.warp(10000);

        id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);

        vm.startPrank(traders[rand]);
        referral.setTraderReferralCodeByUser(codes[averageJoe]);

        vm.warp(10000);

        closeId = _placeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  50000);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _trade.initialPosToken, traderOrderIndex[traders[rand]] - 1,  50000, closeId);

        balanceAfter = usdc.balanceOf(traders[rand]);
        uint referralFees = balance - balanceAfter;
        assert(referralFees < fees);
        assert(tradingStorage.rebates(averageJoe)!= 0);
    }

    function testSwapCodeOwner() public {
        vm.startPrank(coinFlipCanada);
        referral.setPendingCodeOwnershipTransfer(codes[coinFlipCanada], averageJoe );
        vm.stopPrank();

        vm.startPrank(averageJoe);
        referral.acceptCodeOwnership(codes[coinFlipCanada]);
        vm.stopPrank();
        assert(referral.codeOwners(codes[coinFlipCanada]) == averageJoe);
    }
    
    function _labelReferrers() internal {
        
        uint256 privateKey;
        (averageJoe, privateKey) = makeAddrAndKey("averageJoe");
        pKey[averageJoe] = privateKey;
        vm.deal(averageJoe, 1 ether);

        (avntMinter, privateKey) = makeAddrAndKey("coinFlipCanada");
        pKey[coinFlipCanada] = privateKey;
        vm.deal(coinFlipCanada, 1 ether);

    }

    function _registerCodes() internal {

        vm.prank(averageJoe);
        referral.registerCode(bytes32("averageJoe"));

        vm.prank(coinFlipCanada);
        referral.registerCode(bytes32("coinFlipCanada"));

        codes[averageJoe] = bytes32("averageJoe");
        codes[coinFlipCanada] = bytes32("coinFlipCanada");

        vm.prank(deployer);
        referral.setReferrerTier(coinFlipCanada, 2);
    }
}