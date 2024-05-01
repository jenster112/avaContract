// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./interfaces/ICallbacks.sol";
import "./interfaces/ITradingStorage.sol";
import "./interfaces/IExecute.sol";
import "./interfaces/IPriceAggregator.sol";
import "pyth-sdk-solidity/IPyth.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract PriceAggregator is Initializable, IPriceAggregator {

    uint private constant _PRECISION = 1e10;

    IPyth public pyth;
    bool public useBackupOnly;

    ITradingStorage public storageT;
    IPairStorage public override pairsStorage;
    IExecute public override executions;
    uint public chainlinkValidityPeriod;

    mapping(uint => Order) public orders;
    mapping(uint => uint[]) public ordersAnswers;
    mapping(uint => PendingSl) private _pendingSlOrders;
    mapping(uint => PendingMarginUpdate) private _pendingMarginUpdateOrders;

    // Modifiers
    modifier onlyGov() {
        require(msg.sender == storageT.gov(), "GOV_ONLY");
        _;
    }
    modifier onlyTrading() {
        require(msg.sender == storageT.trading(), "TRADING_ONLY");
        _;
    }
    
    constructor() {
        _disableInitializers();
    }
    /** 
     * @notice Initialize contract
     * @param _storageT The address of the storage contract
     * @param _pairsStorage The address of the pairs storage contract
     * @param _executions The address of the executions contract
     */
    function initialize(address _storageT, address _pairsStorage, address _executions) external initializer {
        require(address(_pairsStorage) != address(0), "WRONG_PARAMS");

        pairsStorage = IPairStorage(_pairsStorage);
        executions = IExecute(_executions);
        storageT = ITradingStorage(_storageT);
        chainlinkValidityPeriod = 2 minutes; 
    }

    /** 
     * @notice Update the address of the pairs storage contract
     * @param _pairsStorage New address for the pairs storage contract
     */
    function updatePairsStorage(address _pairsStorage) external onlyGov {
        require(address(_pairsStorage) != address(0), "VALUE_0");
        pairsStorage = IPairStorage(_pairsStorage);
        emit AddressUpdated("pairsStorage", address(_pairsStorage));
    }

   /** 
     * @notice Set the address of the Pyth contract
     * @param pythContract The address of the Pyth contract
     */
    function setPyth(address pythContract) external onlyGov {
        pyth = IPyth(pythContract);
        emit PythUpdated(pythContract);
    }

   /** 
     * @notice Sets bool indication only backup oracle will be used as main is dysfunctional
     * @param _start bool indicating state of oracle usage
     */
    function useBackUpOracleOnly(bool _start) external onlyGov {
        useBackupOnly = _start ;
        emit BackUpTriggered(_start);
    }

   /** 
     * @notice Sets chainlink validity period
     * @param _newPeriod new validity period
     */
    function setChainlinkValidityPeriod(uint _newPeriod) external onlyGov {
        chainlinkValidityPeriod = _newPeriod ;
        emit chainlinkValidityPeriodSet(_newPeriod);
    }
    /** 
     * @notice Creates an order and return the order ID
     * @param _pairIndex Index of the trading pair
     * @param _orderType Type of the order (Market open, Market close etc.)
     * @return orderId The ID of the created order
     */
    function getPrice(uint _pairIndex, OrderType _orderType) external override onlyTrading returns (uint) {
        (, , bytes32 job, , uint orderId) = pairsStorage.pairJob(_pairIndex);

        orders[orderId] = Order(_pairIndex, _orderType, job, true);
        return orderId;
    }

    /** 
     * @notice Fulfill an order by updating price feeds and invoking corresponding callbacks
     * @param orderId The ID of the order to fulfill
     * @param priceUpdateData Data required for updating the price feed
     */
    function fulfill(uint orderId, bytes[] calldata priceUpdateData) external payable override onlyTrading {
        Order storage r = orders[orderId];

        if (r.initiated) {

            uint price;
            IPairStorage.BackupFeed memory backupFeed = pairsStorage.pairBackupFeed(r.pairIndex);
            uint[] storage answers = ordersAnswers[orderId];
            if(useBackupOnly && r.orderType == OrderType.LIMIT_CLOSE && backupFeed.feedId != address(0)){
                ITradingStorage.PendingLimitOrder memory o = storageT.reqIDpendingLimitOrder(orderId);
                if(o.orderType == ITradingStorage.LimitOrder.LIQ){
                    // Doomsday situation. Pyth Broke. Only Allow liquidations via CL
                    AggregatorV2V3Interface chainlinkFeed = AggregatorV2V3Interface(backupFeed.feedId);
                    (, int256 rawBkPrice, ,uint updatedAt , ) = chainlinkFeed.latestRoundData(); // e.g. 160414750000, 8 decimals
                    if(updatedAt + chainlinkValidityPeriod >= block.timestamp){
                        uint bkPrice = (uint256(rawBkPrice) * _PRECISION) / 10 ** uint8(chainlinkFeed.decimals());
                        price = bkPrice;
                        emit BackupPriceReceived(orderId, r.pairIndex, bkPrice);
                    }
                }
            }
            else if(!useBackupOnly){
                uint fee = pyth.getUpdateFee(priceUpdateData);
                pyth.updatePriceFeeds{value: fee}(priceUpdateData);

                PythStructs.Price memory pythPrice = pyth.getPrice(r.job);
                uint conf;
                if (pythPrice.expo > 0) {
                    price = uint64(pythPrice.price) * _PRECISION * 10 ** uint32(pythPrice.expo);
                    conf = pythPrice.conf * _PRECISION * 10 ** uint32(pythPrice.expo);
                } else {
                    price = (uint64(pythPrice.price) * _PRECISION) / 10 ** uint32(-pythPrice.expo);
                    conf = (pythPrice.conf * _PRECISION) / 10 ** uint32(-pythPrice.expo);
                }

                IPairStorage.Feed memory f = pairsStorage.pairFeed(r.pairIndex);
 
                require(price > 0 && ((conf * _PRECISION * 100) / price) <= f.maxDeviationP, "PRICE_DEVIATION_TOO_HIGH");

                if (backupFeed.maxDeviationP > 0 && backupFeed.feedId != address(0)) {
                    AggregatorV2V3Interface chainlinkFeed = AggregatorV2V3Interface(backupFeed.feedId);
                    (, int256 rawBkPrice, , uint updatedAt , ) = chainlinkFeed.latestRoundData(); // e.g. 160414750000, 8 decimals
                    if(updatedAt + chainlinkValidityPeriod >= block.timestamp){
                        uint bkPrice = (uint256(rawBkPrice) * _PRECISION) / 10 ** uint8(chainlinkFeed.decimals());
                        emit BackupPriceReceived(orderId, r.pairIndex, bkPrice);

                        if (bkPrice > price) {
                            require(
                                (((bkPrice - price) * 100 * _PRECISION) / price) <= backupFeed.maxDeviationP,
                                "BACKUP_DEVIATION_TOO_HIGH"
                            );
                        }
                        if (bkPrice < price) {
                            require(
                                (((price - bkPrice) * 100 * _PRECISION) / bkPrice) <= backupFeed.maxDeviationP,
                                "BACKUP_DEVIATION_TOO_HIGH"
                            );
                        }
                    }
                }
            }

            answers.push(price);
            emit PriceReceived(orderId, r.pairIndex, price);

            if (answers.length > 0) {
                ICallbacks.AggregatorAnswer memory a = ICallbacks.AggregatorAnswer(
                    orderId,
                    _median(answers),
                    pairsStorage.pairSpreadP(r.pairIndex)
                );

                ICallbacks c = ICallbacks(storageT.callbacks());

                if (r.orderType == OrderType.MARKET_OPEN) {
                    c.openTradeMarketCallback(a.orderId, a.price, a.spreadP);
                } else if (r.orderType == OrderType.MARKET_CLOSE) {
                    c.closeTradeMarketCallback(a.orderId, a.price, a.spreadP);
                } else if (r.orderType == OrderType.LIMIT_OPEN) {
                    c.executeLimitOpenOrderCallback(a.orderId, a.price, a.spreadP);
                } else if (r.orderType == OrderType.LIMIT_CLOSE) {
                    c.executeLimitCloseOrderCallback(a.orderId, a.price, a.spreadP);
                } else if (r.orderType == OrderType.UPDATE_MARGIN) {
                    c.updateMarginCallback(a.orderId, a.price, a.spreadP);
                } else {
                    c.updateSlCallback(a.orderId, a.price, a.spreadP);
                }

                delete orders[orderId];
                delete ordersAnswers[orderId];
            }
        }
    }

    /** 
     * @notice Store information about a pending stop-loss (SL) order
     * @param orderId The ID of the order
     * @param p Data structure containing information about the pending SL order
     */
    function storePendingSlOrder(uint orderId, PendingSl calldata p) external override onlyTrading {
        _pendingSlOrders[orderId] = p;
    }

    /** 
     * @notice Store information about a pending margin update order
     * @param orderId The ID of the order
     * @param p Data structure containing information about the pending margin update order
     */
    function storePendingMarginUpdateOrder(uint orderId, PendingMarginUpdate calldata p) external override onlyTrading {
        _pendingMarginUpdateOrders[orderId] = p;
    }

    /** 
     * @notice Deletes a pending stop-loss (SL) order
     * @param orderId The ID of the order to unregister
     */
    function unregisterPendingSlOrder(uint orderId) external override {
        require(msg.sender == storageT.callbacks(), "CALLBACKS_ONLY");
        delete _pendingSlOrders[orderId];
    }

    /** 
     * @notice Deletes a pending margin update order
     * @param orderId The ID of the order to unregister
     */
    function unregisterPendingMarginUpdateOrder(uint orderId) external override {
        require(msg.sender == storageT.callbacks(), "CALLBACKS_ONLY");
        delete _pendingMarginUpdateOrders[orderId];
    }

    /** 
     * @notice Retrieves pending stop-loss (SL) order
     * @param index The index of the pending SL order
     * @return A struct containing the information about the pending SL order
     */
    function pendingSlOrders(uint index) external view override returns (PendingSl memory) {
        return _pendingSlOrders[index];
    }

    /** 
     * @notice Retrieves a pending margin update order
     * @param index The index of the pending margin update order
     * @return A struct containing the information about the pending margin update order
     */
    function pendingMarginUpdateOrders(uint index) external view override returns (PendingMarginUpdate memory) {
        return _pendingMarginUpdateOrders[index];
    }

    /** 
     * @notice Calculate open fee as a percentage for a trading pair
     * @param _pairIndex Index of the trading pair
     * @param _leveragedPositionSize Size of the leveraged position
     * @param _buy Whether the position is a buy or a sell
     * @return Fee percentage
     */
    function openFeeP(uint _pairIndex, uint _leveragedPositionSize, bool _buy) external view override returns (uint) {
        return pairsStorage.pairOpenFeeP(_pairIndex, _leveragedPositionSize, _buy);
    }
    
    /**
     * @notice Returns order stored
     */
    function getOrder(uint _id) external view override returns(Order memory){
        return orders[_id];
    }

    /** 
     * @notice Swaps the elements at the i^th and j^th index of an array.
     * @param array The array of integers.
     * @param i The index of the first element to be swapped.
     * @param j The index of the second element to be swapped.
     */
    function _swap(uint[] memory array, uint i, uint j) private pure {
        (array[i], array[j]) = (array[j], array[i]);
    }

    /** 
     * @notice Sorts an array of integers using quick sort.
     * @param array The array of integers to be sorted.
     * @param begin The starting index for the sort.
     * @param end The ending index for the sort.
     */
    function _sort(uint[] memory array, uint begin, uint end) private pure {
        if (begin >= end) {
            return;
        }
        uint j = begin;
        uint pivot = array[j];
        for (uint i = begin + 1; i < end; ++i) {
            if (array[i] < pivot) {
                _swap(array, i, ++j);
            }
        }
        _swap(array, begin, j);
        _sort(array, begin, j);
        _sort(array, j + 1, end);
    }

    /** 
     * @notice Calculates the median of an array of integers.
     * @param array The array of integers.
     * @return The median of the array.
     */
    function _median(uint[] memory array) private pure returns (uint) {
        _sort(array, 0, array.length);
        return
            array.length % 2 == 0
                ? (array[array.length >> 1 - 1] + array[array.length >> 1]) >> 1
                : array[array.length >> 1];
    }

}
