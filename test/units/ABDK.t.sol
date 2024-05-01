pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TradeBase} from "../fixtures/TradeBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import {ABDKMathQuadExt} from "../../src/library/abdkQuadMathExt.sol";
contract ABDKTest is TradeBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testDiv() public pure {
        uint256 res= ABDKMathQuadExt.toUInt(ABDKMathQuadExt.mul(ABDKMathQuadExt.div(ABDKMathQuadExt.fromUInt(100), ABDKMathQuadExt.fromUInt(101)),ABDKMathQuadExt.fromUInt(100))) ;
        assert(res == 99);
    }
}