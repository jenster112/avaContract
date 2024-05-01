pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "./TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";


contract SkewedBase is TradeBase{

    uint public longSkew =  85;

    function setUp() public virtual override{
        super.setUp();
        _skew(longSkew);
    }

    function _skew(uint _longSkew) internal {

        for(uint i; i < numTraders; i++){
            uint256 amount;

            vm.startPrank(traders[i]);

            amount = usdc.balanceOf(traders[i]);
            usdc.approve(address(tradingStorage), amount);

            uint id = _placeMarketLong(traders[i], amount*_longSkew/100, btcPairIndex,  50000);
            vm.stopPrank();

            _executeMarketLong(traders[i], amount*_longSkew/100, btcPairIndex,  50000, id);

            vm.startPrank(traders[i]);
            id = _placeMarketShort(traders[i], amount - amount*_longSkew/100, btcPairIndex,  50000);
            vm.stopPrank();
            
            _executeMarketShort(traders[i], amount - amount*_longSkew/100, btcPairIndex,  50000, id);

        }
    }

}