// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {GatekeeperTwo} from "../src/challenge-14-gatekeeper-two/GatekeeperTwo.sol";
import {GatekeeperTwoAttacker} from "../src/challenge-14-gatekeeper-two/GatekeeperTwoAttacker.sol";

contract GatekeeperTwoTest is Test {
    GatekeeperTwo gatekeeper;
    GatekeeperTwoAttacker attacker;
    address USER = makeAddr("user");

    function setUp() public {
        gatekeeper = new GatekeeperTwo();
        vm.prank(USER, USER); // Set both msg.sender and tx.origin
        attacker = new GatekeeperTwoAttacker(address(gatekeeper));
    }

    function testEnter() public {
        assertEq(gatekeeper.entrant(), USER);
    }
}
