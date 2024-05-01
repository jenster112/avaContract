pragma solidity 0.8.7;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";

contract TimelockBase is Base{

    function setUp() public virtual override{
        super.setUp();
        __setGovToTimelock();
    }

    function __setGovToTimelock() internal{
        vm.startPrank(deployer);

        proxyAdmin.transferOwnership(address(timelock));

        tradingStorage.requestGov(address(timelock));
        tradingStorage.setGov(address(timelock));

        referral.requestGov(address(timelock));
        referral.setGov(address(timelock));

        vm.stopPrank();

        vm.startPrank(deployer);
        vaultManager.requestGov(address(timelock));
        vaultManager.setGov(address(timelock));
        vm.stopPrank();
    }
}