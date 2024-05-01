pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {TimelockBase} from "../fixtures/TimelockBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import {IPairStorage} from "../../src/interfaces/IPairStorage.sol";
import {IPairInfos} from "../../src/interfaces/IPairInfos.sol";
import "forge-std/console.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts//proxy/transparent/ProxyAdmin.sol";
import {TradingStorage} from "../../src/TradingStorage.sol";

contract Timelock is TimelockBase{

    function setUp() public virtual override{
        super.setUp();
    }

    function testUpdate() public{

        uint previousTvlCap = tradingStorage.tvlCap();
        uint proposedTvlCap = 80* 1e10;
        vm.startPrank(avantisMultiSig);
        bytes memory data = abi.encodeWithSignature("setTvlCap(uint256)", proposedTvlCap);
        skip(2);
        timelock.schedule(address(tradingStorage), 0, data, bytes32(0), bytes32(0), 0);
        skip(2);
        timelock.execute(address(tradingStorage), 0, data, bytes32(0), bytes32(0));
        vm.stopPrank();

        uint newTvlCap = tradingStorage.tvlCap();

        assertEq(newTvlCap, proposedTvlCap);
        assert(previousTvlCap != newTvlCap);
    }

    function testUpgrade() public{
        address oldImpl = 
            proxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(tradingStorage))));
        
        TradingStorage tradingStorageNewImpl = new TradingStorage();

        vm.startPrank(avantisMultiSig);

        bytes memory data = abi.encodeWithSignature("upgrade(address,address)", address(tradingStorage), address(tradingStorageNewImpl));
        skip(2);
        timelock.schedule(address(proxyAdmin), 0, data, bytes32(0), bytes32(0), 0);
        skip(2);
        timelock.execute(address(proxyAdmin), 0, data, bytes32(0), bytes32(0));
        vm.stopPrank();

        address newImpl = 
            proxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(tradingStorage))));
        
        assert(newImpl != oldImpl);
        assert(newImpl == address(tradingStorageNewImpl));
    }
}