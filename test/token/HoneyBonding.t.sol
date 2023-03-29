// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {Utilities} from "test/utils/Utilities.sol";

import {Honey} from "src/token/Honey.sol";
import {CrobeesAccessControls} from "src/access/CrobeesAccessControls.sol";
import {HoneyBonding} from "src/token/HoneyBonding.sol";

contract HoneyTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils = new Utilities();
    address payable[] internal users;
    address internal crobeesAddress;

    Honey internal token;
    HoneyBonding internal bonding;
    CrobeesAccessControls internal crobeesAccessControls;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(4);
        crobeesAddress = address(users[0]);
        vm.startPrank(crobeesAddress);
        crobeesAccessControls = new CrobeesAccessControls();
        token = new Honey(crobeesAddress, address(crobeesAccessControls));
        bonding = new HoneyBonding(address(token), uint128(block.timestamp + 1 days), crobeesAddress);
        token.transfer(address(bonding), 3_000_000 * 10 ** 18);
        token.transfer(address(users[1]), 1_000_000 * 10 ** 18);
        vm.stopPrank();
    }

    function testConstructor_ShouldSendRightAllocation_WhenDeployed() public {
        assertEq(token.balanceOf(address(bonding)), 3_000_000 * 10 ** 18);
    }
    
    function testConstructor_ShouldSetRightStartingTimestamp_WhenDeployed() public {
        assertEq(bonding.startingTimestamp(), block.timestamp + 1 days);
    }

    function testConstructor_ShouldSetRightCrobeesAddress_WhenDeployed() public {
        assertEq(bonding.crobeesAddress(), crobeesAddress);
    }

    function testConstructor_ShouldSetCorrectBondsConfiguration_WhenDeployed() public {
        (uint248 cA1, uint8 cA3) = bonding.bonds(HoneyBonding.Period.TwoWeeks, 0);
        (uint248 cA4, uint8 cA6) = bonding.bonds(HoneyBonding.Period.OneMonth, 0);
        (uint248 cA7, uint8 cA9) = bonding.bonds(HoneyBonding.Period.TwoMonths, 0);
        assertEq(cA1, 0);
        assertEq(bonding.getBondMaxAllocation(HoneyBonding.Period.TwoWeeks), 62_500 * 10 ** 18);
        assertEq(cA3, 10);

        assertEq(cA4, 0);
        assertEq(bonding.getBondMaxAllocation(HoneyBonding.Period.OneMonth), 125_000 * 10 ** 18);
        assertEq(cA6, 23);

        assertEq(cA7, 0);
        assertEq(bonding.getBondMaxAllocation(HoneyBonding.Period.TwoMonths), 250_000 * 10 ** 18);
        assertEq(cA9, 67);
    }

    function testGetBondsTimeframe_ShouldReturnRightTimeframe_WhenCalled() public {
        assertEq(bonding.getTimeframe(HoneyBonding.Period.TwoWeeks), 15 days);
        assertEq(bonding.getTimeframe(HoneyBonding.Period.OneMonth), 30 days);
        assertEq(bonding.getTimeframe(HoneyBonding.Period.TwoMonths), 60 days);
    }

    function testGetEpoch_ShouldReturnRightEpoch_WhenCalled() public {
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 0);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 0);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 0);

        vm.warp(block.timestamp +  1 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 0);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 0);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 0);

        vm.warp(block.timestamp +  15 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 1);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 0);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 0);

        vm.warp(block.timestamp +  14 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 1);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 0);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 0);

        vm.warp(block.timestamp +  1 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 2);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 1);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 0);

        vm.warp(block.timestamp +  30 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 4);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 2);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 1);

        vm.warp(block.timestamp + 180 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 16);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 8);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 4);

        vm.warp(block.timestamp + 480 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 48);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 24);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 12);
    }

    function testGetEpoch_ShouldReturnRightEpoch_WhenBondingHasEnded() public {
        vm.warp(block.timestamp +  1 days);
        vm.warp(block.timestamp +  720 days);

        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 48);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 24);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 12);
        vm.warp(block.timestamp + 180 days);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoWeeks), 48);
        assertEq(bonding.getEpoch(HoneyBonding.Period.OneMonth), 24);
        assertEq(bonding.getEpoch(HoneyBonding.Period.TwoMonths), 12);
    }

    function testBond_ShouldRevert_WhenNotStarted() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        vm.expectRevert(abi.encodeWithSignature("BondingNotStarted()"));
        bonding.bond(HoneyBonding.Period.TwoWeeks, 500 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenAmountIsZero() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        vm.expectRevert(HoneyBonding.NullAmount.selector);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenBondingHasEnded() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        vm.warp(block.timestamp +  790 days);

        vm.expectRevert(HoneyBonding.BondingHasEnded.selector);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 1_001 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenAmountExceedsUserMaxAllocation() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        vm.expectRevert(HoneyBonding.MaxUserAllocationExceeded.selector);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 6_251 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenNotEnoughHoney() public {
        vm.startPrank(address(users[1]));
        token.transfer(address(users[2]), 100 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(address(users[2]));
        token.approve(address(bonding), 10_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        vm.expectRevert(HoneyBonding.NotEnoughHoney.selector);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 101 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldSucceed_WhenAmountIsWithinUserMaxAllocation() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.stopPrank();

        (uint128 timestamp, uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoWeeks, 0);
        assertEq(timestamp, uint128(block.timestamp));
        assertEq(amount, 100 * 10 ** 18);
    }

    function testBond_ShouldRevert_WhenCalledTwice() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.expectRevert(HoneyBonding.UserAlreadyCommited.selector);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenEpoch0NotStarted() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.expectRevert(HoneyBonding.BondingNotStarted.selector);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenBondPool2WeeksIsFull() public {
        _fillBondingPool(HoneyBonding.Period.TwoWeeks);
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        vm.expectRevert(HoneyBonding.MaxPoolAllocationExceeded.selector);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenBondPool1MonthIsFull() public {
        _fillBondingPool(HoneyBonding.Period.OneMonth);
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        vm.expectRevert(HoneyBonding.MaxPoolAllocationExceeded.selector);
        bonding.bond(HoneyBonding.Period.OneMonth, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testBond_ShouldRevert_WhenBondPool2MonthsIsFull() public {
        _fillBondingPool(HoneyBonding.Period.TwoMonths);
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        vm.expectRevert(HoneyBonding.MaxPoolAllocationExceeded.selector);
        bonding.bond(HoneyBonding.Period.TwoMonths, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function _fillBondingPool(HoneyBonding.Period period) internal {
        address payable[] memory internalUsers = utils.createUsers(10);
        vm.warp(block.timestamp +  1 days);
        for (uint i = 0; i < internalUsers.length; i++) {
            vm.startPrank(crobeesAddress);
            token.transfer(internalUsers[i], bonding.getBondMaxAllocation(period) / 10);
            vm.stopPrank();
            vm.startPrank(address(internalUsers[i]));
            token.approve(address(bonding), 1_000_000 * 10 ** 18);
            bonding.bond(period, uint88(bonding.getBondMaxAllocation(period) / 10));
            vm.stopPrank();
        }
    }

    function testBondFuzz(uint88 _amount) public {
        vm.assume(_amount > 0 && _amount < 6250000000000000000001);
        vm.startPrank(address(users[1]));

        uint contractBalanceBefore = token.balanceOf(address(bonding));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, _amount);
        vm.stopPrank();

        (uint128 timestamp, uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoWeeks, 0);
        assertEq(timestamp, uint128(block.timestamp));
        assertEq(token.balanceOf(address(bonding)), contractBalanceBefore + _amount);
        assertEq(amount, _amount);
    }

    function testClaim_ShouldRevert_WhenEpochNotEnded() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.expectRevert(HoneyBonding.EpochNotEnded.selector);
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testClaim_ShouldRevert_WhenEpochValueIsGreaterThanTheCurrent() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.stopPrank();

        vm.warp(block.timestamp +  1 days);
        vm.expectRevert(HoneyBonding.BadEpoch.selector);
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 1);
        vm.stopPrank();
    }

    function testClaim_ShouldRevert_WhenRewardsAmountIsZero() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  15 days);
        vm.expectRevert(HoneyBonding.NullAmount.selector);
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testClaim_ShouldRevert_WhenClaimedTwice() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days);
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
        vm.warp(block.timestamp +  1 days);
        vm.expectRevert(HoneyBonding.NullAmount.selector);
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testClaim_TwoWeeksShouldSucceed() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        uint honeyBalanceBefore = token.balanceOf(address(users[1]));

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days);
        // 10% of rewards = 10 HONEY
        // 2% of fees on 110 HONEY = 2.2 HONEY
        // amount transfered to user = 100 + 10 - 2.2 = 107.8 HONEY 
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();

        (, uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoWeeks, 0);
        assertEq(amount, 0);

        uint honeyBalanceAfter = token.balanceOf(address(users[1]));
        assertEq(honeyBalanceAfter, honeyBalanceBefore + 7.8 ether);
    }

    function testClaim_OneMonthShouldSucceed() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        uint honeyBalanceBefore = token.balanceOf(address(users[1]));

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.OneMonth, 100 * 10 ** 18);

        vm.warp(block.timestamp +  30 days);
        // 23% of rewards = 23 HONEY
        // 2% of fees on 123 HONEY = 2.46 HONEY
        // rewards transfered to user = 20.54 HONEY
        bonding.claimBond(HoneyBonding.Period.OneMonth, 0);
        vm.stopPrank();

        (,uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.OneMonth, 0);
        assertEq(amount, 0);

        uint honeyBalanceAfter = token.balanceOf(address(users[1]));
        assertEq(honeyBalanceAfter, honeyBalanceBefore + 20.54 ether);
    }

    function testClaim_TwoMonthsShouldSucceed() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        uint honeyBalanceBefore = token.balanceOf(address(users[1]));

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoMonths, 100 * 10 ** 18);

        vm.warp(block.timestamp +  60 days);
        // 67% of rewards = 67 HONEY
        // 2% of fees on 167 HONEY = 3.34 HONEY
        // rewards transfered to user = 63.66 HONEY
        bonding.claimBond(HoneyBonding.Period.TwoMonths, 0);
        vm.stopPrank();

        (,uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoMonths, 0);
        assertEq(amount, 0);

        uint honeyBalanceAfter = token.balanceOf(address(users[1]));
        assertEq(honeyBalanceAfter, honeyBalanceBefore + 63.66 ether);
    }

    function testClaim_TwoWeeks_Fuzz(uint88 _amount) public {
        vm.assume(_amount > 0 && _amount < 6250000000000000000001);
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        uint honeyBalanceBefore = token.balanceOf(address(users[1]));

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, _amount);

        vm.warp(block.timestamp +  15 days);
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();

        (,uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoWeeks, 0);
        assertEq(amount, 0);

        uint honeyBalanceAfter = token.balanceOf(address(users[1]));
        uint rewards = _amount * 10 / 100;
        uint fees = (_amount + rewards) * 2 / 100;
        uint amountToTransfer = rewards - fees; 
        assert(
            honeyBalanceAfter == honeyBalanceBefore + amountToTransfer || 
            honeyBalanceAfter == honeyBalanceBefore + amountToTransfer + 1
        );
    }

    function testClaim_OneMonth_Fuzz(uint88 _amount) public {
        vm.assume(_amount > 0 && _amount < 12500000000000000000001);
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        uint honeyBalanceBefore = token.balanceOf(address(users[1]));

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.OneMonth, _amount);

        vm.warp(block.timestamp +  30 days);
        bonding.claimBond(HoneyBonding.Period.OneMonth, 0);
        vm.stopPrank();

        (,uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.OneMonth, 0);
        assertEq(amount, 0);

        uint honeyBalanceAfter = token.balanceOf(address(users[1]));
        uint rewards = _amount * 23 / 100;
        uint fees = (_amount + rewards) * 2 / 100;
        uint amountToTransfer = rewards - fees; 
        assert(
            honeyBalanceAfter == honeyBalanceBefore + amountToTransfer || 
            honeyBalanceAfter == honeyBalanceBefore + amountToTransfer + 1
        );
    }

    function testClaim_TwoMonths_Fuzz(uint88 _amount) public {
        vm.assume(_amount > 0 && _amount < 25000000000000000000001);
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        uint honeyBalanceBefore = token.balanceOf(address(users[1]));

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoMonths, _amount);

        vm.warp(block.timestamp +  60 days);
        bonding.claimBond(HoneyBonding.Period.TwoMonths, 0);
        vm.stopPrank();

        (, uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoMonths, 0);
        assertEq(amount, 0);

        uint honeyBalanceAfter = token.balanceOf(address(users[1]));
        uint rewards = _amount * 67 / 100;
        uint fees = (_amount + rewards) * 2 / 100;
        uint amountToTransfer = rewards - fees; 
        assert(
            honeyBalanceAfter == honeyBalanceBefore + amountToTransfer || 
            honeyBalanceAfter == honeyBalanceBefore + amountToTransfer + 1
        );
    }

    function testCompound_ShouldRevert_WhenNoRewards() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  16 days);
        vm.expectRevert(HoneyBonding.NullAmount.selector);
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testCompound_ShouldRevert_WhenCalledBeforeEpochEnded() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  14 days);
        vm.expectRevert(HoneyBonding.EpochNotEnded.selector);
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testCompound_ShouldRevert_WhenNextEpochsPoolIsFull() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days + 1 seconds);
        vm.stopPrank();
        _fillBondingPool(HoneyBonding.Period.TwoWeeks);
        
        vm.startPrank(address(users[1]));
        vm.expectRevert(HoneyBonding.MaxPoolAllocationExceeded.selector);
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testCompound_ShouldRevert_WhenUserHasAlreadyCommitedInTheNextEpoch() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days + 1 seconds);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.expectRevert(HoneyBonding.UserAlreadyCommited.selector);
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
    }

    function testCompound_ShouldRevert_WhenCompoundForAFutureEpoch() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days + 1 seconds);
        vm.expectRevert(HoneyBonding.EpochNotEnded.selector);
        bonding.compound(HoneyBonding.Period.OneMonth, 2);
        vm.stopPrank();
    }

    /// @notice Test a successful compound
    function testCompound_ShouldSucceed() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days + 1 seconds);
        // 10 $HONEY of rewards
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);
        // 110 $HONEY should be compound in the new epoch
        vm.stopPrank();

        (uint128 timestamp, uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoWeeks, 1);
        assertEq(amount, 110 * 10 ** 18);
        assertEq(timestamp, uint128(block.timestamp));
    }

    function testCompound_ShouldRevert_WhenAlreadyClaimed() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days + 1 seconds);
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
        vm.expectRevert();
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);
    }

    function testClaim_ShouldRevert_WhenAlreadyCompounded() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);

        vm.warp(block.timestamp +  15 days + 1 seconds);
        // 10 $HONEY of rewards
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);

        vm.expectRevert();
        bonding.claimBond(HoneyBonding.Period.TwoWeeks, 0);
    }

    function testCompound_ShouldSucceed_WhenNextPoolEpochIsNotFull() public {
        vm.startPrank(address(users[1]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);

        vm.warp(block.timestamp +  1 days);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 100 * 10 ** 18);
        vm.stopPrank();
        vm.warp(block.timestamp +  15 days + 1 seconds);
        // 110 $HONEY should be compound in the new epoch


        address payable[] memory internalUsers = utils.createUsers(9);
        for (uint i = 0; i < internalUsers.length; i++) {
            vm.startPrank(crobeesAddress);
            token.transfer(internalUsers[i], bonding.getBondMaxAllocation(HoneyBonding.Period.TwoWeeks) / 10);
            vm.stopPrank();
            vm.startPrank(address(internalUsers[i]));
            token.approve(address(bonding), 1_000_000 * 10 ** 18);
            bonding.bond(HoneyBonding.Period.TwoWeeks, uint88(bonding.getBondMaxAllocation(HoneyBonding.Period.TwoWeeks) / 10));
            vm.stopPrank();
        }
        // 56 250 HONEY in the pool

        address payable[] memory newUser = utils.createUsers(1);
        vm.startPrank(crobeesAddress);
        token.transfer(newUser[0], bonding.getBondMaxAllocation(HoneyBonding.Period.TwoWeeks) / 10);
        vm.stopPrank();

        vm.startPrank(address(newUser[0]));
        token.approve(address(bonding), 1_000_000 * 10 ** 18);
        bonding.bond(HoneyBonding.Period.TwoWeeks, 6200 ether); // 56 250 + 6200 = 62 450 HONEY in the pool
        vm.stopPrank();
        
        // 50 $HONEY compound in the new epoch
        // 2% of 60 HONEY = 1.2 HONEY -> fees
        // 60 - 1.2 = 58.8 HONEY -> amount transfered to user
        uint256 balanceBefore = token.balanceOf(address(users[1]));
        vm.startPrank(address(users[1]));
        bonding.compound(HoneyBonding.Period.TwoWeeks, 0);
        vm.stopPrank();
        uint256 balanceAfter = token.balanceOf(address(users[1]));

        (, uint128 amount) = bonding.bonders(address(users[1]), HoneyBonding.Period.TwoWeeks, 1);
        assertEq(amount, 50 ether);
        assertEq(balanceAfter - balanceBefore, 58.8 ether);
    }

    function testWithdraw_ShouldRevert_WhenCalledByNotOwner() public {
        vm.startPrank(address(users[1]));
        vm.expectRevert("HoneyBonding: only crobees");
        bonding.withdrawHoney();
    }

    function testWithdraw_ShouldRevert_WhenCalledBeforeEnding() public {
        vm.startPrank(crobeesAddress);
        vm.expectRevert(HoneyBonding.EpochNotEnded.selector);
        bonding.withdrawHoney();
    }

    function testWithdraw_ShouldSucceed() public {
        vm.startPrank(crobeesAddress);
        vm.warp(block.timestamp +  721 days);
        bonding.withdrawHoney();
    }

    function testGetCurrentBondStartingTimestamp_ShouldGetTheRightTimestamp() public {
        uint256 timestampTwoWeeks = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoWeeks);
        uint256 timestampOneMonth = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.OneMonth);
        uint256 timestampTwoMonths = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoMonths);
        uint256 startingTimestamp = block.timestamp + 1 days;

        assertEq(timestampTwoWeeks, startingTimestamp);
        assertEq(timestampOneMonth, startingTimestamp);
        assertEq(timestampTwoMonths, startingTimestamp);

        vm.warp(block.timestamp +  16 days);
        timestampTwoWeeks = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoWeeks);
        timestampOneMonth = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.OneMonth);
        timestampTwoMonths = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoMonths);
        assertEq(timestampTwoWeeks, startingTimestamp + 15 days);
        assertEq(timestampOneMonth, startingTimestamp);
        assertEq(timestampTwoMonths, startingTimestamp);

        vm.warp(block.timestamp +  16 days);
        timestampTwoWeeks = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoWeeks);
        timestampOneMonth = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.OneMonth);
        timestampTwoMonths = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoMonths);
        assertEq(timestampTwoWeeks, startingTimestamp + 30 days);
        assertEq(timestampOneMonth, startingTimestamp + 30 days);
        assertEq(timestampTwoMonths, startingTimestamp);

        vm.warp(block.timestamp +  31 days);
        timestampTwoWeeks = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoWeeks);
        timestampOneMonth = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.OneMonth);
        timestampTwoMonths = bonding.getCurrentBondStartingTimestamp(HoneyBonding.Period.TwoMonths);
        assertEq(timestampTwoWeeks, startingTimestamp + 60 days);
        assertEq(timestampOneMonth, startingTimestamp + 60 days);
        assertEq(timestampTwoMonths, startingTimestamp + 60 days);
    }

    function testGetCurrentBondEpochTimestampInfo_ShouldGetTheRightTimestamps() public {
        uint256 startingTimestamp = block.timestamp + 1 days;
        (uint256 epochStart, uint256 epochEnd) = bonding.getCurrentBondEpochTimestampInfo(HoneyBonding.Period.TwoWeeks);
        assertEq(epochStart, startingTimestamp);
        assertEq(epochEnd, startingTimestamp + 15 days);

        vm.warp(block.timestamp +  16 days);
        (epochStart, epochEnd) = bonding.getCurrentBondEpochTimestampInfo(HoneyBonding.Period.TwoWeeks);
        assertEq(epochStart, startingTimestamp + 15 days);
        assertEq(epochEnd, startingTimestamp + 15 days + 15 days);
    }
}