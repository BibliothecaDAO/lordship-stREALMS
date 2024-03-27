// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Wrapper.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC721Wrapper} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Wrapper.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {RealmLordship} from "../src/RealmLordship.sol";
import {LORDS} from "./Lords.sol";
import {REALMS} from "./Realms.sol";

contract RealmLordshipTest is Test {
    RealmLordship public lordship;
    address public REALMS_ERC721_ADDRESS;
    address public LORDS_ADDRESS;
    address public wrappedTokenAddress;
    address public ownerAddress;
    address public rewardTokenAddress;
    address public rewardPayerAddress;

    address public constant REALMS_DAO_ADDRESS = address(0x11);
    uint256 public constant flowRate = 1 * 10 ** 18; // 1 lord per second


    function setUp() public {

        REALMS_ERC721_ADDRESS = address(new REALMS());
        LORDS_ADDRESS = address(new LORDS());
        wrappedTokenAddress = REALMS_ERC721_ADDRESS;
        ownerAddress = REALMS_DAO_ADDRESS;
        rewardTokenAddress = LORDS_ADDRESS;
        rewardPayerAddress = REALMS_DAO_ADDRESS;


        // expect emission of flow rate updated event
        vm.expectEmit();
        emit RealmLordship.FlowRateUpdated(1, flowRate);

        lordship = new RealmLordship(
            wrappedTokenAddress,
            ownerAddress,
            flowRate,
            rewardTokenAddress,
            rewardPayerAddress
        );


        //mint type(uint128).max lords to dao
        LORDS(LORDS_ADDRESS).mint(REALMS_DAO_ADDRESS, type(uint128).max);
        // the dao approves lordship contract to pay streams
        vm.prank(REALMS_DAO_ADDRESS);
        LORDS(LORDS_ADDRESS).approve(address(lordship), type(uint128).max);

    }

    function test_Constructor() public {
        // ensure that all constructor parameters are accurate

        assertEq(lordship.rewardTokenAddress(), rewardTokenAddress);
        assertEq(lordship.rewardPayerAddress(), rewardPayerAddress);

        RealmLordship.Flow memory flow = lordship.currentFlow();
        assertEq(flow.rate, flowRate);
        assertEq(flow.endAt, type(uint256).max);

        // ensure flow with id 0 was never added
        (uint256 lastFlowRate, uint256 lastFlowEndAt) 
            = lordship.flows(0);
        assertEq(lastFlowRate, 0);
        assertEq(lastFlowEndAt, block.timestamp); 

        address underlying = address(ERC721Wrapper(address(lordship)).underlying());
        assertEq(underlying, wrappedTokenAddress);

        address owner = address(Ownable2Step(address(lordship)).owner());
        assertEq(owner, ownerAddress);
    }


    function test_currentFlow() public {
        RealmLordship.Flow memory flow = lordship.currentFlow();
        assertEq(flow.rate, flowRate);
        assertEq(flow.endAt, type(uint256).max);

    }


    function test_UpdateFlowRate() public {

        uint256 ts = 4;
        uint256 newFlowRate = 4 * 10**18;
        vm.startPrank(ownerAddress); // change caller to owner
        vm.warp(ts); // change block timestamp

        // expect emission of flow rate updated event
        vm.expectEmit();
        emit RealmLordship.FlowRateUpdated(2, newFlowRate);

        // call function
        lordship.updateFlowRate(newFlowRate);

        // ensure that precious flow has ended
        (uint256 lastFlowRate, uint256 lastFlowEndAt) 
            = lordship.flows(lordship.currentFlowId() - 1);
        assertEq(lastFlowRate, flowRate);
        assertEq(lastFlowEndAt, ts);

        // ensure current flow rate is correct
        RealmLordship.Flow memory flow = lordship.currentFlow();
        assertEq(flow.rate, newFlowRate);
        assertEq(flow.endAt, type(uint256).max);
    }


    function test_UpdateFlowRate_FailBecauseNotOwner() public {
        vm.expectRevert( 
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );

        uint256 newFlowRate = 4 * 10**18;
        lordship.updateFlowRate(newFlowRate);
    }
    


    function test_UpdateRewardTokenAddress() public {

        address newRewardTokenAddress = address(0x9898989898);
        vm.startPrank(ownerAddress); // change caller to owner

        // expect emission of flow rate updated event
        vm.expectEmit();
        emit RealmLordship.RewardTokenUpdated(rewardTokenAddress, newRewardTokenAddress);

        // call function
        lordship
            .updateRewardTokenAddress(newRewardTokenAddress);

        assertEq(lordship.rewardTokenAddress(), newRewardTokenAddress);
    }


    function test_UpdateRewardTokenAddress_FailBecauseNotOwner() public {
        vm.expectRevert( 
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        address newRewardTokenAddress = address(0x9898989898);
        lordship.updateRewardTokenAddress(newRewardTokenAddress);
    }

    
    function test_UpdateRewardPayerAddress() public {

        address newRewardPayerAddress = address(0x676767676767);
        vm.startPrank(ownerAddress); // change caller to owner

        // expect emission of flow rate updated event
        vm.expectEmit();
        emit RealmLordship.RewardPayerUpdated(rewardPayerAddress, newRewardPayerAddress);

        // call function
        lordship
            .updateRewardPayerAddress(newRewardPayerAddress);

        assertEq(lordship.rewardPayerAddress(), newRewardPayerAddress);
    }


    function test_Claim_StakerClaimsTwiceAtDiffentTimes() public {

        // Scenerio: staker owns x realms, then stakes
        // all of them. Staker then waits y seconds before claiming.
        // Staker then waits an additional z seconds to claim additional 
        /// reward.

        address staker = address(0x4545454545);
        uint256 numStakerRealms = 3;
        uint256[] memory stakerRealmIds = new uint256[](numStakerRealms);
        for (uint256 i = 0; i < numStakerRealms; i++) {
            stakerRealmIds[i] = i;
        }

        _stake(staker, stakerRealmIds);


        uint256 startTs = 1;
    

        ////////////////////////////////////////////////
        // staker claims at the 12th second 
        ////////////////////////////////////////////////
        
        uint256 newTs = 12;
        vm.warp(newTs);
            
        uint256 tsDiff = newTs - startTs;
        uint256 expectedRewardAmount = tsDiff * flowRate * numStakerRealms;
        
        uint256 balanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker);

        // expect event
        vm.expectEmit();
        emit RealmLordship.RewardClaimed(staker, expectedRewardAmount);

        // claim reward
        vm.prank(staker);
        lordship.claim();


        // ensure stream timestamp was updated 
        RealmLordship.Stream memory stream = lordship.getStream(staker);
        assertEq(stream.startAt, newTs);

        // ensure correct amount of lords was given after claim
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker) - balanceBeforeStake, 
            expectedRewardAmount
        );



        ///////////////////////////////////////////
        // staker claims again at the 20th second
        ///////////////////////////////////////////

        startTs = newTs;
        newTs = 20;
        vm.warp(newTs);

        tsDiff = newTs - startTs;
        expectedRewardAmount = tsDiff * flowRate * numStakerRealms;
        
        balanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker);

        // expect event
        vm.expectEmit();
        emit RealmLordship.RewardClaimed(staker, expectedRewardAmount);
        // staker claims
        vm.prank(staker);
        lordship.claim();

        // ensure stream timestamp was updated 
        stream = lordship.getStream(staker);
        assertEq(stream.startAt, newTs);

        // ensure correct amount of lords was claimed
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker) - balanceBeforeStake, 
            expectedRewardAmount
        );
    }


    function test_Claim_EnsureClaimIsAutomaticallyMadeWhenTokenIsTransferredOut() public {

        // Scenerio: staker owns x realms, then stakes
        // all of them. Staker waits y seconds then unstakes 1 realm, 
        // leaving the staker with x - 1 staked realms and then the 
        // staker waits an another z seconds to claim additional reward.

        address staker = address(0x4545454545);
        uint256 numStakerRealms = 3;
        uint256[] memory stakerRealmIds = new uint256[](numStakerRealms);
        for (uint256 i = 0; i < numStakerRealms; i++) {
            stakerRealmIds[i] = i;
        }
        
        _stake(staker, stakerRealmIds);


        uint256 startTs = 1;
    

        ////////////////////////////////////////////////
        // staker unstakes 1 realm at the 12th second 
        ////////////////////////////////////////////////
        
        uint256 newTs = 12;
        vm.warp(newTs);            
        uint256 tsDiff = newTs - startTs;


        uint256 expectedRewardAmount = tsDiff * flowRate * numStakerRealms;
        
        uint256 balanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker);

        // expect event
        vm.expectEmit();
        emit RealmLordship.RewardClaimed(staker, expectedRewardAmount);

        // unstake realm with id 2
        uint256[] memory unstakeRealmIds = new uint256[](1);
        unstakeRealmIds[0] = 2;
        _unstake(staker, unstakeRealmIds);
        
        // update numStakerRealms
        numStakerRealms--;

        // ensure stream timestamp was updated 
        RealmLordship.Stream memory stream = lordship.getStream(staker);
        assertEq(stream.startAt, newTs);

        // ensure correct amount of lords was given when realm 
        // was unstaked
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker) - balanceBeforeStake, 
            expectedRewardAmount
        );



        /////////////////////////////////////////
        // staker claims again at the 20th second
        /////////////////////////////////////////

        startTs = newTs;
        newTs = 20;
        vm.warp(newTs);

        tsDiff = newTs - startTs;
        expectedRewardAmount = tsDiff * flowRate * numStakerRealms;
        
        balanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker);

        // expect event
        vm.expectEmit();
        emit RealmLordship.RewardClaimed(staker, expectedRewardAmount);
        // staker claims
        vm.startPrank(staker);
        lordship.claim();

        // ensure stream timestamp was updated 
        stream = lordship.getStream(staker);
        assertEq(stream.startAt, newTs);

        // ensure correct amount of lords was claimed
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker) - balanceBeforeStake, 
            expectedRewardAmount
        );
    }



    function test_Claim_EnsureClaimIsAutomaticallyMadeWhenTokenIsTransferredIn() public {

        // Scenerio: staker1 owns 3 realms and staker2 owns 1 realm, Both
        // stake for a while. Staker 2 then decides to give his vRealm to 
        // staker1 leaving staker1 with 3 + 1 staked realms and then 
        // staker1 waits an another x seconds to claim additional reward.

        address staker1 = address(0x4545454545);
        uint256 numStaker1Realms = 3;
        uint256[] memory staker1RealmIds = new uint256[](numStaker1Realms);
        for (uint256 i = 0; i < numStaker1Realms; i++) {
            staker1RealmIds[i] = i;
        }
        
        _stake(staker1, staker1RealmIds);

        address staker2 = address(0x88888888999990);
        uint256 numStaker2Realms = 1;
        uint256[] memory staker2RealmIds = new uint256[](numStaker2Realms);
        for (uint256 i = 0; i < numStaker2Realms; i++) {
            staker2RealmIds[i] = staker1RealmIds.length + i;
        }
        
        _stake(staker2, staker2RealmIds);


        uint256 startTs = 1;
    

        ////////////////////////////////////////////////////////////
        // staker2 sends 1 vRealm to staker1 at the 12th second 
        ////////////////////////////////////////////////////////////
        
        uint256 newTs = 12;
        vm.warp(newTs);
            
        uint256 tsDiff = newTs - startTs;

        uint256 staker1ExpectedRewardAmount = tsDiff * flowRate * numStaker1Realms;
        uint256 staker1BalanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker1);

        uint256 staker2ExpectedRewardAmount = tsDiff * flowRate * numStaker2Realms;
        uint256 staker2BalanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker2);

        // expect event
        vm.expectEmit();
        emit RealmLordship.RewardClaimed(staker2, staker2ExpectedRewardAmount);
        vm.expectEmit();
        emit RealmLordship.RewardClaimed(staker1, staker1ExpectedRewardAmount);

        // staker 2 sends 1 vRealm to staker 1
        vm.prank(staker2);
        ERC721(address(lordship)).transferFrom(staker2, staker1, 3);
        
        // update numStakerRealms
        numStaker1Realms++;
        numStaker2Realms--;

        // ensure stream timestamp was updated 
        RealmLordship.Stream memory streamStaker1 = lordship.getStream(staker1);
        assertEq(streamStaker1.startAt, newTs);

        RealmLordship.Stream memory streamStaker2 = lordship.getStream(staker2);
        assertEq(streamStaker2.startAt, newTs);


        // ensure correct amount of lords was given
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker1) - staker1BalanceBeforeStake, 
            staker1ExpectedRewardAmount
        );
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker2) - staker2BalanceBeforeStake, 
            staker2ExpectedRewardAmount
        );




        ///////////////////////////////////////////
        // stakers claims again at the 20th second
        ///////////////////////////////////////////

        startTs = newTs;
        newTs = 20;
        vm.warp(newTs);

        tsDiff = newTs - startTs;
        staker1ExpectedRewardAmount = tsDiff * flowRate * numStaker1Realms;
        staker2ExpectedRewardAmount = 0;
        
        staker1BalanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker1);
        staker2BalanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker2);

        // expect event
        vm.expectEmit();
        emit RealmLordship.RewardClaimed(staker1, staker1ExpectedRewardAmount);

        // staker1 claims
        vm.startPrank(staker1);
        lordship.claim();

        // staker2 claims
        vm.startPrank(staker1);
        lordship.claim();

        // ensure stream timestamp was updated 
        streamStaker1 = lordship.getStream(staker1);
        assertEq(streamStaker1.startAt, newTs);

        // ensure nothing happened for staker 2
        streamStaker2 = lordship.getStream(staker2);
        assertEq(streamStaker2.startAt, startTs);


        // ensure correct amount of lords was claimed
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker1) - staker1BalanceBeforeStake, 
            staker1ExpectedRewardAmount
        );
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker2) - staker2BalanceBeforeStake, 
            staker2ExpectedRewardAmount // 0
        );
    }

    function test_Claim_StreamDoesNotRunUntilDelegate() public {

        // Scenerio: staker does not delegate

        address staker = address(0x4545454545);
        uint256 numStakerRealms = 3;
        uint256[] memory stakerRealmIds = new uint256[](numStakerRealms);
        for (uint256 i = 0; i < numStakerRealms; i++) {
            stakerRealmIds[i] = i;
        }

        _stake(staker, stakerRealmIds);
        vm.prank(staker);
        Votes(address(lordship))
            .delegate(address(0));
    

        ////////////////////////////////////////////////
        // staker claims at the 12th second 
        ////////////////////////////////////////////////
        
        uint256 newTs = 12;
        vm.warp(newTs);
            
        uint256 expectedRewardAmount = 0;
        
        uint256 balanceBeforeStake = LORDS(LORDS_ADDRESS).balanceOf(staker);

        // claim reward
        vm.prank(staker);
        lordship.claim();

        // ensure correct amount of lords was given after claim
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker) - balanceBeforeStake, 
            expectedRewardAmount
        );
    }


    function test_Claim_StreamStopsRunningWhenDelegationStops() public {

        // Scenerio: staker stops delegating after a while

        address staker = address(0x4545454545);
        uint256 numStakerRealms = 3;
        uint256[] memory stakerRealmIds = new uint256[](numStakerRealms);
        for (uint256 i = 0; i < numStakerRealms; i++) {
            stakerRealmIds[i] = i;
        }

        _stake(staker, stakerRealmIds);


        ////////////////////////////////////////////////
        // staker stops delegating at the 12th second 
        ////////////////////////////////////////////////
        
        uint256 startTs = 1;
        uint256 stopDelegationTs = 12;
        vm.warp(stopDelegationTs);

        vm.prank(staker);
        Votes(address(lordship))
            .delegate(address(0));
            
        uint tsDiff = stopDelegationTs - startTs;
        uint256 expectedRewardAmount =  tsDiff * flowRate * numStakerRealms;
        // ensure correct amount of lords was given after delegation stopped
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker), 
            expectedRewardAmount
        );

        /////////////////////////////////////////////////////
        // staker tries to claims reward at the 20th second 
        //////////////////////////////////////////////////////
        uint256 newTs = 20;
        vm.warp(newTs);

        // claim reward
        vm.prank(staker);
        lordship.claim();

        // ensure staker gets no additional lords since delegation stopped
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker), 
            expectedRewardAmount // should be unchanged
        );
    }


    function test_Claim_EnsureStreamStopsWhenFlowRateChanges() public {

        // Scenerio: staker stakes 3 realms with original flow rate. then flow rate 
        //          changes on the 12th second. Staker doesnt claim until the 20th second
        //          but his reward should only be from timestamp 1 - 12. New reward should
        //          start applying after claim (so the 20th second). we confirm this by making the
        //          staker claim again at the 31st second (i.e after another 11 seconds)
        uint256 originalFlowRate = flowRate;
        address staker = address(0x4545454545);
        uint256 numStakerRealms = 3;
        uint256[] memory stakerRealmIds = new uint256[](numStakerRealms);
        for (uint256 i = 0; i < numStakerRealms; i++) {
            stakerRealmIds[i] = i;
        }

        _stake(staker, stakerRealmIds);


        ////////////////////////////////////////////////
        // flow rate changes at 12th second 
        ////////////////////////////////////////////////
        
        uint256 startTs = 1;
        uint256 flowRateChangeTs = 12;
        vm.warp(flowRateChangeTs);

        vm.prank(ownerAddress);
        uint256 newFlowRate = originalFlowRate * 2; // twice the original flow rate
        lordship.updateFlowRate(newFlowRate);


 
        /////////////////////////////////////////////////////
        // staker claims reward at the 20th second 
        //////////////////////////////////////////////////////
        uint256 newTs = 20;
        vm.warp(newTs);

        // claim reward
        vm.prank(staker);
        lordship.claim();


        uint256 tsDiff = flowRateChangeTs - startTs;
        uint256 expectedRewardAmount =  tsDiff * originalFlowRate * numStakerRealms;
        uint256 balanceAfterFirstClaim = LORDS(LORDS_ADDRESS).balanceOf(staker);
        // ensure staker only gets rewards up to 12th second
        assertEq(
            balanceAfterFirstClaim, 
            expectedRewardAmount // should be unchanged
        );

         
        /////////////////////////////////////////////////////
        // staker claims reward at the 31st second where the new
        // flow rate should apply
        /////////////////////////////////////////////////////

        startTs = 20;
        newTs = 31;
        vm.warp(newTs);

        // claim reward
        vm.prank(staker);
        lordship.claim();


        tsDiff = newTs - startTs;
        uint256 newExpectedRewardAmount =  tsDiff * newFlowRate * numStakerRealms;
        assertEq(newExpectedRewardAmount, expectedRewardAmount * 2);

        // ensure staker only gets rewards from 20th second to 31st second
        // using the new flow rate
        assertEq(
            LORDS(LORDS_ADDRESS).balanceOf(staker) - balanceAfterFirstClaim, 
            newExpectedRewardAmount // should be unchanged
        );
    }



    function _stake(address _for, uint256[] memory stakerRealmIds) public {
        address staker = _for;
        REALMS realms = REALMS(REALMS_ERC721_ADDRESS);

        // mint numRealms realms to staker
        for (uint256 i = 0; i < stakerRealmIds.length; i++) {
            realms.mint(staker);
        }


        // staker stakes all realms and self delegates
        vm.startPrank(staker);
        ERC721(address(realms)).setApprovalForAll(address(lordship), true);

        ERC721Wrapper(address(lordship))
            .depositFor(staker, stakerRealmIds);
            
        Votes(address(lordship)).delegate(staker);

        vm.stopPrank();

    }

    function _unstake(address _for, uint256[] memory tokenIds) public {

        vm.startPrank(_for);

        ERC721Wrapper(address(lordship))
            .withdrawTo(_for, tokenIds);

        vm.stopPrank();
    }



}