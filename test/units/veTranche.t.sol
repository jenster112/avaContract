pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";
import {SkewedBase} from "../fixtures/SkewedBase.t.sol";
import "pyth-sdk-solidity/PythStructs.sol";
import "pyth-sdk-solidity/PythErrors.sol";
import "../../src/interfaces/ITradingStorage.sol";
import "../../src/interfaces/IExecute.sol";
import {PositionMath} from "../../src/library/PositionMath.sol";

contract veTranche is SkewedBase{

    using PositionMath for uint256;

    mapping(address => uint ) public tokenIdsMinted;

    function setUp() public virtual override{
        super.setUp();
    }

    function testLock() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numLPs;

        vm.startPrank(liquidityProviders[rand]);

        uint _juniorShares = juniorTranche.balanceOf(liquidityProviders[rand]);
        juniorTranche.approve(address(juniorVeTranche), _juniorShares);
        juniorVeTranche.lock(_juniorShares, 25 days);
        uint tokenIdMinted = 0;
        vm.stopPrank();

        assertEq(juniorVeTranche.tokensByTokenId(tokenIdMinted), _juniorShares );
        assertEq(juniorVeTranche.lockTimeByTokenId(tokenIdMinted), block.timestamp + 25 days );
        assertEq(juniorVeTranche.rewardsByTokenId(tokenIdMinted), 0);     
        assertGt(juniorVeTranche.lockMultiplierByTokenId(tokenIdMinted), 0);    

    }

    function testDryUnlock() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numLPs;

        vm.startPrank(liquidityProviders[rand]);

        // Lock
        uint _juniorShares = juniorTranche.balanceOf(liquidityProviders[rand]);
        juniorTranche.approve(address(juniorVeTranche), _juniorShares);
        juniorVeTranche.lock(_juniorShares,25 days);
        
        uint tokenIdMinted = 0;
        assertEq(juniorVeTranche.balanceOf(liquidityProviders[rand]), 1);

        vm.warp(30 days);

        assertEq(juniorVeTranche.checkUnlockFee(tokenIdMinted), 0);
        juniorVeTranche.unlock(tokenIdMinted);

        vm.stopPrank();

        assertEq(juniorVeTranche.balanceOf(liquidityProviders[rand]), 0);
    }

    function testRewardDistribution() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numLPs;
        vm.startPrank(liquidityProviders[rand]);

        uint _juniorShares = juniorTranche.balanceOf(liquidityProviders[rand]);
        juniorTranche.approve(address(juniorVeTranche), _juniorShares);
        juniorVeTranche.lock(_juniorShares,25 days);

        vm.stopPrank();

        vm.warp(14 days);
        uint juniorBalance = usdc.balanceOf(address(juniorTranche));
        uint seniorBalance = usdc.balanceOf(address(seniorTranche));

        uint juniorVeBalance = usdc.balanceOf(address(juniorVeTranche));
        uint seniorVeBalance = usdc.balanceOf(address(seniorVeTranche));

        vm.startPrank(deployer);

        assertGt(vaultManager.totalRewards(), 0);
        vaultManager.distributeRewards();

        vm.stopPrank();

        uint juniorRewards = usdc.balanceOf(address(juniorTranche)) - juniorBalance;
        uint seniorRewards = usdc.balanceOf(address(seniorTranche)) - seniorBalance;    


        uint juniorVeRewards = usdc.balanceOf(address(juniorVeTranche)) - juniorVeBalance;
        uint seniorVeRewards = usdc.balanceOf(address(seniorVeTranche)) - seniorVeBalance;  

        assertGt(juniorRewards, 0);
        assertGt(seniorRewards, 0);         
        assertGt(juniorVeRewards, 0);
        assertEq(seniorVeRewards, 0);   

    }

    function testUnlockFee() public {
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numLPs;
        vm.startPrank(liquidityProviders[rand]);

        uint _juniorShares = juniorTranche.balanceOf(liquidityProviders[rand]);
        juniorTranche.approve(address(juniorVeTranche), _juniorShares);
        juniorVeTranche.lock(_juniorShares, 90 days);
        uint tokenIdMinted = 0;
        vm.stopPrank();
        assertApproxEqAbs(juniorVeTranche.checkUnlockFee(tokenIdMinted), 10 * _juniorShares / 100, 5);

        vm.warp(45 days);
        assertApproxEqRel(juniorVeTranche.checkUnlockFee(tokenIdMinted), 10 * 45 * _juniorShares / 100 / 90, 1e14);
    }

    function testUnlock() public {

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numLPs;
        vm.startPrank(liquidityProviders[rand]);

        uint _juniorShares = juniorTranche.balanceOf(liquidityProviders[rand]);
        juniorTranche.approve(address(juniorVeTranche), _juniorShares);
        juniorVeTranche.lock(_juniorShares, 180 days);
        uint tokenIdMinted = 0;
        vm.stopPrank();

        vm.warp(7 days);

        vm.prank(deployer);
        vaultManager.distributeRewards();

        uint balBefore = usdc.balanceOf(liquidityProviders[rand]);

        vm.startPrank(liquidityProviders[rand]);
        assertGt(juniorVeTranche.checkUnlockFee(tokenIdMinted), 0);
        juniorVeTranche.unlock(tokenIdMinted);
        vm.stopPrank();

        uint rewardsClaimed = usdc.balanceOf(liquidityProviders[rand]) - balBefore;

        assertGt(rewardsClaimed, 0);
    }

    function testVeTrancheFeeCollectionDistribution() public {

        // All the LPs lock for 200 days
        for(uint i; i< numLPs; i++){
            vm.startPrank(liquidityProviders[i]);

            uint _juniorShares = juniorTranche.balanceOf(liquidityProviders[i]);
            juniorTranche.approve(address(juniorVeTranche), _juniorShares);
            juniorVeTranche.lock(_juniorShares, 180 days);
            tokenIdsMinted[liquidityProviders[i]] = i;
            vm.stopPrank();
        }

        // Half the LPs unlock after 100 days
        // They pay a fee to vaultManager in shares
        vm.warp(100 days);
        for(uint i; i< numLPs/2; i++){

            vm.startPrank(liquidityProviders[i]);
            juniorVeTranche.unlock(tokenIdsMinted[liquidityProviders[i]]);
            vm.stopPrank();
        }

        uint feeCollected = juniorTranche.balanceOf(address(vaultManager));
        assertGt(feeCollected, 0);

        uint juniorVeBalance = usdc.balanceOf(address(juniorVeTranche));

        // Distribute Fee collected to Locked LPs
        vm.prank(deployer);
        vaultManager.distributeCollectedFeeShares(address(juniorTranche));

        uint juniorVeRewards = usdc.balanceOf(address(juniorVeTranche)) - juniorVeBalance;
        assertGt(juniorVeRewards, 0);
        //assertGt(juniorVeTranche.rewardsByTokenId(tokenIdsMinted[liquidityProviders[numLPs -1]]), 0);
    }

    function testForceUnlock() public{

        uint rand = uint(keccak256(abi.encodePacked(block.timestamp))) % numLPs;
        vm.startPrank(liquidityProviders[rand]);

        uint _juniorShares = juniorTranche.balanceOf(liquidityProviders[rand]);
        juniorTranche.approve(address(juniorVeTranche), _juniorShares);
        juniorVeTranche.lock(_juniorShares, 180 days);
        vm.stopPrank();

        vm.warp(7 days);

        vm.prank(deployer);
        vaultManager.distributeRewards();

        uint rands = uint(keccak256(abi.encodePacked(block.timestamp))) % numTraders;
        vm.startPrank(traders[rands]);
        vm.expectRevert();
        juniorVeTranche.forceUnlock(0);

        vm.stopPrank();

        vm.warp(181 days);

        uint balBefore = usdc.balanceOf(liquidityProviders[rand]);

        vm.startPrank(traders[rands]);
        juniorVeTranche.forceUnlock(0);
        vm.stopPrank();

        uint rewardsClaimed = usdc.balanceOf(liquidityProviders[rand]) - balBefore;

        assertGt(rewardsClaimed, 0);
    }
}