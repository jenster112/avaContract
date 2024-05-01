// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./interfaces/ITradingStorage.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IPairStorage.sol";

contract PairStorage is Initializable, IPairStorage {
    
    ITradingStorage public storageT;

    uint private constant _MAX_LOSS_REBATE = 50;
    uint private constant _PRECISION = 1e10;
    uint private constant _MIN_LEVERAGE = 2 * _PRECISION;
    uint private constant _MAX_LEVERAGE = 150 * _PRECISION;

    uint public currentOrderId;
    uint public override pairsCount;
    uint public groupsCount;
    uint public feesCount;
    uint public skewedFeesCount;

    mapping(uint => Pair) public pairs;
    mapping(uint => Group) public groups;
    mapping(uint => Fee) public fees;
    mapping(string => mapping(string => bool)) public isPairListed;
    mapping(uint => uint[2]) public groupOIs;
    mapping(uint => mapping(uint => uint)) public lossProtection;
    mapping(uint => SkewFee) private skewFees;
    mapping(uint => uint) public override blockOILimit;
    
    modifier onlyGov() {
        require(msg.sender == storageT.gov(), "GOV_ONLY");
        _;
    }

    modifier groupListed(uint _groupIndex) {
        require(groups[_groupIndex].minLeverage > 0, "GROUP_NOT_LISTED");
        _;
    }
    modifier feeListed(uint _feeIndex) {
        require(fees[_feeIndex].openFeeP > 0, "FEE_NOT_LISTED");
        _;
    }

    modifier feedOk(Feed calldata _feed) {
        require(_feed.maxDeviationP > 0, "WRONG_FEED");
        _;
    }
    modifier groupOk(Group calldata _group) {
        require(
            _group.minLeverage >= _MIN_LEVERAGE &&
                _group.maxLeverage <= _MAX_LEVERAGE &&
                _group.minLeverage < _group.maxLeverage,
            "WRONG_LEVERAGES"
        );
        _;
    }

    modifier feeOk(Fee calldata _fee) {
        require(
            _fee.openFeeP > 0 && _fee.closeFeeP > 0 && _fee.limitOrderFeeP > 0 && _fee.minLevPosUSDC > 0,
            "WRONG_FEES"
        );
        _;
    }
    
    constructor() {
        _disableInitializers();
    }
    /**
     * @dev Initializes the contract.
     * @param _storageT Address of the trading storage contract.
     * @param _currentOrderId Initial order ID.
     */
    function initialize(address _storageT, uint _currentOrderId) external initializer {
        require(_currentOrderId > 0, "ORDER_ID_0");
        currentOrderId = _currentOrderId;
        storageT = ITradingStorage(_storageT);
    }

    /**
     * @dev Adds a skew open fee.
     * @param _skewFee The skew fee to add.
     */
    function addSkewOpenFees(SkewFee calldata _skewFee) external onlyGov {
        skewFees[skewedFeesCount] = _skewFee;
        emit SkewFeeAdded(skewedFeesCount++);
    }

    /**
     * @dev Updates a skew open fee.
     * @param _pairIndex The index of the pair to update.
     * @param _skewFee The new skew fee.
     */
    function udpateSkewOpenFees(uint _pairIndex, SkewFee calldata _skewFee) external onlyGov {
        skewFees[_pairIndex] = _skewFee;
        emit SkewFeeUpdated(_pairIndex);
    }

    /**
     * @dev Adds a new trading pair.
     * @param _pair The new trading pair to add.
     */
    function addPair(
        Pair calldata _pair
    ) external onlyGov feedOk(_pair.feed) groupListed(_pair.groupIndex) feeListed(_pair.feeIndex) {
        require(!isPairListed[_pair.from][_pair.to], "PAIR_ALREADY_LISTED");

        pairs[pairsCount] = _pair;
        isPairListed[_pair.from][_pair.to] = true;

        emit PairAdded(pairsCount++, _pair.from, _pair.to);
    }

    /**
     * @dev Updates an existing trading pair.
     * @param _pairIndex The index of the pair to update.
     * @param _pair The new pair data.
     */
    function updatePair(
        uint _pairIndex,
        Pair calldata _pair
    ) external onlyGov feedOk(_pair.feed) feeListed(_pair.feeIndex) {
        Pair storage p = pairs[_pairIndex];
        require(isPairListed[p.from][p.to], "PAIR_NOT_LISTED");

        p.feed = _pair.feed;
        p.spreadP = _pair.spreadP;
        p.feeIndex = _pair.feeIndex;
        if (_pair.backupFeed.maxDeviationP > 0 && _pair.backupFeed.feedId != address(0)) {
            p.backupFeed = _pair.backupFeed;
        } else {
            delete p.backupFeed;
        }

        emit PairUpdated(_pairIndex);
    }

    /**
     * @notice Delists a trading pair by index.
     * @param _pairIndex The index of the pair to be delisted.
     */
    function delistPair(
        uint _pairIndex
    ) external onlyGov {
        Pair storage p = pairs[_pairIndex];
        require(isPairListed[p.from][p.to], "PAIR_NOT_LISTED");
        
        isPairListed[p.from][p.to]= false;
        emit PairUpdated(_pairIndex);
        delete pairs[_pairIndex];
    }

    /**
     * @notice Adds a new trading group.
     * @param _group The new group to be added.
     */
    function addGroup(Group calldata _group) external onlyGov groupOk(_group) {
        groups[groupsCount] = _group;
        emit GroupAdded(groupsCount++, _group.name);
    }

    /**
     * @notice Updates an existing trading group.
     * @param _id The ID of the group to be updated.
     * @param _group The new group data.
     */
    function updateGroup(uint _id, Group calldata _group) external onlyGov groupListed(_id) groupOk(_group) {
        groups[_id] = _group;
        emit GroupUpdated(_id);
    }

    /**
     * @notice Adds a new fee structure.
     * @param _fee The Fee structure to add.
     */
    function addFee(Fee calldata _fee) external onlyGov feeOk(_fee) {
        fees[feesCount] = _fee;
        emit FeeAdded(feesCount++, _fee.name);
    }

    /**
     * @notice Updates an existing fee structure.
     * @param _id The ID of the fee structure to update.
     * @param _fee The new Fee structure.
     */
    function updateFee(uint _id, Fee calldata _fee) external onlyGov feeListed(_id) feeOk(_fee) {
        fees[_id] = _fee;
        emit FeeUpdated(_id);
    }

    /**
     * @notice Updates per block OI limit
     * @param _pairIndex Array of pair Indexes to update Limits for
     * @param _limits Value of per block OI limits
     */
    function setBlockOILImits(uint[] calldata _pairIndex, uint[] calldata _limits) external onlyGov{

        require(_pairIndex.length == _limits.length, "LEN_MISMATCH");
        for(uint8 i; i< _pairIndex.length; ++i){
            blockOILimit[_pairIndex[i]] = _limits[i];
        }

        emit BlockOILimitsSet(_pairIndex, _limits);
    }


    /**
     * @notice Updates the collateral open interest for a trading group.
     * @param _pairIndex The index of the trading pair.
     * @param _amount The amount to update the open interest by.
     * @param _long Specifies if the position is long.
     * @param _increase Specifies if the open interest should be increased.
     */
    function updateGroupOI(uint _pairIndex, uint _amount, bool _long, bool _increase) external override {
        require(msg.sender == storageT.callbacks(), "CALLBACKS_ONLY");

        uint[2] storage oi = groupOIs[pairs[_pairIndex].groupIndex];
        uint index = _long ? 0 : 1;

        if (_increase) {
            oi[index] += _amount;
        } else {
            oi[index] = oi[index] > _amount ? oi[index] - _amount : 0;
        }
    }

    /**
     * @notice Updates the loss protection multiplier for a given trading pair.
     * @param _pairIndex The index of the trading pair.
     * @param _tier The tiers for the loss protection.
     * @param _multiplierPercent The corresponding multipliers for each tier.
     */
    function updateLossProtectionMultiplier(
        uint _pairIndex,
        uint[] calldata _tier,
        uint[] calldata _multiplierPercent
    ) external onlyGov {
        require(_tier.length == _multiplierPercent.length);

        for (uint i; i < _tier.length; ++i) {
            require(_multiplierPercent[i] >= _MAX_LOSS_REBATE, "REBATE_EXCEEDS_MAX");
            lossProtection[_pairIndex][_tier[i]] = _multiplierPercent[i];
        }

        emit LossProtectionAdded(_pairIndex, _tier, _multiplierPercent);
    }

    /**
     * @notice Fetches relevant information for an order.
     * @param _pairIndex The index of the trading pair.
     * @return A tuple containing the feed IDs and the order ID.
     */
    function pairJob(uint _pairIndex) external override returns (string memory, string memory, bytes32, address, uint) {
        require(msg.sender == address(storageT.priceAggregator()), "AGGREGATOR_ONLY");

        Pair memory p = pairs[_pairIndex];
        require(isPairListed[p.from][p.to], "PAIR_NOT_LISTED");

        return (p.from, p.to, p.feed.feedId, p.backupFeed.feedId, currentOrderId++);
    }

    /** 
     * @notice Get the Pyth feed information of a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return Feed memory object containing feed related information.
     */
    function pairFeed(uint _pairIndex) external view override returns (Feed memory) {
        return pairs[_pairIndex].feed;
    }

    /** 
     * @notice Get the Chainlink backup feed information of a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return BackupFeed memory object containing backup feed information.
     */
    function pairBackupFeed(uint _pairIndex) external view override returns (BackupFeed memory) {
        return pairs[_pairIndex].backupFeed;
    }

    /** 
     * @notice Get the spread percentage of a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return The spread percentage.
     */
    function pairSpreadP(uint _pairIndex) external view override returns (uint) {
        return pairs[_pairIndex].spreadP;
    }

    /** 
     * @notice Get the group index to which a trading pair belongs.
     * @param _pairIndex The index of the trading pair.
     * @return The group index.
     */
    function pairGroupIndex(uint _pairIndex) external view override returns (uint) {
        return pairs[_pairIndex].groupIndex;
    }

    /** 
     * @notice Get the minimum leverage available for a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return The minimum leverage.
     */
    function pairMinLeverage(uint _pairIndex) external view override returns (uint) {
        return groups[pairs[_pairIndex].groupIndex].minLeverage;
    }

    /** 
     * @notice Get the maximum leverage available for a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return The maximum leverage.
     */
    function pairMaxLeverage(uint _pairIndex) external view override returns (uint) {
        return groups[pairs[_pairIndex].groupIndex].maxLeverage;
    }

    /** 
     * @notice Get the maximum open interest (OI) for a group.
     * @param _pairIndex The index of the trading pair.
     * @return The maximum open interest for the group.
     */
    function groupMaxOI(uint _pairIndex) public view override returns (uint) {
        return
            (groups[pairs[_pairIndex].groupIndex].maxOpenInterestP * storageT.vaultManager().currentBalanceUSDC()) /
            100;
    }

    /** 
     * @notice Get the maximum open interest (OI) for a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return The maximum open interest for the pair.
     */
    function pairMaxOI(uint _pairIndex) external view override returns (uint) {
        return (pairs[_pairIndex].groupOpenInterestPecentage * groupMaxOI(_pairIndex)) / 100;
    }

    /** 
     * @notice Get the total open interest (OI) for a group.
     * @param _pairIndex The index of the trading pair.
     * @return The total open interest for the group.
     */
    function groupOI(uint _pairIndex) public view override returns (uint) {
        return groupOIs[pairs[_pairIndex].groupIndex][0] + groupOIs[pairs[_pairIndex].groupIndex][1];
    }

    /** 
     * @notice Get the loss protection multiplier for a trading pair and tier.
     * @param _pairIndex The index of the trading pair.
     * @param _tier The tier level.
     * @return The loss protection multiplier.
     */
    function lossProtectionMultiplier(uint _pairIndex, uint _tier) external view override returns (uint) {
        return lossProtection[_pairIndex][_tier];
    }

    /** 
     * @notice Check if guaranteed stop loss is enabled for a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return True if enabled, false otherwise.
     */
    function guaranteedSlEnabled(uint _pairIndex) external view override returns (bool) {
        return pairs[_pairIndex].groupIndex == 0; // crypto only
    }

    /** 
     * @notice Get the maximum open interest (OI) for a wallet in a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return The maximum open interest for the wallet.
     */
    function maxWalletOI(uint _pairIndex) external view override returns (uint) {
        return (groupMaxOI(_pairIndex) * pairs[_pairIndex].maxWalletOI) / 100;
    }

    /**
     * @notice Calculate the fee for opening a leveraged position on a trading pair based on skew
     * @param _pairIndex The index of the trading pair.
     * @param _leveragedPosition The size of the leveraged position.
     * @param _buy Boolean indicating whether the position is a long (true) or short (false).
     * @return The fee percentage for opening the position.
     */
    function pairOpenFeeP(uint _pairIndex, uint _leveragedPosition, bool _buy) external view override returns (uint) {
        uint openInterestUSDCLong = storageT.openInterestUSDC(_pairIndex, 0);
        uint openInterestUSDCShort = storageT.openInterestUSDC(_pairIndex, 1);

        if (_buy) {
            openInterestUSDCLong += _leveragedPosition;
        } else {
            openInterestUSDCShort += _leveragedPosition;
        }

        uint openInterestPct = (100 * (_buy ? openInterestUSDCShort : openInterestUSDCLong)) /
            (openInterestUSDCLong + openInterestUSDCShort);
        SkewFee memory skewFee = skewFees[_pairIndex];

        uint box = openInterestPct/10;
        return (uint(skewFee.eqParams[box][0]*int(openInterestPct) + skewFee.eqParams[box][1])*_PRECISION /10000);
    }

    /**
     * @notice Get the fee for closing a position on a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return The fee percentage for closing the position.
     */
    function pairCloseFeeP(uint _pairIndex) external view override returns (uint) {
        return fees[pairs[_pairIndex].feeIndex].closeFeeP;
    }

    /**
     * @notice Get the fee for executing a TP/SL limit close.
     * @param _pairIndex The index of the trading pair.
     * @return The fee percentage for the limit order.
     */
    function pairLimitOrderFeeP(uint _pairIndex) external view override returns (uint) {
        return fees[pairs[_pairIndex].feeIndex].limitOrderFeeP;
    }

    /**
     * @notice Get the minimum leveraged position size (in USDC) allowed for a trading pair.
     * @param _pairIndex The index of the trading pair.
     * @return The minimum leveraged position size in USDC.
     */
    function pairMinLevPosUSDC(uint _pairIndex) external view override returns (uint) {
        return fees[pairs[_pairIndex].feeIndex].minLevPosUSDC;
    }

    /**
     * @notice Get backend details for a specific trading pair, its group, and associated fees.
     * @param _index The index of the trading pair.
     * @return Pair memory, Group memory, and Fee memory objects containing details for the trading pair, group, and fees.
     */
    function pairsBackend(uint _index) external view returns (Pair memory, Group memory, Fee memory) {
        Pair memory p = pairs[_index];
        return (p, groups[p.groupIndex], fees[p.feeIndex]);
    }

    /**
     * @notice Get priceImpact multiplier for a certain pair
     * @param _pairIndex The pair Index
     * @return Pair Price Impact multiplier
     */
    function pairPriceImpactMultiplier(uint _pairIndex) external override view returns(uint){
        Pair memory p = pairs[_pairIndex];
        return p.priceImpactMultiplier;
    }

    /**
     * @notice Get priceImpact multiplier for a certain pair
     * @param _pairIndex The pair Index
     * @return Pair Skew Impact multiplier
     */
    function pairSkewImpactMultiplier(uint _pairIndex) external override view returns(int){
        Pair memory p = pairs[_pairIndex];
        return p.skewImpactMultiplier;
    }

    /**
     * @notice Helper method to Check pair is usdc aligned
     * @param _pairIndex The index of the trading pair.
     * @return bool
     */
    function isUSDCAligned(uint _pairIndex) external view override returns(bool){
        return (keccak256(abi.encodePacked(pairs[_pairIndex].from)) == keccak256(abi.encodePacked("USD")));
    }

}
