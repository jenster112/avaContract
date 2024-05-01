// SPDX-License-Identifier: MIT
import "./interfaces/ITradingStorage.sol";
import "./interfaces/IPairInfos.sol";
import "./interfaces/IExecute.sol";
import "./interfaces/ICallbacks.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {PositionMath} from "./library/PositionMath.sol";

pragma solidity 0.8.7;

contract Trading is PausableUpgradeable {
    using PositionMath for uint;

    uint private constant _PRECISION = 1e10;
    uint private constant _MAX_SL_P = 80; // -80% PNL

    ITradingStorage public storageT;
    IPairInfos public pairInfos;

    uint public limitOrdersTimelock;
    bool public isWhitelisted; // Toggle whitelisting
    address public operator;

    mapping(address => bool) public whitelistedAddress;
    mapping(address => mapping(uint => uint)) public lastUpdateTime;
    mapping(address => bool) public isOperator;

    // Events
    event Whitelist(bool whitelist);

    event NumberUpdated(string name, uint value);
    event AddressUpdated(string name, address a);

    event MarketOrderInitiated(
        address indexed trader, 
        uint pairIndex, 
        bool open, 
        uint orderId, 
        uint timestamp
    );

    event LimitOrderInitiated(
        address indexed trader, 
        uint pairIndex, 
        uint orderId, 
        uint timestamp
    );

    event LimitOrderSameBlock(
        address indexed trader, 
        uint pairIndex, 
        uint timestamp
    );

    event OpenLimitPlaced(
        address indexed trader, 
        uint pairIndex, 
        uint index, 
        bool isBuy,
        uint openPrice,
        uint executionFee,
        IExecute.OpenLimitOrderType orderType,
        uint slippageP
    );

    event OpenLimitUpdated(
        address indexed trader,
        uint pairIndex,
        uint index,
        uint newPrice,
        uint newTp,
        uint newSl,
        uint timestamp
    );

    event OpenLimitCanceled(
        address indexed trader, 
        uint pairIndex, 
        uint index, 
        uint timestamp
    );

    event TpUpdated(
        address indexed trader, 
        uint pairIndex, 
        uint index, 
        uint newTp, 
        uint timestamp
    );

    event SlUpdated(
        address indexed trader, 
        uint pairIndex, 
        uint index, 
        uint newSl, 
        uint timestamp
    );

    event SlUpdateInitiated(
        address indexed trader,
        uint pairIndex,
        uint index,
        uint newSl,
        uint orderId,
        uint timestamp
    );

    event MarginUpdated(
        address indexed trader,
        uint pairIndex,
        uint index,
        ITradingStorage.updateType _type,
        ITradingStorage.Trade newTrade,
        uint marginFees,
        uint lossProtectionTier,
        uint timestamp
    );

    event OperatorUpdated(
        address operator,
        bool isOperator
    );

    // Modifiers
    modifier onlyGov() {
        require(msg.sender == storageT.gov(), "GOV_ONLY");
        _;
    }

    modifier onlyWhitelist() {
        if (isWhitelisted) require(whitelistedAddress[msg.sender], "WHITELIST_ONLY");
        _;
    }

    modifier onlyOperator() {
        require(isOperator[msg.sender], "ONLY_OPERATOR");
        _;
    }

    constructor() {
        _disableInitializers();
    }
    /**
     * @notice Initializes the proxy
     * @param _storageT The address of the storage contract
     * @param _pairInfos The address of the pair information contract
     */
    function initialize(address _storageT, address _pairInfos) external initializer {
        storageT = ITradingStorage(_storageT);
        pairInfos = IPairInfos(_pairInfos);
        limitOrdersTimelock = 30;
        isWhitelisted = false;
        __Pausable_init();
    }

    /**
     * @notice Sets the time-lock for limit order updates
     * @param _blocks The new time-lock duration in blocks
     */
    function setLimitOrdersTimelock(uint _blocks) external onlyGov {
        require(_blocks > 0, "VALUE_0");
        limitOrdersTimelock = _blocks;
        emit NumberUpdated("limitOrdersTimelock", _blocks);
    }

    /**
     * @notice Adds an address to the whitelist
     * @param _address The address to add to the whitelist
     */
    function addWhitelist(address _address) external onlyGov {
        require(_address != address(0));
        whitelistedAddress[_address] = true;
        emit AddressUpdated("addWhitelist", _address);
    }

    /**
     * @notice Remove an address from the whitelist
     * @param _address The address to remove from the whitelist
     */
    function removeWhitelist(address _address) external onlyGov {
        require(_address != address(0));
        whitelistedAddress[_address] = false;
        emit AddressUpdated("removeWhitelist", _address);
    }

    /**
     * @notice Pauses the contract
     */
    function pause() external onlyGov {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     */
    function unpause() external onlyGov {
        _unpause();
    }

    /**
     * @notice Enables/disables Whitelisting
     */
    function toggleWhitelist() external onlyGov {
        isWhitelisted = !isWhitelisted;
        emit Whitelist(isWhitelisted);
    }

    function updateOperator(address _operator, bool _isOperator) external onlyGov{
        isOperator[_operator] = _isOperator;
        emit OperatorUpdated(_operator, _isOperator);
    }

    function setMarketExecFeeReciever(address _reciever) external onlyGov{
        require(_reciever != address(0), "ZERO_ADDRESS");
        operator = _reciever;
    }

    /**
     * @notice Updates(Deposit/Withdraw) the margin for an open trade
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the trade
     * @param _type Withdraw or Deposit
     * @param _amount The Collateral by which to update the margin
     * @param priceUpdateData Pyth price update
     */
    function updateMargin(
        uint _pairIndex,
        uint _index,
        ITradingStorage.updateType _type,
        uint _amount,
        bytes[] calldata priceUpdateData
    ) external payable onlyWhitelist whenNotPaused returns(uint orderId){
        IPriceAggregator aggregator = storageT.priceAggregator();

        ITradingStorage.Trade memory t = storageT.openTrades(msg.sender, _pairIndex, _index);
        ITradingStorage.TradeInfo memory i = storageT.openTradesInfo(msg.sender, _pairIndex, _index);

        require(!i.beingMarketClosed, "ALREADY_BEING_CLOSED");
        require(t.leverage > 0, "NO_TRADE");

        uint marginFees = pairInfos.getTradeRolloverFee(
            t.trader,
            t.pairIndex,
            t.index,
            t.buy,
            t.initialPosToken,
            t.leverage
        );

        orderId = aggregator.getPrice(_pairIndex, IPriceAggregator.OrderType.UPDATE_MARGIN);
        aggregator.storePendingMarginUpdateOrder(
            orderId,
            IPriceAggregator.PendingMarginUpdate(msg.sender, _pairIndex, _index, _type, _amount, i.lossProtection, marginFees, t.leverage)
        );

        (t.leverage, t.initialPosToken) = _calculateNewLeverage(
            i.openInterestUSDC,
            t.initialPosToken,
            _type,
            _amount,
            marginFees
        );
        require(
            t.leverage > 0 &&
                t.leverage >= aggregator.pairsStorage().pairMinLeverage(t.pairIndex) &&
                t.leverage <= aggregator.pairsStorage().pairMaxLeverage(t.pairIndex),
            "LEVERAGE_INCORRECT"
        );

        emit MarginUpdated(
            msg.sender, 
            _pairIndex, 
            _index, 
            _type, 
            t, 
            marginFees, 
            i.lossProtection, 
            block.timestamp);
            
        storageT.updateTrade(t);
        aggregator.fulfill{value: msg.value}(orderId, priceUpdateData);
    }

    /**
     * @notice Opens a new Market/Limit trade
     * @param t The details of the trade to open
     * @param _type Market or Limit or Stop Limit
     * @param _slippageP The slippage percentage
     * @param _executionFee The fee for executing the trade (in USDC)
     */
    function openTrade(
        ITradingStorage.Trade calldata t,
        IExecute.OpenLimitOrderType _type,
        uint _slippageP,
        uint _executionFee // In USDC. Optional for Limit orders
    ) external payable onlyWhitelist whenNotPaused returns(uint orderId) {
        
        IPriceAggregator aggregator = storageT.priceAggregator();
        IPairStorage pairsStored = aggregator.pairsStorage();

        (bool sent, ) = payable(operator).call{value: msg.value}("");
        require(sent, "EXECUTION_FEE_NOT_SENT");

        require(storageT.pendingOrderIdsCount(msg.sender) < storageT.maxPendingMarketOrders(), "MAX_PENDING_ORDERS");
        
        require(
            storageT.openTradesCount(msg.sender, t.pairIndex) +
                storageT.pendingMarketOpenCount(msg.sender, t.pairIndex) +
                storageT.openLimitOrdersCount(msg.sender, t.pairIndex) <
                storageT.maxTradesPerPair(),
            "MAX_TRADES_PER_PAIR"
        );

        require(t.positionSizeUSDC.mul(t.leverage) >= pairsStored.pairMinLevPosUSDC(t.pairIndex), "BELOW_MIN_POS");

        require(
            t.leverage > 0 &&
                t.leverage >= pairsStored.pairMinLeverage(t.pairIndex) &&
                t.leverage <= pairsStored.pairMaxLeverage(t.pairIndex),
            "LEVERAGE_INCORRECT"
        );

        require(t.tp == 0 || (t.buy ? t.tp > t.openPrice : t.tp < t.openPrice), "WRONG_TP");
        require(t.sl == 0 || (t.buy ? t.sl < t.openPrice : t.sl > t.openPrice), "WRONG_SL");

        if (_type != IExecute.OpenLimitOrderType.MARKET) {
            storageT.transferUSDC(msg.sender, address(storageT), t.positionSizeUSDC + _executionFee);
            uint index = storageT.firstEmptyOpenLimitIndex(msg.sender, t.pairIndex);

            storageT.storeOpenLimitOrder(
                ITradingStorage.OpenLimitOrder(
                    msg.sender,
                    t.pairIndex,
                    index,
                    t.positionSizeUSDC,
                    t.buy,
                    t.leverage,
                    t.tp,
                    t.sl,
                    t.openPrice,
                    _slippageP,
                    block.number,
                    _executionFee
                )
            );

            aggregator.executions().setOpenLimitOrderType(msg.sender, t.pairIndex, index, _type);

            emit OpenLimitPlaced(msg.sender, t.pairIndex, index, t.buy, t.openPrice, _executionFee, _type, _slippageP);
        } else {

            storageT.transferUSDC(msg.sender, address(storageT), t.positionSizeUSDC);

            orderId = aggregator.getPrice(t.pairIndex, IPriceAggregator.OrderType.MARKET_OPEN);

            storageT.storePendingMarketOrder(
                ITradingStorage.PendingMarketOrder(
                    ITradingStorage.Trade(
                        msg.sender,
                        t.pairIndex,
                        0,
                        0,
                        t.positionSizeUSDC,
                        0,
                        t.buy,
                        t.leverage,
                        t.tp,
                        t.sl,
                        0
                    ),
                    0,
                    t.openPrice,
                    _slippageP
                ),
                orderId,
                true
            );

            emit MarketOrderInitiated(msg.sender, t.pairIndex, true, orderId, block.timestamp);
        }
    }

    /**
     * @notice Closes a trade using market execution
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the trade
     * @param _amount The amount of collateral being closed
     */
    function closeTradeMarket(
        uint _pairIndex,
        uint _index,
        uint _amount, // Collateral being closed
        uint _executionFee
    ) external payable onlyWhitelist whenNotPaused returns(uint orderId){

        (bool sent, ) = payable(operator).call{value: msg.value}("");
        require(sent, "EXECUTION_FEE_NOT_SENT");

        uint leverage = storageT.openTrades(msg.sender, _pairIndex, _index).leverage;
        bool beingMarketClosed = storageT.openTradesInfo(msg.sender, _pairIndex, _index).beingMarketClosed;

        require(storageT.pendingOrderIdsCount(msg.sender) < storageT.maxPendingMarketOrders(), "MAX_PENDING_ORDERS");
        require(!beingMarketClosed, "ALREADY_BEING_CLOSED");
        require(leverage > 0, "NO_TRADE");

        orderId = storageT.priceAggregator().getPrice(_pairIndex, IPriceAggregator.OrderType.MARKET_CLOSE);

        storageT.storePendingMarketOrder(
            ITradingStorage.PendingMarketOrder(
                ITradingStorage.Trade(msg.sender, _pairIndex, _index, _amount, 0, 0, false, 0, 0, 0, 0),
                0,
                0,
                0
            ),
            orderId,
            false
        );
        
        emit MarketOrderInitiated(msg.sender, _pairIndex, false, orderId, block.timestamp);
    }


    /**
     * @notice Keeper method to close pending market orders
     * @param pairIndex The index of the trading pair
     * @param orderId The array of orderIDs
     * @param priceUpdateData Pyth price update calldata
     */
    function executeMarketOrders(uint pairIndex, uint[] calldata orderId, bytes[] calldata priceUpdateData) external payable onlyOperator{
        
        for(uint i = 0; i< orderId.length; i++){
            storageT.priceAggregator().fulfill{value: msg.value}(orderId[i], priceUpdateData);
        }
    }

    /**
     * @notice Updates an open limit order
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the order
     * @param _price The price level to set (_PRECISION)
     * @param _tp The take-profit price
     * @param _sl The stop-loss price
     */
    function updateOpenLimitOrder(
        uint _pairIndex,
        uint _index,
        uint _price, 
        uint _slippageP,
        uint _tp,
        uint _sl
    ) external onlyWhitelist whenNotPaused {
        ITradingStorage.OpenLimitOrder memory o = storageT.getOpenLimitOrder(msg.sender, _pairIndex, _index);
        require(block.number - o.block >= limitOrdersTimelock, "LIMIT_TIMELOCK");

        require(_tp == 0 || (o.buy ? _price < _tp : _price > _tp), "WRONG_TP");
        require(_sl == 0 || (o.buy ? _price > _sl : _price < _sl), "WRONG_SL");

        o.price = _price;
        o.slippageP = _slippageP;
        o.tp = _tp;
        o.sl = _sl;

        storageT.updateOpenLimitOrder(o);

        emit OpenLimitUpdated(msg.sender, _pairIndex, _index, _price, _tp, _sl, block.timestamp);
    }

    /**
     * @notice Cancels an open limit order
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the order
     */
    function cancelOpenLimitOrder(uint _pairIndex, uint _index) external onlyWhitelist whenNotPaused {
        ITradingStorage.OpenLimitOrder memory o = storageT.getOpenLimitOrder(msg.sender, _pairIndex, _index);
        require(block.number - o.block >= limitOrdersTimelock, "LIMIT_TIMELOCK");

        storageT.transferUSDC(address(storageT), msg.sender, o.positionSize + o.executionFee);
        storageT.unregisterOpenLimitOrder(msg.sender, _pairIndex, _index);

        emit OpenLimitCanceled(msg.sender, _pairIndex, _index, block.timestamp);
    }

    /**
     * @notice Updates the take-profit and stop-loss for a open Trade
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the order
     * @param _newSl The new stop-loss price
     * @param _newTP The new take-profit price
     * @param priceUpdateData Pyth price update data
     */
    function updateTpAndSl(
        uint _pairIndex,
        uint _index,
        uint _newSl,
        uint _newTP,
        bytes[] calldata priceUpdateData
    ) external payable onlyWhitelist whenNotPaused {
        _updateTp(_pairIndex, _index, _newTP);
        _updateSl(_pairIndex, _index, _newSl, priceUpdateData);
    }

    /**
     * @notice Updates the take-profit level for a open trade
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the order
     * @param _newTp The new take-profit price
     */
    function updateTp(uint _pairIndex, uint _index, uint _newTp) external onlyWhitelist whenNotPaused {
        _updateTp(_pairIndex, _index, _newTp);
    }

    /**
     * @notice Updates the stop-loss level for a open trade
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the order
     * @param _newSl The new stop-loss level
     * @param priceUpdateData Pyth price update data
     */
    function updateSl(
        uint _pairIndex,
        uint _index,
        uint _newSl,
        bytes[] calldata priceUpdateData
    ) external payable onlyWhitelist whenNotPaused {
        _updateSl(_pairIndex, _index, _newSl, priceUpdateData);
    }

    /**
     * @notice Executes a limit order (either open or close)
     * @param _orderType The type of limit order (OPEN, CLOSE, TP, SL, LIQ)
     * @param _trader The address of the trader
     * @param _pairIndex The index of the trading pair
     * @param _index The index of the order
     * @param priceUpdateData Pyth price update data
     */
    function executeLimitOrder(
        ITradingStorage.LimitOrder _orderType,
        address _trader,
        uint _pairIndex,
        uint _index,
        bytes[] calldata priceUpdateData
    ) external payable onlyWhitelist whenNotPaused {


        if (_orderType == ITradingStorage.LimitOrder.OPEN) {
            IPairStorage pairsStored = IPriceAggregator(storageT.priceAggregator()).pairsStorage();
        
            require(storageT.hasOpenLimitOrder(_trader, _pairIndex, _index), "NO_LIMIT");
              
            lastUpdateTime[_trader][_pairIndex] =  block.timestamp;
        } else {
            ITradingStorage.Trade memory t = storageT.openTrades(_trader, _pairIndex, _index);

            require(t.leverage > 0, "NO_TRADE");
            require(_orderType != ITradingStorage.LimitOrder.SL || t.sl > 0, "NO_SL");

            if (_orderType == ITradingStorage.LimitOrder.LIQ) {
                uint liqPrice = _getTradeLiquidationPrice(t);
                require(t.sl == 0 || (t.buy ? liqPrice > t.sl : liqPrice < t.sl), "HAS_SL");
            }
        }

        IPriceAggregator aggregator = storageT.priceAggregator();
        IExecute executor = aggregator.executions();

        IExecute.TriggeredLimitId memory triggeredLimitId = IExecute.TriggeredLimitId(
            _trader,
            _pairIndex,
            _index,
            _orderType
        );

        uint orderId = aggregator.getPrice(
            _pairIndex,
            _orderType == ITradingStorage.LimitOrder.OPEN
                ? IPriceAggregator.OrderType.LIMIT_OPEN
                : IPriceAggregator.OrderType.LIMIT_CLOSE
        );

        storageT.storePendingLimitOrder(
            ITradingStorage.PendingLimitOrder(_trader, _pairIndex, _index, _orderType),
            orderId
        );

        executor.storeFirstToTrigger(triggeredLimitId, msg.sender);
        emit LimitOrderInitiated(_trader, _pairIndex, orderId, block.timestamp);

        aggregator.fulfill{value: msg.value}(orderId, priceUpdateData);
    }

    /**
     * @notice FallBack method in case unregister is not working directly
     */
    function cancelPendingMarketOrder(uint256 _id) external onlyOperator{
        storageT.forceUnregisterPendingMarketOrder(_id);
    }
    
    /** 
     * @notice Internal function to update Take Profit value.
     * @param _pairIndex The index of the trading pair.
     * @param _index The index of the trade.
     * @param _newTp New Take Profit value.
     */
    function _updateTp(uint _pairIndex, uint _index, uint _newTp) internal {
        uint leverage = storageT.openTrades(msg.sender, _pairIndex, _index).leverage;
        uint tpLastUpdated = storageT.openTradesInfo(msg.sender, _pairIndex, _index).tpLastUpdated;

        require(leverage > 0, "NO_TRADE");
        require(block.number - tpLastUpdated >= limitOrdersTimelock, "LIMIT_TIMELOCK");
        require(_newTp < uint(type(int256).max), "INCORRECT_TP");

        storageT.updateTp(msg.sender, _pairIndex, _index, _newTp);

        emit TpUpdated(msg.sender, _pairIndex, _index, _newTp, block.timestamp);
    }

    /** 
     * @notice Internal function to update Stop Loss value.
     * @param _pairIndex The index of the trading pair.
     * @param _index The index of the trade.
     * @param _newSl New Stop Loss value.
     * @param priceUpdateData Pyth price data.
     */
    function _updateSl(uint _pairIndex, uint _index, uint _newSl, bytes[] calldata priceUpdateData) internal {
        ITradingStorage.Trade memory t = storageT.openTrades(msg.sender, _pairIndex, _index);
        uint slLastUpdated = storageT.openTradesInfo(msg.sender, _pairIndex, _index).slLastUpdated;

        require(t.leverage > 0, "NO_TRADE");
        require(_newSl < uint(type(int256).max), "INCORRECT_SL");

        uint maxSlDist = ((t.openPrice * _MAX_SL_P) / 100).div(t.leverage);
        require(
            _newSl == 0 || (t.buy ? _newSl >= t.openPrice - maxSlDist : _newSl <= t.openPrice + maxSlDist),
            "SL_TOO_BIG"
        );

        require(block.number - slLastUpdated >= limitOrdersTimelock, "LIMIT_TIMELOCK");

        IPriceAggregator aggregator = storageT.priceAggregator();

        if (_newSl == 0 || !aggregator.pairsStorage().guaranteedSlEnabled(_pairIndex)) {
            storageT.updateSl(msg.sender, _pairIndex, _index, _newSl);
            emit SlUpdated(msg.sender, _pairIndex, _index, _newSl, block.timestamp);
        } else {
            uint levPosUSDC = t.initialPosToken.mul(t.leverage);

            t.initialPosToken -= storageT.handleDevGovFees(t.trader, t.pairIndex, levPosUSDC >> 1, false, true, t.buy);

            storageT.updateTrade(t);

            uint orderId = aggregator.getPrice(_pairIndex, IPriceAggregator.OrderType.UPDATE_SL);

            aggregator.storePendingSlOrder(
                orderId,
                IPriceAggregator.PendingSl(msg.sender, _pairIndex, _index, t.openPrice, t.buy, _newSl)
            );

            emit SlUpdateInitiated(msg.sender, _pairIndex, _index, _newSl, orderId, block.timestamp);

            aggregator.fulfill{value: msg.value}(orderId, priceUpdateData);
        }
    }

    /** 
     * @notice Internal function to calculate new leverage.
     * @param _openInterestUSDC The total open interest in USDC.
     * @param _currentCollateral The current collateral amount.
     * @param _type The type of update (DEPOSIT/WITHDRAW).
     * @param _newAmount The new amount to be deposited/withdrawn.
     * @param _fees Margin Fees
     */
    function _calculateNewLeverage(
        uint _openInterestUSDC,
        uint _currentCollateral,
        ITradingStorage.updateType _type,
        uint _newAmount,
        uint _fees
    ) internal pure returns (uint newLeverage, uint newAmount) {
        if (_type == ITradingStorage.updateType.DEPOSIT) {
            newAmount = _currentCollateral + _newAmount - _fees;
            newLeverage = (_openInterestUSDC * _PRECISION) / (newAmount);
        } else if (_type == ITradingStorage.updateType.WITHDRAW) {
            newAmount = _currentCollateral - _newAmount - _fees;
            newLeverage = (_openInterestUSDC * _PRECISION) / (newAmount);
        }
    }


    /** 
     * @notice Internal function to get the liquidation price of a trade.
     * @param t The trade information in memory.
     */
    function _getTradeLiquidationPrice(ITradingStorage.Trade memory t) private view returns (uint) {
        return
            pairInfos.getTradeLiquidationPrice(
                t.trader,
                t.pairIndex,
                t.index,
                t.openPrice,
                t.buy,
                t.initialPosToken,
                t.leverage
            );
    }
}
