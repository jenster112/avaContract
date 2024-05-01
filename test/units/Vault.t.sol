pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import {PositionMath} from "../../src/library/PositionMath.sol";
import "forge-std/console.sol";

contract Vault is TradeBase{

    using PositionMath for uint256;
    function setUp() public virtual override{
        super.setUp();
    }

    function testReserve() public {

        uint juniorTrancheReserved = juniorTranche.totalReserved();
        uint seniorTranchReserved =  seniorTranche.totalReserved();

        //Random trader opens a market long
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rand]);
        uint amount = usdc.balanceOf(traders[rand]);
        usdc.approve(address(tradingStorage), amount );
        uint id = _placeMarketLong(traders[rand], amount, btcPairIndex,  50000);
        vm.stopPrank();
        _executeMarketLong(traders[rand], amount, btcPairIndex,  50000, id);

        ITradingStorage.TradeInfo memory  _trade = 
            tradingStorage.openTradesInfo(traders[rand], btcPairIndex, traderOrderIndex[traders[rand]] -1);

        uint newJuniorTrancheReserved = juniorTranche.totalReserved();
        uint newSeniorTranchReserved =  seniorTranche.totalReserved();

        uint juniorReserveAmount =  _trade.openInterestUSDC*vaultManager.targetReserveRatio()/100;
        uint seniorReserveAmount = _trade.openInterestUSDC - juniorReserveAmount;

        assert(newJuniorTrancheReserved - juniorTrancheReserved 
                ==  juniorReserveAmount);
        assert(newSeniorTranchReserved - seniorTranchReserved 
                == seniorReserveAmount);
    }
}
