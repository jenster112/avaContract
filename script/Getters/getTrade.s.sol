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
import "forge-std/console.sol";

contract UpdateScript is Script {

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
        _displayTrade();

    }

    function _displayTrade() internal view {

        consoleTrade(tradingStorage.openTrades(0xA2B9c5C0B544Aa161624b6767744D4106a1e32C1, 0, 0));
    }

    function consoleTrade(ITradingStorage.Trade memory _trade) internal view {
        console.logString("Trader address: ");
        console.logAddress(_trade.trader);
        
        console.logString("Pair Index: ");
        console.logUint(_trade.pairIndex);
        
        console.logString("Index: ");
        console.logUint(_trade.index);
        
        console.logString("Initial Position Token: ");
        console.logUint(_trade.initialPosToken);
        
        console.logString("Position Size USDC: ");
        console.logUint(_trade.positionSizeUSDC);
        
        console.logString("Open Price: ");
        console.logUint(_trade.openPrice);
        
        console.logString("Buy: ");
        console.logBool(_trade.buy);
        
        console.logString("Leverage: ");
        console.logUint(_trade.leverage);
        
        console.logString("Take Profit (tp): ");
        console.logUint(_trade.tp);
        
        console.logString("Stop Loss (sl): ");
        console.logUint(_trade.sl);
        
        console.logString("Timestamp: ");
        console.logUint(_trade.timestamp);
    }
}