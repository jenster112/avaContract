pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";

contract LiquidBase is Base{

    uint public juniorRatio = 50; 
    function setUp() public virtual override{
        super.setUp();
        _LP();
    }

    function _LP() internal {

        uint256 balance;
        for(uint i; i< numLPs; i++){

            vm.startPrank(liquidityProviders[i]);
            balance = usdc.balanceOf(liquidityProviders[i]);

            usdc.approve(address(juniorTranche), balance*juniorRatio/100 );
            juniorTranche.deposit(balance*juniorRatio/100, liquidityProviders[i]);

            usdc.approve(address(seniorTranche), balance - balance*juniorRatio/100 );
            seniorTranche.deposit(balance - balance*juniorRatio/100, liquidityProviders[i]);
            
            vm.stopPrank();
        }
    }
}
