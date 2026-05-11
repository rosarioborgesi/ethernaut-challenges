// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {GatekeeperOne} from "src/challenge-13-gatekeeper-one/GatekeeperOne.sol";
import {GatekeeperOneAttacker} from "src/challenge-13-gatekeeper-one/GatekeeperOneAttacker.sol";

contract GatekeeperOneTest is Test {
    address constant MY_ADDRESS = 0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0;
    GatekeeperOne gatekeeper;
    GatekeeperOneAttacker attacker;

    function setUp() public {
        gatekeeper = new GatekeeperOne();
        attacker = new GatekeeperOneAttacker(address(gatekeeper));
    }

    function testEnters() public {
        vm.prank(MY_ADDRESS, MY_ADDRESS); // both msg.sender and tx.origin are MY_ADDRESS
        bool entered = attacker.attack();
        assertTrue(entered);
    }
}
