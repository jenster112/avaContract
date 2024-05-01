// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./interfaces/ITradingStorage.sol";
import "./interfaces/IPairInfos.sol";
import "./interfaces/ICallbacks.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PositionMath} from "./library/PositionMath.sol";

contract TradingCallbacks is Initializable, ICallbacks {
    using PositionMath for uint;

    uint private constant _PRECISION = 1e10;
    uint private constant _MAX_SL_P = 80;
    uint private constant _MAX_GAIN_P = 500;
    uint private constant _WITHDRAW_THRESHOLD_P = 80;
    uint private constant _MAX_EXEC_REWARD = 10e6;

    ITradingStorage public storageT;
    IPairInfos public pairInfos;

    uint public liqFeeP;
    uint public liqTotalFeeP;
    uint public override vaultFeeP;

    modifier onlyPriceAggregator() {
        require(msg.sender == address(storageT.priceAggregator()), "A_O");
        _;
    }

    constructor() {
        _disableInitializers();
    }

   /**
     * @dev Initializes proxy
     * @param _storageT Address of the Trading Storage contract.
     * @param _pairInfos Address of the PairInfos contract.
     */
    function initialize(address _storageT, address _pairInfos) external initializer {
        storageT = ITradingStorage(_storageT);
        pairInfos = IPairInfos(_pairInfos);
        vaultFeeP = 20;
        liqFeeP = 5;
        liqTotalFeeP = 10;
    }

    /**
     * @dev Updates the fees for liquidation, total liquidation, and the vault.
     * Can only be called by the governance address.
     * @param _liqFeeP Executor Reward for Liquidation
     * @param _liqTotalFeeP Total liquidation fee percentage inlcuding LP percentage
     * @param _vaultFeeP New vault fee percentage of Total Fees
     */
    function setFeeP(uint _liqFeeP, uint _liqTotalFeeP, uint _vaultFeeP) external{
        require(msg.sender == storageT.gov(), "G_O");
        liqFeeP = _liqFeeP;
        liqTotalFeeP = _liqTotalFeeP;
        vaultFeeP = _vaultFeeP;
    }

    /**
     * @dev Callback function for updating a trader's margin.(Deposit/Withdraw)
     * @param orderId orderId.
     * @param price price.
     * @param spreadP spreadP.
     */
    function updateMarginCallback(
        uint orderId, uint price, uint spreadP
    ) external override onlyPriceAggregator {
        IPriceAggregator aggregator = storageT.priceAggregator();
        IPriceAggregator.PendingMarginUpdate memory o = aggregator.pendingMarginUpdateOrders(orderId);
        ITradingStorage.Trade memory _trade = storageT.openTrades(o.trader, o.pairIndex, o.index);
        
        if(price != 0){
            if (o._type == ITradingStorage.updateType.DEPOSIT) {
                //Route USDC to Vault Mananger
                storageT.transferUSDC(_trade.trader, address(storageT), o.amount);
                storageT.vaultManager().receiveUSDCFromTrader(_trade.trader, o.amount);
            } else {
                {
                    int profitP = _currentPercentProfit(_trade.openPrice, price, _trade.buy, _trade.leverage);
                    int pnl = (int(_trade.initialPosToken) * profitP) / int(_PRECISION) / 100;
                    if (pnl < 0) {
                        pnl = (pnl * int(aggregator.pairsStorage().lossProtectionMultiplier(_trade.pairIndex, o.tier))) / 100;
                    }
                    require((int(_trade.initialPosToken) + pnl) > (int(_trade.initialPosToken) * int(100 - _WITHDRAW_THRESHOLD_P)) / 100, 
                                "W_T_B");
                }
                storageT.vaultManager().sendUSDCToTrader(_trade.trader, o.amount);
            }
        }

        // Margin Fees can be zero in case of very low utilization/Last update time being close
        if (o.marginFees != 0){
            storageT.vaultManager().allocateRewards(o.marginFees, false);
            storageT.priceAggregator().pairsStorage().updateGroupOI(
                _trade.pairIndex,
                o.marginFees.mul(o.oldLeverage),
                _trade.buy,
                false
            );
        }
        pairInfos.storeTradeInitialAccFees(_trade.trader, _trade.pairIndex, _trade.index, _trade.buy);

        aggregator.unregisterPendingMarginUpdateOrder(orderId);
    }

    /**
     * @dev Callback function for opening a trade on the market.
     * @param orderId orderId.
     * @param price price.
     * @param spreadP spreadP.
     */
    function openTradeMarketCallback(uint orderId, uint price, uint spreadP) external override onlyPriceAggregator {
        ITradingStorage.PendingMarketOrder memory o = storageT.reqIDpendingMarketOrder(orderId);
        if (o.block == 0) {
            return;
        }
        // Check to avoid spamming
        if(o.trade.trader == address(0)) revert('INV_PENDING_ORDER');
        ITradingStorage.Trade memory t = o.trade;
        IPriceAggregator aggregator = storageT.priceAggregator();
        IPairStorage pairsStored = aggregator.pairsStorage();

        // crypto only
        if (pairsStored.pairGroupIndex(t.pairIndex) < 2)
        {
            (uint priceAfterImpact) = pairInfos.getTradePriceImpact(
                price,
                t.pairIndex,
                t.buy,
                t.positionSizeUSDC.mul(t.leverage)
            );

            t.openPrice = priceAfterImpact;
        } else {
            t.openPrice = _marketExecutionPrice(price, spreadP, t.buy);
        }

        uint maxSlippage = (o.wantedPrice * o.slippageP) / 100 / _PRECISION;

        if (
            price == 0 ||
            (t.buy ? t.openPrice > o.wantedPrice + maxSlippage : t.openPrice < o.wantedPrice - maxSlippage) ||
            (t.tp > 0 && (t.buy ? t.openPrice >= t.tp : t.openPrice <= t.tp)) ||
            (t.sl > 0 && (t.buy ? t.openPrice <= t.sl : t.openPrice >= t.sl)) ||
            !withinExposureLimits(t.trader, t.pairIndex, t.positionSizeUSDC.mul(t.leverage))
        ) {
            // Send back collateral but not execution Fee as execution was tried
            storageT.transferUSDC(address(storageT), t.trader, t.positionSizeUSDC);
            emit MarketOpenCanceled(orderId, t.trader, t.pairIndex);

        } else {
            ITradingStorage.Trade memory finalTrade = _registerTrade(t);

            emit MarketExecuted(
                orderId,
                finalTrade,
                true,
                finalTrade.openPrice,
                finalTrade.initialPosToken,
                0,
                0
            );
        }

        storageT.unregisterPendingMarketOrder(orderId, true);
    }

    /**
     * @dev Callback function for closing a trade on the market.
     * @param orderId orderId.
     * @param price price.
     * @param spreadP spreadP.
     */
    function closeTradeMarketCallback(uint orderId, uint price, uint spreadP) external override onlyPriceAggregator {
        ITradingStorage.PendingMarketOrder memory o = storageT.reqIDpendingMarketOrder(orderId);
        ITradingStorage.Trade memory t = storageT.openTrades(o.trade.trader, o.trade.pairIndex, o.trade.index);
        // Check to avoid spamming
        if(o.trade.trader == address(0)) revert('INV_PENDING_ORDER');
        if (price != 0 && t.leverage > 0) {
            ITradingStorage.TradeInfo memory i = storageT.openTradesInfo(t.trader, t.pairIndex, t.index);
            IPriceAggregator aggregator = storageT.priceAggregator();

            int profitP = _currentPercentProfit(t.openPrice, price, t.buy, t.leverage);
            
            int pnl = (int(o.trade.initialPosToken) * profitP) / int(_PRECISION) / 100;
            uint levPosToken = ((pnl < 0) && (pnl * -1) > int(o.trade.initialPosToken)) ? 0 : uint(int(o.trade.initialPosToken) + pnl).mul(t.leverage);

            uint usdcSentToTrader = _unregisterTrade(
                t,
                profitP,
                o.trade.initialPosToken,
                0,
                (levPosToken * aggregator.pairsStorage().pairCloseFeeP(t.pairIndex)) / 100 / _PRECISION,
                i.lossProtection
            );

            emit MarketExecuted(
                orderId,
                t,
                false,
                price,
                o.trade.initialPosToken,
                profitP,
                usdcSentToTrader
            );
        }
        else {
            emit MarketOpenCanceled(orderId, t.trader, t.pairIndex);
        }
        storageT.unregisterPendingMarketOrder(orderId, false);
    }

    /**
     * @dev Callback function for executing limit open orders.
     * @param orderId orderId.
     * @param price price.
     * @param spreadP spreadP.
     */
    function executeLimitOpenOrderCallback(uint orderId, uint price, uint spreadP) external override onlyPriceAggregator {
        ITradingStorage.PendingLimitOrder memory n = storageT.reqIDpendingLimitOrder(orderId);
        IExecute executor = storageT.priceAggregator().executions();

        if (price != 0 && storageT.hasOpenLimitOrder(n.trader, n.pairIndex, n.index)) {
            ITradingStorage.OpenLimitOrder memory o = storageT.getOpenLimitOrder(n.trader, n.pairIndex, n.index);
            IExecute.OpenLimitOrderType t = executor.openLimitOrderTypes(n.trader, n.pairIndex, n.index);

            IPriceAggregator aggregator = storageT.priceAggregator();
            //IPairStorage pairsStored = aggregator.pairsStorage();

            if ((t == IExecute.OpenLimitOrderType.REVERSAL
                    ? (o.buy ? price >= o.price : price <= o.price)
                    : (o.buy ? price <= o.price : price >= o.price))
                && withinExposureLimits(o.trader, o.pairIndex, o.positionSize.mul(o.leverage)))
            {

                uint priceBeforeImpact = price;

                if (IPairStorage(aggregator.pairsStorage()).pairGroupIndex(o.pairIndex) < 2) 
                {
                    // crypto only
                    (uint priceAfterImpact) = pairInfos.getTradePriceImpact(
                        price,
                        o.pairIndex,
                        o.buy,
                        o.positionSize.mul(o.leverage)
                    );

                    price = priceAfterImpact;
                } else {
                    price = _marketExecutionPrice(price, spreadP, o.buy);
                }

                uint maxSlippage = (o.price * o.slippageP) / 100 / _PRECISION;

                if(!(o.buy ? price  > o.price + maxSlippage : price < o.price - maxSlippage)) {
                    ITradingStorage.Trade memory finalTrade = _registerTrade(
                    ITradingStorage.Trade(
                        o.trader,
                        o.pairIndex,
                        0,
                        0,
                        o.positionSize,
                        price,
                        o.buy,
                        o.leverage,
                        o.tp,
                        o.sl,
                        0
                        )
                    );

                    if (o.executionFee > 0) {
                        storageT.transferUSDC(address(storageT), address(storageT.vaultManager()), o.executionFee);

                        executor.distributeReward(
                            IExecute.TriggeredLimitId(o.trader, o.pairIndex, o.index, ITradingStorage.LimitOrder.OPEN),
                            o.executionFee
                        );
                    }

                    storageT.unregisterOpenLimitOrder(o.trader, o.pairIndex, o.index);

                    //Non mathcing with def to avoid more vars
                    emit LimitExecuted(
                        orderId,
                        n.index,
                        finalTrade,
                        ITradingStorage.LimitOrder.OPEN,
                        finalTrade.openPrice,
                        finalTrade.initialPosToken,
                        int(o.price),
                        priceBeforeImpact
                    );
                }
            }
        }

        executor.unregisterTrigger(IExecute.TriggeredLimitId(n.trader, n.pairIndex, n.index, n.orderType));
        storageT.unregisterPendingLimitOrder(orderId);
    }

    /**
     * @dev Callback function for executing limit close orders(TP/SL/LIQ)
     * @param orderId orderId.
     * @param price price.
     * @param spreadP spreadP.
     */
    function executeLimitCloseOrderCallback(uint orderId, uint price, uint spreadP) external override onlyPriceAggregator {
        ITradingStorage.PendingLimitOrder memory o = storageT.reqIDpendingLimitOrder(orderId);
        ITradingStorage.Trade memory t = storageT.openTrades(o.trader, o.pairIndex, o.index);

        IPriceAggregator aggregator = storageT.priceAggregator();
        IExecute executor = aggregator.executions();

        if (price != 0 && t.leverage > 0) {
            ITradingStorage.TradeInfo memory i = storageT.openTradesInfo(t.trader, t.pairIndex, t.index);
            
            uint vPrice = aggregator.pairsStorage().guaranteedSlEnabled(t.pairIndex)
                ? o.orderType == ITradingStorage.LimitOrder.TP ? t.tp : o.orderType == ITradingStorage.LimitOrder.SL
                    ? (t.buy && t.sl > t.openPrice) || (!t.buy && t.sl < t.openPrice)
                        ? price
                        : t.sl
                    : price
                : price;

            int vProfitP = _currentPercentProfit(t.openPrice, vPrice, t.buy, t.leverage);
            uint vReward;

            if (o.orderType == ITradingStorage.LimitOrder.LIQ) {
                uint liqPrice = pairInfos.getTradeLiquidationPrice(
                    t.trader,
                    t.pairIndex,
                    t.index,
                    t.openPrice,
                    t.buy,
                    t.initialPosToken,
                    t.leverage
                );
                vReward = (t.buy ? price <= liqPrice : price >= liqPrice) ? (t.initialPosToken * liqFeeP) / 100 : 0;
            } else {
                vReward = (o.orderType == ITradingStorage.LimitOrder.TP &&
                    t.tp > 0 &&
                    (t.buy ? price >= t.tp : price <= t.tp)) ||
                    (o.orderType == ITradingStorage.LimitOrder.SL &&
                        t.sl > 0 &&
                        (t.buy ? price <= t.sl : price >= t.sl))
                    ? (t.initialPosToken * aggregator.pairsStorage().pairLimitOrderFeeP(t.pairIndex)) /
                        100 /
                        _PRECISION
                    : 0;
            }

            if (o.orderType == ITradingStorage.LimitOrder.LIQ && vReward > 0) {
                uint usdcSentToTrader = _unregisterTrade(
                    t,
                    vProfitP,
                    t.initialPosToken,
                    vReward,
                    (vReward * (liqTotalFeeP - liqFeeP)) / liqFeeP,
                    i.lossProtection
                );

                executor.distributeReward(
                    IExecute.TriggeredLimitId(o.trader, o.pairIndex, o.index, o.orderType),
                    vReward
                );

                emit LimitExecuted(
                    orderId,
                    price,
                    t,
                    o.orderType,
                    vPrice,
                    t.initialPosToken,
                    vProfitP,
                    usdcSentToTrader
                );
            }

            if (o.orderType != ITradingStorage.LimitOrder.LIQ && vReward > 0) {
                
                vReward = vReward > _MAX_EXEC_REWARD  ? _MAX_EXEC_REWARD : vReward;
                int pnl = (int(t.initialPosToken) * vProfitP) / int(_PRECISION) / 100;
                uint lpFee = ((pnl < 0) && (pnl * -1) > int(t.initialPosToken)) ? 0 : uint(int(t.initialPosToken) + pnl).mul(t.leverage) * aggregator.pairsStorage().pairCloseFeeP(t.pairIndex);

                uint usdcSentToTrader = _unregisterTrade(
                    t,
                    vProfitP,
                    t.initialPosToken,
                    vReward,
                    lpFee / 100 / _PRECISION,
                    i.lossProtection
                );

                executor.distributeReward(
                    IExecute.TriggeredLimitId(o.trader, o.pairIndex, o.index, o.orderType),
                    vReward
                );
                emit LimitExecuted(
                    orderId,
                    price,// Index can be fetched from t. Need price for efficiency analysis of bots
                    t,
                    o.orderType,
                    vPrice,
                    t.initialPosToken,
                    vProfitP,
                    usdcSentToTrader
                );
            }
        }

        executor.unregisterTrigger(IExecute.TriggeredLimitId(o.trader, o.pairIndex, o.index, o.orderType));
        storageT.unregisterPendingLimitOrder(orderId);
    }

    /** 
     * @notice Updates stop loss order based on aggregator's callback
     * @param orderId orderId.
     * @param price price.
     * @param spreadP spreadP.
     */
    function updateSlCallback(uint orderId, uint price, uint spreadP) external override onlyPriceAggregator {
        IPriceAggregator aggregator = storageT.priceAggregator();
        IPriceAggregator.PendingSl memory o = aggregator.pendingSlOrders(orderId);

        ITradingStorage.Trade memory t = storageT.openTrades(o.trader, o.pairIndex, o.index);
        if (
            price != 0 &&
            t.buy == o.buy &&
            t.openPrice == o.openPrice &&
            (t.buy ? o.newSl <= price : o.newSl >= price)
        ) {
            storageT.updateSl(o.trader, o.pairIndex, o.index, o.newSl);
            emit SlUpdated(orderId, o.trader, o.pairIndex, o.index, o.newSl);
        }

        aggregator.unregisterPendingSlOrder(orderId);
    }

    /** 
     * @notice Transfers funds from the vault to the trader
     * @param _trader Address of the trader
     * @param _amount Amount to be transferred
     */
    function transferFromVault(address _trader, uint _amount) external override {
        require(_amount > 0 && msg.sender == address(storageT.priceAggregator().executions()), "E_O");
        storageT.vaultManager().sendUSDCToTrader(_trader, _amount);
    }

    function correctTp(uint openPrice, uint leverage, uint tp, bool buy) public override pure returns (uint) {
        if (tp == 0 || _currentPercentProfit(openPrice, tp, buy, leverage) == int(_MAX_GAIN_P) * int(_PRECISION)) {
            uint tpDiff = ((openPrice * _MAX_GAIN_P).div(leverage)) / 100;
            return buy ? openPrice + tpDiff : tpDiff <= openPrice ? openPrice - tpDiff : 0;
        }
        return tp;
    }

    function correctSl(uint openPrice, uint leverage, uint sl, bool buy) public override pure returns (uint) {
        if (sl > 0 && _currentPercentProfit(openPrice, sl, buy, leverage) < int(_MAX_SL_P) * int(_PRECISION) * (-1)) {
            uint slDiff = ((openPrice * _MAX_SL_P).div(leverage)) / 100;
            return buy ? openPrice - slDiff : openPrice + slDiff;
        }
        return sl;
    }

    function withinExposureLimits(address _trader, uint _pairIndex, uint _leveragedPos) public view returns (bool) {
        IPairStorage pairsStored = storageT.priceAggregator().pairsStorage();
        return
            //90%TVL cap
            storageT.totalOI() + _leveragedPos <= storageT.maxOpenInterest() &&
            // Asset Wise Limitation
            pairsStored.groupOI(_pairIndex) + _leveragedPos <= pairsStored.groupMaxOI(_pairIndex) &&
            // Pair Wise limitation
            storageT.pairOI(_pairIndex) + _leveragedPos <= pairsStored.pairMaxOI(_pairIndex) &&
            // Wallet Exposure Limit
            storageT.walletOI(_trader) + _leveragedPos <= pairsStored.maxWalletOI(_pairIndex);
            
    }
    
    /** 
     * @notice Registers a new trade(Market/Limit)
     * @param _trade Trade information to be registered
     * @return Updated trade information
     */
    function _registerTrade(ITradingStorage.Trade memory _trade) private returns (ITradingStorage.Trade memory) {
        IPriceAggregator aggregator = storageT.priceAggregator();
        IPairStorage pairsStored = aggregator.pairsStorage();

        _trade.timestamp = block.timestamp;
        _trade.positionSizeUSDC -= storageT.handleDevGovFees(
            _trade.trader,
            _trade.pairIndex,
            _trade.positionSizeUSDC.mul(_trade.leverage),
            true,
            true,
            _trade.buy
        );

        storageT.vaultManager().reserveBalance(_trade.positionSizeUSDC.mul(_trade.leverage));
        storageT.vaultManager().receiveUSDCFromTrader(_trade.trader, _trade.positionSizeUSDC);

        _trade.initialPosToken = _trade.positionSizeUSDC;
        _trade.positionSizeUSDC = 0;

        _trade.index = storageT.firstEmptyTradeIndex(_trade.trader, _trade.pairIndex);
        _trade.tp = correctTp(_trade.openPrice, _trade.leverage, _trade.tp, _trade.buy);
        _trade.sl = correctSl(_trade.openPrice, _trade.leverage, _trade.sl, _trade.buy);

        pairInfos.storeTradeInitialAccFees(_trade.trader, _trade.pairIndex, _trade.index, _trade.buy);

        pairsStored.updateGroupOI(_trade.pairIndex, _trade.initialPosToken.mul(_trade.leverage), _trade.buy, true);

        storageT.storeTrade(
            _trade,
            ITradingStorage.TradeInfo(
                _trade.initialPosToken.mul(_trade.leverage),
                block.number,
                block.number,
                false,
                pairInfos.lossProtectionTier(_trade)
            )
        );

        return (_trade);
    }

    /** 
     * @notice Unregisters an existing trade. Called during Partial order close as well.
     * @param _trade Trade information
     * @param _percentProfit Percentage profit of the trade
     * @param _collateral Current USDC position
     * @param _feeAmountToken Fee in token for the executor
     * @param _lpFeeToken Fee in token for the liquidity provider
     * @param _tier Tier level for the trade
     * @return usdcSentToTrader Amount of USDC sent to the trader
     */
    function _unregisterTrade(
        ITradingStorage.Trade memory _trade,
        int _percentProfit,
        uint _collateral,
        uint _feeAmountToken, // executor reward
        uint _lpFeeToken,
        uint _tier
    ) private returns (uint usdcSentToTrader) {
        //Scoping Local Variables to avoid stack too deep
        uint totalFees;
        {
            (uint feeAfterRebate, uint referrerRebate) = storageT.applyReferral(
                _trade.trader,
                _lpFeeToken,
                _collateral.mul(_trade.leverage)
            );
            
            int pnl;
            (usdcSentToTrader, pnl, totalFees) = pairInfos.getTradeValue(
                _trade,
                _collateral,
                _percentProfit,
                feeAfterRebate + _feeAmountToken,
                _tier
            );

            if (usdcSentToTrader > 0) {
                storageT.vaultManager().sendUSDCToTrader(_trade.trader, usdcSentToTrader);
            }
            if (pnl < 0) {
                storageT.vaultManager().allocateRewards(uint(-pnl), true);
                storageT.vaultManager().allocateRewards(totalFees - _feeAmountToken, false);
            } else if (totalFees > 0 ) storageT.vaultManager().allocateRewards(totalFees - _feeAmountToken, false);

            if (referrerRebate > 0) {
                storageT.vaultManager().sendReferrerRebateToStorage(referrerRebate);
            }

        }
        storageT.vaultManager().releaseBalance(_collateral.mul(_trade.leverage));

        if (_trade.initialPosToken == _collateral)
            storageT.unregisterTrade(_trade.trader, _trade.pairIndex, _trade.index);
        else {
            storageT.registerPartialTrade(_trade.trader, _trade.pairIndex, _trade.index, _collateral + totalFees);
        }

        storageT.priceAggregator().pairsStorage().updateGroupOI(
            _trade.pairIndex,
            _collateral.mul(_trade.leverage),
            _trade.buy,
            false
        );

        return usdcSentToTrader;
    }

    function _currentPercentProfit(
        uint openPrice,
        uint currentPrice,
        bool buy,
        uint leverage
    ) private pure returns (int p) {
        int diff = buy ? (int(currentPrice) - int(openPrice)) : (int(openPrice) - int(currentPrice));
        int minPnlP = int(_PRECISION) * (-100);
        int maxPnlP = int(_MAX_GAIN_P) * int(_PRECISION);
        p = (diff * 100 * int(_PRECISION.mul(leverage))) / int(openPrice);
        p = p < minPnlP ? minPnlP : p > maxPnlP ? maxPnlP : p;
    }

    function _marketExecutionPrice(uint _price, uint _spreadP, bool _long) private pure returns (uint) {
        uint priceDiff = (_price * _spreadP) / 100 / _PRECISION;
        return _long ? _price + priceDiff : _price - priceDiff;
    }
}
