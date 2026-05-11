// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Switch} from "src/challenge-29-switch/Switch.sol";
import {SwitchAttacker} from "src/challenge-29-switch/SwitchAttacker.sol";

contract SwitchTest is Test {
    Switch public switchContract;
    SwitchAttacker public attacker;

    function setUp() public {
        switchContract = new Switch();
        attacker = new SwitchAttacker(address(switchContract));

        vm.label(address(switchContract), "Switch");
        vm.label(address(attacker), "Attacker");
    }

    function testAttack() public {
        attacker.attack();
        assertTrue(switchContract.switchOn());
    }
}
