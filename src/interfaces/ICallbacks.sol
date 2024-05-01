// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "./ITradingStorage.sol";
import "./IExecute.sol";

interface ICallbacks {
    
    struct AggregatorAnswer {
        uint orderId;
        uint price;
        uint spreadP;
    }
    struct Values {
        uint price;
        int profitP;
        uint posToken;
        uint posUSDC;
        uint reward;
    }

    // Events
    event MarketExecuted(
        uint orderId,
        ITradingStorage.Trade t,
        bool open,
        uint price,
        uint positionSizeUSDC,
        int percentProfit,
        uint usdcSentToTrader
    );

    event LimitExecuted(
        uint orderId,
        uint limitIndex,
        ITradingStorage.Trade t,
        ITradingStorage.LimitOrder orderType,
        uint price,
        uint positionSizeUSDC,
        int percentProfit,
        uint usdcSentToTrader
    );

    event MarketOpenCanceled(
        uint orderId, 
        address indexed trader, 
        uint pairIndex
    );

    event SlUpdated(
        uint orderId, 
        address indexed trader, 
        uint pairIndex, 
        uint index, 
        uint newSl
    );

    event MarginUpdated(
        address indexed trader, 
        uint pairIndex, 
        uint index, 
        uint newSl, 
        uint timestamp
    );
    
    event AddressUpdated(string name, address a);
    event FeeUpdated(uint _vaultFeeP, uint _liqFeeP, uint _liqTotalFeeP);
    event Pause(bool paused);
    event Done(bool done);

    function vaultFeeP() external returns (uint);

    function openTradeMarketCallback(uint, uint, uint) external;

    function closeTradeMarketCallback(uint, uint, uint) external;

    function executeLimitOpenOrderCallback(uint, uint, uint) external;

    function executeLimitCloseOrderCallback(uint, uint, uint) external;

    function updateSlCallback(uint, uint, uint) external;

    function updateMarginCallback(uint, uint, uint) external;

    function transferFromVault(address, uint) external;

    function correctSl(uint openPrice, uint leverage, uint sl, bool buy) external returns (uint);

    function correctTp(uint openPrice, uint leverage, uint tp, bool buy) external returns (uint); 
}
