// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "./ITradingStorage.sol";

interface IExecute {
    // Custom data types
    struct TriggeredLimit {
        address first;
        uint block;
    }
    
    struct TriggeredLimitId {
        address trader;
        uint pairIndex;
        uint index;
        ITradingStorage.LimitOrder order;
    }

    enum OpenLimitOrderType {
        MARKET,
        REVERSAL, // Stop Limit
        MOMENTUM // Limit
    }

    // Events
    event NumberUpdated(string name, uint value);
    event PercentagesUpdated(uint firstP);
    event TriggeredFirst(TriggeredLimitId id, address bot);
    event TriggerUnregistered(TriggeredLimitId id);
    event TriggerRewarded(TriggeredLimitId id, uint reward);
    event PoolTokensClaimed(address bot, uint fromRound, uint toRound, uint tokens);
    event TokensClaimed(address bot, uint tokens);

    function storeFirstToTrigger(TriggeredLimitId calldata, address) external;

    function unregisterTrigger(TriggeredLimitId calldata) external;

    function distributeReward(TriggeredLimitId calldata, uint) external;

    function openLimitOrderTypes(address, uint, uint) external view returns (OpenLimitOrderType);

    function setOpenLimitOrderType(address, uint, uint, OpenLimitOrderType) external;
}
