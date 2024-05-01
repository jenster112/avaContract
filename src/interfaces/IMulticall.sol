// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./ITradingStorage.sol";
import "./IPairStorage.sol";
import "./IPairInfos.sol";

interface IMulticall {
    struct AggregatedTrade {
        ITradingStorage.Trade trade;
        ITradingStorage.TradeInfo tradeInfo;
        uint rolloverFee;
        uint liquidationPrice;
    }

    struct AggregatedOrder {
        ITradingStorage.OpenLimitOrder order;
        uint liquidationPrice;
    }

    function getPositions(
        address userAddress
    ) external view returns (AggregatedTrade[] memory, AggregatedOrder[] memory);

    // function getPairs() external view returns (IPairStorage.Pair[] memory resultPairs);

    function getLongShortRatios()
        external
        view
        returns (uint[] memory longRatio, uint[] memory shortRatio);

    function getFirstEmptyTradeIndexes(
        address userAddress
    ) external view returns (uint[] memory firstEmptyTradeIndexes);

    function getOpenLimitOrdersCounts(address userAddress) external view returns (uint[] memory openLimitOrdersCounts);

    function getMargins()
        external
        view
        returns (
            uint[] memory rolloverFeePerBlockP,
            uint[] memory rolloverFeePerBlockLong,
            uint[] memory rolloverFeePerBlockShort
        );

    //     function updateSlTp(
    //         uint _pairIndex,
    //         uint _index,
    //         uint _newSl,
    //         uint _newTp,
    //         bytes[] calldata priceUpdateData
    //     ) external payable;
}

interface IExtendedPairStorage is IPairStorage {
    function pairs(uint) external view returns (Pair memory);
}

interface IExtendedPairInfos is IPairInfos {
    function getRolloverFeePerBlockP(uint pairIndex) external view returns (uint);

    function getUtilizationMultiplier(uint pairIndex) external view returns (uint);

    function getLongMultiplier(uint pairIndex) external view returns (uint);

    function getShortMultiplier(uint pairIndex) external view returns (uint);

    function getBlendedUtilizationRatio(uint _pairIndex, uint _longOI, uint _shortOI) external view returns(uint256);

    function getBlendedSkew(uint _pairIndex, bool _long,  uint _longOI, uint _shortOI) external view returns(uint256);
}

interface IExtendedTrading {
    function updateSl(uint _pairIndex, uint _index, uint _newSl, bytes[] calldata priceUpdateData) external payable;

    function updateTp(uint _pairIndex, uint _index, uint _newTp) external;
}
