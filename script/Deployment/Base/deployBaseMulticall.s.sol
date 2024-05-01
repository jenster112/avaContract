pragma solidity 0.8.7;

import "forge-std/Script.sol";
import {Multicall} from "../../../src/Multicall.sol";

contract MulticallDeployScript is Script {
    // Set This false for mainnet Deployment
    bool constant isTestnet = false;

    uint constant PRECISION = 1e10;

    address public deployer;

    function run() public {
        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        deployer = vm.rememberKey(deployerKey);

        // Doing it here cause don't want to disturb exising deployment setups
        // Can be moved to base
        // --------------------------------------
        __deployMulticallContracts();
    }

    /**
     * @dev Deploy the contracts.
     */
    function __deployMulticallContracts() internal {
        vm.startBroadcast(deployer);

        __deployMulticall();

        vm.stopBroadcast();
    }

    /**
     * @dev Deploy the Multicall contract.
     */
    function __deployMulticall() internal {
        new Multicall(
            0x8a311D7048c35985aa31C131B9A13e03a5f7422d, // Trading Storage
            0x81F22d0Cc22977c91bEfE648C9fddf1f2bd977e5, // PairInfos
            0x92Ed158d5e423CFdc9eed5Bd7328FFF7CeD6fF94, // Pair Storage
            0x5FF292d70bA9cD9e7CCb313782811b3D7120535f // Trading
        );
    }
}