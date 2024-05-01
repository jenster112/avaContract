pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import {Multicall} from "../../src/Multicall.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import "../../src/interfaces/IMulticall.sol";
import "forge-std/console.sol";

contract MulticallGroup is TradeBase {
    Multicall public multicall;

    /**
     * @dev Set up the test.
     */
    function setUp() public virtual override {
        super.setUp();

        // Doing it here cause don't want to disturb exising test setups
        // Can be moved to base
        // --------------------------------------
        __deployMulticallContracts();
    }

    /**
     * @dev Deploy the contracts.
     */
    function __deployMulticallContracts() internal {
        vm.startPrank(deployer);
        __deployMulticall();
        vm.stopPrank();
    }

    /**
     * @dev Deploy the Multicall contract.
     */
    function __deployMulticall() internal {
        multicall = new Multicall(
            address(tradingStorage),
            address(pairInfos),
            address(pairStorage),
            address(trading)
        );
    }

    /**
     * @dev Test that the positions length is correct.
     * The length should be equal to the number of pairs * maxTradesPerPair.
     */
    function testPositionsLength() public view {
        uint256 pairCount = pairStorage.pairsCount();
        uint256 maxTradesPerPair = tradingStorage.maxTradesPerPair();
        uint256 totalPositions = maxTradesPerPair * pairCount;

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) %
            numTraders;

        (
            IMulticall.AggregatedTrade[] memory _aggregatedTrades,
            IMulticall.AggregatedOrder[] memory _aggregatedOrders
        ) = multicall.getPositions(traders[rand]);

        assert(_aggregatedTrades.length == totalPositions);
        assert(_aggregatedOrders.length == totalPositions);
    }

    /**
     * @dev Test that the market open works.
     * Opens a long and short position.
     * Leverage of both should be greater than 0.
     */
    function testMarketOpen() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) %
            numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        uint amountToOpen = amount / 2;

        usdc.approve(address(tradingStorage), amount);

        uint id = _placeMarketLong(traders[rand], amountToOpen, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amountToOpen, btcPairIndex,  50000, id);

        vm.startPrank(traders[rand]);
        uint newId = _placeMarketShort(traders[rand], amountToOpen, btcPairIndex,  50000);
        vm.stopPrank();

        _executeMarketShort(traders[rand], amountToOpen, btcPairIndex,  50000, newId);

        (IMulticall.AggregatedTrade[] memory _aggregatedTrades, ) = multicall
            .getPositions(traders[rand]);

        uint256 maxTradesPerPair = tradingStorage.maxTradesPerPair();
        uint256 startPositionIndex = (maxTradesPerPair * (btcPairIndex));

        assert(_aggregatedTrades[startPositionIndex].trade.leverage > 0);
        assert(_aggregatedTrades[startPositionIndex + 1].trade.leverage > 0);
    }

    /**
     * @dev Test that the limit open works.
     * Opens a long and short position.
     * Leverage of both should be greater than 0.
     */
    function testLimitOpen() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) %
            numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        uint amountToOpen = amount / 2;

        usdc.approve(address(tradingStorage), amount);

        _placeLimitLong(traders[rand], amountToOpen, btcPairIndex, 51000, 0);
        _placeLimitShort(traders[rand], amountToOpen, btcPairIndex, 51000, 0);

        vm.stopPrank();

        (, IMulticall.AggregatedOrder[] memory _aggregatedOrders) = multicall
            .getPositions(traders[rand]);

        uint256 maxTradesPerPair = tradingStorage.maxTradesPerPair();
        uint256 startPositionIndex = (maxTradesPerPair * (btcPairIndex));

        assert(_aggregatedOrders[startPositionIndex].order.leverage > 0);
        assert(_aggregatedOrders[startPositionIndex + 1].order.leverage > 0);
    }

    /**
     * @dev Test that the market close works.
     * Opens a long and short position.
     * Closes both.
     * Leverage of both should be 0.
     */
    function testMarketClose() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) %
            numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        uint amountToOpen = amount / 2;

        usdc.approve(address(tradingStorage), amount);

        uint id = _placeMarketLong(traders[rand], amountToOpen, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amountToOpen, btcPairIndex,  50000, id);

        vm.startPrank(traders[rand]);
        uint newId = _placeMarketShort(traders[rand], amountToOpen, btcPairIndex,  50000);
        vm.stopPrank();
        
        _executeMarketShort(traders[rand], amountToOpen, btcPairIndex,  50000, newId);
        vm.startPrank(traders[rand]);
        vm.warp(10000);

        uint256 maxTradesPerPair = tradingStorage.maxTradesPerPair();
        uint256 startPositionIndex = (maxTradesPerPair * (btcPairIndex));

        (IMulticall.AggregatedTrade[] memory _aggregatedTrades, ) = multicall
            .getPositions(traders[rand]);

        uint closeId = _placeMarketClose(btcPairIndex, _aggregatedTrades[startPositionIndex + 1].trade.initialPosToken, _aggregatedTrades[startPositionIndex + 1].trade.index,  51000);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _aggregatedTrades[startPositionIndex + 1].trade.initialPosToken, _aggregatedTrades[startPositionIndex + 1].trade.index,  51000, closeId);
        vm.startPrank(traders[rand]);

        closeId = _placeMarketClose(btcPairIndex, _aggregatedTrades[startPositionIndex ].trade.initialPosToken, _aggregatedTrades[startPositionIndex ].trade.index,  51000);
        vm.stopPrank();
        _executeMarketClose(btcPairIndex, _aggregatedTrades[startPositionIndex ].trade.initialPosToken, _aggregatedTrades[startPositionIndex ].trade.index,  51000, closeId);
        vm.startPrank(traders[rand]);

        vm.stopPrank();

        (_aggregatedTrades, ) = multicall.getPositions(traders[rand]);

        assert(_aggregatedTrades[startPositionIndex].trade.leverage == 0);
        assert(_aggregatedTrades[startPositionIndex + 1].trade.leverage == 0);
    }

    /**
     * @dev Test that the limit close works.
     * Opens a long and short position.
     * Closes both.
     * Leverage of both should be 0.
     */
    function testLimitCancel() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) %
            numTraders;

        vm.startPrank(traders[rand]);

        uint amount = usdc.balanceOf(traders[rand]);
        uint amountToOpen = amount / 2;

        usdc.approve(address(tradingStorage), amount);

        _placeLimitLong(traders[rand], amountToOpen, btcPairIndex, 51000, 0);
        _placeLimitShort(traders[rand], amountToOpen, btcPairIndex, 51000, 0);

        vm.roll(1000);

        (, IMulticall.AggregatedOrder[] memory _aggregatedOrders) = multicall
            .getPositions(traders[rand]);

        uint256 maxTradesPerPair = tradingStorage.maxTradesPerPair();
        uint256 startPositionIndex = (maxTradesPerPair * (btcPairIndex));

        trading.cancelOpenLimitOrder(
            btcPairIndex,
            _aggregatedOrders[startPositionIndex + 1].order.index
        );
        trading.cancelOpenLimitOrder(
            btcPairIndex,
            _aggregatedOrders[startPositionIndex].order.index
        );

        vm.stopPrank();

        (, _aggregatedOrders) = multicall.getPositions(traders[rand]);

        assert(_aggregatedOrders[startPositionIndex].order.leverage == 0);
        assert(_aggregatedOrders[startPositionIndex + 1].order.leverage == 0);
    }

    /**
     * @dev Test that the getMargins works.
     */
    function testGetMargins() public view {
        multicall.getMargins();
    }

    /**
     * @dev Test that the getLongShortRatios works.
     */
    function testGetLongShortRatios() public view {
        multicall.getLongShortRatios();
    }
}