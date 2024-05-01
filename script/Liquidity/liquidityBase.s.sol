pragma solidity 0.8.7;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
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
import {USDC} from "../../src/testnet/USDC.sol";
import {MockPyth} from "pyth-sdk-solidity/MockPyth.sol";
import {Referral} from "../../src/Referral.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import "../../src/interfaces/IPairInfos.sol";
import {Constants} from "../Deployment/Constants.sol";

contract LiquidityScript is Script {

    // Set This false for mainnet Deployment
    bool constant isTestnet  = true; 

    address public deployer;
    address public vaultGovernor;
    address public pairInfoManager;

    Trading public trading;

    Tranche public juniorTranche;
    Tranche public seniorTranche;
    USDC public usdc;
    TradingStorage public tradingStorage;
    PairStorage public pairStorage;
    uint lpAmount = 10000000e6; // 10 million
    uint public juniorRatio = 50; 
    
    function run() public {

        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        deployer = vm.rememberKey(deployerKey);

        uint256 vaultGovernorKey = vm.envUint("VAULT_GOVERNOR_KEY");
        vaultGovernor = vm.rememberKey(vaultGovernorKey);

        uint256 pairInfoManagerKey = vm.envUint("PAIR_INFO_MANAGER_KEY");
        pairInfoManager = vm.rememberKey(pairInfoManagerKey);

        trading = Trading(0x711871098b840Ed5027ed20f4132657986CFe7FC);
        juniorTranche = Tranche(0x9E01320841226f77AcfE212641241a134A53ECB9);
        seniorTranche = Tranche(0xd945E36a73358f095026A01fE51660874461c09a);
        usdc = USDC(0x4B2d9827F7Ee26e8e1732b4614A35fBEa1f06D7A);
        tradingStorage = TradingStorage(0x107049d5138AFE61ba43635f4bef07206CE6d91B);
        pairStorage = PairStorage(0xD10D3c5b3BEC9eBFe338Ca0F5463cFDA35E51C42);
        _LP();
    }

    function _LP() internal {

        _dealUSDC(lpAmount);

        uint256 balance = lpAmount;

        vm.startBroadcast(deployer);

        usdc.approve(address(juniorTranche), balance*juniorRatio/100 );
        juniorTranche.deposit(balance*juniorRatio/100, deployer);

        usdc.approve(address(seniorTranche), balance - balance*juniorRatio/100 );
        seniorTranche.deposit(balance - balance*juniorRatio/100, deployer);
        
        vm.stopBroadcast();

        vm.startBroadcast(vaultGovernor);

        usdc.approve(address(juniorTranche), balance*juniorRatio/100 );
        juniorTranche.deposit(balance*juniorRatio/100, vaultGovernor);

        usdc.approve(address(seniorTranche), balance - balance*juniorRatio/100 );
        seniorTranche.deposit(balance - balance*juniorRatio/100, vaultGovernor);
        
        vm.stopBroadcast();

        vm.startBroadcast(pairInfoManager);

        usdc.approve(address(juniorTranche), balance*juniorRatio/100 );
        juniorTranche.deposit(balance*juniorRatio/100, pairInfoManager);

        usdc.approve(address(seniorTranche), balance - balance*juniorRatio/100 );
        seniorTranche.deposit(balance - balance*juniorRatio/100, pairInfoManager);
        
        vm.stopBroadcast();
    }

    function _dealUSDC(uint256 amount) internal {

        vm.startBroadcast(deployer);
        usdc.mint(deployer, amount);
        vm.stopBroadcast();

        vm.startBroadcast(vaultGovernor);
        usdc.mint(vaultGovernor, amount);
        vm.stopBroadcast();

        vm.startBroadcast(pairInfoManager);
        usdc.mint(pairInfoManager, amount);
        vm.stopBroadcast();
    }
}
