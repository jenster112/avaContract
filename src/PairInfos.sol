// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./interfaces/ITradingStorage.sol";
import "./interfaces/IPairStorage.sol";
import "./interfaces/IPairInfos.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PositionMath} from "./library/PositionMath.sol";
import {ABDKMathQuadExt} from "./library/abdkQuadMathExt.sol";

contract PairInfos is Initializable, IPairInfos {
    using PositionMath for uint;

    // LIQ_THRESHOLD and other var should gov set
    uint private constant _PRECISION = 1e10;

    ITradingStorage public storageT;
    IPairStorage public pairsStorage;

    address public manager;
    address public keeper;
    uint public liqThreshold; 

    mapping(uint => PairParams) public pairParams;
    mapping(uint => PairRolloverFees) public pairRolloverFees;
    mapping(address => mapping(uint => mapping(uint => TradeInitialAccFees))) public tradeInitialAccFees;

    mapping(uint => uint) public lossProtectionNumTiers;
    mapping(uint => uint[]) public longSkewConfig;
    mapping(uint => uint[]) public shortSkewConfig;


    modifier onlyGov() {
        require(msg.sender == storageT.gov(), "GOV_ONLY");
        _;
    }
    modifier onlyManager() {
        require(msg.sender == manager, "MANAGER_ONLY");
        _;
    }
    modifier onlyCallbacks() {
        require(msg.sender == storageT.callbacks(), "CALLBACKS_ONLY");
        _;
    }

    modifier onlyKeeper(){
        require(msg.sender == address(keeper), "KEEPER_ONLY");
        _;
    }
    
    constructor() {
        _disableInitializers();
    }
    /**
     * @dev Initialize the PairInfos Proxy.
     * @param _storageT Address of the ITradingStorage contract.
     * @param _pairsStorage Address of the IPairStorage contract.
     */
    function initialize(address _storageT, address _pairsStorage) external initializer {
        storageT = ITradingStorage(_storageT);
        pairsStorage = IPairStorage(_pairsStorage);
        liqThreshold =  85;
    }

    /**
     * @dev Set the manager address.
     * @param _manager Address of the new manager.
     */
    function setManager(address _manager) external onlyGov {
        require(_manager != address(0), "ZERO_ADDR");
        
        manager = _manager;
        emit ManagerUpdated(_manager);
    }


    /**
     * @dev Set the Keeper address.
     * @param _keeper Address of the new Keeper.
     */
    function setKeeper(address _keeper) external onlyGov{
        require(_keeper != address(0), "ZERO_ADDR");

        keeper = _keeper;
        emit KeeperUpdated(_keeper);
    }

    /**
     * @dev Set the new Liq Threshold.
     * @param _newThreshold New Liq Threshold
     */
    function udpateLiquidationThreshold(uint _newThreshold) external onlyGov {
        
        liqThreshold = _newThreshold;
        emit LiqThresholdUpdated(_newThreshold);
    }


    /**
     * @dev Set parameters for a trading pair.
     * @param pairIndex Index of the trading pair.
     * @param value Parameters to set.
     */
    function setPairParams(uint pairIndex, PairParams calldata value) external onlyManager {
        _setPairParams(pairIndex, value);
    }

    /**
     * @dev Set parameters for a trading pairs.
     * @param indices Index array of the trading pair.
     * @param values Parameters Array to set.
     */
    function setPairParamsArray(uint[] calldata indices, PairParams[] calldata values) external onlyManager {
        require(indices.length == values.length, "WRONG_LENGTH");

        for (uint i; i < indices.length;) {
            _setPairParams(indices[i], values[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets the one percent depth values for a trading pair
     * @param pairIndex The index of the trading pair
     * @param valueAbove The value above the one percent depth
     * @param valueBelow The value below the one percent depth
     */
    function setOnePercentDepth(uint pairIndex, uint valueAbove, uint valueBelow) external onlyKeeper {
        _setOnePercentDepth(pairIndex, valueAbove, valueBelow);
    }

    /**
     * @dev Set loss protection configuration for a pair index.
     * @param _pairIndex The pair index to configure.
     * @param _longSkewConfig Configuration for long skew.
     * @param _shortSkewConfig Configuration for short skew.
     */
    function setLossProtectionConfig(
        uint _pairIndex,
        uint[] calldata _longSkewConfig,
        uint[] calldata _shortSkewConfig
    ) external onlyManager {
        require(_longSkewConfig.length == _shortSkewConfig.length);

        lossProtectionNumTiers[_pairIndex] = _longSkewConfig.length;
        longSkewConfig[_pairIndex] = _longSkewConfig;
        shortSkewConfig[_pairIndex] = _shortSkewConfig;

        emit LossProtectionConfigSet(lossProtectionNumTiers[_pairIndex], _longSkewConfig, _shortSkewConfig);
    }
    /**
     * @notice Sets the one percent depth values for a trading pairs
     * @param indices The index array of the trading pair
     * @param valuesAbove The value array above the one percent depth
     * @param valuesBelow The value array below the one percent depth
     */
    function setOnePercentDepthArray(
        uint[] calldata indices,
        uint[] calldata valuesAbove,
        uint[] calldata valuesBelow
    ) external onlyManager {
        require(indices.length == valuesAbove.length && indices.length == valuesBelow.length, "WRONG_LENGTH");

        for (uint i; i < indices.length;) {
            _setOnePercentDepth(indices[i], valuesAbove[i], valuesBelow[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Set rollover fee per block for a trading pair.
     * @param pairIndex Index of the trading pair.
     * @param value Fee value to set.
     */
    function setRolloverFeePerBlockP(uint pairIndex, uint value) external onlyManager {
        require(value <= 25e6, "TOO_HIGH"); // ≈ 100% per day, 43200 blocks per day, 1800 per hour, 0.01% per hour is

        _storeAccRolloverFees(pairIndex);

        pairParams[pairIndex].rolloverFeePerBlockP = value;

        emit RolloverFeePerBlockPUpdated(pairIndex, value);
    }

    /**
     * @dev Get trade value, PnL, and fees.
     * @param _trade Details of the trade.
     * @param collateral Amount of collateral.
     * @param percentProfit Profit percentage.
     * @param closingFee Closing fee.
     * @param _tier Loss protection tier.
     */
    function getTradeValue(
        ITradingStorage.Trade memory _trade,
        uint collateral,
        int percentProfit,
        uint closingFee,
        uint _tier
    ) external override onlyCallbacks returns (uint amount, int pnl, uint fees) {
        _storeAccRolloverFees(_trade.pairIndex);

        uint r = getTradeRolloverFee(
            _trade.trader,
            _trade.pairIndex,
            _trade.index,
            _trade.buy,
            collateral,
            _trade.leverage
        );
        uint lossProtection = pairsStorage.lossProtectionMultiplier(_trade.pairIndex, _tier);
        (amount, pnl, fees) = getTradeValuePure(
            collateral,
            percentProfit,
            r,
            closingFee,
            lossProtection
        );
        
        emit FeesCharged(
            _trade.buy,
            collateral, 
            _trade.leverage, 
            percentProfit, 
            r, 
            closingFee,
            lossProtection
        );
    }

    /**
     * @dev Called while registering trade. Stores margin fee accumulator at start of a trade
     * @param trader Address of the trader.
     * @param pairIndex Index of the trading pair.
     * @param index Index of the trade.
     * @param long Whether the trade is long or not.
     */
    function storeTradeInitialAccFees(
        address trader,
        uint pairIndex,
        uint index,
        bool long
    ) external override onlyCallbacks {
        _storeAccRolloverFees(pairIndex);

        TradeInitialAccFees storage t = tradeInitialAccFees[trader][pairIndex][index];

        t.rollover = long ? pairRolloverFees[pairIndex].accPerOiLong : pairRolloverFees[pairIndex].accPerOiShort;

        t.openedAfterUpdate = true;

        emit TradeInitialAccFeesStored(trader, pairIndex, index, t.rollover);
    }

    /**
     * @notice Calculate liquidation price after trade rollover.
     * @param trader Address of the trader.
     * @param pairIndex Index of the trading pair.
     * @param index Unique index for trade.
     * @param openPrice Opening price of the trade.
     * @param long True if it's a long position, false otherwise.
     * @param collateral Amount of collateral.
     * @param leverage Leverage used in the trade.
     * @return Calculated liquidation price.
     */
    function getTradeLiquidationPrice(
        address trader,
        uint pairIndex,
        uint index,
        uint openPrice,
        bool long,
        uint collateral,
        uint leverage
    ) external view override returns (uint) {
        return
            getTradeLiquidationPricePure(
                openPrice,
                long,
                collateral,
                leverage,
                getTradeRolloverFee(trader, pairIndex, index, long, collateral, leverage)
            );
    }

    /**
     * @notice Calculate price impact on trade opening. Only for Crypto Group
     * @param openPrice Opening price of the trade.
     * @param pairIndex Index of the trading pair.
     * @param long True if it's a long position, false otherwise.
     * @param tradeOpenInterest Open interest of the trade.
     * @return priceAfterImpact Price after taking impact into account.
     */
    function getTradePriceImpact(
        uint openPrice,
        uint pairIndex,
        bool long,
        uint tradeOpenInterest
    ) external view override returns (uint priceAfterImpact) {

        int priceImpactSpread = getPriceImpactSpread(pairIndex, long, tradeOpenInterest);
        int skewImpactSpread = getSkewImpactSpread(pairIndex, long, tradeOpenInterest);
        int dynamicSpread =  (int(pairsStorage.pairSpreadP(pairIndex)) + priceImpactSpread + skewImpactSpread);
       
        dynamicSpread = dynamicSpread < -int(_PRECISION / 10) ? -int(_PRECISION / 10) : dynamicSpread;
        int priceImpact = (dynamicSpread * int(openPrice)) / int(_PRECISION) / int(100);
        int pricePostImpact = long ? int(openPrice) + priceImpact : int(openPrice) - priceImpact;
        priceAfterImpact = uint(pricePostImpact);
    }

    function getPriceImpactSpread(uint256 _pairIndex, bool _isBuy, uint256 _leveragePosition) public view returns(int256 spread){

        uint b = pairsStorage.pairPriceImpactMultiplier(_pairIndex);

        uint onePercentDepth = _isBuy ? pairParams[_pairIndex].onePercentDepthAbove : pairParams[_pairIndex].onePercentDepthBelow;
        spread = ABDKMathQuadExt.expInt(b*_leveragePosition / _PRECISION,onePercentDepth, _PRECISION) - int(_PRECISION) ; 
    }

    function getSkewImpactSpread(uint _pairIndex, bool _isBuy, uint _leveragePosition) public view returns(int256 spread){

        int intPrecision =  int(_PRECISION);
        int skewParam = pairsStorage.pairSkewImpactMultiplier(_pairIndex);

        uint openInterestUSDCLong = storageT.openInterestUSDC(_pairIndex, 0);
        uint openInterestUSDCShort = storageT.openInterestUSDC(_pairIndex, 1);
        if(openInterestUSDCLong == 0) return 0;
        uint skewPct = _isBuy 
                        ? (1e4 * openInterestUSDCLong) / (openInterestUSDCLong + openInterestUSDCShort) 
                        : (1e4 * openInterestUSDCShort) / (openInterestUSDCLong + openInterestUSDCShort);
        uint skewPctAfter = _isBuy 
                        ? (1e4 * (openInterestUSDCLong  + _leveragePosition)) / (openInterestUSDCLong + openInterestUSDCShort + _leveragePosition) 
                        : (1e4 * (openInterestUSDCShort + _leveragePosition)) / (openInterestUSDCLong + openInterestUSDCShort + _leveragePosition);
        int rawSpread = (ABDKMathQuadExt.expInt(skewPctAfter, 1e4, _PRECISION) - ABDKMathQuadExt.expInt(skewPct,1e4, _PRECISION) + ABDKMathQuadExt.expInt((1e4 - skewPctAfter), 1e4, _PRECISION) - ABDKMathQuadExt.expInt((1e4 - skewPct), 1e4, _PRECISION));        spread = (skewParam*rawSpread)/intPrecision;
        spread = (skewParam*rawSpread)/intPrecision;

    }

   /** @notice Calculate and return the loss protection tier for a given trade based on current skew
     *  @param _trade The trade object containing details of the trade
     *  @return The index of the loss protection tier
     */
    function lossProtectionTier(ITradingStorage.Trade memory _trade) external view override returns (uint) {
        uint openInterestUSDCLong = storageT.openInterestUSDC(_trade.pairIndex, 0);
        uint openInterestUSDCShort = storageT.openInterestUSDC(_trade.pairIndex, 1);

        uint updatedInterest = _trade.initialPosToken.mul(_trade.leverage);

        if (_trade.buy) {
            openInterestUSDCLong += updatedInterest;
            uint openInterestUSDCShortPct = (100 * openInterestUSDCShort) /
                (openInterestUSDCLong + openInterestUSDCShort);

            for (uint i = shortSkewConfig[_trade.pairIndex].length; i > 0;) {
                if (openInterestUSDCShortPct >= shortSkewConfig[_trade.pairIndex][i - 1]) return i - 1;
                unchecked {
                    --i;
                }
            }
        } else {
            openInterestUSDCShort += updatedInterest;
            uint openInterestUSDCLongPct = (100 * openInterestUSDCLong) /
                (openInterestUSDCLong + openInterestUSDCShort);
            for (uint i = longSkewConfig[_trade.pairIndex].length; i > 0;) {
                if (openInterestUSDCLongPct >= longSkewConfig[_trade.pairIndex][i - 1]) return i - 1;
                unchecked {
                    --i;
                }
            }
        }
        return 0; // No Protection Tier
    }

    /** @notice Fetches and returns trading pair information for specified indices
     *  @param indices An array of indices for which to fetch the pair information
     *  @return PairParams[] and PairRolloverFees[] arrays containing trading pair parameters and rollover fees
     */
    function getPairInfos(
        uint[] calldata indices
    ) external view returns (PairParams[] memory, PairRolloverFees[] memory) {
        PairParams[] memory params = new PairParams[](indices.length);
        PairRolloverFees[] memory rolloverFees = new PairRolloverFees[](indices.length);

        for (uint i; i < indices.length;) {
            uint index = indices[i];

            params[i] = pairParams[index];
            rolloverFees[i] = pairRolloverFees[index];
            unchecked {
                ++i;
            }
        }

        return (params, rolloverFees);
    }

   /** @notice Get the one percent depth above the current price for the given pair index
     *  @param pairIndex The index of the trading pair
     *  @return The one percent depth above the current price
     */
    function getOnePercentDepthAbove(uint pairIndex) external view returns (uint) {
        return pairParams[pairIndex].onePercentDepthAbove;
    }

    /**
     * @notice Retrieves the one percent depth below the current price for a given pair index
     * @param pairIndex The index of the trading pair
     * @return The one percent depth below the current price
     */
    function getOnePercentDepthBelow(uint pairIndex) external view returns (uint) {
        return pairParams[pairIndex].onePercentDepthBelow;
    }

    /**
     * @notice Retrieves the rollover fee per block for a given pair index
     * @param pairIndex The index of the trading pair
     * @return The rollover fee per block
     */
    function getRolloverFeePerBlockP(uint pairIndex) external view returns (uint) {
        return pairParams[pairIndex].rolloverFeePerBlockP;
    }

    /**
     * @notice Retrieves the accumulated rollover fees for long positions for a given pair index
     * @param pairIndex The index of the trading pair
     * @return The accumulated rollover fees for long positions
     */
    function getAccRolloverFeesLong(uint pairIndex) external view returns (uint) {
        return pairRolloverFees[pairIndex].accPerOiLong;
    }

    /**
     * @notice Retrieves the accumulated rollover fees for short positions for a given pair index
     * @param pairIndex The index of the trading pair
     * @return The accumulated rollover fees for short positions
     */
    function getAccRolloverFeesShort(uint pairIndex) external view returns (uint) {
        return pairRolloverFees[pairIndex].accPerOiShort;
    }

    /**
     * @notice Retrieves the last block where the accumulated rollover fees were updated for a given pair index
     * @param pairIndex The index of the trading pair
     * @return The last block number where the accumulated rollover fees were updated
     */
    function getAccRolloverFeesUpdateBlock(uint pairIndex) external view returns (uint) {
        return pairRolloverFees[pairIndex].lastUpdateBlock;
    }

    /**
     * @notice Retrieves the starting rollover fee accumulator of a trade
     * @param trader Address of the trader
     * @param pairIndex The index of the trading pair
     * @param index The index of the trade
     * @return The initial accumulated rollover fees for the trade
     */
    function getTradeInitialAccRolloverFeesPerCollateral(
        address trader,
        uint pairIndex,
        uint index
    ) external view returns (uint) {
        return tradeInitialAccFees[trader][pairIndex][index].rollover;
    }

    /**
     * @notice Retrieves the blended utlization ratio
     * @param _pairIndex The index of the trading pair
     * @param _longOI Long Open Interest
     * @param _shortOI Short Open Interest
     * @return Utlization Ratio in 1e10 precision
     */
    function getBlendedUtilizationRatio(uint _pairIndex, uint _longOI, uint _shortOI) public view returns(uint256){
        
        uint groupUtilization = (pairsStorage.groupOI(_pairIndex) * _PRECISION) /
            (pairsStorage.groupMaxOI(_pairIndex));
        uint pairUtilization = ((_longOI + _shortOI) * _PRECISION) /
            (pairsStorage.pairMaxOI(_pairIndex));

        return (75*groupUtilization + 25*pairUtilization)/100 ;
    }
    /**
     * @notice Retrieves the blended skew ratio
     * @param _pairIndex The index of the trading pair
     * @return Utlization Ratio in 1e10 precision
     */
    function getBlendedSkew(uint _pairIndex, bool _long,  uint _longOI, uint _shortOI) public view returns(uint256){
        if(_longOI + _shortOI == 0) return 0;
        if(pairsStorage.pairGroupIndex(_pairIndex) == 2){ // FOREX
                uint[2] memory usdOI = storageT.getUsdOI();
                uint index = _long ? 0 : 1;
                uint indexOI = usdOI[pairsStorage.isUSDCAligned(_pairIndex) ? index : 1 - index];
                uint nonIndexOI = usdOI[pairsStorage.isUSDCAligned(_pairIndex) ? 1 - index : index];
                uint usdSkew = (100*indexOI)/(nonIndexOI +indexOI);
                uint assetSkew = _long ? (100*_longOI)/(_longOI +  _shortOI): (100*_shortOI)/(_longOI +  _shortOI);

                return (75*usdSkew + 25*assetSkew)/100;
        }
        else{
            uint assetSkew = _long ? (100*_longOI)/(_longOI +  _shortOI): (100*_shortOI)/(_longOI +  _shortOI);
            return assetSkew;
        }
    }

    /**
     * @notice Retrieves the pending accumulated rollover fees for a given trading pair
     * @param pairIndex The index of the trading pair
     * @return valueLong The pending accumulated rollover fees for long positions
     * @return valueShort The pending accumulated rollover fees for short positions
     */
    function getPendingAccRolloverFees(uint pairIndex) public view returns (uint valueLong, uint valueShort) {
        PairRolloverFees storage f = pairRolloverFees[pairIndex];
        uint256 blendedUtilizationRatio;
        
        valueLong = f.accPerOiLong;
        valueShort = f.accPerOiShort;

        uint openInterestUSDCLong = storageT.openInterestUSDC(pairIndex, 0);
        uint openInterestUSDCShort = storageT.openInterestUSDC(pairIndex, 1);

        if (openInterestUSDCLong > 0) {
            blendedUtilizationRatio = getBlendedUtilizationRatio(pairIndex,openInterestUSDCLong, openInterestUSDCShort);
            uint skewRatio = getBlendedSkew(pairIndex, true, openInterestUSDCLong, openInterestUSDCShort);
            uint longMultiplier = _PRECISION*(blendedUtilizationRatio*skewRatio)/(_PRECISION*1e2 - blendedUtilizationRatio*skewRatio);

            uint rolloverFeesPaidByLongs = (longMultiplier *
                _PRECISION*
                (block.number - f.lastUpdateBlock) *
                pairParams[pairIndex].rolloverFeePerBlockP) /
                _PRECISION /
                _PRECISION ;

            valueLong += rolloverFeesPaidByLongs;
        }

        if (openInterestUSDCShort > 0) {

            uint skewRatio = getBlendedSkew(pairIndex, false, openInterestUSDCLong, openInterestUSDCShort);
            uint shortMultiplier = _PRECISION*(blendedUtilizationRatio*skewRatio)/(_PRECISION*1e2 - blendedUtilizationRatio*skewRatio);
            uint rolloverFeesPaidByShort = (shortMultiplier *
                _PRECISION *
                (block.number - f.lastUpdateBlock) *
                pairParams[pairIndex].rolloverFeePerBlockP) /
                _PRECISION /
                _PRECISION ;

            valueShort += rolloverFeesPaidByShort;
        }
    }

   /**
     * @notice Calculates the trade rollover fee for a given trader and trading pair
     * @param trader Address of the trader
     * @param pairIndex The index of the trading pair
     * @param index The index of the trade
     * @param long Indicates if the position is long
     * @param collateral The collateral for the trade
     * @param leverage The leverage for the trade
     * @return The trade rollover fee
     */
    function getTradeRolloverFee(
        address trader,
        uint pairIndex,
        uint index,
        bool long,
        uint collateral,
        uint leverage
    ) public view override returns (uint) {
        TradeInitialAccFees memory t = tradeInitialAccFees[trader][pairIndex][index];
        if (!t.openedAfterUpdate) {
            return 0;
        }

        (uint pendingLong, uint pendingShort) = getPendingAccRolloverFees(pairIndex);
        return getTradeRolloverFeePure(t.rollover, long ? pendingLong : pendingShort, collateral, leverage);
    }

    /**
     * @notice Calculates the trade rollover fee for accumulated Roll over fees
     * @param accRolloverFeesPerOi Accumulated rollover fees per open interest
     * @param endAccRolloverFeesPerOi End accumulated rollover fees per open interest
     * @param collateral The collateral for the trade
     * @param leverage The leverage for the trade
     * @return The trade rollover fee
     */
    function getTradeRolloverFeePure(
        uint accRolloverFeesPerOi,
        uint endAccRolloverFeesPerOi,
        uint collateral,
        uint leverage
    ) public pure returns (uint) {
            return ((endAccRolloverFeesPerOi - accRolloverFeesPerOi) * collateral.mul(leverage)) / _PRECISION;
    }


    /**
     * @notice Calculates the liquidation price of the trade 
     * @param openPrice The opening price of the trade
     * @param long Indicates if the position is long
     * @param collateral The collateral for the trade
     * @param leverage The leverage for the trade
     * @param rolloverFee The rollover fee for the trade
     * @return The liquidation price
     */
    function getTradeLiquidationPricePure(
        uint openPrice,
        bool long,
        uint collateral,
        uint leverage,
        uint rolloverFee
    ) public view returns (uint) {
        int liqPriceDistance = (int(openPrice) * (int((collateral * liqThreshold) / 100) - int(rolloverFee))) /
            int(collateral.mul(leverage));

        int liqPrice = long ? int(openPrice) - liqPriceDistance : int(openPrice) + liqPriceDistance;

        return liqPrice > 0 ? uint(liqPrice) : 0;
    }

    /**
     * @notice Calculates the Pnl, fees and pnl adjusted collateral
     * @param collateral The collateral for the trade
     * @param percentProfit The percent profit for the trade
     * @param rolloverFee The rollover fee for the trade
     * @param closingFee The closing fee for the trade
     * @param lossProtection The loss protection for the trade
     * @return The trade value, profit and loss, and fees
     */
    function getTradeValuePure(
        uint collateral,
        int percentProfit,
        uint rolloverFee,
        uint closingFee,
        uint lossProtection
    ) public view returns (uint, int, uint) {
        int pnl = (int(collateral) * percentProfit) / int(_PRECISION) / 100;
        if (pnl < 0) {
            pnl = (pnl * int(lossProtection)) / 100;
        }
        int fees = int(rolloverFee) + int(closingFee);
        int value = int(collateral) + pnl - fees;
        if (value <= (int(collateral) * int(100 - liqThreshold)) / 100) {
            value = 0;
            pnl = fees - int(collateral);
        }
        return (value > 0 ? uint(value) : 0, pnl, uint(fees));
    }

    function _setOnePercentDepth(uint pairIndex, uint valueAbove, uint valueBelow) internal {
        PairParams storage p = pairParams[pairIndex];

        p.onePercentDepthAbove = valueAbove;
        p.onePercentDepthBelow = valueBelow;

        emit OnePercentDepthUpdated(pairIndex, valueAbove, valueBelow);
    }

    function _setPairParams(uint pairIndex, PairParams calldata value) internal{
        _storeAccRolloverFees(pairIndex);

        pairParams[pairIndex] = value;
        emit PairParamsUpdated(pairIndex, value);
    }

    function _storeAccRolloverFees(uint pairIndex) private {
        PairRolloverFees storage f = pairRolloverFees[pairIndex];

        (f.accPerOiLong, f.accPerOiShort) = getPendingAccRolloverFees(pairIndex);
        f.lastUpdateBlock = block.number;

        emit AccRolloverFeesStored(pairIndex, f.accPerOiLong, f.accPerOiShort);
    }
}
