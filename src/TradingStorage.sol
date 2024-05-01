// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./interfaces/IPriceAggregator.sol";
import "./interfaces/IPausable.sol";
import "./interfaces/ICallbacks.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/ITradingStorage.sol";
import "./interfaces/IReferral.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PositionMath} from "./library/PositionMath.sol";

contract TradingStorage is Initializable, ITradingStorage {
    using PositionMath for uint;
    using SafeERC20 for IERC20;

    uint private constant _PRECISION = 1e10;

    IPriceAggregator public override priceAggregator;
    IPausable internal _trading;
    ICallbacks internal _callbacks;
    IERC20 public override usdc;
    IVaultManager public override vaultManager;
    IReferral public referral;

    uint public override maxTradesPerPair;
    uint public override maxPendingMarketOrders;
    uint public override totalOI;
    uint public tvlCap;
    uint public devFeesUSDC;
    uint public govFeesUSDC;

    address public requestedGov;
    address public override gov;
    address public override dev;
    address public govTreasury;

    OpenLimitOrder[] public openLimitOrders;
    uint[2] public usdOI;

    // Trades mappings
    mapping(address => mapping(uint => mapping(uint => Trade))) private _openTrades;
    mapping(address => mapping(uint => mapping(uint => TradeInfo))) private _openTradesInfo;
    mapping(address => mapping(uint => uint)) private _openTradesCount;
    mapping(address => uint) private _walletOI;

    // Limit orders mappings
    mapping(address => mapping(uint => mapping(uint => uint))) public openLimitOrderIds;
    mapping(address => mapping(uint => uint)) public override openLimitOrdersCount;

    // Pending orders mappings
    mapping(uint => PendingMarketOrder) private _reqIDpendingMarketOrder;
    mapping(uint => PendingLimitOrder) private _reqIDpendingLimitOrder;
    mapping(address => uint[]) public pendingOrderIds;
    mapping(address => mapping(uint => uint)) public override pendingMarketOpenCount;
    mapping(address => mapping(uint => uint)) public override pendingMarketCloseCount;

    // List of open trades & limit orders
    mapping(uint => address[]) public pairTraders;
    mapping(address => mapping(uint => uint)) public pairTradersId;

    // Current and max open interests for each pair
    mapping(uint => uint[2]) public override openInterestUSDC;

    // List of allowed contracts => can update storage + mint/burn tokens
    mapping(address => bool) public isTradingContract;
    mapping(address => uint) public rebates;

    // Limits against gamification 
    mapping(uint => mapping(uint=> uint)) public blockOI;

    // Modifiers
    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

    modifier onlyTrading() {
        require(isTradingContract[msg.sender]);
        _;
    }
    
    constructor() {
        _disableInitializers();
    }
    /**
     * @notice Initializes the proxy
     * @dev Can be called only once.
     */
    function initialize() external initializer {
        gov = msg.sender;
        maxTradesPerPair = 5;
        maxPendingMarketOrders = 5;
        tvlCap = 90 * _PRECISION;
    }
    /**
     * @notice Updates the USDC token contract address.
     * @dev Only callable by the governance.
     * @param _token The new USDC token address.
     */
    function setUSDC(address _token) external onlyGov {
        require(_token != address(0));
        usdc = IERC20(_token);
        emit AddressUpdated("usdc", _token);
    }

    /**
     * @notice Requests the governance address.
     * @dev Only callable by the current governance.
     * @param _gov The new governance address.
     */
    function requestGov(address _gov) external onlyGov {
        require(_gov != address(0));
        requestedGov = _gov;
    }

    /**
     * @notice Updates the governance address.
     * @dev Only callable by the current governance.
     * @param _gov The new governance address.
     */
    function setGov(address _gov) external onlyGov {
        require(_gov != address(0));
        require(_gov == requestedGov);
        gov = _gov;
        emit AddressUpdated("gov", _gov);
    }

    /**
     * @notice Updates the wallet recieveing developer share of fees
     * @dev Only callable by the current governance.
     * @param _dev The new developer address.
     */
    function setDev(address _dev) external onlyGov {
        require(_dev != address(0));
        dev = _dev;
        emit AddressUpdated("dev", _dev);
    }

    /**
     * @notice Updates the wallet recieveing gov share of fees
     * @dev Only callable by the current governance.
     * @param _govTreasury The new developer address.
     */
    function setGovTreasury(address _govTreasury) external onlyGov {
        require(_govTreasury != address(0));
        govTreasury = _govTreasury;
        emit AddressUpdated("govTreasury", _govTreasury);
    }

    /** 
     * @notice Adds a new trading contract to the list of approved trading contracts.
     * @dev Can only be called by the governor.
     * @param __trading The address of the trading contract to be added.
     */
    function addTradingContract(address __trading) external onlyGov {
        require(__trading != address(0));
        isTradingContract[__trading] = true;
        emit TradingContractAdded(__trading);
    }

    /** 
     * @notice Removes a trading contract from the list of approved trading contracts.
     * @dev Can only be called by the governor.
     * @param __trading The address of the trading contract to be removed.
     */
    function removeTradingContract(address __trading) external onlyGov {
        require(__trading != address(0));
        isTradingContract[__trading] = false;
        emit TradingContractRemoved(__trading);
    }

    /** 
     * @notice Sets the price aggregator contract.
     * @dev Can only be called by the governor.
     * @param _aggregator The address of the new price aggregator.
     */
    function setPriceAggregator(address _aggregator) external onlyGov {
        require(_aggregator != address(0));
        priceAggregator = IPriceAggregator(_aggregator);
        emit AddressUpdated("priceAggregator", _aggregator);
    }

    /** 
     * @notice Sets the vault manager contract.
     * @dev Can only be called by the governor.
     * @param _vaultManager The address of the new vault manager.
     */
    function setVaultManager(address _vaultManager) external onlyGov {
        require(_vaultManager != address(0));
        vaultManager = IVaultManager(_vaultManager);
        emit AddressUpdated("vaultManager", _vaultManager);
    }

    /** 
     * @notice Sets the referral contract.
     * @dev Can only be called by the governor.
     * @param _refferal The address of the new referral contract.
     */
    function setReferral(address _refferal) external onlyGov {
        require(_refferal != address(0));
        referral = IReferral(_refferal);
        emit AddressUpdated("Referral", _refferal);
    }

    /** 
     * @notice Sets the trading contract.
     * @dev Can only be called by the governor.
     * @param __trading The address of the new trading contract.
     */
    function setTrading(address __trading) external onlyGov {
        require(__trading != address(0));
        _trading = IPausable(__trading);
        emit AddressUpdated("trading", __trading);
    }

    /** 
     * @notice Sets the callbacks contract.
     * @dev Can only be called by the governor.
     * @param __callbacks The address of the new callbacks contract.
     */
    function setCallbacks(address __callbacks) external onlyGov {
        require(__callbacks != address(0));
        _callbacks = ICallbacks(__callbacks);
        emit AddressUpdated("callbacks", __callbacks);
    }

    /** 
     * @notice Sets the maximum number of trades allowed per trading pair.
     * @dev Can only be called by the governor.
     * @param _maxTradesPerPair The new maximum number of trades per pair.
     */
    function setMaxTradesPerPair(uint _maxTradesPerPair) external onlyGov {
        require(_maxTradesPerPair > 0);
        maxTradesPerPair = _maxTradesPerPair;
        emit NumberUpdated("maxTradesPerPair", _maxTradesPerPair);
    }

    /** 
     * @notice Sets the maximum number of pending market orders.
     * @dev Can only be called by the governor.
     * @param _maxPendingMarketOrders The new maximum number of pending market orders.
     */
    function setMaxPendingMarketOrders(uint _maxPendingMarketOrders) external onlyGov {
        require(_maxPendingMarketOrders > 0);
        maxPendingMarketOrders = _maxPendingMarketOrders;
        emit NumberUpdated("maxPendingMarketOrders", _maxPendingMarketOrders);
    }

    /** 
     * @notice Sets the TVL cap that be borrowed from LP tranches
     * @dev Can only be called by the governor.
     * @param _newCap The new TVl cal
     */
    function setTvlCap(uint _newCap) external onlyGov {
        // Can set max open interest to 0 to pause _trading on this pair only
        tvlCap = _newCap;
        emit NumberUpdated("tvlCap", _newCap);
    }

    /** 
     * @notice Stores a new trade and updates the associated trade information.
     * @dev Can only be called by trading contract.
     * @param _trade The details of the trade to store.
     * @param _tradeInfo Trade Info struct
     */
    function storeTrade(Trade memory _trade, TradeInfo memory _tradeInfo) external override onlyTrading {
        _trade.index = firstEmptyTradeIndex(_trade.trader, _trade.pairIndex);
        _openTrades[_trade.trader][_trade.pairIndex][_trade.index] = _trade;

        _openTradesCount[_trade.trader][_trade.pairIndex]++;

        if (_openTradesCount[_trade.trader][_trade.pairIndex] == 1) {
            pairTradersId[_trade.trader][_trade.pairIndex] = pairTraders[_trade.pairIndex].length;
            pairTraders[_trade.pairIndex].push(_trade.trader);
        }

        _tradeInfo.beingMarketClosed = false;
        _openTradesInfo[_trade.trader][_trade.pairIndex][_trade.index] = _tradeInfo;

        _updateOpenInterestUSDC(_trade.trader, _trade.pairIndex, _tradeInfo.openInterestUSDC, true, _trade.buy, _trade.openPrice);
    }

    /** 
     * @notice Registers a partial trade and updates trade information accordingly.
     * @dev Can only be called by trading contract.
     * @param trader Address of the trader.
     * @param pairIndex Index of the trading pair.
     * @param index Index of the trade.
     * @param _amountReduced The amount by which the trade is reduced.
     */
    function registerPartialTrade(
        address trader,
        uint pairIndex,
        uint index,
        uint _amountReduced
    ) external override onlyTrading {
        Trade storage t = _openTrades[trader][pairIndex][index];
        TradeInfo storage i = _openTradesInfo[trader][pairIndex][index];
        if (t.leverage == 0) {
            return;
        }
        t.initialPosToken -= _amountReduced;
        i.openInterestUSDC -= _amountReduced.mul(t.leverage);
        _updateOpenInterestUSDC(trader, pairIndex, _amountReduced.mul(t.leverage), false, t.buy, t.openPrice);
    }

    /** 
     * @notice Unregisters a trade and deletes trade information accordingly.
     * @dev Can only be called by trading contract.
     * @param trader Address of the trader.
     * @param pairIndex Index of the trading pair.
     * @param index Index of the trade.
     */
    function unregisterTrade(address trader, uint pairIndex, uint index) external override onlyTrading {
        Trade storage t = _openTrades[trader][pairIndex][index];
        TradeInfo storage i = _openTradesInfo[trader][pairIndex][index];
        if (t.leverage == 0) {
            return;
        }
        _updateOpenInterestUSDC(trader, pairIndex, i.openInterestUSDC, false, t.buy, t.openPrice);

        if (_openTradesCount[trader][pairIndex] == 1) {
            uint _pairTradersId = pairTradersId[trader][pairIndex];
            address[] storage p = pairTraders[pairIndex];

            p[_pairTradersId] = p[p.length - 1];
            pairTradersId[p[_pairTradersId]][pairIndex] = _pairTradersId;

            delete pairTradersId[trader][pairIndex];
            p.pop();
        }

        delete _openTrades[trader][pairIndex][index];
        delete _openTradesInfo[trader][pairIndex][index];

        _openTradesCount[trader][pairIndex]--;
    }

    /** 
     * @notice Stores a new pending market order and updates associated counters.
     * @dev Can only be called by trading contract.
     * @param _order Details of the pending market order.
     * @param _id The ID associated with the pending market order.
     * @param _open Specifies whether the order opens a new position.
     */
    function storePendingMarketOrder(
        PendingMarketOrder memory _order,
        uint _id,
        bool _open
    ) external override onlyTrading {
        pendingOrderIds[_order.trade.trader].push(_id);

        _reqIDpendingMarketOrder[_id] = _order;
        _reqIDpendingMarketOrder[_id].block = block.number;

        if (_open) {
            pendingMarketOpenCount[_order.trade.trader][_order.trade.pairIndex]++;
        } else {
            pendingMarketCloseCount[_order.trade.trader][_order.trade.pairIndex]++;
            _openTradesInfo[_order.trade.trader][_order.trade.pairIndex][_order.trade.index].beingMarketClosed = true;
        }
    }

    /** 
     * @notice Unregisters a pending market order and updates counters.
     * @param _id The ID associated with the pending market order.
     * @param _open Specifies whether the order opens or closes a position.
     */
    function unregisterPendingMarketOrder(uint _id, bool _open) external override onlyTrading {
        PendingMarketOrder memory _order = _reqIDpendingMarketOrder[_id];
        uint[] storage orderIds = pendingOrderIds[_order.trade.trader];

        for (uint i = 0; i < orderIds.length;) {
            if (orderIds[i] == _id) {
                if (_open) {
                    pendingMarketOpenCount[_order.trade.trader][_order.trade.pairIndex]--;
                } else {
                    pendingMarketCloseCount[_order.trade.trader][_order.trade.pairIndex]--;
                    _openTradesInfo[_order.trade.trader][_order.trade.pairIndex][_order.trade.index]
                        .beingMarketClosed = false;
                }

                orderIds[i] = orderIds[orderIds.length - 1];
                orderIds.pop();

                delete _reqIDpendingMarketOrder[_id];
                return;
            }
            unchecked { i++; }
        }
    }
    /**
     * @notice This is used as last resort in case a trader's collateral get stuck in storage
     */
    function forceUnregisterPendingMarketOrder(uint _id) external override onlyTrading{

        IPriceAggregator.OrderType orderType = priceAggregator.getOrder(_id).orderType;

        PendingMarketOrder memory _order = _reqIDpendingMarketOrder[_id];
        uint[] storage orderIds = pendingOrderIds[_order.trade.trader];

        for (uint i = 0; i < orderIds.length; i++) {
            if (orderIds[i] == _id) {
                if (orderType == IPriceAggregator.OrderType.MARKET_OPEN) {
                    pendingMarketOpenCount[_order.trade.trader][_order.trade.pairIndex]--;
                } else {
                    pendingMarketCloseCount[_order.trade.trader][_order.trade.pairIndex]--;
                    _openTradesInfo[_order.trade.trader][_order.trade.pairIndex][_order.trade.index]
                        .beingMarketClosed = false;
                }

                orderIds[i] = orderIds[orderIds.length - 1];
                orderIds.pop();

                delete _reqIDpendingMarketOrder[_id];
            }
        }
        // Send back collateral but not execution Fee as execution was probably tried
        IERC20(usdc).safeTransfer(_order.trade.trader, _order.trade.positionSizeUSDC);
        emit MarketOpenCanceled(_id, _order.trade.trader, _order.trade.pairIndex);
    }

    /** 
     * @notice Stores a new pending limit order.
     * @param _limitOrder Details of the pending limit order.
     * @param _orderId The ID for the pending limit order.
     */
    function storePendingLimitOrder(PendingLimitOrder memory _limitOrder, uint _orderId) external override onlyTrading {
        _reqIDpendingLimitOrder[_orderId] = _limitOrder;
    }

    /** 
     * @notice Unregisters a pending limit order.
     * @param _order The ID for the pending limit order to unregister.
     */
    function unregisterPendingLimitOrder(uint _order) external override onlyTrading {
        delete _reqIDpendingLimitOrder[_order];
    }

    /** 
     * @notice Stores an open limit order.
     * @param o Details of the open limit order.
     */
    function storeOpenLimitOrder(OpenLimitOrder memory o) external override onlyTrading {
        o.index = firstEmptyOpenLimitIndex(o.trader, o.pairIndex);
        o.block = block.number;
        openLimitOrders.push(o);
        openLimitOrderIds[o.trader][o.pairIndex][o.index] = openLimitOrders.length - 1;
        openLimitOrdersCount[o.trader][o.pairIndex]++;
    }

    /** 
     * @notice Updates an existing open limit order.
     * @param _o Details of the updated open limit order.
     */
    function updateOpenLimitOrder(OpenLimitOrder calldata _o) external override onlyTrading {
        if (!hasOpenLimitOrder(_o.trader, _o.pairIndex, _o.index)) {
            return;
        }
        OpenLimitOrder storage o = openLimitOrders[openLimitOrderIds[_o.trader][_o.pairIndex][_o.index]];
        o.positionSize = _o.positionSize;
        o.buy = _o.buy;
        o.leverage = _o.leverage;
        o.tp = _o.tp;
        o.sl = _o.sl;
        o.price = _o.price;
        o.block = block.number;
    }

    /** 
     * @notice Unregisters an open limit order.
     * @param _trader Address of the trader.
     * @param _pairIndex Index of the trading pair.
     * @param _index Index of the limit order.
     */
    function unregisterOpenLimitOrder(address _trader, uint _pairIndex, uint _index) external override onlyTrading {
        if (!hasOpenLimitOrder(_trader, _pairIndex, _index)) {
            return;
        }

        // Copy last order to deleted order => update id of this limit order
        uint id = openLimitOrderIds[_trader][_pairIndex][_index];
        openLimitOrders[id] = openLimitOrders[openLimitOrders.length - 1];
        openLimitOrderIds[openLimitOrders[id].trader][openLimitOrders[id].pairIndex][openLimitOrders[id].index] = id;

        delete openLimitOrderIds[_trader][_pairIndex][_index];
        openLimitOrders.pop();

        openLimitOrdersCount[_trader][_pairIndex]--;
    }

    /** 
     * @notice Updates the stop loss level for a trade.
     * @param _trader Address of the trader.
     * @param _pairIndex Index of the trading pair.
     * @param _index Index of the trade.
     * @param _newSl The new stop loss level.
     */
    function updateSl(address _trader, uint _pairIndex, uint _index, uint _newSl) external override onlyTrading {
        Trade storage t = _openTrades[_trader][_pairIndex][_index];
        TradeInfo storage i = _openTradesInfo[_trader][_pairIndex][_index];
        if (t.leverage == 0) {
            return;
        }
        _newSl =  _callbacks.correctSl(t.openPrice, t.leverage, _newSl, t.buy);
        t.sl = _newSl;
        i.slLastUpdated = block.number;
    }

    /** 
     * @notice Updates the take profit level for a trade.
     * @param _trader Address of the trader.
     * @param _pairIndex Index of the trading pair.
     * @param _index Index of the trade.
     * @param _newTp The new take profit level.
     */
    function updateTp(address _trader, uint _pairIndex, uint _index, uint _newTp) external override onlyTrading {
        Trade storage t = _openTrades[_trader][_pairIndex][_index];
        TradeInfo storage i = _openTradesInfo[_trader][_pairIndex][_index];
        if (t.leverage == 0) {
            return;
        }
        _newTp = _callbacks.correctTp(t.openPrice, t.leverage, _newTp, t.buy);
        t.tp = _newTp;
        i.tpLastUpdated = block.number;
    }

    /** 
     * @notice Updates the details of an existing trade.
     * @param _t The updated trade details.
     */
    function updateTrade(Trade memory _t) external override onlyTrading {
        // useful when partial adding/closing
        Trade storage t = _openTrades[_t.trader][_t.pairIndex][_t.index];
        if (t.leverage == 0) {
            return;
        }
        t.initialPosToken = _t.initialPosToken;
        t.positionSizeUSDC = _t.positionSizeUSDC;
        t.openPrice = _t.openPrice;
        t.leverage = _t.leverage;
    }

    /**
     * @notice Applies the referral program during the opening of a trade.
     * @param _trader Address of the trader.
     * @param _fees The initial fees for the trade.
     * @param _leveragedPosition The size of the leveraged position.
     * @return The updated fee after applying the referral program.
     */
    function applyReferral(
        address _trader,
        uint _fees,
        uint _leveragedPosition
    ) public override onlyTrading returns (uint, uint) {
        (uint traderFeePostDiscount, address referrer, uint referrerRebate) = referral.traderReferralDiscount(_trader, _fees);

        if (referrer != address(0)) {
            rebates[referrer] += referrerRebate;
            emit TradeReferred(
                _trader, 
                referrer, 
                _leveragedPosition, 
                traderFeePostDiscount, 
                _fees - traderFeePostDiscount,
                referrerRebate
            );
            return (traderFeePostDiscount - referrerRebate, referrerRebate);
        }
        return (_fees, referrerRebate);
    }

    /**
     * @notice Handles the calculation and distribution of development and governance fees.
     * @param _trader Address of the trader.
     * @param _pairIndex Index of the trading pair.
     * @param _leveragedPositionSize Size of the leveraged position.
     * @param _usdc Whether the fee is in USDC.
     * @param _fullFee Indicates if the full fee should be applied.
     * @param _buy Indicates if it's a buy operation.
     * @return feeAfterRebate The fee amount after applying any rebates.
     */
    function handleDevGovFees(
        address _trader,
        uint _pairIndex,
        uint _leveragedPositionSize,
        bool _usdc,
        bool _fullFee,
        bool _buy
    ) external override onlyTrading returns (uint feeAfterRebate) {
        uint fee = (_leveragedPositionSize * priceAggregator.openFeeP(_pairIndex, _leveragedPositionSize, _buy)) /
            _PRECISION /
            100;

        if (!_fullFee) {
            fee /= 2;
        }

        (feeAfterRebate,) = applyReferral(_trader, fee, _leveragedPositionSize);

        uint vaultAllocation = (feeAfterRebate * (100 - _callbacks.vaultFeeP())) / 100;
        uint govFees = (feeAfterRebate * _callbacks.vaultFeeP()) / 100 >> 1;

        if (_usdc) IERC20(usdc).safeTransfer(address(vaultManager), vaultAllocation);

        vaultManager.allocateRewards(vaultAllocation, false);
        govFeesUSDC += govFees;
        devFeesUSDC += feeAfterRebate - vaultAllocation - govFees;

        emit FeesCharged(_trader, _pairIndex, _buy, feeAfterRebate);
    }

    /**
     * @notice Allows the governance to claim the accumulated governance fees.
     */
    function claimFees() external onlyGov {
        IERC20(usdc).safeTransfer(govTreasury, govFeesUSDC);
        IERC20(usdc).safeTransfer(dev, devFeesUSDC);

        devFeesUSDC = 0;
        govFeesUSDC = 0;
    }

    /**
     * @notice Allows a referrer to claim their rebate.
     */
    function claimRebate() external {
        IERC20(usdc).safeTransfer(msg.sender, rebates[msg.sender]);
        rebates[msg.sender] = 0;
    }

    /**
     * @notice Transfers USDC tokens between addresses. USDC intermediately sits in trading storage 
     * before moving to vault
     * @param _from Address from which to transfer.
     * @param _to Address to which to transfer.
     * @param _amount Amount to transfer.
     */
    function transferUSDC(address _from, address _to, uint _amount) external override onlyTrading {
        if (_from == address(this)) {
            IERC20(usdc).safeTransfer(_to, _amount);
        } else {
            IERC20(usdc).safeTransferFrom(_from, _to, _amount);
        }
    }

    /**
     * @notice Calculates the maximum open interest based on tvl cap
     * @return The maximum open interest.
     */
    function maxOpenInterest() external view override returns (uint) {
        return (vaultManager.currentBalanceUSDC() * tvlCap) / _PRECISION / 100;
    }

    /**
     * @notice Retrieves an open trade for a specific trader and pair index.
     * @param _trader Address of the trader.
     * @param _pairIndex Index of the trading pair.
     * @param _index Index of the trade.
     * @return Trade struct containing the trade's details.
     */
    function openTrades(address _trader, uint _pairIndex, uint _index) external view override returns (Trade memory) {
        return _openTrades[_trader][_pairIndex][_index];
    }

    /**
     * @notice Retrieves open trade info 
     * @param _trader Address of the trader.
     * @param _pairIndex Index of the trading pair.
     * @param _index Index of the trade.
     * @return TradeInfo struct
     */
    function openTradesInfo(
        address _trader,
        uint _pairIndex,
        uint _index
    ) external view override returns (TradeInfo memory) {
        return _openTradesInfo[_trader][_pairIndex][_index];
    }

    /**
     * @notice Retrieves pending market order details by order ID.
     * @param orderId The ID of the pending market order.
     * @return PendingMarketOrder struct containing the order's details.
     */
    function reqIDpendingMarketOrder(uint orderId) external view override returns (PendingMarketOrder memory) {
        return _reqIDpendingMarketOrder[orderId];
    }

    /**
     * @notice Retrieves pending limit order details by order ID.
     * @param orderId The ID of the pending limit order.
     * @return PendingLimitOrder struct containing the order's details.
     */
    function reqIDpendingLimitOrder(uint orderId) external view override returns (PendingLimitOrder memory) {
        return _reqIDpendingLimitOrder[orderId];
    }

    /**
     * @notice Retrieves the count of open trades for a specific trader and pair index.
     * @param _trader Address of the trader.
     * @param _pairIndex Index of the trading pair.
     * @return The count of open trades.
     */
    function openTradesCount(address _trader, uint _pairIndex) external view override returns (uint) {
        return _openTradesCount[_trader][_pairIndex];
    }

    /**
     * @notice Gets the address of the contract that implements callbacks.
     * @return The address of the callbacks contract.
     */
    function callbacks() external view override returns (address) {
        return address(_callbacks);
    }

    /**
     * @notice Gets the address of the contract that manages user facingtrading.
     * @return The address of the trading contract.
     */
    function trading() external view override returns (address) {
        return address(_trading);
    }

/**
     * @notice Retrieves the array of traders for a specific pair index.
     * @param _pairIndex Index of the trading pair.
     * @return An array of trader addresses.
     */
    function pairTradersArray(uint _pairIndex) external view returns (address[] memory) {
        return pairTraders[_pairIndex];
    }

    /**
     * @notice Retrieves the IDs of pending orders for a specific trader.
     * @param _trader Address of the trader.
     * @return An array of pending order IDs.
     */
    function getPendingOrderIds(address _trader) external view override returns (uint[] memory) {
        return pendingOrderIds[_trader];
    }

    /**
     * @notice Retrieves usd OI
     * @return USD OI
     */
    function getUsdOI() external view override returns (uint[2] memory) {
        return usdOI;
    }

    /**
     * @notice Retrieves the count of pending order IDs for a specific trader.
     * @param _trader Address of the trader.
     * @return The count of pending orders.
     */
    function pendingOrderIdsCount(address _trader) external view override returns (uint) {
        return pendingOrderIds[_trader].length;
    }

    /**
     * @notice Retrieves the total open interest for a specific pair index.
     * @param _pairIndex Index of the trading pair.
     * @return The total open interest.
     */
    function pairOI(uint _pairIndex) external view override returns (uint) {
        return openInterestUSDC[_pairIndex][0] + openInterestUSDC[_pairIndex][1];
    }

    /**
     * @notice Retrieves the total open interest for a specific trader's wallet.
     * @param _trader Address of the trader.
     * @return The total open interest in the trader's wallet.
     */
    function walletOI(address _trader) external view override returns (uint) {
        return _walletOI[_trader];
    }

    /**
     * @notice Retrieves a specific open limit order for a trader and pair index.
     * @param _trader The address of the trader.
     * @param _pairIndex The index of the trading pair.
     * @param _index The index of the limit order.
     * @return OpenLimitOrder struct containing the order details.
     */
    function getOpenLimitOrder(
        address _trader,
        uint _pairIndex,
        uint _index
    ) external view override returns (OpenLimitOrder memory) {
        require(hasOpenLimitOrder(_trader, _pairIndex, _index));
        return openLimitOrders[openLimitOrderIds[_trader][_pairIndex][_index]];
    }

    /**
     * @notice Retrieves all open limit orders.
     * @return An array of OpenLimitOrder structs containing all open limit orders.
     */
    function getOpenLimitOrders() external view returns (OpenLimitOrder[] memory) {
        return openLimitOrders;
    }

    /**
     * @notice Finds the first empty trade index for a trader and pair index.
     * @param trader The address of the trader.
     * @param pairIndex The index of the trading pair.
     * @return index The index of the first empty trade.
     */
    function firstEmptyTradeIndex(address trader, uint pairIndex) public view override returns (uint index) {
        for (uint i = 0; i < maxTradesPerPair;) {
            if (_openTrades[trader][pairIndex][i].leverage == 0) {
                index = i;
                break;
            }
            if (((i + 1) == maxTradesPerPair) && index == 0) {
                revert("MAX_TRADES_REACHED");
            }
            unchecked { i++; }
        }
    }

    /**
     * @notice Finds the first empty open limit order index for a trader and pair index.
     * @param trader The address of the trader.
     * @param pairIndex The index of the trading pair.
     * @return index The index of the first empty open limit order.
     */
    function firstEmptyOpenLimitIndex(address trader, uint pairIndex) public view override returns (uint index) {
        for (uint i = 0; i < maxTradesPerPair;) {
            if (!hasOpenLimitOrder(trader, pairIndex, i)) {
                index = i;
                break;
            }
            if (((i + 1) == maxTradesPerPair) && index == 0) {
                revert("MAX_LIMITS_REACHED");
            }
            unchecked { i++; }
        }
    }

    /**
     * @notice Checks if a trader has an open limit order at a specific index and pair index.
     * @param trader The address of the trader.
     * @param pairIndex The index of the trading pair.
     * @param index The index of the limit order.
     * @return True if an open limit order exists, false otherwise.
     */
    function hasOpenLimitOrder(address trader, uint pairIndex, uint index) public view override returns (bool) {
        if (openLimitOrders.length == 0) {
            return false;
        }
        OpenLimitOrder storage o = openLimitOrders[openLimitOrderIds[trader][pairIndex][index]];
        return o.trader == trader && o.pairIndex == pairIndex && o.index == index;
    }

    /**
     * @notice Keeps track of OI for protocol and trader
     * @param _trader The address of the trader.
     * @param _pairIndex The index of the trading pair.
     * @param _leveragedPosUSDC The leveraged position size in USDC.
     * @param _open True if the position is being opened, false if it's being closed.
     * @param _long True if the position is long, false if it's short.
     */
    function _updateOpenInterestUSDC(
        address _trader,
        uint _pairIndex,
        uint _leveragedPosUSDC,
        bool _open,
        bool _long,
        uint _price
    ) private {
        uint index = _long ? 0 : 1;
        uint[2] storage o = openInterestUSDC[_pairIndex];

        // Fix beacuse of Dust during partial close
        if (!_open) _leveragedPosUSDC = _leveragedPosUSDC > o[index] ? o[index] : _leveragedPosUSDC;

        o[index] = _open ? o[index] + _leveragedPosUSDC : o[index] - _leveragedPosUSDC;
        totalOI = _open ? totalOI + _leveragedPosUSDC : totalOI - _leveragedPosUSDC;
        _walletOI[_trader] = _open ? _walletOI[_trader] + _leveragedPosUSDC : _walletOI[_trader] - _leveragedPosUSDC;
        blockOI[_pairIndex][block.number] = blockOI[_pairIndex][block.number] + _leveragedPosUSDC;

        IPairStorage pairsStored = priceAggregator.pairsStorage();
        require(blockOI[_pairIndex][block.number] <= pairsStored.blockOILimit(_pairIndex), "BLOCK_OI_LIMIT_BREACHED");

        if(pairsStored.pairGroupIndex(_pairIndex) == 2) {
            bool isUSDCAligned = pairsStored.isUSDCAligned(_pairIndex);
            uint inverseIndex = _long ? 1 : 0;
            if(isUSDCAligned) {
                usdOI[index] = _open ? usdOI[index] + _leveragedPosUSDC : usdOI[index] - _leveragedPosUSDC;
            } else {
                usdOI[inverseIndex] =  _open ? usdOI[inverseIndex] + _leveragedPosUSDC : usdOI[inverseIndex] - _leveragedPosUSDC;
            }
        } 
        
        emit OIUpdated(_open, _long, _pairIndex, _leveragedPosUSDC, _price);
    }
}
