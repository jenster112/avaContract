pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {Base} from "../fixtures/Base.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts//proxy/transparent/ProxyAdmin.sol";
import {Execute} from "../../src/Execute.sol";
import {PairInfos} from "../../src/PairInfos.sol";
import {PairStorage} from "../../src/PairStorage.sol";
import {PriceAggregator} from "../../src/PriceAggregator.sol";
import {Trading} from "../../src/Trading.sol";
import {TradingCallbacks} from "../../src/TradingCallbacks.sol";
import {TradingStorage} from "../../src/TradingStorage.sol";
import {Tranche} from "../../src/Tranche.sol";
import {VaultManager} from "../../src/VaultManager.sol";
import {VeTranche} from "../../src/VeTranche.sol";

contract Upgradability is Base{

    function setUp() public virtual override{
        super.setUp();
    }

    function testProxyAdmin() public {

        address adminProxy = 
            proxyAdmin.getProxyAdmin(ITransparentUpgradeableProxy(payable(address(tradingStorage))));
        
        assert(adminProxy == address(proxyAdmin));

        ProxyAdmin newProxyAdmin = new ProxyAdmin(); 

        vm.startPrank(deployer);
        proxyAdmin.changeProxyAdmin(
            ITransparentUpgradeableProxy(payable(address(tradingStorage))), 
            address(newProxyAdmin)
        );
        vm.stopPrank();

        vm.expectRevert();
        proxyAdmin.changeProxyAdmin(
            ITransparentUpgradeableProxy(payable(address(tradingStorage))), 
            address(newProxyAdmin)
        );

    }
    ///@dev Add more asserts to check storage after update
    function testStorageUpgrade() public {

        address oldImpl = 
            proxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(tradingStorage))));
        
        TradingStorage tradingStorageNewImpl = new TradingStorage();
        vm.startPrank(deployer);
        proxyAdmin.upgrade(
            ITransparentUpgradeableProxy(payable(address(tradingStorage))), 
            address(tradingStorageNewImpl)
        );
        vm.stopPrank();

        address newImpl = 
            proxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(address(tradingStorage))));
        
        assert(newImpl != oldImpl);
        assert(newImpl == address(tradingStorageNewImpl));

    }

}