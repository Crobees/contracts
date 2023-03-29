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

    function testAddRole_ShouldSucceed_WhenCalledByAdmin() public {
        vm.startPrank(crobeesAddress);
        crobeesAccessControls.addBurnerRole(address(users[1]));

        token.transfer(address(users[1]), 100);
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        token.burn(100);
        vm.stopPrank();
    }

    function testAddRole_ShouldRevert_WhenCalledByUser() public {
        vm.startPrank(address(users[1]));
        vm.expectRevert();
        crobeesAccessControls.addBurnerRole(address(users[1]));
        vm.expectRevert();
        crobeesAccessControls.addAdminRole(address(users[1]));
        vm.stopPrank();
    }

    function testRemoveRole_ShouldRevert_WhenCalledByUser() public {
        vm.startPrank(crobeesAddress);
        crobeesAccessControls.addBurnerRole(address(users[1]));
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        vm.expectRevert();
        crobeesAccessControls.removeBurnerRole(address(users[1]));
        vm.expectRevert();
        crobeesAccessControls.removeAdminRole(address(crobeesAddress));
        vm.stopPrank();
    }

    function testRemoveRole_ShouldSucceed_WhenCalledByAdmin() public {
        vm.startPrank(crobeesAddress);
        crobeesAccessControls.addAdminRole(address(users[1]));
        assert(crobeesAccessControls.hasAdminRole(address(users[1])));
        crobeesAccessControls.addBurnerRole(address(users[1]));
        token.transfer(address(users[1]), 200);
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        token.burn(100);
        vm.stopPrank();

        vm.startPrank(crobeesAddress);
        crobeesAccessControls.removeBurnerRole(address(users[1]));
        crobeesAccessControls.removeAdminRole(address(users[1]));
        assert(!crobeesAccessControls.hasAdminRole(address(users[1])));
        vm.stopPrank();

        vm.startPrank(address(users[1]));
        vm.expectRevert();
        token.burn(100);
        vm.stopPrank();
    }
    
}