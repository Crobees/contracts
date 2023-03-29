// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {Utilities} from "test/utils/Utilities.sol";

import {Honey} from "src/token/Honey.sol";
import {CrobeesAccessControls} from "src/access/CrobeesAccessControls.sol";

contract HoneyTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils = new Utilities();
    address payable[] internal users;
    address internal crobeesAddress;

    Honey internal token;
    CrobeesAccessControls internal crobeesAccessControls;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(4);
        crobeesAddress = address(users[0]);
        vm.startPrank(crobeesAddress);
        crobeesAccessControls = new CrobeesAccessControls();
        token = new Honey(crobeesAddress, address(crobeesAccessControls));
        vm.stopPrank();
    }

    function testTotalSupply() public {
        assertEq(token.totalSupply(), 10_000_000 * 10 ** 18);
    }

    function testBurn_ShouldSucceed_WhenCalledByBurnerRole() public {
        vm.startPrank(crobeesAddress);
        token.burn(100);
        vm.stopPrank();
    }

    function testBurn_ShouldRevert_WhenCalledByLambdaUser() public {
        vm.startPrank(crobeesAddress);
        token.transfer(address(users[1]), 100);
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        vm.expectRevert();
        token.burn(100);
        vm.stopPrank();
    }

    function testBurn_ShouldSucceed_WhenOtherUserApprovedBurnerRole() public {
        vm.startPrank(crobeesAddress);
        token.transfer(address(users[1]), 100);
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        token.approve(crobeesAddress, 100);
        vm.stopPrank();

        vm.startPrank(crobeesAddress);
        token.burnFrom(address(users[1]), 100);
        vm.stopPrank();
    }   

    function testBurnFrom_ShouldRevert_WhenOtherUserDoesNotApprovedSpender() public {
        vm.startPrank(crobeesAddress);
        vm.expectRevert();
        token.burnFrom(address(users[1]), 1);
        vm.stopPrank();
    }

    function testBurnFrom_ShouldRevert_WhenOtherUsersAllowanceIsLessThanAmount() public {
        vm.startPrank(crobeesAddress);
        token.transfer(address(users[1]), 100);
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        token.approve(crobeesAddress, 100);
        vm.stopPrank();

        vm.startPrank(crobeesAddress);
        vm.expectRevert();
        token.burnFrom(address(users[1]), 200);
        vm.stopPrank();
    }

    function testBurnFrom_ShouldRevert_WhenFromOtherUser() public {
        vm.startPrank(crobeesAddress);
        token.transfer(address(users[1]), 100);
        vm.expectRevert();
        token.burnFrom(address(users[1]), 100);
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        vm.expectRevert();
        token.burnFrom(address(users[1]), 100);
        vm.stopPrank();
    }

    function testBurnFrom_ShouldRevert_WhenCalledByLambdaUser() public {
        vm.startPrank(crobeesAddress);
        token.transfer(address(users[1]), 100);
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        vm.expectRevert();
        token.burnFrom(msg.sender, 100);
        vm.stopPrank();
    }

    function testTransfer_ShouldSucceed_WhenEnoughBalance() public {
        vm.prank(crobeesAddress);
        token.transfer(users[1], 100 ether);
    }

    function testTransfer_ShouldRevert_WhenNotEnoughBalance() public {
        vm.prank(crobeesAddress);
        token.transfer(users[1], 100 ether);

        vm.prank(users[1]);
        vm.expectRevert();
        token.transfer(crobeesAddress, 101 ether);
        assertEq(100 ether, token.balanceOf(users[1]));
        
        // should succeed now
        vm.prank(users[1]);
        token.transfer(crobeesAddress, 100 ether);
        assertEq(0, token.balanceOf(users[1]));
    }

    function testTransferFrom_ShouldRevert_WhenNotEnoughAllowance() public {
        vm.prank(users[1]);
        vm.expectRevert();
        token.transferFrom(crobeesAddress, users[1], 100 ether);
    }

    function testTransferFrom_ShouldSucceed_WhenEnoughAllowance() public {
        // should succeed now
        vm.prank(crobeesAddress);
        token.approve(users[1], 100 ether);

        assertEq(0 ether, token.balanceOf(users[1]));
        vm.prank(users[1]);
        token.transferFrom(crobeesAddress, users[1], 100 ether);
        assertEq(100 ether, token.balanceOf(users[1]));
    }

    function testTransferFrom_ShouldRevert_WhenAlreadySpendAllowance() public {
        vm.prank(crobeesAddress);
        token.approve(users[1], 100 ether);

        vm.startPrank(users[1]);
        token.transferFrom(crobeesAddress, users[1], 100 ether);
        vm.expectRevert();
        token.transferFrom(crobeesAddress, users[1], 100 ether);
    }
}
