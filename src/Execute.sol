// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./interfaces/ITradingStorage.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/ICallbacks.sol";
import {IExecute} from "./interfaces/IExecute.sol";

/**
 * @title Execute
 * @dev Contract handling limit order triggers and rewards distribution.
 */
contract Execute is Initializable, IExecute {

    ITradingStorage public storageT;
    uint public triggerTimeout;
    uint public tokensClaimedTotal;

    mapping(address => uint) public tokensToClaim;
    mapping(address => mapping(uint => mapping(uint => mapping(ITradingStorage.LimitOrder => TriggeredLimit))))
        public triggeredLimits;

    mapping(address => mapping(uint => mapping(uint => OpenLimitOrderType))) public override openLimitOrderTypes;
    mapping(address => uint) public tokensClaimed;

    // Modifiers
    modifier onlyGov() {
        require(msg.sender == storageT.gov(), "GOV_ONLY");
        _;
    }

    modifier onlyTrading() {
        require(msg.sender == storageT.trading(), "TRADING_ONLY");
        _;
    }

    modifier onlyCallbacks() {
        require(msg.sender == storageT.callbacks(), "CALLBACKS_ONLY");
        _;
    }
    
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the given storage contract address.
     * @param _storageT The address of the storage contract.
     */
    function initialize(address _storageT) external initializer {
        storageT = ITradingStorage(_storageT);
        triggerTimeout = 5;
    }

    /**
     * @notice Updates the timeout for trigger functions.
     * @param _triggerTimeout The new timeout value, must be greater than or equal to 5.
     */
    function updateTriggerTimeout(uint _triggerTimeout) external onlyGov {
        require(_triggerTimeout >= 5, "LESS_THAN_5");
        triggerTimeout = _triggerTimeout;
        emit NumberUpdated("triggerTimeout", _triggerTimeout);
    }

    /**
     * @notice Stores the first address to trigger a limit order.
     * @param _id Identifier for the triggered limit.
     * @param _bot The address that triggered the limit order.
     */
    function storeFirstToTrigger(TriggeredLimitId calldata _id, address _bot) external override onlyTrading {
        TriggeredLimit storage t = triggeredLimits[_id.trader][_id.pairIndex][_id.index][_id.order];
        t.first = _bot;
        t.block = block.number;
        emit TriggeredFirst(_id, _bot);
    }

    /**
     * @notice Unregisters a triggered limit order.
     * @param _id Identifier for the triggered limit.
     */
    function unregisterTrigger(TriggeredLimitId calldata _id) external override onlyCallbacks {
        delete triggeredLimits[_id.trader][_id.pairIndex][_id.index][_id.order];
        emit TriggerUnregistered(_id);
    }

    /**
     * @notice Distributes the reward for a triggered limit order.
     * @param _id Identifier for the triggered limit.
     * @param _reward The reward amount to distribute.
     */
    function distributeReward(TriggeredLimitId calldata _id, uint _reward) external override onlyCallbacks {
        TriggeredLimit memory t = triggeredLimits[_id.trader][_id.pairIndex][_id.index][_id.order];
        require(t.block > 0, "NOT_TRIGGERED");

        tokensToClaim[t.first] += _reward;
        emit TriggerRewarded(_id, _reward);
    }

    /**
     * @notice Claims the pending token Reward for the caller.
     */
    function claimTokens() external {
        uint tokens = tokensToClaim[msg.sender];
        require(tokens > 0, "NOTHING_TO_CLAIM");

        tokensToClaim[msg.sender] = 0;
        tokensClaimed[msg.sender] += tokens;
        tokensClaimedTotal += tokens;

        ICallbacks(storageT.callbacks()).transferFromVault(msg.sender, tokens);
        emit TokensClaimed(msg.sender, tokens);
    }

    /**
     * @notice Sets the type of a given open limit order.
     * @param _trader The trader's address.
     * @param _pairIndex The index of the trading pair.
     * @param _index The index of the open limit order.
     * @param _type The type of the limit order.
     */
    function setOpenLimitOrderType(
        address _trader,
        uint _pairIndex,
        uint _index,
        OpenLimitOrderType _type
    ) external override onlyTrading {
        openLimitOrderTypes[_trader][_pairIndex][_index] = _type;
    }

}
