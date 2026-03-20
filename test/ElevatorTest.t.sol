// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Elevator} from "../src/challenge-11-elevator/Elevator.sol";
import {ElevatorAttacker} from "../src/challenge-11-elevator/ElevatorAttacker.sol";

contract ElevatorTest is Test {
    Elevator elevator;
    ElevatorAttacker attacker;

    function setUp() public {
        elevator = new Elevator();
        attacker = new ElevatorAttacker(address(elevator));
    }

    function testAttackDoesntRevert() public {
        vm.prank(address(attacker));
        attacker.attack();
    }
}