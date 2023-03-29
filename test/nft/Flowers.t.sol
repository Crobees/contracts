// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {Utilities} from "test/utils/Utilities.sol";

import {FlowersMock} from "src/mock/Flowers.sol";
import {mockERC20} from "src/mock/mockERC20.sol";
import {mockERC721} from "src/mock/mockERC721.sol";
import {mockERC1155} from "src/mock/mockERC1155.sol";

contract FlowersTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils = new Utilities();
    address payable[] internal users;
    address internal crobeesAddress;
    address internal feesAddress = 0xFbfF4df52bD43D7AbC1fD9c5a9A29b856c4866c5;
    address[] internal airdropUsers;

    FlowersMock internal flowers;
    mockERC20 internal honey;
    mockERC721 internal bees;
    mockERC721 internal moonflow;
    mockERC1155 internal ruggedBees;
    
    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(6);
        crobeesAddress = address(users[0]);
        honey = new mockERC20();
        bees = new mockERC721();
        ruggedBees = new mockERC1155();
        moonflow = new mockERC721();
        flowers = new FlowersMock(
            "https://ifps/cid/", 
            address(ruggedBees),
            address(bees),
            address(honey),
            address(moonflow),
            uint128(block.timestamp),
            60
        );
        flowers.transferOwnership(users[5]);
    }

    function testMint_ShouldRevert_WhenTooEarly() public {
        FlowersMock flowers_test_timestamp = new FlowersMock(
            "https://ifps/cid/", 
            address(ruggedBees),
            address(bees),
            address(honey),
            address(moonflow),
            uint128(block.timestamp + 1000),
            60
        );
        flowers_test_timestamp.transferOwnership(users[5]);
        vm.startPrank(users[1]);
        vm.expectRevert();
        flowers_test_timestamp.mint{value: 75 ether}(1);
        vm.stopPrank();
    }

    function testPrice_ShouldSetTheRightPrice_WhenDifferentHolders() public {
        bees.mint(users[1], 3);
        moonflow.mint(users[2], 3);
        ruggedBees.mint(users[3], 3, 1);
        assertEq(flowers.mintCost(users[1]), 25 ether);

        bees.mint(users[2], 1);
        assertEq(flowers.mintCost(users[2]), 25 ether);

        moonflow.mint(users[3], 1);
        assertEq(flowers.mintCost(users[3]), 50 ether);

        assertEq(flowers.mintCost(users[4]), 75 ether);
    }

    function testMint_ShouldRevert_WhenExceedMaxAmountPerTx() public {
        bees.mint(users[1], 1);
        bees.mint(users[2], 1);
        bees.mint(users[3], 1);

        vm.startPrank(users[1]);
        vm.expectRevert();
        flowers.mint{value: 400 ether}(16);
        vm.stopPrank();

        vm.startPrank(users[2]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();
    }

    function testCanMintEthSupply_ShouldGetTheRightValue() public {
        assertEq(flowers.canMint(), 15);

        bees.mint(users[1], 1);
        bees.mint(users[2], 1);
        bees.mint(users[3], 1);

        vm.startPrank(users[1]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();

        assertEq(flowers.canMint(), 15);
        assertEq(flowers.balanceOf(users[1]), 10);

        vm.startPrank(users[2]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();

        assertEq(flowers.canMint(), 10);
        assertEq(flowers.balanceOf(users[2]), 10);

        vm.startPrank(users[3]);
        vm.expectRevert();
        flowers.mint{value: 275 ether}(11);
        vm.stopPrank();
    }

    function testMint_ShouldRevert_WhenFrozen() public {
        vm.startPrank(users[5]);
        flowers.freezeMint();
        bees.mint(users[1], 1);
        vm.stopPrank();

        vm.startPrank(users[1]);
        vm.expectRevert();
        flowers.mint{value: 25 ether}(1);
        vm.stopPrank();
    }

    function testEthMint_ShouldRevert_WhenNotEnoughEth() public {
        vm.startPrank(users[1]);
        vm.expectRevert();
        flowers.mint{value: 25 ether}(1);
        vm.stopPrank();

        vm.startPrank(users[2]);
        vm.expectRevert();
        flowers.mint{value: 50 ether}(1);
        vm.stopPrank();

        vm.startPrank(users[3]);
        flowers.mint{value: 75 ether}(1);
        vm.stopPrank();
    }

    function testEthMint_ShouldRevert_WhenEmptyAmount() public {
        vm.startPrank(users[1]);
        vm.expectRevert();
        flowers.mint{value: 25 ether}(0);
        vm.stopPrank();
    }

    function testEthMint_ShouldRevert_WhenSoldOut() public {
        bees.mint(users[1], 1);
        bees.mint(users[2], 1);
        bees.mint(users[3], 1);
        bees.mint(users[4], 1);

        vm.startPrank(users[1]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();

        vm.startPrank(users[2]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();

        vm.startPrank(users[3]);
        flowers.mint{value: 125 ether}(5);
        vm.stopPrank();

        assertEq(flowers.canMint(), 5);

        vm.startPrank(users[3]);
        flowers.mint{value: 125 ether}(5);
        vm.stopPrank();

        vm.startPrank(users[4]);
        vm.expectRevert();
        flowers.mint{value: 125 ether}(5);
        vm.stopPrank();
    }

    function testEthMint_ShouldTransferFees1() public {
        uint256 balance = feesAddress.balance;
        uint256 balanceContract = address(flowers).balance;
        vm.startPrank(users[1]);
        bees.mint(users[1], 1);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();

        assertEq(feesAddress.balance, balance + 15 ether);
        assertEq(address(flowers).balance, balanceContract + 235 ether);
    }

    function testEthMint_ShouldTransferFees2() public {
        uint256 balance = feesAddress.balance;
        uint256 balanceContract = address(flowers).balance;
        vm.startPrank(users[1]);
        bees.mint(users[1], 1);
        flowers.mint{value: 25 ether}(1);
        vm.stopPrank();

        assertEq(feesAddress.balance, balance + 1.5 ether);
        assertEq(address(flowers).balance, balanceContract + 23.5 ether);
    }

    function soldoutEthSupply() internal {
        bees.mint(users[1], 1);

        vm.startPrank(users[1]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();

        vm.startPrank(users[1]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();

        vm.startPrank(users[1]);
        flowers.mint{value: 250 ether}(10);
        vm.stopPrank();
    }

    function testHoneyMint_ShouldGetTheRightMintPrice() public {
        soldoutEthSupply();
        bees.mint(users[1], 1);

        honey.mint(users[1], 10000 ether);

        assertEq(flowers.mintCost(users[1]), 250 ether);
    }

    function testHoneyMint_ShouldMint_WhenEnoughHoneyBalance() public {
        soldoutEthSupply();
        honey.mint(users[0], 10000 ether);

        vm.startPrank(users[0]);
        honey.approve(address(flowers), 10000 ether);
        flowers.mint(10);
        vm.stopPrank();

        assertEq(flowers.balanceOf(users[0]), 10);
        assertEq(honey.balanceOf(users[0]), 7500 ether);
    }

    function testHoneyMint_ShouldRevert_WhenNotEnoughSupply() public {
        soldoutEthSupply();
        honey.mint(users[0], 10000 ether);

        vm.startPrank(users[0]);
        flowers.mint(15);
        vm.expectRevert();
        flowers.mint(6);
        vm.stopPrank();
    }

    function testHoneyMint_ShouldRevert_WhenNotEnoughHoneyBalance() public {
        soldoutEthSupply();
        honey.mint(users[0], 1000 ether);

        vm.startPrank(users[0]);
        honey.approve(address(flowers), 1000 ether);
        vm.expectRevert();
        flowers.mint(5);
        
        flowers.mint(4);
        vm.stopPrank();
        assertEq(flowers.balanceOf(users[0]), 4);
        assertEq(honey.balanceOf(users[0]), 0 ether);
    }

    function testHoneyMint_ShouldGetTheRightMintAmount() public {
        soldoutEthSupply();
        honey.mint(users[0], 10000 ether);
        assertEq(flowers.canMint(), 15);

        vm.startPrank(users[0]);
        honey.approve(address(flowers), 10000 ether);
        flowers.mint(15);
        vm.stopPrank();

        assertEq(flowers.balanceOf(users[0]), 15);
        assertEq(flowers.canMint(), 5);

        vm.startPrank(users[0]);
        flowers.mint(5);
        vm.expectRevert();
        flowers.mint(1);
        vm.stopPrank();

        assertEq(flowers.canMint(), 0);
    }

    function soldoutHoneySupply() internal {
        soldoutEthSupply();
        honey.mint(users[2], 10000 ether);
        vm.startPrank(users[2]);
        flowers.mint(10);
        flowers.mint(10);
        vm.stopPrank();
    }

    function testAirdrop_ShouldRevert_WhenMintNotFinished() public {
        airdropUsers.push(users[0]);
        vm.startPrank(users[5]);
        vm.expectRevert();
        flowers.airdrop(airdropUsers);
        vm.stopPrank();
    }

    function testAirdrop_ShouldSucced_WhenMintFinished() public {
        soldoutHoneySupply();
        airdropUsers.push(users[3]);
        airdropUsers.push(users[4]);

        vm.startPrank(users[5]);
        flowers.airdrop(airdropUsers);
        assertEq(flowers.balanceOf(users[3]), 1);
        assertEq(flowers.balanceOf(users[4]), 1);
        vm.stopPrank();
    }

    function testAirdrop_ShouldRevert_WhenSupplySoldOut() public {
        soldoutHoneySupply();

        for (uint i = 0; i < 11; i++) {
            airdropUsers.push(users[3]);
        }
        vm.startPrank(users[5]);
        vm.expectRevert();
        flowers.airdrop(airdropUsers);
        vm.stopPrank();
    }

    function testWhithDraw_ShouldRevert_WhenNotOwner() public {
        vm.startPrank(users[1]);
        vm.expectRevert();
        flowers.withdraw();
        vm.stopPrank();
    }

    function testWhitdraw_ShouldSucceed_WhenOwner() public {
        uint256 balance = address(users[5]).balance;
        soldoutHoneySupply();
        uint256 balanceContract  = address(flowers).balance;

        vm.startPrank(users[5]);
        flowers.withdraw();
        assertEq(address(users[5]).balance, balance + balanceContract);
        vm.stopPrank();
    }
}